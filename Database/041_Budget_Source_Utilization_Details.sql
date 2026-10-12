USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetBudgetSources
AS
BEGIN
 SET NOCOUNT ON;
 WITH ApprovedUsage AS (
  SELECT p.BudgetSourceId, SUM(pet.RequestedAmount) Amount
  FROM dbo.Projects p
  JOIN dbo.PETRequests pet ON pet.ProjectId=p.ProjectId
  WHERE pet.Status='Approved'
  GROUP BY p.BudgetSourceId
 )
 SELECT b.BudgetSourceId,b.BudgetType,b.ExternalId,b.Description,b.Budget,
  CAST(ISNULL(u.Amount,0) AS decimal(19,2)) Utilization,
  CAST(ISNULL(b.Budget,0)-ISNULL(u.Amount,0) AS decimal(19,2)) AvailableBudget,
  b.LockedAmount,b.BudgetAfterLocked,b.ClaimAmount,
  CAST(ISNULL(b.Budget,0)-ISNULL(u.Amount,0) AS decimal(19,2)) NetBalance,
  b.SourceFile,b.LastSyncUtc,b.UpdatedUtc
 FROM dbo.BudgetSources b
 LEFT JOIN ApprovedUsage u ON u.BudgetSourceId=b.BudgetSourceId
 ORDER BY b.BudgetType,b.ExternalId;
END;
GO

CREATE OR ALTER VIEW dbo.vw_ManagementDashboard AS
WITH ApprovedUsage AS (
 SELECT p.BudgetType, SUM(pet.RequestedAmount) Amount
 FROM dbo.Projects p
 JOIN dbo.PETRequests pet ON pet.ProjectId=p.ProjectId
 WHERE pet.Status='Approved'
 GROUP BY p.BudgetType
)
SELECT (SELECT COUNT(*) FROM dbo.Projects) ProjectsRegistered,
 (SELECT COUNT(*) FROM dbo.PETRequests WHERE Status='Approved') PetsApproved,
 (SELECT COUNT(*) FROM dbo.PETRequests WHERE Status IN('Pending Review','Pending Approval')) PetsOnTrack,
 (SELECT COUNT(*) FROM dbo.PETRequests WHERE Status='Rejected') PetsRejected,
 (SELECT COUNT(*) FROM dbo.Invoices) InvoicesRaised,
 (SELECT COUNT(*) FROM dbo.Invoices WHERE InvoiceStatus IN('Raised','Outstanding','Received')) InvoicesOutstanding,
 (SELECT COUNT(*) FROM dbo.Invoices WHERE InvoiceStatus IN('Settled','Paid')) InvoicesSettled,
 (SELECT ISNULL(SUM(Budget),0) FROM dbo.BudgetSources WHERE BudgetType='CAPEX') CapexBudget,
 ISNULL((SELECT Amount FROM ApprovedUsage WHERE BudgetType='CAPEX'),0) CapexUtilized,
 (SELECT ISNULL(SUM(Budget),0) FROM dbo.BudgetSources WHERE BudgetType='OPEX') OpexBudget,
 ISNULL((SELECT Amount FROM ApprovedUsage WHERE BudgetType='OPEX'),0) OpexUtilized;
GO

CREATE OR ALTER VIEW dbo.vw_CapexProjectUtilization AS
SELECT
 b.BudgetSourceId,
 b.BudgetType,
 b.ExternalId BudgetSource,
 b.Description BudgetDescription,
 p.ProjectId,
 COALESCE(NULLIF(p.JiraKey,''),p.ProjectCode) ProjectDisplayId,
 p.ProjectCode,
 p.JiraKey,
 p.ProjectName,
 pet.PetId,
 pet.Code PetCode,
 pet.Status PetStatus,
 pet.RequestedAmount PetAmount,
 pet.ApprovedUtc
FROM dbo.BudgetSources b
JOIN dbo.Projects p ON p.BudgetSourceId=b.BudgetSourceId
JOIN dbo.PETRequests pet ON pet.ProjectId=p.ProjectId AND pet.Status='Approved';
GO