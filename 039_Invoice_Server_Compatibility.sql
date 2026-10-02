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

CREATE OR ALTER PROCEDURE dbo.sp_DeleteBudgetLine @BudgetLineId int, @User nvarchar(254)
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @ProjectId int, @RequestorEmail nvarchar(254), @IsElevated bit;
 SELECT @ProjectId=p.ProjectId, @RequestorEmail=p.RequestorEmail
 FROM dbo.BudgetLines bl
 JOIN dbo.PETRequests pet ON pet.PetId=bl.PetId
 JOIN dbo.Projects p ON p.ProjectId=pet.ProjectId
 WHERE bl.BudgetLineId=@BudgetLineId;
 IF @ProjectId IS NULL THROW 50030,'Budget Line not found.',1;
 SELECT @IsElevated=CASE WHEN EXISTS(SELECT 1 FROM dbo.Users u JOIN dbo.UserRoles ur ON ur.UserId=u.UserId JOIN dbo.Roles r ON r.RoleId=ur.RoleId WHERE UPPER(LTRIM(RTRIM(u.Email)))=UPPER(LTRIM(RTRIM(@User))) AND r.Name IN ('Master','Admin')) THEN 1 ELSE 0 END;
 IF ISNULL(@IsElevated,0)=0 AND UPPER(LTRIM(RTRIM(ISNULL(@RequestorEmail,''))))<>UPPER(LTRIM(RTRIM(ISNULL(@User,''))))
    THROW 50031,'You are not allowed to delete this Budget Line.',1;
 IF EXISTS(SELECT 1 FROM dbo.Invoices WHERE BudgetLineId=@BudgetLineId) THROW 50035,'Budget Line cannot be deleted because it has Invoice(s). Delete the Invoice(s) first.',1;
 DELETE FROM dbo.Attachments WHERE EntityType IN ('BudgetLineCAM','BudgetLineLPO') AND EntityId=@BudgetLineId;
 IF OBJECT_ID('dbo.BudgetLineSpendItems','U') IS NOT NULL DELETE FROM dbo.BudgetLineSpendItems WHERE BudgetLineId=@BudgetLineId;
 DELETE FROM dbo.BudgetLines WHERE BudgetLineId=@BudgetLineId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_DeletePet @PetId int, @User nvarchar(254)
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @ProjectId int, @Status nvarchar(50), @RequestorEmail nvarchar(254), @IsElevated bit;
 SELECT @ProjectId=pet.ProjectId, @Status=pet.Status, @RequestorEmail=p.RequestorEmail
 FROM dbo.PETRequests pet
 JOIN dbo.Projects p ON p.ProjectId=pet.ProjectId
 WHERE pet.PetId=@PetId;
 IF @ProjectId IS NULL THROW 50010,'PET not found.',1;
 IF @Status NOT IN ('Draft','Pending Review','Sent Back') THROW 50011,'Only a PET that has not been approved yet can be deleted.',1;
 SELECT @IsElevated=CASE WHEN EXISTS(SELECT 1 FROM dbo.Users u JOIN dbo.UserRoles ur ON ur.UserId=u.UserId JOIN dbo.Roles r ON r.RoleId=ur.RoleId WHERE UPPER(LTRIM(RTRIM(u.Email)))=UPPER(LTRIM(RTRIM(@User))) AND r.Name IN ('Master','Admin')) THEN 1 ELSE 0 END;
 IF ISNULL(@IsElevated,0)=0 AND UPPER(LTRIM(RTRIM(ISNULL(@RequestorEmail,''))))<>UPPER(LTRIM(RTRIM(ISNULL(@User,''))))
    THROW 50012,'You are not allowed to delete this PET.',1;
 DELETE FROM dbo.Attachments WHERE EntityType='InvoiceDocument' AND EntityId IN (SELECT i.InvoiceId FROM dbo.Invoices i JOIN dbo.BudgetLines bl ON bl.BudgetLineId=i.BudgetLineId WHERE bl.PetId=@PetId);
 DELETE FROM dbo.Attachments WHERE EntityType IN ('BudgetLineCAM','BudgetLineLPO') AND EntityId IN (SELECT BudgetLineId FROM dbo.BudgetLines WHERE PetId=@PetId);
 DELETE FROM dbo.Attachments WHERE EntityType='PET' AND EntityId=@PetId;
 DELETE i FROM dbo.Invoices i JOIN dbo.BudgetLines bl ON bl.BudgetLineId=i.BudgetLineId WHERE bl.PetId=@PetId;
 IF OBJECT_ID('dbo.BudgetLineSpendItems','U') IS NOT NULL DELETE bsi FROM dbo.BudgetLineSpendItems bsi JOIN dbo.BudgetLines bl ON bl.BudgetLineId=bsi.BudgetLineId WHERE bl.PetId=@PetId;
 DELETE FROM dbo.BudgetLines WHERE PetId=@PetId;
 DELETE FROM dbo.SpendItems WHERE PetId=@PetId;
 DELETE FROM dbo.WorkflowHistory WHERE PetId=@PetId;
 DELETE FROM dbo.PETRequests WHERE PetId=@PetId;
 IF NOT EXISTS(SELECT 1 FROM dbo.PETRequests WHERE ProjectId=@ProjectId AND Status NOT IN('Rejected'))
    UPDATE dbo.Projects SET Status=CASE WHEN RequiresPet=0 THEN 'Registered' ELSE 'Active' END, UpdatedUtc=SYSUTCDATETIME() WHERE ProjectId=@ProjectId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_DeleteProject @ProjectId int, @User nvarchar(254)
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @RequestorEmail nvarchar(254), @IsElevated bit;
 SELECT @RequestorEmail=RequestorEmail FROM dbo.Projects WHERE ProjectId=@ProjectId;
 IF @RequestorEmail IS NULL THROW 50013,'Project not found.',1;
 SELECT @IsElevated=CASE WHEN EXISTS(SELECT 1 FROM dbo.Users u JOIN dbo.UserRoles ur ON ur.UserId=u.UserId JOIN dbo.Roles r ON r.RoleId=ur.RoleId WHERE UPPER(LTRIM(RTRIM(u.Email)))=UPPER(LTRIM(RTRIM(@User))) AND r.Name IN ('Master','Admin')) THEN 1 ELSE 0 END;
 IF ISNULL(@IsElevated,0)=0 AND UPPER(LTRIM(RTRIM(ISNULL(@RequestorEmail,''))))<>UPPER(LTRIM(RTRIM(ISNULL(@User,''))))
    THROW 50014,'You are not allowed to delete this project.',1;
 IF EXISTS(SELECT 1 FROM dbo.PETRequests WHERE ProjectId=@ProjectId) THROW 50015,'This project has PET requests; delete them first.',1;
 DELETE FROM dbo.Attachments WHERE EntityType='Project' AND EntityId=@ProjectId;
 DELETE FROM dbo.Projects WHERE ProjectId=@ProjectId;
END;
GO