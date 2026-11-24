USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF COL_LENGTH('dbo.Invoices','InvoiceDate') IS NULL ALTER TABLE dbo.Invoices ADD InvoiceDate DATE NULL;
IF COL_LENGTH('dbo.Invoices','VendorSubmissionDate') IS NULL ALTER TABLE dbo.Invoices ADD VendorSubmissionDate DATE NULL;
IF COL_LENGTH('dbo.Invoices','SystemEntryDate') IS NULL ALTER TABLE dbo.Invoices ADD SystemEntryDate DATETIME2 NULL;
IF COL_LENGTH('dbo.Invoices','Department') IS NULL ALTER TABLE dbo.Invoices ADD Department NVARCHAR(200) NULL;
GO

UPDATE dbo.Invoices
SET InvoiceDate=ISNULL(InvoiceDate,CONVERT(date,CreatedUtc)),
    SystemEntryDate=ISNULL(SystemEntryDate,CreatedUtc);
GO

IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('dbo.Invoices') AND name='SystemEntryDate' AND is_nullable=1)
    ALTER TABLE dbo.Invoices ALTER COLUMN SystemEntryDate DATETIME2 NOT NULL;
GO

IF NOT EXISTS(SELECT 1 FROM sys.default_constraints WHERE parent_object_id=OBJECT_ID('dbo.Invoices') AND name='DF_Invoices_SystemEntryDate')
    ALTER TABLE dbo.Invoices ADD CONSTRAINT DF_Invoices_SystemEntryDate DEFAULT SYSUTCDATETIME() FOR SystemEntryDate;
GO

CREATE OR ALTER PROCEDURE dbo.sp_SaveInvoice
 @Id int=NULL,@Line int=NULL,@Vendor nvarchar(300),@Justification nvarchar(1000)=NULL,@Gl nvarchar(50)=NULL,
 @Number nvarchar(100),@Amount decimal(19,2),@Status nvarchar(50),@PaymentDate date=NULL,@User nvarchar(254),@Project int=NULL,
 @InvoiceDate date=NULL,@VendorSubmissionDate date=NULL,@Department nvarchar(200)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 IF (@Project IS NULL AND @Line IS NULL) OR (@Project IS NOT NULL AND @Line IS NOT NULL)
  THROW 50080,'Select either an OPEX Contract or a Budget Line for the invoice.',1;
 IF @Project IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.Projects WHERE ProjectId=@Project AND ProjectType=N'OPEX Contract')
  THROW 50081,'Direct invoices can be created only for an OPEX Contract.',1;
 IF @Line IS NOT NULL AND EXISTS(SELECT 1 FROM dbo.BudgetLines bl JOIN dbo.PETRequests pet ON pet.PetId=bl.PetId JOIN dbo.Projects p ON p.ProjectId=pet.ProjectId WHERE bl.BudgetLineId=@Line AND p.ProjectType=N'OPEX Contract')
  THROW 50082,'OPEX Contract invoices must be linked directly to the contract.',1;
 IF @InvoiceDate IS NULL THROW 50083,'Invoice date is required.',1;
 IF @Id IS NULL
 BEGIN
  INSERT dbo.Invoices(ProjectId,BudgetLineId,VendorName,Justification,GlNumber,InvoiceNumber,InvoiceAmount,InvoiceStatus,PaymentDate,InvoiceDate,VendorSubmissionDate,Department,CreatedBy)
  VALUES(@Project,@Line,@Vendor,@Justification,@Gl,@Number,@Amount,@Status,@PaymentDate,@InvoiceDate,@VendorSubmissionDate,NULLIF(LTRIM(RTRIM(@Department)),''),@User);
  SET @Id=SCOPE_IDENTITY();
 END
 ELSE
  UPDATE dbo.Invoices SET ProjectId=@Project,BudgetLineId=@Line,VendorName=@Vendor,Justification=@Justification,GlNumber=@Gl,
   InvoiceNumber=@Number,InvoiceAmount=@Amount,InvoiceStatus=@Status,PaymentDate=@PaymentDate,InvoiceDate=@InvoiceDate,
   VendorSubmissionDate=@VendorSubmissionDate,Department=NULLIF(LTRIM(RTRIM(@Department)),''),UpdatedUtc=SYSUTCDATETIME()
  WHERE InvoiceId=@Id;
 SELECT InvoiceId FROM dbo.Invoices WHERE InvoiceId=@Id;
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
 (SELECT COUNT(*) FROM dbo.Invoices WHERE InvoiceStatus IN('Raised','Outstanding','Received','In Progress','Resubmitted')) InvoicesOutstanding,
 (SELECT COUNT(*) FROM dbo.Invoices WHERE InvoiceStatus IN('Settled','Paid')) InvoicesSettled,
 (SELECT ISNULL(SUM(Budget),0) FROM dbo.BudgetSources WHERE BudgetType='CAPEX') CapexBudget,
 ISNULL((SELECT Amount FROM ApprovedUsage WHERE BudgetType='CAPEX'),0) CapexUtilized,
 (SELECT ISNULL(SUM(Budget),0) FROM dbo.BudgetSources WHERE BudgetType='OPEX') OpexBudget,
 ISNULL((SELECT Amount FROM ApprovedUsage WHERE BudgetType='OPEX'),0)
    + ISNULL((SELECT SUM(AmountApprovedAed) FROM dbo.vw_NonProjectOpexUtilization),0) OpexUtilized;
GO