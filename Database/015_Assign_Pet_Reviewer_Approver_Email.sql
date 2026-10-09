USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
UPDATE pet
SET ReviewerEmail=COALESCE(NULLIF(pet.ReviewerEmail,''),reviewer.Email),
    ApproverEmail=COALESCE(NULLIF(pet.ApproverEmail,''),approver.Email)
FROM dbo.PETRequests pet
JOIN dbo.Projects p ON p.ProjectId=pet.ProjectId
LEFT JOIN dbo.Users reviewer ON LTRIM(RTRIM(reviewer.DisplayName))=LTRIM(RTRIM(p.AccountableExecLead))
LEFT JOIN dbo.Users approver ON LTRIM(RTRIM(approver.DisplayName))=LTRIM(RTRIM(p.AccountableExec))
WHERE pet.Status IN('Pending Review','Pending Approval')
  AND (pet.ReviewerEmail IS NULL OR pet.ReviewerEmail='' OR pet.ApproverEmail IS NULL OR pet.ApproverEmail='');
GO
CREATE OR ALTER PROCEDURE dbo.sp_SavePet @PetId int=NULL,@ProjectId int,@Code nvarchar(50),@Amount decimal(19,2),@Currency char(3),@User nvarchar(254),@VendorName nvarchar(300)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @SkipReview bit,@RequiresPet bit,@InitialStatus nvarchar(50),@Status nvarchar(50),@ReviewerEmail nvarchar(254),@ApproverEmail nvarchar(254);
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
  IF @Status IN('Draft','Pending Review','Pending Approval') UPDATE dbo.PETRequests SET Code=@Code,RequestedAmount=@Amount,Currency=@Currency,ReviewerEmail=COALESCE(NULLIF(ReviewerEmail,''),@ReviewerEmail),ApproverEmail=COALESCE(NULLIF(ApproverEmail,''),@ApproverEmail),UpdatedUtc=SYSUTCDATETIME() WHERE PetId=@PetId;
  IF @Status='Approved' UPDATE dbo.PETRequests SET VendorName=@VendorName,UpdatedUtc=SYSUTCDATETIME() WHERE PetId=@PetId;
 END
 UPDATE dbo.Projects SET Status=CASE WHEN @SkipReview=1 THEN 'PET Approval' ELSE 'PET Review' END,UpdatedUtc=SYSUTCDATETIME() WHERE ProjectId=@ProjectId AND ISNULL(@Status,'')<>'Approved';
 SELECT PetId,Status FROM dbo.PETRequests WHERE PetId=@PetId;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_PetDecision @PetId int,@Stage nvarchar(20),@Approve bit,@Comments nvarchar(2000),@User nvarchar(254)
AS
BEGIN SET XACT_ABORT ON; BEGIN TRAN;
 DECLARE @Old nvarchar(50),@New nvarchar(50),@Amount decimal(19,2),@BudgetSource int,@Available decimal(19,2),@ProjectId int;
 DECLARE @ExecLead nvarchar(200),@Exec nvarchar(200),@UserDisplayName nvarchar(200),@AssignedReviewerEmail nvarchar(254),@AssignedApproverEmail nvarchar(254);
 SELECT @Old=pet.Status,@Amount=pet.RequestedAmount,@ProjectId=pet.ProjectId,@BudgetSource=p.BudgetSourceId,@ExecLead=p.AccountableExecLead,@Exec=p.AccountableExec,@AssignedReviewerEmail=pet.ReviewerEmail,@AssignedApproverEmail=pet.ApproverEmail
 FROM dbo.PETRequests pet WITH(UPDLOCK) JOIN dbo.Projects p ON p.ProjectId=pet.ProjectId WHERE pet.PetId=@PetId;
 SET @UserDisplayName=(SELECT DisplayName FROM dbo.Users WHERE Email=@User);
 IF @Stage='Review' AND ((@AssignedReviewerEmail IS NOT NULL AND LOWER(@AssignedReviewerEmail)<>LOWER(@User)) OR (@AssignedReviewerEmail IS NULL AND (LTRIM(RTRIM(ISNULL(@UserDisplayName,''))) <> LTRIM(RTRIM(ISNULL(@ExecLead,''))) OR @UserDisplayName IS NULL)))
  THROW 50009,'Only the assigned Accountable Executive Lead can review this PET.',1;
 IF @Stage='Approval' AND ((@AssignedApproverEmail IS NOT NULL AND LOWER(@AssignedApproverEmail)<>LOWER(@User)) OR (@AssignedApproverEmail IS NULL AND (LTRIM(RTRIM(ISNULL(@UserDisplayName,''))) <> LTRIM(RTRIM(ISNULL(@Exec,''))) OR @UserDisplayName IS NULL)))
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