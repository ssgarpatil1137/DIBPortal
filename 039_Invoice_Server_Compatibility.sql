USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_SaveInvoice @Id int=NULL,@Line int,@Vendor nvarchar(300),@Justification nvarchar(1000)=NULL,@Gl nvarchar(50)=NULL,@Number nvarchar(100),@Amount decimal(19,2),@Status nvarchar(50),@PaymentDate date=NULL,@User nvarchar(254)
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @BudgetLineCost decimal(19,2), @ExistingInvoiceTotal decimal(19,2);
 SELECT @BudgetLineCost=Cost FROM dbo.BudgetLines WHERE BudgetLineId=@Line;
 IF @BudgetLineCost IS NULL THROW 50035,'Budget Line was not found.',1;
 IF @Amount<=0 THROW 50036,'A positive Invoice amount is required.',1;
 SELECT @ExistingInvoiceTotal=ISNULL(SUM(InvoiceAmount),0) FROM dbo.Invoices WHERE BudgetLineId=@Line AND (@Id IS NULL OR InvoiceId<>@Id);
 IF @Amount > @BudgetLineCost-ISNULL(@ExistingInvoiceTotal,0) THROW 50037,'Invoice amount exceeds the available Budget Line balance.',1;
 IF @Id IS NULL BEGIN INSERT dbo.Invoices(BudgetLineId,VendorName,Justification,GlNumber,InvoiceNumber,InvoiceAmount,InvoiceStatus,PaymentDate,CreatedBy) VALUES(@Line,@Vendor,@Justification,@Gl,@Number,@Amount,@Status,@PaymentDate,@User); SET @Id=SCOPE_IDENTITY(); END
 ELSE UPDATE dbo.Invoices SET VendorName=@Vendor,Justification=@Justification,GlNumber=@Gl,InvoiceNumber=@Number,InvoiceAmount=@Amount,InvoiceStatus=@Status,PaymentDate=@PaymentDate,UpdatedUtc=SYSUTCDATETIME() WHERE InvoiceId=@Id;
 SELECT InvoiceId FROM dbo.Invoices WHERE InvoiceId=@Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_DeleteInvoice @InvoiceId int, @User nvarchar(254)
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @ProjectId int, @Status nvarchar(50), @RequestorEmail nvarchar(254), @IsElevated bit;
 SELECT @ProjectId=p.ProjectId, @Status=i.InvoiceStatus, @RequestorEmail=p.RequestorEmail
 FROM dbo.Invoices i
 JOIN dbo.BudgetLines bl ON bl.BudgetLineId=i.BudgetLineId
 JOIN dbo.PETRequests pet ON pet.PetId=bl.PetId
 JOIN dbo.Projects p ON p.ProjectId=pet.ProjectId
 WHERE i.InvoiceId=@InvoiceId;
 IF @ProjectId IS NULL THROW 50032,'Invoice not found.',1;
 IF UPPER(LTRIM(RTRIM(ISNULL(@Status,'')))) IN ('SETTLED','PAID') THROW 50033,'Settled or Paid invoices cannot be deleted.',1;
 SELECT @IsElevated=CASE WHEN EXISTS(SELECT 1 FROM dbo.Users u JOIN dbo.UserRoles ur ON ur.UserId=u.UserId JOIN dbo.Roles r ON r.RoleId=ur.RoleId WHERE UPPER(LTRIM(RTRIM(u.Email)))=UPPER(LTRIM(RTRIM(@User))) AND r.Name IN ('Master','Admin')) THEN 1 ELSE 0 END;
 IF ISNULL(@IsElevated,0)=0 AND UPPER(LTRIM(RTRIM(ISNULL(@RequestorEmail,''))))<>UPPER(LTRIM(RTRIM(ISNULL(@User,''))))
  THROW 50034,'You are not allowed to delete this Invoice.',1;
 DELETE FROM dbo.Attachments WHERE EntityType='InvoiceDocument' AND EntityId=@InvoiceId;
 DELETE FROM dbo.Invoices WHERE InvoiceId=@InvoiceId;
END;
GO