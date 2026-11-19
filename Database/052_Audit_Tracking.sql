USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF COL_LENGTH('dbo.Projects','CreatedBy') IS NULL ALTER TABLE dbo.Projects ADD CreatedBy NVARCHAR(254) NULL;
IF COL_LENGTH('dbo.Projects','UpdatedBy') IS NULL ALTER TABLE dbo.Projects ADD UpdatedBy NVARCHAR(254) NULL;
IF COL_LENGTH('dbo.PETRequests','UpdatedBy') IS NULL ALTER TABLE dbo.PETRequests ADD UpdatedBy NVARCHAR(254) NULL;
IF COL_LENGTH('dbo.SpendItems','UpdatedBy') IS NULL ALTER TABLE dbo.SpendItems ADD UpdatedBy NVARCHAR(254) NULL;
IF COL_LENGTH('dbo.SpendItems','UpdatedUtc') IS NULL ALTER TABLE dbo.SpendItems ADD UpdatedUtc DATETIME2 NULL;
IF COL_LENGTH('dbo.BudgetLines','UpdatedBy') IS NULL ALTER TABLE dbo.BudgetLines ADD UpdatedBy NVARCHAR(254) NULL;
IF COL_LENGTH('dbo.Invoices','UpdatedBy') IS NULL ALTER TABLE dbo.Invoices ADD UpdatedBy NVARCHAR(254) NULL;
GO

UPDATE dbo.Projects SET CreatedBy=RequestorEmail WHERE CreatedBy IS NULL;
UPDATE dbo.Projects SET UpdatedBy=CreatedBy WHERE UpdatedBy IS NULL;
UPDATE dbo.PETRequests SET UpdatedBy=CreatedBy WHERE UpdatedBy IS NULL;
UPDATE dbo.SpendItems SET UpdatedBy=CreatedBy WHERE UpdatedBy IS NULL AND COL_LENGTH('dbo.SpendItems','CreatedBy') IS NOT NULL;
UPDATE dbo.BudgetLines SET UpdatedBy=CreatedBy WHERE UpdatedBy IS NULL;
UPDATE dbo.Invoices SET UpdatedBy=CreatedBy WHERE UpdatedBy IS NULL;
GO

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_AuditLog_Entity' AND object_id=OBJECT_ID('dbo.AuditLog'))
    CREATE INDEX IX_AuditLog_Entity ON dbo.AuditLog(EntityType,EntityId,ActionUtc DESC);
GO
