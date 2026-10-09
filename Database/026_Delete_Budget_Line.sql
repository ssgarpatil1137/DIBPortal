USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_DeleteBudgetLine @BudgetLineId int, @User nvarchar(254)
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @ProjectId int;
 SELECT @ProjectId=p.ProjectId
 FROM dbo.BudgetLines bl
 JOIN dbo.PETRequests pet ON pet.PetId=bl.PetId
 JOIN dbo.Projects p ON p.ProjectId=pet.ProjectId
 WHERE bl.BudgetLineId=@BudgetLineId;
 IF @ProjectId IS NULL THROW 50030,'Budget Line not found.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.Projects p WHERE p.ProjectId=@ProjectId AND (p.RequestorEmail=@User OR EXISTS(SELECT 1 FROM dbo.Users u JOIN dbo.UserRoles ur ON ur.UserId=u.UserId JOIN dbo.Roles r ON r.RoleId=ur.RoleId WHERE u.Email=@User AND r.Name='Master')))
  THROW 50031,'You are not allowed to delete this Budget Line.',1;
 IF EXISTS(SELECT 1 FROM dbo.Invoices WHERE BudgetLineId=@BudgetLineId) THROW 50035,'Budget Line cannot be deleted because it has Invoice(s). Delete the Invoice(s) first.',1;
 IF OBJECT_ID('dbo.BudgetLineSpendItems','U') IS NOT NULL DELETE FROM dbo.BudgetLineSpendItems WHERE BudgetLineId=@BudgetLineId;
 DELETE FROM dbo.BudgetLines WHERE BudgetLineId=@BudgetLineId;
END;
GO