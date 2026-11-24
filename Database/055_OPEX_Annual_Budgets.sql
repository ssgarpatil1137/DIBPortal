USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF OBJECT_ID('dbo.OpexContractBudgets','U') IS NULL
BEGIN
    CREATE TABLE dbo.OpexContractBudgets
    (
        OpexContractBudgetId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_OpexContractBudgets PRIMARY KEY,
        ProjectId INT NOT NULL CONSTRAINT FK_OpexContractBudgets_Projects REFERENCES dbo.Projects(ProjectId) ON DELETE CASCADE,
        BudgetYear INT NOT NULL,
        AnnualBudget DECIMAL(19,2) NOT NULL,
        CarryForwardAmount DECIMAL(19,2) NOT NULL CONSTRAINT DF_OpexContractBudgets_CarryForward DEFAULT(0),
        ReturnedAmount DECIMAL(19,2) NOT NULL CONSTRAINT DF_OpexContractBudgets_Returned DEFAULT(0),
        CreatedUtc DATETIME2 NOT NULL CONSTRAINT DF_OpexContractBudgets_CreatedUtc DEFAULT SYSUTCDATETIME(),
        CreatedBy NVARCHAR(254) NOT NULL,
        UpdatedUtc DATETIME2 NOT NULL CONSTRAINT DF_OpexContractBudgets_UpdatedUtc DEFAULT SYSUTCDATETIME(),
        UpdatedBy NVARCHAR(254) NOT NULL,
        CONSTRAINT UQ_OpexContractBudgets_Project_Year UNIQUE(ProjectId,BudgetYear),
        CONSTRAINT CK_OpexContractBudgets_Year CHECK(BudgetYear BETWEEN 2000 AND 2100),
        CONSTRAINT CK_OpexContractBudgets_Amounts CHECK(AnnualBudget>=0 AND CarryForwardAmount>=0 AND ReturnedAmount>=0)
    );
END;
GO

IF OBJECT_ID('dbo.OpexContractBudgetHistory','U') IS NULL
BEGIN
    CREATE TABLE dbo.OpexContractBudgetHistory
    (
        BudgetHistoryId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_OpexContractBudgetHistory PRIMARY KEY,
        ProjectId INT NOT NULL,
        BudgetYear INT NOT NULL,
        PreviousAnnualBudget DECIMAL(19,2) NULL,
        AnnualBudget DECIMAL(19,2) NOT NULL,
        PreviousCarryForwardAmount DECIMAL(19,2) NULL,
        CarryForwardAmount DECIMAL(19,2) NOT NULL,
        PreviousReturnedAmount DECIMAL(19,2) NULL,
        ReturnedAmount DECIMAL(19,2) NOT NULL,
        ChangedUtc DATETIME2 NOT NULL CONSTRAINT DF_OpexContractBudgetHistory_ChangedUtc DEFAULT SYSUTCDATETIME(),
        ChangedBy NVARCHAR(254) NOT NULL
    );
    CREATE INDEX IX_OpexContractBudgetHistory_Project_Year ON dbo.OpexContractBudgetHistory(ProjectId,BudgetYear,ChangedUtc DESC);
END;
GO

IF DATABASE_PRINCIPAL_ID('dfm_app') IS NOT NULL
BEGIN
    GRANT SELECT,INSERT,UPDATE ON dbo.OpexContractBudgets TO dfm_app;
    GRANT SELECT,INSERT ON dbo.OpexContractBudgetHistory TO dfm_app;
END;
GO