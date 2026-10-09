USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_DeletePet @PetId int, @User nvarchar(254)
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @ProjectId int, @Status nvarchar(50);
 SELECT @ProjectId=ProjectId, @Status=Status FROM dbo.PETRequests WHERE PetId=@PetId;
 IF @ProjectId IS NULL THROW 50010,'PET not found.',1;
 IF @Status NOT IN ('Draft','Pending Review','Sent Back') THROW 50011,'Only a PET that has not been approved yet can be deleted.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.Projects p WHERE p.ProjectId=@ProjectId AND (p.RequestorEmail=@User OR EXISTS(SELECT 1 FROM dbo.Users u JOIN dbo.UserRoles ur ON ur.UserId=u.UserId JOIN dbo.Roles r ON r.RoleId=ur.RoleId WHERE u.Email=@User AND r.Name='Master')))
  THROW 50012,'You are not allowed to delete this PET.',1;
 DELETE i FROM dbo.Invoices i JOIN dbo.BudgetLines bl ON bl.BudgetLineId=i.BudgetLineId WHERE bl.PetId=@PetId;
 DELETE FROM dbo.BudgetLines WHERE PetId=@PetId;
 DELETE FROM dbo.SpendItems WHERE PetId=@PetId;
 DELETE FROM dbo.WorkflowHistory WHERE PetId=@PetId;
 DELETE FROM dbo.PETRequests WHERE PetId=@PetId;
 IF NOT EXISTS(SELECT 1 FROM dbo.PETRequests WHERE ProjectId=@ProjectId AND Status NOT IN('Rejected'))
  UPDATE dbo.Projects SET Status=CASE WHEN RequiresPet=0 THEN 'Registered' ELSE 'Active' END, UpdatedUtc=SYSUTCDATETIME() WHERE ProjectId=@ProjectId;
END;
GO