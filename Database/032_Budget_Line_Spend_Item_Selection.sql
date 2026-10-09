USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF OBJECT_ID('dbo.BudgetLineSpendItems','U') IS NULL
BEGIN
 CREATE TABLE dbo.BudgetLineSpendItems(
  BudgetLineId int NOT NULL,
  SpendItemId int NOT NULL,
  CreatedUtc datetime2 NOT NULL CONSTRAINT DF_BudgetLineSpendItems_CreatedUtc DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_BudgetLineSpendItems PRIMARY KEY(BudgetLineId),
  CONSTRAINT FK_BudgetLineSpendItems_BudgetLines FOREIGN KEY(BudgetLineId) REFERENCES dbo.BudgetLines(BudgetLineId) ON DELETE CASCADE,
  CONSTRAINT FK_BudgetLineSpendItems_SpendItems FOREIGN KEY(SpendItemId) REFERENCES dbo.SpendItems(SpendItemId)
 );
END;
GO