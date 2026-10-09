USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF COL_LENGTH('dbo.PETRequests','ReviewRequired') IS NULL
 ALTER TABLE dbo.PETRequests ADD ReviewRequired bit NOT NULL CONSTRAINT DF_PETRequests_ReviewRequired DEFAULT 1;
GO

CREATE OR ALTER PROCEDURE dbo.sp_SavePet @PetId int=NULL,@ProjectId int,@Code nvarchar(50),@Amount decimal(19,2),@Currency char(3),@User nvarchar(254),@VendorName nvarchar(300)=NULL,@Comments nvarchar(2000)=NULL,@ReviewRequired bit=NULL
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @SkipReview bit,@RequiresPet bit,@InitialStatus nvarchar(50),@Status nvarchar(50),@ReviewerEmail nvarchar(254),@ApproverEmail nvarchar(254),@ResubmitStatus nvarchar(50),@EffectiveReviewRequired bit;
 SELECT @SkipReview=p.SkipReview,@RequiresPet=p.RequiresPet,@ReviewerEmail=reviewer.Email,@ApproverEmail=approver.Email
 FROM dbo.Projects p
 LEFT JOIN dbo.Users reviewer ON LTRIM(RTRIM(reviewer.DisplayName))=LTRIM(RTRIM(p.AccountableExecLead))
 LEFT JOIN dbo.Users approver ON LTRIM(RTRIM(approver.DisplayName))=LTRIM(RTRIM(p.AccountableExec))
 WHERE p.ProjectId=@ProjectId;
 IF ISNULL(@RequiresPet,0)=0 THROW 50008,'This project does not require PET registration.',1;
 SET @EffectiveReviewRequired=CASE WHEN @ReviewRequired IS NULL THEN CASE WHEN ISNULL(@SkipReview,0)=1 THEN 0 ELSE 1 END ELSE @ReviewRequired END;
 SET @InitialStatus=CASE WHEN @EffectiveReviewRequired=0 THEN 'Pending Approval' ELSE 'Pending Review' END;
 IF @PetId IS NULL
 BEGIN
  INSERT dbo.PETRequests(ProjectId,Code,RequestedAmount,Currency,Status,ReviewerEmail,ApproverEmail,ReviewRequired,CreatedBy) VALUES(@ProjectId,@Code,@Amount,@Currency,@InitialStatus,@ReviewerEmail,@ApproverEmail,@EffectiveReviewRequired,@User);
  SET @PetId=SCOPE_IDENTITY();
  INSERT dbo.WorkflowHistory(PetId,ToStatus,ActionBy,Comments) VALUES(@PetId,@InitialStatus,@User,CASE WHEN @EffectiveReviewRequired=0 THEN 'Reviewer skipped for this PET request.' ELSE NULL END);
 END
 ELSE
 BEGIN
  SELECT @Status=Status,@EffectiveReviewRequired=ReviewRequired FROM dbo.PETRequests WHERE PetId=@PetId AND ProjectId=@ProjectId;
  SET @EffectiveReviewRequired=CASE WHEN @ReviewRequired IS NULL THEN ISNULL(@EffectiveReviewRequired,CASE WHEN ISNULL(@SkipReview,0)=1 THEN 0 ELSE 1 END) ELSE @ReviewRequired END;
  IF @Status='Sent Back'
  BEGIN
   IF NULLIF(LTRIM(RTRIM(ISNULL(@Comments,''))),'') IS NULL THROW 50012,'Requester comments / amendment notes are required before resubmitting.',1;
   SET @ResubmitStatus=CASE WHEN @EffectiveReviewRequired=1 THEN 'Pending Review' ELSE 'Pending Approval' END;
   UPDATE dbo.PETRequests SET Code=@Code,RequestedAmount=@Amount,Currency=@Currency,Status=@ResubmitStatus,ReviewRequired=@EffectiveReviewRequired,ReviewerEmail=COALESCE(NULLIF(ReviewerEmail,''),@ReviewerEmail),ApproverEmail=COALESCE(NULLIF(ApproverEmail,''),@ApproverEmail),UpdatedUtc=SYSUTCDATETIME() WHERE PetId=@PetId;
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