USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF OBJECT_ID('dbo.Platforms','U') IS NULL
BEGIN
    CREATE TABLE dbo.Platforms
    (
        PlatformId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Platforms PRIMARY KEY,
        Name NVARCHAR(200) NOT NULL,
        NormalizedName AS UPPER(LTRIM(RTRIM(Name))) PERSISTED,
        Description NVARCHAR(500) NULL,
        IsActive BIT NOT NULL CONSTRAINT DF_Platforms_IsActive DEFAULT(1),
        CreatedUtc DATETIME2 NOT NULL CONSTRAINT DF_Platforms_CreatedUtc DEFAULT SYSUTCDATETIME(),
        CreatedBy NVARCHAR(254) NULL,
        UpdatedUtc DATETIME2 NOT NULL CONSTRAINT DF_Platforms_UpdatedUtc DEFAULT SYSUTCDATETIME(),
        UpdatedBy NVARCHAR(254) NULL
    );
    CREATE UNIQUE INDEX UX_Platforms_NormalizedName ON dbo.Platforms(NormalizedName);
END;
GO

-- Nullable so existing projects and OPEX Contracts are unaffected; one platform can link to many contracts.
IF COL_LENGTH('dbo.Projects','PlatformId') IS NULL
BEGIN
    ALTER TABLE dbo.Projects ADD PlatformId INT NULL;
END;
GO

IF OBJECT_ID('dbo.FK_Projects_Platforms','F') IS NULL
BEGIN
    ALTER TABLE dbo.Projects ADD CONSTRAINT FK_Projects_Platforms FOREIGN KEY (PlatformId) REFERENCES dbo.Platforms(PlatformId);
END;
GO

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_Projects_PlatformId' AND object_id=OBJECT_ID('dbo.Projects'))
BEGIN
    CREATE INDEX IX_Projects_PlatformId ON dbo.Projects(PlatformId) WHERE PlatformId IS NOT NULL;
END;
GO

-- Same as 038_GL_Funding_Management.sql with PlatformId/PlatformName appended.
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
 p.PlatformId,pl.Name PlatformName
FROM dbo.Projects p LEFT JOIN dbo.Users u ON u.Email=p.RequestorEmail LEFT JOIN dbo.BudgetSources b ON b.BudgetSourceId=p.BudgetSourceId LEFT JOIN dbo.Platforms pl ON pl.PlatformId=p.PlatformId;
GO

IF DATABASE_PRINCIPAL_ID('dfm_app') IS NOT NULL
BEGIN
    GRANT SELECT ON dbo.Platforms TO dfm_app;
    GRANT INSERT ON dbo.Platforms TO dfm_app;
    GRANT UPDATE ON dbo.Platforms TO dfm_app;
END;
GO
