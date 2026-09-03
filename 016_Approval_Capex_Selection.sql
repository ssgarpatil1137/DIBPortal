USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
CREATE OR ALTER PROCEDURE dbo.sp_PetDecision @PetId int,@Stage nvarchar(20),@Approve bit,@Comments nvarchar(2000),@User nvarchar(254),@BudgetSourceId int=NULL
AS
BEGIN SET XACT_ABORT ON; BEGIN TRAN;
 DECLARE @Old nvarchar(50),@New nvarchar(50),@Amount decimal(19,2),@BudgetSource int,@Available decimal(19,2),@ProjectId int,@SelectedBudgetType nvarchar(10);
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
 IF @Stage='Approval' AND @Approve=1 AND @BudgetSourceId IS NOT NULL
 BEGIN
  SELECT @SelectedBudgetType=BudgetType FROM dbo.BudgetSources WHERE BudgetSourceId=@BudgetSourceId;
  IF @SelectedBudgetType IS NULL THROW 50010,'Selected CapEx source was not found.',1;
  IF @SelectedBudgetType<>'CAPEX' THROW 50011,'Select a CapEx budget source for approval.',1;
  SET @BudgetSource=@BudgetSourceId;
 END
 SET @New=CASE WHEN @Approve=0 THEN 'Rejected' WHEN @Stage='Review' THEN 'Pending Approval' ELSE 'Approved' END;
 IF @New='Approved' BEGIN SELECT @Available=AvailableBudget FROM dbo.BudgetSources WITH(UPDLOCK) WHERE BudgetSourceId=@BudgetSource; IF @Available<@Amount THROW 50004,'Insufficient remaining budget.',1; UPDATE dbo.BudgetSources SET Utilization=Utilization+@Amount,AvailableBudget=AvailableBudget-@Amount,NetBalance=NetBalance-@Amount,UpdatedUtc=SYSUTCDATETIME() WHERE BudgetSourceId=@BudgetSource; END
 UPDATE dbo.PETRequests SET Status=@New,ReviewerEmail=CASE WHEN @Stage='Review' THEN @User ELSE ReviewerEmail END,ReviewComments=CASE WHEN @Stage='Review' THEN @Comments ELSE ReviewComments END,ReviewedUtc=CASE WHEN @Stage='Review' THEN SYSUTCDATETIME() ELSE ReviewedUtc END,ApproverEmail=CASE WHEN @Stage='Approval' THEN @User ELSE ApproverEmail END,ApprovalComments=CASE WHEN @Stage='Approval' THEN @Comments ELSE ApprovalComments END,ApprovedUtc=CASE WHEN @New='Approved' THEN SYSUTCDATETIME() ELSE ApprovedUtc END,RejectedUtc=CASE WHEN @New='Rejected' THEN SYSUTCDATETIME() ELSE RejectedUtc END,UpdatedUtc=SYSUTCDATETIME() WHERE PetId=@PetId;
 UPDATE dbo.Projects SET Status=CASE WHEN @New='Approved' THEN 'Approved' WHEN @New='Rejected' THEN 'PET Rejected' ELSE 'PET Approval' END,BudgetType=CASE WHEN @New='Approved' AND @BudgetSourceId IS NOT NULL THEN 'CAPEX' ELSE BudgetType END,BudgetSourceId=CASE WHEN @New='Approved' AND @BudgetSourceId IS NOT NULL THEN @BudgetSource ELSE BudgetSourceId END,UpdatedUtc=SYSUTCDATETIME() WHERE ProjectId=@ProjectId;
 INSERT dbo.WorkflowHistory(PetId,FromStatus,ToStatus,ActionBy,Comments) VALUES(@PetId,@Old,@New,@User,@Comments); COMMIT;
END;
GO