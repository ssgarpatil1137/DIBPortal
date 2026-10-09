USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_DeleteInvoice @InvoiceId int, @User nvarchar(254)
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @ProjectId int, @Status nvarchar(50);
 SELECT @ProjectId=p.ProjectId, @Status=i.InvoiceStatus
 FROM dbo.Invoices i
 JOIN dbo.BudgetLines bl ON bl.BudgetLineId=i.BudgetLineId
 JOIN dbo.PETRequests pet ON pet.PetId=bl.PetId
 JOIN dbo.Projects p ON p.ProjectId=pet.ProjectId
 WHERE i.InvoiceId=@InvoiceId;
 IF @ProjectId IS NULL THROW 50032,'Invoice not found.',1;
 IF UPPER(LTRIM(RTRIM(ISNULL(@Status,'')))) IN ('SETTLED','PAID') THROW 50033,'Settled or Paid invoices cannot be deleted.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.Projects p WHERE p.ProjectId=@ProjectId AND (p.RequestorEmail=@User OR EXISTS(SELECT 1 FROM dbo.Users u JOIN dbo.UserRoles ur ON ur.UserId=u.UserId JOIN dbo.Roles r ON r.RoleId=ur.RoleId WHERE u.Email=@User AND r.Name='Master')))
  THROW 50034,'You are not allowed to delete this Invoice.',1;
 DELETE FROM dbo.Attachments WHERE EntityType='InvoiceDocument' AND EntityId=@InvoiceId;
 DELETE FROM dbo.Invoices WHERE InvoiceId=@InvoiceId;
END;
GO