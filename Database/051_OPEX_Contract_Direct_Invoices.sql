USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF COL_LENGTH('dbo.Invoices','ProjectId') IS NULL ALTER TABLE dbo.Invoices ADD ProjectId INT NULL;
GO

ALTER TABLE dbo.Invoices ALTER COLUMN BudgetLineId INT NULL;
GO

IF OBJECT_ID('dbo.FK_Invoices_Projects','F') IS NULL
    ALTER TABLE dbo.Invoices ADD CONSTRAINT FK_Invoices_Projects FOREIGN KEY(ProjectId) REFERENCES dbo.Projects(ProjectId);
GO

IF OBJECT_ID('dbo.CK_Invoices_Parent','C') IS NULL
    ALTER TABLE dbo.Invoices ADD CONSTRAINT CK_Invoices_Parent CHECK(
        (ProjectId IS NOT NULL AND BudgetLineId IS NULL) OR
        (ProjectId IS NULL AND BudgetLineId IS NOT NULL));
GO

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_Invoices_ProjectId' AND object_id=OBJECT_ID('dbo.Invoices'))
    CREATE INDEX IX_Invoices_ProjectId ON dbo.Invoices(ProjectId,CreatedUtc DESC) WHERE ProjectId IS NOT NULL;
GO

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='UX_Invoices_ProjectNumber' AND object_id=OBJECT_ID('dbo.Invoices'))
    CREATE UNIQUE INDEX UX_Invoices_ProjectNumber ON dbo.Invoices(ProjectId,InvoiceNumber) WHERE ProjectId IS NOT NULL;
GO

UPDATE dbo.Projects SET RequiresPet=0,SkipReview=1,UpdatedUtc=SYSUTCDATETIME()
WHERE ProjectType=N'OPEX Contract' AND (RequiresPet<>0 OR SkipReview<>1);
GO

CREATE OR ALTER PROCEDURE dbo.sp_SaveInvoice
 @Id int=NULL,@Line int=NULL,@Vendor nvarchar(300),@Justification nvarchar(1000)=NULL,@Gl nvarchar(50)=NULL,
 @Number nvarchar(100),@Amount decimal(19,2),@Status nvarchar(50),@PaymentDate date=NULL,@User nvarchar(254),@Project int=NULL
AS
BEGIN
 SET NOCOUNT ON;
 IF (@Project IS NULL AND @Line IS NULL) OR (@Project IS NOT NULL AND @Line IS NOT NULL)
  THROW 50080,'Select either an OPEX Contract or a Budget Line for the invoice.',1;
 IF @Project IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.Projects WHERE ProjectId=@Project AND ProjectType=N'OPEX Contract')
  THROW 50081,'Direct invoices can be created only for an OPEX Contract.',1;
 IF @Line IS NOT NULL AND EXISTS(SELECT 1 FROM dbo.BudgetLines bl JOIN dbo.PETRequests pet ON pet.PetId=bl.PetId JOIN dbo.Projects p ON p.ProjectId=pet.ProjectId WHERE bl.BudgetLineId=@Line AND p.ProjectType=N'OPEX Contract')
  THROW 50082,'OPEX Contract invoices must be linked directly to the contract.',1;
 IF @Id IS NULL
 BEGIN
  INSERT dbo.Invoices(ProjectId,BudgetLineId,VendorName,Justification,GlNumber,InvoiceNumber,InvoiceAmount,InvoiceStatus,PaymentDate,CreatedBy)
  VALUES(@Project,@Line,@Vendor,@Justification,@Gl,@Number,@Amount,@Status,@PaymentDate,@User);
  SET @Id=SCOPE_IDENTITY();
 END
 ELSE
  UPDATE dbo.Invoices SET ProjectId=@Project,BudgetLineId=@Line,VendorName=@Vendor,Justification=@Justification,GlNumber=@Gl,
   InvoiceNumber=@Number,InvoiceAmount=@Amount,InvoiceStatus=@Status,PaymentDate=@PaymentDate,UpdatedUtc=SYSUTCDATETIME()
  WHERE InvoiceId=@Id;
 SELECT InvoiceId FROM dbo.Invoices WHERE InvoiceId=@Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetProjectDetail @ProjectId int
AS
BEGIN
 SET NOCOUNT ON;
 SELECT * FROM dbo.vw_ProjectPortfolio WHERE ProjectId=@ProjectId;
 SELECT * FROM dbo.PETRequests WHERE ProjectId=@ProjectId ORDER BY CreatedUtc;
 SELECT s.* FROM dbo.SpendItems s JOIN dbo.PETRequests p ON p.PetId=s.PetId WHERE p.ProjectId=@ProjectId;
 SELECT b.* FROM dbo.BudgetLines b JOIN dbo.PETRequests p ON p.PetId=b.PetId WHERE p.ProjectId=@ProjectId;
 SELECT i.* FROM dbo.Invoices i
 WHERE i.ProjectId=@ProjectId OR i.BudgetLineId IN (
  SELECT b.BudgetLineId FROM dbo.BudgetLines b JOIN dbo.PETRequests p ON p.PetId=b.PetId WHERE p.ProjectId=@ProjectId)
 ORDER BY i.CreatedUtc;
 SELECT AttachmentId,EntityType,EntityId,OriginalName,ContentType,FileSize,UploadedUtc FROM dbo.Attachments
 WHERE (EntityType='Project' AND EntityId=@ProjectId) OR (EntityType='PET' AND EntityId IN (SELECT PetId FROM dbo.PETRequests WHERE ProjectId=@ProjectId));
END;
GO

-- Same portfolio contract as migration 050, with direct OPEX Contract invoices included.
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
 (SELECT COUNT(*) FROM dbo.Invoices i WHERE i.ProjectId=p.ProjectId OR i.BudgetLineId IN (SELECT bl.BudgetLineId FROM dbo.BudgetLines bl JOIN dbo.PETRequests pet ON pet.PetId=bl.PetId WHERE pet.ProjectId=p.ProjectId)) InvoiceCount,
 (SELECT ISNULL(SUM(i.InvoiceAmount),0) FROM dbo.Invoices i WHERE i.ProjectId=p.ProjectId OR i.BudgetLineId IN (SELECT bl.BudgetLineId FROM dbo.BudgetLines bl JOIN dbo.PETRequests pet ON pet.PetId=bl.PetId WHERE pet.ProjectId=p.ProjectId)) InvoicedAmount,
 p.PlatformId,pl.Name PlatformName,p.VendorId,v.Name VendorName,p.ContractNumber,p.ContractStartDate,p.ContractEndDate,p.ContractBudget,p.ContractGlNumber,p.MemoCamId,p.MemoCamStatus,p.LpoSoNumber,p.ContractDescription,p.ContractStatus,p.ContractClosedDate,
 CASE WHEN p.ContractStartDate IS NULL OR p.ContractEndDate IS NULL THEN NULL WHEN YEAR(p.ContractStartDate)=YEAR(p.ContractEndDate) THEN CONVERT(VARCHAR(4),YEAR(p.ContractStartDate)) ELSE CONVERT(VARCHAR(4),YEAR(p.ContractStartDate))+'-'+RIGHT(CONVERT(VARCHAR(4),YEAR(p.ContractEndDate)),2) END ContractYear,
 CAST(CASE WHEN p.ProjectType=N'OPEX Contract' AND p.ContractEndDate<CONVERT(date,GETDATE()) AND ISNULL(p.ContractStatus,N'Open')<>N'Closed' THEN 1 ELSE 0 END AS bit) IsExpiredUnclosed,
 DATEDIFF(day,CONVERT(date,GETDATE()),p.ContractEndDate) DaysToExpiry
FROM dbo.Projects p
LEFT JOIN dbo.Users u ON u.Email=p.RequestorEmail
LEFT JOIN dbo.BudgetSources b ON b.BudgetSourceId=p.BudgetSourceId
LEFT JOIN dbo.Platforms pl ON pl.PlatformId=p.PlatformId
LEFT JOIN dbo.Vendors v ON v.VendorId=p.VendorId;
GO