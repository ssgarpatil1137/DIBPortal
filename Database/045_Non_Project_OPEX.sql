USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE TABLE dbo.NonProjectOpexBatches(
 NonProjectOpexBatchId int IDENTITY PRIMARY KEY,
 SourceFile nvarchar(260) NOT NULL,
 CreatedBy nvarchar(254) NOT NULL,
 CreatedUtc datetime2 NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.NonProjectOpexLines(
 NonProjectOpexLineId int IDENTITY PRIMARY KEY,
 NonProjectOpexBatchId int NOT NULL REFERENCES dbo.NonProjectOpexBatches(NonProjectOpexBatchId),
 Initiative nvarchar(500) NOT NULL,
 Platform nvarchar(200) NULL,
 LineItem nvarchar(200) NOT NULL,
 EpmId nvarchar(100) NULL,
 BudgetType nvarchar(10) NOT NULL CONSTRAINT CK_NonProjectOpexLines_BudgetType CHECK(BudgetType='OPEX'),
 OpexReference nvarchar(100) NULL,
 GlNumber nvarchar(50) NULL,
 BudgetApprovedAed decimal(19,2) NULL,
 MemoCamId nvarchar(100) NULL,
 AmountApprovedAed decimal(19,2) NOT NULL,
 Vendor nvarchar(300) NOT NULL,
 DateRaised date NULL,
 LpoSoNumber nvarchar(100) NULL,
 PoDate date NULL,
 AmsNumber nvarchar(100) NULL,
 CamStatus nvarchar(100) NULL,
 Description nvarchar(1000) NULL,
 InvoiceMemoNumber nvarchar(100) NULL,
 InvoiceNumber nvarchar(100) NULL,
 InvoiceAmountAed decimal(19,2) NULL,
 InvoiceDate date NULL,
 InvoiceEntryProcessDate date NULL,
 InvoiceStatus nvarchar(100) NULL,
 InvoiceDescription nvarchar(1000) NULL,
 Folder nvarchar(500) NULL,
 HandledBy nvarchar(254) NULL,
 Column1 nvarchar(500) NULL,
 CreatedBy nvarchar(254) NOT NULL,
 CreatedUtc datetime2 NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE INDEX IX_NonProjectOpexLines_Batch ON dbo.NonProjectOpexLines(NonProjectOpexBatchId,NonProjectOpexLineId);
CREATE INDEX IX_NonProjectOpexLines_Creator ON dbo.NonProjectOpexLines(CreatedBy,CreatedUtc DESC);
GO