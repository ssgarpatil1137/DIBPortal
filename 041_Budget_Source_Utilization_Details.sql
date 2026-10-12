USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
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
 pet.ApprovedUtc,
 bl.BudgetLineId,
 bl.Vendor,
 bl.Justification,
 bl.Cost,
 bl.Currency,
 bl.GlNumber GlId,
 CASE WHEN NULLIF(LTRIM(RTRIM(ISNULL(bl.GlNumber,''))),'') IS NULL THEN b.BudgetType ELSE 'GL' END FundingSource,
 gl.GlName GlName,
 bl.CamId,
 bl.CamStatus,
 bl.CamComments CamComment,
 bl.LpoRequest LpoRequestId,
 bl.LpoStatus,
 i.InvoiceId,
 i.InvoiceNo,
 i.InvoiceAmount,
 i.InvoiceStatus
FROM dbo.BudgetSources b
JOIN dbo.Projects p ON p.BudgetSourceId=b.BudgetSourceId
JOIN dbo.PETRequests pet ON pet.ProjectId=p.ProjectId AND pet.Status='Approved'
LEFT JOIN dbo.BudgetLines bl ON bl.PetId=pet.PetId
LEFT JOIN dbo.GLFunds gl ON UPPER(LTRIM(RTRIM(gl.GlNumber)))=UPPER(LTRIM(RTRIM(ISNULL(bl.GlNumber,''))))
OUTER APPLY (
 SELECT
  MAX(x.InvoiceId) InvoiceId,
  MAX(x.InvoiceNumber) InvoiceNo,
  SUM(x.InvoiceAmount) InvoiceAmount,
  MAX(x.InvoiceStatus) InvoiceStatus
 FROM dbo.Invoices x
 WHERE x.BudgetLineId=bl.BudgetLineId
) i;
GO