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
 IF @Stage IN('Review','Approval') AND @NormalizedDecision='Approve'
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
 UPDATE dbo.Projects SET Status=CASE WHEN @New='Approved' THEN 'Approved' WHEN @New='Rejected' THEN 'PET Rejected' WHEN @New='Sent Back' THEN 'PET Sent Back' ELSE 'PET Approval' END,BudgetType=CASE WHEN @NormalizedDecision='Approve' AND @BudgetSourceId IS NOT NULL THEN 'CAPEX' ELSE BudgetType END,BudgetSourceId=CASE WHEN @NormalizedDecision='Approve' AND @BudgetSourceId IS NOT NULL THEN @BudgetSource ELSE BudgetSourceId END,UpdatedUtc=SYSUTCDATETIME() WHERE ProjectId=@ProjectId;
 INSERT dbo.WorkflowHistory(PetId,FromStatus,ToStatus,ActionBy,Comments) VALUES(@PetId,@Old,@New,@User,@Comments); COMMIT;
END;
GO