USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
CREATE OR ALTER PROCEDURE dbo.sp_SavePet @PetId int=NULL,@ProjectId int,@Code nvarchar(50),@Amount decimal(19,2),@Currency char(3),@User nvarchar(254),@VendorName nvarchar(300)=NULL,@Comments nvarchar(2000)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @SkipReview bit,@RequiresPet bit,@InitialStatus nvarchar(50),@Status nvarchar(50),@ReviewerEmail nvarchar(254),@ApproverEmail nvarchar(254),@ResubmitStatus nvarchar(50);
 SELECT @SkipReview=p.SkipReview,@RequiresPet=p.RequiresPet,@ReviewerEmail=reviewer.Email,@ApproverEmail=approver.Email
 FROM dbo.Projects p
 LEFT JOIN dbo.Users reviewer ON LTRIM(RTRIM(reviewer.DisplayName))=LTRIM(RTRIM(p.AccountableExecLead))
 LEFT JOIN dbo.Users approver ON LTRIM(RTRIM(approver.DisplayName))=LTRIM(RTRIM(p.AccountableExec))
 WHERE p.ProjectId=@ProjectId;
 IF ISNULL(@RequiresPet,0)=0 THROW 50008,'This project does not require PET registration.',1;
 SET @InitialStatus=CASE WHEN @SkipReview=1 THEN 'Pending Approval' ELSE 'Pending Review' END;
 IF @PetId IS NULL
 BEGIN
  INSERT dbo.PETRequests(ProjectId,Code,RequestedAmount,Currency,Status,ReviewerEmail,ApproverEmail,CreatedBy) VALUES(@ProjectId,@Code,@Amount,@Currency,@InitialStatus,@ReviewerEmail,@ApproverEmail,@User);
  SET @PetId=SCOPE_IDENTITY();
  INSERT dbo.WorkflowHistory(PetId,ToStatus,ActionBy,Comments) VALUES(@PetId,@InitialStatus,@User,CASE WHEN @SkipReview=1 THEN 'Reviewer skipped during project registration.' ELSE NULL END);
 END
 ELSE
 BEGIN
  SELECT @Status=Status FROM dbo.PETRequests WHERE PetId=@PetId AND ProjectId=@ProjectId;
  IF @Status='Sent Back'
  BEGIN
   IF NULLIF(LTRIM(RTRIM(ISNULL(@Comments,''))),'') IS NULL THROW 50012,'Requester comments / amendment notes are required before resubmitting.',1;
   SELECT TOP 1 @ResubmitStatus=CASE WHEN FromStatus='Pending Review' THEN 'Pending Review' ELSE 'Pending Approval' END FROM dbo.WorkflowHistory WHERE PetId=@PetId AND ToStatus='Sent Back' ORDER BY ActionUtc DESC,WorkflowHistoryId DESC;
   SET @ResubmitStatus=ISNULL(@ResubmitStatus,@InitialStatus);
   UPDATE dbo.PETRequests SET Code=@Code,RequestedAmount=@Amount,Currency=@Currency,Status=@ResubmitStatus,ReviewerEmail=COALESCE(NULLIF(ReviewerEmail,''),@ReviewerEmail),ApproverEmail=COALESCE(NULLIF(ApproverEmail,''),@ApproverEmail),UpdatedUtc=SYSUTCDATETIME() WHERE PetId=@PetId;
   INSERT dbo.WorkflowHistory(PetId,FromStatus,ToStatus,ActionBy,Comments) VALUES(@PetId,@Status,@ResubmitStatus,@User,@Comments);
  END
  ELSE
  BEGIN
   IF @Status IN('Draft','Pending Review','Pending Approval') UPDATE dbo.PETRequests SET Code=@Code,RequestedAmount=@Amount,Currency=@Currency,ReviewerEmail=COALESCE(NULLIF(ReviewerEmail,''),@ReviewerEmail),ApproverEmail=COALESCE(NULLIF(ApproverEmail,''),@ApproverEmail),UpdatedUtc=SYSUTCDATETIME() WHERE PetId=@PetId;
   IF @Status='Approved' UPDATE dbo.PETRequests SET VendorName=@VendorName,UpdatedUtc=SYSUTCDATETIME() WHERE PetId=@PetId;
  END
 END
 UPDATE dbo.Projects SET Status=CASE WHEN ISNULL(@ResubmitStatus,ISNULL(@Status,@InitialStatus))='Pending Approval' THEN 'PET Approval' WHEN ISNULL(@ResubmitStatus,ISNULL(@Status,@InitialStatus))='Sent Back' THEN 'PET Sent Back' ELSE 'PET Review' END,UpdatedUtc=SYSUTCDATETIME() WHERE ProjectId=@ProjectId AND ISNULL(@Status,'')<>'Approved';
 SELECT PetId,Status FROM dbo.PETRequests WHERE PetId=@PetId;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_SaveSpendItem
 @Id int=NULL,@Pet int,@Head nvarchar(200)=NULL,@Topic nvarchar(300)=NULL,@Vendor nvarchar(300),@CostType nvarchar(100)=NULL,
 @UnitType nvarchar(50)=NULL,@Units decimal(19,4),@UnitPrice decimal(19,2),@Currency char(3),@Foreign decimal(19,2),
 @Aed decimal(19,2),@Contingency decimal(9,4),@Gl nvarchar(50)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 IF NOT EXISTS(SELECT 1 FROM dbo.PETRequests pet JOIN dbo.Projects p ON p.ProjectId=pet.ProjectId WHERE pet.PetId=@Pet AND (pet.Status IN('Draft','Pending Review','Sent Back') OR (pet.Status='Pending Approval' AND p.SkipReview=1))) THROW 50007,'Spend items cannot be changed after review or final approval.',1;
 IF @Id IS NULL BEGIN INSERT dbo.SpendItems(PetId,Head,Topic,Vendor,CostType,UnitType,Units,UnitPrice,Currency,ForeignAmount,AedAmount,ContingencyPercent,GlNumber) VALUES(@Pet,@Head,@Topic,@Vendor,@CostType,@UnitType,@Units,@UnitPrice,@Currency,@Foreign,@Aed,@Contingency,@Gl); SET @Id=SCOPE_IDENTITY(); END
 ELSE UPDATE dbo.SpendItems SET Head=@Head,Topic=@Topic,Vendor=@Vendor,CostType=@CostType,UnitType=@UnitType,Units=@Units,UnitPrice=@UnitPrice,Currency=@Currency,ForeignAmount=@Foreign,AedAmount=@Aed,ContingencyPercent=@Contingency,GlNumber=@Gl WHERE SpendItemId=@Id AND PetId=@Pet;
 UPDATE dbo.PETRequests SET RequestedAmount=(SELECT ISNULL(SUM(FinalAedAmount),0) FROM dbo.SpendItems WHERE PetId=@Pet),UpdatedUtc=SYSUTCDATETIME() WHERE PetId=@Pet;
 SELECT SpendItemId,(SELECT RequestedAmount FROM dbo.PETRequests WHERE PetId=@Pet) FinalRequestAedAmount FROM dbo.SpendItems WHERE SpendItemId=@Id;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_PetDecision @PetId int,@Stage nvarchar(20),@Approve bit,@Comments nvarchar(2000),@User nvarchar(254),@BudgetSourceId int=NULL,@Decision nvarchar(30)=NULL
AS
BEGIN SET XACT_ABORT ON; BEGIN TRAN;
 DECLARE @Old nvarchar(50),@New nvarchar(50),@Amount decimal(19,2),@BudgetSource int,@Available decimal(19,2),@ProjectId int,@SelectedBudgetType nvarchar(10),@NormalizedDecision nvarchar(30);
 DECLARE @ExecLead nvarchar(200),@Exec nvarchar(200),@UserDisplayName nvarchar(200),@AssignedReviewerEmail nvarchar(254),@AssignedApproverEmail nvarchar(254);
 SELECT @Old=pet.Status,@Amount=pet.RequestedAmount,@ProjectId=pet.ProjectId,@BudgetSource=p.BudgetSourceId,@ExecLead=p.AccountableExecLead,@Exec=p.AccountableExec,@AssignedReviewerEmail=pet.ReviewerEmail,@AssignedApproverEmail=pet.ApproverEmail
 FROM dbo.PETRequests pet WITH(UPDLOCK) JOIN dbo.Projects p ON p.ProjectId=pet.ProjectId WHERE pet.PetId=@PetId;
 SET @NormalizedDecision=COALESCE(NULLIF(@Decision,''),CASE WHEN @Approve=1 THEN 'Approve' ELSE 'RejectCancel' END);
 SET @UserDisplayName=(SELECT DisplayName FROM dbo.Users WHERE Email=@User);
 IF @Stage='Review' AND ((@AssignedReviewerEmail IS NOT NULL AND LOWER(@AssignedReviewerEmail)<>LOWER(@User)) OR (@AssignedReviewerEmail IS NULL AND (LTRIM(RTRIM(ISNULL(@UserDisplayName,''))) <> LTRIM(RTRIM(ISNULL(@ExecLead,''))) OR @UserDisplayName IS NULL)))
  THROW 50009,'Only the assigned Accountable Executive Lead can review this PET.',1;
 IF @Stage='Approval' AND ((@AssignedApproverEmail IS NOT NULL AND LOWER(@AssignedApproverEmail)<>LOWER(@User)) OR (@AssignedApproverEmail IS NULL AND (LTRIM(RTRIM(ISNULL(@UserDisplayName,''))) <> LTRIM(RTRIM(ISNULL(@Exec,''))) OR @UserDisplayName IS NULL)))
  THROW 50009,'Only the assigned Accountable Executive can approve this PET.',1;
 IF @Stage='Review' AND @Old<>'Pending Review' THROW 50002,'PET is not awaiting review.',1;
 IF @Stage='Approval' AND @Old<>'Pending Approval' THROW 50003,'PET is not awaiting approval.',1;
 IF @NormalizedDecision NOT IN('Approve','SendBack','RejectCancel') THROW 50013,'Select a valid decision.',1;
 IF @NormalizedDecision IN('SendBack','RejectCancel') AND NULLIF(LTRIM(RTRIM(ISNULL(@Comments,''))),'') IS NULL THROW 50014,'Comments / reason is required for this decision.',1;
 IF @Stage='Approval' AND @NormalizedDecision='Approve'
 BEGIN
  IF @BudgetSourceId IS NULL THROW 50015,'Select a CapEx source before approval.',1;
  SELECT @SelectedBudgetType=BudgetType FROM dbo.BudgetSources WHERE BudgetSourceId=@BudgetSourceId;
  IF @SelectedBudgetType IS NULL THROW 50010,'Selected CapEx source was not found.',1;
  IF @SelectedBudgetType<>'CAPEX' THROW 50011,'Select a CapEx budget source for approval.',1;
  SET @BudgetSource=@BudgetSourceId;
 END
 SET @New=CASE WHEN @NormalizedDecision='SendBack' THEN 'Sent Back' WHEN @NormalizedDecision='RejectCancel' THEN 'Rejected' WHEN @Stage='Review' THEN 'Pending Approval' ELSE 'Approved' END;
 IF @New='Approved' BEGIN SELECT @Available=AvailableBudget FROM dbo.BudgetSources WITH(UPDLOCK) WHERE BudgetSourceId=@BudgetSource; IF @Available<@Amount THROW 50004,'Insufficient remaining budget.',1; UPDATE dbo.BudgetSources SET Utilization=Utilization+@Amount,AvailableBudget=AvailableBudget-@Amount,NetBalance=NetBalance-@Amount,UpdatedUtc=SYSUTCDATETIME() WHERE BudgetSourceId=@BudgetSource; END
 UPDATE dbo.PETRequests SET Status=@New,ReviewerEmail=CASE WHEN @Stage='Review' AND @New<>'Sent Back' THEN @User ELSE ReviewerEmail END,ReviewComments=CASE WHEN @Stage='Review' THEN @Comments ELSE ReviewComments END,ReviewedUtc=CASE WHEN @Stage='Review' AND @New<>'Sent Back' THEN SYSUTCDATETIME() ELSE ReviewedUtc END,ApproverEmail=CASE WHEN @Stage='Approval' AND @New<>'Sent Back' THEN @User ELSE ApproverEmail END,ApprovalComments=CASE WHEN @Stage='Approval' THEN @Comments ELSE ApprovalComments END,ApprovedUtc=CASE WHEN @New='Approved' THEN SYSUTCDATETIME() ELSE ApprovedUtc END,RejectedUtc=CASE WHEN @New='Rejected' THEN SYSUTCDATETIME() ELSE RejectedUtc END,UpdatedUtc=SYSUTCDATETIME() WHERE PetId=@PetId;
 UPDATE dbo.Projects SET Status=CASE WHEN @New='Approved' THEN 'Approved' WHEN @New='Rejected' THEN 'PET Rejected' WHEN @New='Sent Back' THEN 'PET Sent Back' ELSE 'PET Approval' END,BudgetType=CASE WHEN @New='Approved' AND @BudgetSourceId IS NOT NULL THEN 'CAPEX' ELSE BudgetType END,BudgetSourceId=CASE WHEN @New='Approved' AND @BudgetSourceId IS NOT NULL THEN @BudgetSource ELSE BudgetSourceId END,UpdatedUtc=SYSUTCDATETIME() WHERE ProjectId=@ProjectId;
 INSERT dbo.WorkflowHistory(PetId,FromStatus,ToStatus,ActionBy,Comments) VALUES(@PetId,@Old,@New,@User,@Comments); COMMIT;
END;
GO