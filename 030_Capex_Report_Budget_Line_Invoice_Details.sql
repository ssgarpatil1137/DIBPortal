USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER VIEW dbo.vw_CapexProjectUtilization AS
SELECT
 b.BudgetSourceId,
 b.ExternalId BudgetSource,
 b.Description BudgetDescription,
 p.ProjectId,
 p.ProjectCode,
 p.ProjectName,
 pet.PetId,
 pet.Code PetCode,
 pet.RequestedAmount ApprovedAmount,
 pet.ApprovedUtc,
 bl.Vendor,
 bl.Justification,
 bl.Cost,
 bl.Currency,
 bl.GlNumber GlId,
 bl.CamId,
 bl.CamStatus,
 bl.CamComments CamComment,
 bl.LpoRequest LpoRequestId,
 bl.LpoStatus,
 i.InvoiceNumber InvoiceNo,
 i.InvoiceAmount,
 i.InvoiceStatus
FROM dbo.BudgetSources b
JOIN dbo.Projects p ON p.BudgetSourceId=b.BudgetSourceId
JOIN dbo.PETRequests pet ON pet.ProjectId=p.ProjectId AND pet.Status='Approved'
LEFT JOIN dbo.BudgetLines bl ON bl.PetId=pet.PetId
LEFT JOIN dbo.Invoices i ON i.BudgetLineId=bl.BudgetLineId
WHERE b.BudgetType='CAPEX';
GO