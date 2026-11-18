USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF COL_LENGTH('dbo.Projects','VendorId') IS NULL ALTER TABLE dbo.Projects ADD VendorId INT NULL;
IF COL_LENGTH('dbo.Projects','ContractNumber') IS NULL ALTER TABLE dbo.Projects ADD ContractNumber NVARCHAR(100) NULL;
IF COL_LENGTH('dbo.Projects','ContractStartDate') IS NULL ALTER TABLE dbo.Projects ADD ContractStartDate DATE NULL;
IF COL_LENGTH('dbo.Projects','ContractEndDate') IS NULL ALTER TABLE dbo.Projects ADD ContractEndDate DATE NULL;
IF COL_LENGTH('dbo.Projects','ContractBudget') IS NULL ALTER TABLE dbo.Projects ADD ContractBudget DECIMAL(19,2) NULL;
IF COL_LENGTH('dbo.Projects','ContractGlNumber') IS NULL ALTER TABLE dbo.Projects ADD ContractGlNumber NVARCHAR(50) NULL;
IF COL_LENGTH('dbo.Projects','MemoCamId') IS NULL ALTER TABLE dbo.Projects ADD MemoCamId NVARCHAR(100) NULL;
IF COL_LENGTH('dbo.Projects','MemoCamStatus') IS NULL ALTER TABLE dbo.Projects ADD MemoCamStatus NVARCHAR(50) NULL;
IF COL_LENGTH('dbo.Projects','LpoSoNumber') IS NULL ALTER TABLE dbo.Projects ADD LpoSoNumber NVARCHAR(100) NULL;
IF COL_LENGTH('dbo.Projects','ContractDescription') IS NULL ALTER TABLE dbo.Projects ADD ContractDescription NVARCHAR(2000) NULL;
IF COL_LENGTH('dbo.Projects','ContractStatus') IS NULL ALTER TABLE dbo.Projects ADD ContractStatus NVARCHAR(20) NULL;
IF COL_LENGTH('dbo.Projects','ContractClosedDate') IS NULL ALTER TABLE dbo.Projects ADD ContractClosedDate DATE NULL;
GO

IF OBJECT_ID('dbo.FK_Projects_Vendors','F') IS NULL
BEGIN
    ALTER TABLE dbo.Projects ADD CONSTRAINT FK_Projects_Vendors FOREIGN KEY (VendorId) REFERENCES dbo.Vendors(VendorId);
END;
GO

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='UX_Projects_OpexContractNumber' AND object_id=OBJECT_ID('dbo.Projects'))
BEGIN
    CREATE UNIQUE INDEX UX_Projects_OpexContractNumber ON dbo.Projects(ContractNumber)
    WHERE ProjectType=N'OPEX Contract' AND ContractNumber IS NOT NULL;
END;
GO

IF OBJECT_ID('dbo.CK_Projects_OpexContractStatus','C') IS NULL
BEGIN
    ALTER TABLE dbo.Projects ADD CONSTRAINT CK_Projects_OpexContractStatus
    CHECK(ProjectType<>N'OPEX Contract' OR ContractStatus IS NULL OR ContractStatus IN(N'Open',N'Closed'));
END;
GO

-- Existing OPEX Contract rows remain accessible and editable; lifecycle details can be completed later.
UPDATE dbo.Projects SET ContractStatus=N'Open'
WHERE ProjectType=N'OPEX Contract' AND ContractStatus IS NULL;
GO

-- Same portfolio contract as 048_Platform_Master.sql with OPEX Contract fields appended.
CREATE OR ALTER VIEW dbo.vw_ProjectPortfolio AS
SELECT p.ProjectId,p.ProjectCode,p.JiraKey,p.ProjectName,p.ProjectType,p.AccountableExecLead,p.AccountableExec,p.SmeLead,p.ProjectSize,p.ProjectSizingScores,p.ProjectManager,p.RequestorEmail,COALESCE(u.DisplayName,p.RequestorEmail) RequestorName,p.BudgetType,p.BudgetSourceId,p.RequiresPet,p.SkipReview,p.Status,p.CreatedUtc,
 b.ExternalId BudgetSource,b.Budget,b.Utilization,
 CAST(ISNULL(b.Budget,0)-ISNULL((SELECT SUM(x.RequestedAmount) FROM dbo.PETRequests x WHERE x.ProjectId=p.ProjectId AND ISNULL(x.Status,'') NOT IN ('Rejected','Cancelled')),0)+ISNULL((SELECT SUM(bl.Cost) FROM dbo.BudgetLines bl JOIN dbo.PETRequests pet ON pet.PetId=bl.PetId WHERE pet.ProjectId=p.ProjectId AND NULLIF(LTRIM(RTRIM(ISNULL(bl.GlNumber,''))),'') IS NOT NULL AND ISNULL(pet.Status,'') NOT IN ('Rejected','Cancelled') AND ISNULL(bl.CamStatus,'') NOT IN ('Rejected','Cancelled')),0) AS decimal(19,2)) AvailableBudget,
 (SELECT COUNT(*) FROM dbo.PETRequests x WHERE x.ProjectId=p.ProjectId) PetCount,
 (SELECT COUNT(*) FROM dbo.PETRequests x WHERE x.ProjectId=p.ProjectId AND x.Status='Approved') ApprovedPetCount,
 (SELECT COUNT(*) FROM dbo.PETRequests x WHERE x.ProjectId=p.ProjectId AND x.Status='Pending Review') PendingReviewPetCount,
 (SELECT COUNT(*) FROM dbo.PETRequests x WHERE x.ProjectId=p.ProjectId AND x.Status='Pending Approval') PendingApprovalPetCount,
 (SELECT COUNT(*) FROM dbo.PETRequests x WHERE x.ProjectId=p.ProjectId AND x.Status='Rejected') RejectedPetCount,
 (SELECT COUNT(*) FROM dbo.PETRequests x WHERE x.ProjectId=p.ProjectId AND x.Status='Sent Back') SentBackPetCount,
 (SELECT COUNT(*) FROM dbo.SpendItems s JOIN dbo.PETRequests pet ON pet.PetId=s.PetId WHERE pet.ProjectId=p.ProjectId) SpendRequestCount,
 (SELECT COUNT(*) FROM dbo.BudgetLines bl JOIN dbo.PETRequests pet ON pet.PetId=bl.PetId WHERE pet.ProjectId=p.ProjectId) BudgetLineCount,
 (SELECT COUNT(*) FROM dbo.Invoices i JOIN dbo.BudgetLines bl ON bl.BudgetLineId=i.BudgetLineId JOIN dbo.PETRequests pet ON pet.PetId=bl.PetId WHERE pet.ProjectId=p.ProjectId) InvoiceCount,
 (SELECT ISNULL(SUM(x.InvoiceAmount),0) FROM dbo.Invoices x JOIN dbo.BudgetLines bl ON bl.BudgetLineId=x.BudgetLineId JOIN dbo.PETRequests pet ON pet.PetId=bl.PetId WHERE pet.ProjectId=p.ProjectId) InvoicedAmount,
 p.PlatformId,pl.Name PlatformName,p.VendorId,v.Name VendorName,p.ContractNumber,p.ContractStartDate,p.ContractEndDate,p.ContractBudget,p.ContractGlNumber,p.MemoCamId,p.MemoCamStatus,p.LpoSoNumber,p.ContractDescription,p.ContractStatus,p.ContractClosedDate,
 CASE WHEN p.ContractStartDate IS NULL OR p.ContractEndDate IS NULL THEN NULL
      WHEN YEAR(p.ContractStartDate)=YEAR(p.ContractEndDate) THEN CONVERT(VARCHAR(4),YEAR(p.ContractStartDate))
      ELSE CONVERT(VARCHAR(4),YEAR(p.ContractStartDate))+'-'+RIGHT(CONVERT(VARCHAR(4),YEAR(p.ContractEndDate)),2) END ContractYear,
 CAST(CASE WHEN p.ProjectType=N'OPEX Contract' AND p.ContractEndDate<CONVERT(date,GETDATE()) AND ISNULL(p.ContractStatus,N'Open')<>N'Closed' THEN 1 ELSE 0 END AS bit) IsExpiredUnclosed,
 DATEDIFF(day,CONVERT(date,GETDATE()),p.ContractEndDate) DaysToExpiry
FROM dbo.Projects p
LEFT JOIN dbo.Users u ON u.Email=p.RequestorEmail
LEFT JOIN dbo.BudgetSources b ON b.BudgetSourceId=p.BudgetSourceId
LEFT JOIN dbo.Platforms pl ON pl.PlatformId=p.PlatformId
LEFT JOIN dbo.Vendors v ON v.VendorId=p.VendorId;
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
 (SELECT COUNT(*) FROM dbo.Invoices WHERE InvoiceStatus IN('Raised','Outstanding','Received','In Progress')) InvoicesOutstanding,
 (SELECT COUNT(*) FROM dbo.Invoices WHERE InvoiceStatus IN('Settled','Paid')) InvoicesSettled,
 (SELECT ISNULL(SUM(Budget),0) FROM dbo.BudgetSources WHERE BudgetType='CAPEX') CapexBudget,
 ISNULL((SELECT Amount FROM ApprovedUsage WHERE BudgetType='CAPEX'),0) CapexUtilized,
 (SELECT ISNULL(SUM(Budget),0) FROM dbo.BudgetSources WHERE BudgetType='OPEX') OpexBudget,
 ISNULL((SELECT Amount FROM ApprovedUsage WHERE BudgetType='OPEX'),0)
    + ISNULL((SELECT SUM(AmountApprovedAed) FROM dbo.vw_NonProjectOpexUtilization),0) OpexUtilized;
GO

IF DATABASE_PRINCIPAL_ID('dfm_app') IS NOT NULL
BEGIN
    GRANT SELECT,UPDATE ON dbo.Projects TO dfm_app;
END;
GO