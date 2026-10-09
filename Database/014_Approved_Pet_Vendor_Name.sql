USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
IF COL_LENGTH('dbo.PETRequests','VendorName') IS NULL ALTER TABLE dbo.PETRequests ADD VendorName nvarchar(300) NULL;
GO
CREATE OR ALTER PROCEDURE dbo.sp_SavePet @PetId int=NULL,@ProjectId int,@Code nvarchar(50),@Amount decimal(19,2),@Currency char(3),@User nvarchar(254),@VendorName nvarchar(300)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @SkipReview bit,@RequiresPet bit,@InitialStatus nvarchar(50),@Status nvarchar(50);
 SELECT @SkipReview=SkipReview,@RequiresPet=RequiresPet FROM dbo.Projects WHERE ProjectId=@ProjectId;
 IF ISNULL(@RequiresPet,0)=0 THROW 50008,'This project does not require PET registration.',1;
 SET @InitialStatus=CASE WHEN @SkipReview=1 THEN 'Pending Approval' ELSE 'Pending Review' END;
 IF @PetId IS NULL
 BEGIN
  INSERT dbo.PETRequests(ProjectId,Code,RequestedAmount,Currency,Status,CreatedBy) VALUES(@ProjectId,@Code,@Amount,@Currency,@InitialStatus,@User);
  SET @PetId=SCOPE_IDENTITY();
  INSERT dbo.WorkflowHistory(PetId,ToStatus,ActionBy,Comments) VALUES(@PetId,@InitialStatus,@User,CASE WHEN @SkipReview=1 THEN 'Reviewer skipped during project registration.' ELSE NULL END);
 END
 ELSE
 BEGIN
  SELECT @Status=Status FROM dbo.PETRequests WHERE PetId=@PetId AND ProjectId=@ProjectId;
  IF @Status IN('Draft','Pending Review','Pending Approval') UPDATE dbo.PETRequests SET Code=@Code,RequestedAmount=@Amount,Currency=@Currency,UpdatedUtc=SYSUTCDATETIME() WHERE PetId=@PetId;
  IF @Status='Approved' UPDATE dbo.PETRequests SET VendorName=@VendorName,UpdatedUtc=SYSUTCDATETIME() WHERE PetId=@PetId;
 END
 UPDATE dbo.Projects SET Status=CASE WHEN @SkipReview=1 THEN 'PET Approval' ELSE 'PET Review' END,UpdatedUtc=SYSUTCDATETIME() WHERE ProjectId=@ProjectId AND ISNULL(@Status,'')<>'Approved';
 SELECT PetId,Status FROM dbo.PETRequests WHERE PetId=@PetId;
END;
GO