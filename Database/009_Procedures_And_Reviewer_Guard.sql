USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
-- Converts the ad-hoc SQL text that used to live in PortfolioController.cs into stored procedures.
CREATE OR ALTER PROCEDURE dbo.sp_GetBudgetSources
AS
BEGIN
 SET NOCOUNT ON;
 SELECT * FROM dbo.BudgetSources ORDER BY BudgetType,ExternalId;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_GetJiraRegistrationCandidates @ProjectKey nvarchar(20), @AccountableExec nvarchar(200)
AS
BEGIN
 SET NOCOUNT ON;
 SELECT ParentJiraID, * FROM dbo.JiraIssues
 WHERE ProjectKey = @ProjectKey
   AND AccountableExec = @AccountableExec
   AND ISNULL(Status,'') NOT IN ('FAST TRACK. ADDL INFO REQUIRED','Doability – Addl.Info','DO - BRD PREPARATION - STRATEGIC','DO INCOMPLETE / ADD. INFO REQUIRED','Live – Pending Business Feedback','IT BP REVIEW','Demand On Hold','Deferred','Live','Tech No Capacity','Completed','Cancelled')
 ORDER BY JiraUpdated DESC;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_GetJiraProjectPlan @ProjectKey nvarchar(20), @AccountableExec nvarchar(200)
AS
BEGIN
 SET NOCOUNT ON;
 SELECT * FROM dbo.JiraIssues WHERE ParentJiraID IN (
   SELECT JiraID FROM dbo.JiraIssues
   WHERE ProjectKey = @ProjectKey
     AND AccountableExec = @AccountableExec
     AND ISNULL(Status,'') NOT IN ('FAST TRACK. ADDL INFO REQUIRED','Doability – Addl.Info','DO - BRD PREPARATION - STRATEGIC','DO INCOMPLETE / ADD. INFO REQUIRED','Live – Pending Business Feedback','IT BP REVIEW','Demand On Hold','Deferred','Live','Tech No Capacity','Completed','Cancelled')
 )
 ORDER BY JiraUpdated DESC;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_GetProjectDetail @ProjectId int
AS
BEGIN
 SET NOCOUNT ON;
 SELECT * FROM dbo.vw_ProjectPortfolio WHERE ProjectId=@ProjectId;
 SELECT * FROM dbo.PETRequests WHERE ProjectId=@ProjectId ORDER BY CreatedUtc;
 SELECT s.* FROM dbo.SpendItems s JOIN dbo.PETRequests p ON p.PetId=s.PetId WHERE p.ProjectId=@ProjectId;
 SELECT b.* FROM dbo.BudgetLines b JOIN dbo.PETRequests p ON p.PetId=b.PetId WHERE p.ProjectId=@ProjectId;
 SELECT i.* FROM dbo.Invoices i JOIN dbo.BudgetLines b ON b.BudgetLineId=i.BudgetLineId JOIN dbo.PETRequests p ON p.PetId=b.PetId WHERE p.ProjectId=@ProjectId;
 SELECT AttachmentId,EntityType,EntityId,OriginalName,ContentType,FileSize,UploadedUtc FROM dbo.Attachments WHERE (EntityType='Project' AND EntityId=@ProjectId) OR (EntityType='PET' AND EntityId IN (SELECT PetId FROM dbo.PETRequests WHERE ProjectId=@ProjectId));
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_InsertAttachment
 @EntityType nvarchar(30), @EntityId int, @OriginalName nvarchar(260), @StoredName nvarchar(260),
 @ContentType nvarchar(150), @FileSize bigint, @UploadedBy nvarchar(254)
AS
BEGIN
 SET NOCOUNT ON;
 INSERT dbo.Attachments(EntityType,EntityId,OriginalName,StoredName,ContentType,FileSize,UploadedBy)
 VALUES(@EntityType,@EntityId,@OriginalName,@StoredName,@ContentType,@FileSize,@UploadedBy);
END;
GO
-- Workflow history for the PET history popup; resolves ActionBy (an email) to the user's display name.
CREATE OR ALTER PROCEDURE dbo.sp_GetWorkflowHistory @PetId int
AS
BEGIN
 SET NOCOUNT ON;
 SELECT wh.WorkflowHistoryId, wh.FromStatus, wh.ToStatus, COALESCE(u.DisplayName, wh.ActionBy) ActionByName, wh.Comments, wh.ActionUtc
 FROM dbo.WorkflowHistory wh LEFT JOIN dbo.Users u ON u.Email=wh.ActionBy
 WHERE wh.PetId=@PetId ORDER BY wh.ActionUtc;
END;
GO
-- Only the person named as AccountableExecLead (review stage) or AccountableExec (approval stage) on the
-- project may act on its PETs - matched against the logged-in user's Users.DisplayName (Email is the login id).
CREATE OR ALTER PROCEDURE dbo.sp_PetDecision @PetId int,@Stage nvarchar(20),@Approve bit,@Comments nvarchar(2000),@User nvarchar(254)
AS
BEGIN SET XACT_ABORT ON; BEGIN TRAN;
 DECLARE @Old nvarchar(50),@New nvarchar(50),@Amount decimal(19,2),@BudgetSource int,@Available decimal(19,2),@ProjectId int;
 DECLARE @ExecLead nvarchar(200),@Exec nvarchar(200),@UserDisplayName nvarchar(200);
 SELECT @Old=pet.Status,@Amount=pet.RequestedAmount,@ProjectId=pet.ProjectId,@BudgetSource=p.BudgetSourceId,@ExecLead=p.AccountableExecLead,@Exec=p.AccountableExec
 FROM dbo.PETRequests pet WITH(UPDLOCK) JOIN dbo.Projects p ON p.ProjectId=pet.ProjectId WHERE pet.PetId=@PetId;
 SET @UserDisplayName=(SELECT DisplayName FROM dbo.Users WHERE Email=@User);
 IF @Stage='Review' AND (LTRIM(RTRIM(ISNULL(@UserDisplayName,''))) <> LTRIM(RTRIM(ISNULL(@ExecLead,''))) OR @UserDisplayName IS NULL)
  THROW 50009,'Only the assigned Accountable Executive Lead can review this PET.',1;
 IF @Stage='Approval' AND (LTRIM(RTRIM(ISNULL(@UserDisplayName,''))) <> LTRIM(RTRIM(ISNULL(@Exec,''))) OR @UserDisplayName IS NULL)
  THROW 50009,'Only the assigned Accountable Executive can approve this PET.',1;
 IF @Stage='Review' AND @Old<>'Pending Review' THROW 50002,'PET is not awaiting review.',1;
 IF @Stage='Approval' AND @Old<>'Pending Approval' THROW 50003,'PET is not awaiting approval.',1;
 SET @New=CASE WHEN @Approve=0 THEN 'Rejected' WHEN @Stage='Review' THEN 'Pending Approval' ELSE 'Approved' END;
 IF @New='Approved' BEGIN SELECT @Available=AvailableBudget FROM dbo.BudgetSources WITH(UPDLOCK) WHERE BudgetSourceId=@BudgetSource; IF @Available<@Amount THROW 50004,'Insufficient remaining budget.',1; UPDATE dbo.BudgetSources SET Utilization=Utilization+@Amount,AvailableBudget=AvailableBudget-@Amount,NetBalance=NetBalance-@Amount,UpdatedUtc=SYSUTCDATETIME() WHERE BudgetSourceId=@BudgetSource; END
 UPDATE dbo.PETRequests SET Status=@New,ReviewerEmail=CASE WHEN @Stage='Review' THEN @User ELSE ReviewerEmail END,ReviewComments=CASE WHEN @Stage='Review' THEN @Comments ELSE ReviewComments END,ReviewedUtc=CASE WHEN @Stage='Review' THEN SYSUTCDATETIME() ELSE ReviewedUtc END,ApproverEmail=CASE WHEN @Stage='Approval' THEN @User ELSE ApproverEmail END,ApprovalComments=CASE WHEN @Stage='Approval' THEN @Comments ELSE ApprovalComments END,ApprovedUtc=CASE WHEN @New='Approved' THEN SYSUTCDATETIME() ELSE ApprovedUtc END,RejectedUtc=CASE WHEN @New='Rejected' THEN SYSUTCDATETIME() ELSE RejectedUtc END,UpdatedUtc=SYSUTCDATETIME() WHERE PetId=@PetId;
 UPDATE dbo.Projects SET Status=CASE WHEN @New='Approved' THEN 'Approved' WHEN @New='Rejected' THEN 'PET Rejected' ELSE 'PET Approval' END,UpdatedUtc=SYSUTCDATETIME() WHERE ProjectId=@ProjectId;
 INSERT dbo.WorkflowHistory(PetId,FromStatus,ToStatus,ActionBy,Comments) VALUES(@PetId,@Old,@New,@User,@Comments); COMMIT;
END;
GO
