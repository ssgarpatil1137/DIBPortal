IF COL_LENGTH('dbo.SpendItems','Department') IS NULL ALTER TABLE dbo.SpendItems ADD Department nvarchar(200) NULL;
IF COL_LENGTH('dbo.SpendItems','Description') IS NULL ALTER TABLE dbo.SpendItems ADD Description nvarchar(500) NULL;
IF COL_LENGTH('dbo.SpendItems','YearlyRecurrence') IS NULL ALTER TABLE dbo.SpendItems ADD YearlyRecurrence int NULL;
GO

CREATE OR ALTER PROCEDURE dbo.sp_SaveSpendItem
 @Id int=NULL,@Pet int,@Head nvarchar(200)=NULL,@Topic nvarchar(300)=NULL,@Vendor nvarchar(300),@CostType nvarchar(100)=NULL,
 @UnitType nvarchar(50)=NULL,@Units decimal(19,4),@UnitPrice decimal(19,2),@Currency char(3),@Foreign decimal(19,2),
 @Aed decimal(19,2),@Contingency decimal(9,4),@Gl nvarchar(50)=NULL,@Department nvarchar(200)=NULL,
 @Description nvarchar(500)=NULL,@YearlyRecurrence int=NULL
AS
BEGIN
 SET NOCOUNT ON;
 IF NOT EXISTS(SELECT 1 FROM dbo.PETRequests pet JOIN dbo.Projects p ON p.ProjectId=pet.ProjectId WHERE pet.PetId=@Pet AND (pet.Status IN('Draft','Pending Review','Sent Back') OR (pet.Status='Pending Approval' AND p.SkipReview=1))) THROW 50007,'Spend items cannot be changed after review or final approval.',1;
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
