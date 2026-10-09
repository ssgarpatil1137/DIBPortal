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
  SET @EffectiveReviewRequired=ISNULL(@EffectiveReviewRequired,CASE WHEN ISNULL(@SkipReview,0)=1 THEN 0 ELSE 1 END);
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
 @Aed decimal(19,2),@Contingency decimal(9,4),@Gl nvarchar(50)=NULL,@Department nvarchar(200)=NULL,
 @Description nvarchar(500)=NULL,@YearlyRecurrence int=NULL
AS
BEGIN
 SET NOCOUNT ON;
 IF NOT EXISTS(SELECT 1 FROM dbo.PETRequests pet JOIN dbo.Projects p ON p.ProjectId=pet.ProjectId WHERE pet.PetId=@Pet AND (pet.Status IN('Draft','Pending Review','Sent Back') OR (pet.Status='Pending Approval' AND (p.SkipReview=1 OR ISNULL(pet.ReviewRequired,1)=0)))) THROW 50007,'Spend items cannot be changed after review or final approval.',1;
 IF @Id IS NULL
 BEGIN
  INSERT dbo.SpendItems(PetId,Department,Head,Topic,Vendor,Description,CostType,UnitType,Units,UnitPrice,Currency,ForeignAmount,AedAmount,ContingencyPercent,GlNumber,YearlyRecurrence)
  VALUES(@Pet,@Department,@Head,@Topic,@Vendor,@Description,@CostType,@UnitType,@Units,@UnitPrice,@Currency,@Foreign,@Aed,@Contingency,@Gl,@YearlyRecurrence);
  SET @Id=SCOPE_IDENTITY();
 END
 ELSE
  UPDATE dbo.SpendItems SET Department=@Department,Head=@Head,Topic=@Topic,Vendor=@Vendor,Description=@Description,CostType=@CostType,UnitType=@UnitType,Units=@Units,UnitPrice=@UnitPrice,Currency=@Currency,ForeignAmount=@Foreign,AedAmount=@Aed,ContingencyPercent=@Contingency,GlNumber=@Gl,YearlyRecurrence=@YearlyRecurrence WHERE SpendItemId=@Id AND PetId=@Pet;
 UPDATE dbo.PETRequests SET RequestedAmount=(SELECT ISNULL(SUM(FinalAedAmount),0) FROM dbo.SpendItems WHERE PetId=@Pet),UpdatedUtc=SYSUTCDATETIME() WHERE PetId=@Pet;
 SELECT SpendItemId,(SELECT RequestedAmount FROM dbo.PETRequests WHERE PetId=@Pet) FinalRequestAedAmount FROM dbo.SpendItems WHERE SpendItemId=@Id;
END;
GO