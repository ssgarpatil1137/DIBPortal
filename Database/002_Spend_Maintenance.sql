USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
CREATE OR ALTER PROCEDURE dbo.sp_SaveSpendItem
 @Id int=NULL,@Pet int,@Head nvarchar(200)=NULL,@Topic nvarchar(300)=NULL,@Vendor nvarchar(300),@CostType nvarchar(100)=NULL,
 @UnitType nvarchar(50)=NULL,@Units decimal(19,4),@UnitPrice decimal(19,2),@Currency char(3),@Foreign decimal(19,2),
 @Aed decimal(19,2),@Contingency decimal(9,4),@Gl nvarchar(50)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 IF NOT EXISTS(SELECT 1 FROM dbo.PETRequests WHERE PetId=@Pet AND Status IN('Draft','Pending Review'))
  THROW 50007,'Spend items can only be changed before reviewer approval.',1;
 IF @Id IS NULL
 BEGIN
  INSERT dbo.SpendItems(PetId,Head,Topic,Vendor,CostType,UnitType,Units,UnitPrice,Currency,ForeignAmount,AedAmount,ContingencyPercent,GlNumber)
  VALUES(@Pet,@Head,@Topic,@Vendor,@CostType,@UnitType,@Units,@UnitPrice,@Currency,@Foreign,@Aed,@Contingency,@Gl);
  SET @Id=SCOPE_IDENTITY();
 END
 ELSE
  UPDATE dbo.SpendItems SET Head=@Head,Topic=@Topic,Vendor=@Vendor,CostType=@CostType,UnitType=@UnitType,Units=@Units,UnitPrice=@UnitPrice,Currency=@Currency,ForeignAmount=@Foreign,AedAmount=@Aed,ContingencyPercent=@Contingency,GlNumber=@Gl WHERE SpendItemId=@Id AND PetId=@Pet;
 SELECT SpendItemId FROM dbo.SpendItems WHERE SpendItemId=@Id;
END;
GO
