USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- Non Project OPEX lines are linked to an OPEX source through OpexReference = BudgetSources.ExternalId.
CREATE OR ALTER VIEW dbo.vw_NonProjectOpexUtilization AS
SELECT
 b.BudgetSourceId,
 b.BudgetType,
 b.ExternalId BudgetSource,
 l.NonProjectOpexLineId,
 l.Initiative,
 l.LineItem,
 l.Vendor,
 l.MemoCamId,
 l.InvoiceNumber,
 l.InvoiceStatus,
 l.AmountApprovedAed,
 l.InvoiceAmountAed,
 l.CreatedBy,
 l.CreatedUtc
FROM dbo.NonProjectOpexLines l
JOIN dbo.BudgetSources b ON b.BudgetType='OPEX' AND b.ExternalId=l.OpexReference;
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
 ), NonProjectUsage AS (
  SELECT BudgetSourceId, SUM(AmountApprovedAed) Amount
  FROM dbo.vw_NonProjectOpexUtilization
  GROUP BY BudgetSourceId
 )
 SELECT b.BudgetSourceId,b.BudgetType,b.ExternalId,b.Description,b.Budget,
  CAST(ISNULL(u.Amount,0)+ISNULL(n.Amount,0) AS decimal(19,2)) Utilization,
  CAST(ISNULL(b.Budget,0)-ISNULL(u.Amount,0)-ISNULL(n.Amount,0) AS decimal(19,2)) AvailableBudget,
  b.LockedAmount,b.BudgetAfterLocked,b.ClaimAmount,
  CAST(ISNULL(b.Budget,0)-ISNULL(u.Amount,0)-ISNULL(n.Amount,0) AS decimal(19,2)) NetBalance,
  b.SourceFile,b.LastSyncUtc,b.UpdatedUtc
 FROM dbo.BudgetSources b
 LEFT JOIN ApprovedUsage u ON u.BudgetSourceId=b.BudgetSourceId
 LEFT JOIN NonProjectUsage n ON n.BudgetSourceId=b.BudgetSourceId
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
 ISNULL((SELECT Amount FROM ApprovedUsage WHERE BudgetType='OPEX'),0)
  + ISNULL((SELECT SUM(AmountApprovedAed) FROM dbo.vw_NonProjectOpexUtilization),0) OpexUtilized;
GO
