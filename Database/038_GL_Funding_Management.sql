USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF OBJECT_ID('dbo.GLFunds','U') IS NULL
BEGIN
 CREATE TABLE dbo.GLFunds(
  GLFundId int IDENTITY PRIMARY KEY,
  GlNumber nvarchar(50) NOT NULL,
  GlName nvarchar(300) NOT NULL,
  FundAmount decimal(19,2) NOT NULL,
  IsActive bit NOT NULL CONSTRAINT DF_GLFunds_IsActive DEFAULT 1,
  CreatedUtc datetime2 NOT NULL CONSTRAINT DF_GLFunds_CreatedUtc DEFAULT SYSUTCDATETIME(),
  CreatedBy nvarchar(254) NOT NULL,
  UpdatedUtc datetime2 NULL,
  UpdatedBy nvarchar(254) NULL,
  CONSTRAINT UQ_GLFunds_GlNumber UNIQUE(GlNumber),
  CONSTRAINT CK_GLFunds_FundAmount_Positive CHECK(FundAmount>0)
 );
END;
GO

CREATE OR ALTER VIEW dbo.vw_GLFundBalances AS
SELECT
 g.GLFundId GlFundId,
 g.GlNumber,
 g.GlName,
 g.FundAmount,
 CAST(ISNULL((SELECT SUM(bl.Cost)
  FROM dbo.BudgetLines bl
  JOIN dbo.PETRequests pet ON pet.PetId=bl.PetId
  WHERE UPPER(LTRIM(RTRIM(ISNULL(bl.GlNumber,''))))=UPPER(LTRIM(RTRIM(g.GlNumber)))
   AND ISNULL(pet.Status,'') NOT IN ('Rejected','Cancelled')
   AND ISNULL(bl.CamStatus,'') NOT IN ('Rejected','Cancelled')),0) AS decimal(19,2)) ReservedAmount,
 CAST(g.FundAmount-ISNULL((SELECT SUM(bl.Cost)
  FROM dbo.BudgetLines bl
  JOIN dbo.PETRequests pet ON pet.PetId=bl.PetId
  WHERE UPPER(LTRIM(RTRIM(ISNULL(bl.GlNumber,''))))=UPPER(LTRIM(RTRIM(g.GlNumber)))
   AND ISNULL(pet.Status,'') NOT IN ('Rejected','Cancelled')
   AND ISNULL(bl.CamStatus,'') NOT IN ('Rejected','Cancelled')),0) AS decimal(19,2)) AvailableBalance,
 g.IsActive,
 g.CreatedUtc,
 g.CreatedBy,
 g.UpdatedUtc,
 g.UpdatedBy,
 CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.BudgetLines bl WHERE UPPER(LTRIM(RTRIM(ISNULL(bl.GlNumber,''))))=UPPER(LTRIM(RTRIM(g.GlNumber)))) THEN 1 ELSE 0 END AS bit) IsUsed
FROM dbo.GLFunds g;
GO

CREATE OR ALTER PROCEDURE dbo.sp_SaveGLFund
 @GLFundId int=NULL,@GlNumber nvarchar(50),@GlName nvarchar(300),@FundAmount decimal(19,2),@IsActive bit=1,@User nvarchar(254)
AS
BEGIN
 SET NOCOUNT ON;
 SET @GlNumber=UPPER(LTRIM(RTRIM(ISNULL(@GlNumber,''))));
 SET @GlName=LTRIM(RTRIM(ISNULL(@GlName,'')));
 IF @GlNumber='' THROW 50040,'GL Number is required.',1;
 IF @GlName='' THROW 50041,'GL Description/Name is required.',1;
 IF ISNULL(@FundAmount,0)<=0 THROW 50042,'Fund Amount must be a positive amount.',1;
 IF EXISTS(SELECT 1 FROM dbo.GLFunds WHERE UPPER(LTRIM(RTRIM(GlNumber)))=@GlNumber AND (@GLFundId IS NULL OR GLFundId<>@GLFundId)) THROW 50043,'GL Number already exists.',1;
 IF @GLFundId IS NULL
 BEGIN
  INSERT dbo.GLFunds(GlNumber,GlName,FundAmount,IsActive,CreatedBy) VALUES(@GlNumber,@GlName,@FundAmount,@IsActive,@User);
  SET @GLFundId=SCOPE_IDENTITY();
 END
 ELSE
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM dbo.GLFunds WHERE GLFundId=@GLFundId) THROW 50044,'GL was not found.',1;
  UPDATE dbo.GLFunds SET GlNumber=@GlNumber,GlName=@GlName,FundAmount=@FundAmount,IsActive=@IsActive,UpdatedUtc=SYSUTCDATETIME(),UpdatedBy=@User WHERE GLFundId=@GLFundId;
 END
 SELECT * FROM dbo.vw_GLFundBalances WHERE GLFundId=@GLFundId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetBudgetSources
AS
BEGIN
 SET NOCOUNT ON;
 WITH GlRelease AS (
  SELECT p.BudgetSourceId, SUM(bl.Cost) Amount
  FROM dbo.BudgetLines bl
  JOIN dbo.PETRequests pet ON pet.PetId=bl.PetId
  JOIN dbo.Projects p ON p.ProjectId=pet.ProjectId
  WHERE NULLIF(LTRIM(RTRIM(ISNULL(bl.GlNumber,''))),'') IS NOT NULL
   AND ISNULL(pet.Status,'') NOT IN ('Rejected','Cancelled')
   AND ISNULL(bl.CamStatus,'') NOT IN ('Rejected','Cancelled')
  GROUP BY p.BudgetSourceId
 )
 SELECT b.BudgetSourceId,b.BudgetType,b.ExternalId,b.Description,b.Budget,
  CAST(ISNULL(b.Utilization,0)-ISNULL(r.Amount,0) AS decimal(19,2)) Utilization,
  CAST(ISNULL(b.AvailableBudget,0)+ISNULL(r.Amount,0) AS decimal(19,2)) AvailableBudget,
  b.LockedAmount,b.BudgetAfterLocked,b.ClaimAmount,
  CAST(ISNULL(b.NetBalance,0)+ISNULL(r.Amount,0) AS decimal(19,2)) NetBalance,
  b.SourceFile,b.LastSyncUtc,b.UpdatedUtc
 FROM dbo.BudgetSources b
 LEFT JOIN GlRelease r ON r.BudgetSourceId=b.BudgetSourceId
 ORDER BY b.BudgetType,b.ExternalId;
END;
GO

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
 (SELECT ISNULL(SUM(x.InvoiceAmount),0) FROM dbo.Invoices x JOIN dbo.BudgetLines bl ON bl.BudgetLineId=x.BudgetLineId JOIN dbo.PETRequests pet ON pet.PetId=bl.PetId WHERE pet.ProjectId=p.ProjectId) InvoicedAmount
FROM dbo.Projects p LEFT JOIN dbo.Users u ON u.Email=p.RequestorEmail LEFT JOIN dbo.BudgetSources b ON b.BudgetSourceId=p.BudgetSourceId;
GO

CREATE OR ALTER PROCEDURE dbo.sp_SaveBudgetLine
 @Id int=NULL,@Pet int,@Vendor nvarchar(300),@Justification nvarchar(1000)=NULL,@Cost decimal(19,2),@Currency char(3),@Gl nvarchar(50)=NULL,@PetRef nvarchar(100)=NULL,@CamId nvarchar(100)=NULL,@CamStatus nvarchar(50)=NULL,@CamComments nvarchar(1000)=NULL,@LpoRequest nvarchar(100)=NULL,@LpoStatus nvarchar(50)=NULL,@LpoComments nvarchar(1000)=NULL,@User nvarchar(254),@CamCreatedDate date=NULL,@CamApprovedDate date=NULL,@LpoIssueDate date=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET @Gl=NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@Gl,'')))),'');
 IF @Cost<=0 THROW 50045,'A positive Budget Line amount is required.',1;
 IF @Id IS NULL AND NOT EXISTS(SELECT 1 FROM dbo.PETRequests WHERE PetId=@Pet AND Status='Approved') THROW 50016,'Budget Lines can be added only after the selected PET is approved.',1;
 IF @Gl IS NOT NULL
 BEGIN
  DECLARE @AvailableGL decimal(19,2);
  SELECT @AvailableGL=FundAmount-ISNULL((SELECT SUM(bl.Cost)
   FROM dbo.BudgetLines bl
   JOIN dbo.PETRequests pet ON pet.PetId=bl.PetId
   WHERE UPPER(LTRIM(RTRIM(ISNULL(bl.GlNumber,''))))=UPPER(LTRIM(RTRIM(g.GlNumber)))
    AND ISNULL(pet.Status,'') NOT IN ('Rejected','Cancelled')
    AND ISNULL(bl.CamStatus,'') NOT IN ('Rejected','Cancelled')
    AND (@Id IS NULL OR bl.BudgetLineId<>@Id)),0)
  FROM dbo.GLFunds g WITH(UPDLOCK)
  WHERE UPPER(LTRIM(RTRIM(g.GlNumber)))=@Gl
   AND (g.IsActive=1 OR EXISTS(SELECT 1 FROM dbo.BudgetLines existing WHERE existing.BudgetLineId=@Id AND UPPER(LTRIM(RTRIM(ISNULL(existing.GlNumber,''))))=@Gl));
  IF @AvailableGL IS NULL THROW 50046,'Selected GL is not active or was not found.',1;
  IF @Cost>@AvailableGL THROW 50047,'Budget Line amount exceeds the available GL balance.',1;
 END;
 IF @Id IS NULL BEGIN INSERT dbo.BudgetLines(PetId,Vendor,Justification,Cost,Currency,GlNumber,PetReference,CamId,CamStatus,CamCreatedDate,CamApprovedDate,CamComments,LpoRequest,LpoStatus,LpoIssueDate,LpoComments,CreatedBy) VALUES(@Pet,@Vendor,@Justification,@Cost,@Currency,@Gl,@PetRef,@CamId,@CamStatus,@CamCreatedDate,@CamApprovedDate,@CamComments,@LpoRequest,@LpoStatus,@LpoIssueDate,@LpoComments,@User); SET @Id=SCOPE_IDENTITY(); END ELSE UPDATE dbo.BudgetLines SET Vendor=@Vendor,Justification=@Justification,Cost=@Cost,Currency=@Currency,GlNumber=@Gl,PetReference=@PetRef,CamId=@CamId,CamStatus=@CamStatus,CamCreatedDate=@CamCreatedDate,CamApprovedDate=@CamApprovedDate,CamComments=@CamComments,LpoRequest=@LpoRequest,LpoStatus=@LpoStatus,LpoIssueDate=@LpoIssueDate,LpoComments=@LpoComments,UpdatedUtc=SYSUTCDATETIME() WHERE BudgetLineId=@Id;
 SELECT BudgetLineId FROM dbo.BudgetLines WHERE BudgetLineId=@Id;
END;
GO

CREATE OR ALTER VIEW dbo.vw_CapexProjectUtilization AS
SELECT
 b.BudgetSourceId,
 b.BudgetType,
 b.ExternalId BudgetSource,
 b.Description BudgetDescription,
 p.ProjectId,
 p.ProjectCode,
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
 CASE WHEN NULLIF(LTRIM(RTRIM(ISNULL(bl.GlNumber,''))),'') IS NULL THEN 'CAPEX/OPEX' ELSE 'GL' END FundingSource,
 gl.GlName GlName,
 bl.CamId,
 bl.CamStatus,
 bl.CamComments CamComment,
 bl.LpoRequest LpoRequestId,
 bl.LpoStatus,
 i.InvoiceId,
 i.InvoiceNumber InvoiceNo,
 i.InvoiceAmount,
 i.InvoiceStatus
FROM dbo.BudgetSources b
JOIN dbo.Projects p ON p.BudgetSourceId=b.BudgetSourceId
JOIN dbo.PETRequests pet ON pet.ProjectId=p.ProjectId
LEFT JOIN dbo.BudgetLines bl ON bl.PetId=pet.PetId AND NULLIF(LTRIM(RTRIM(ISNULL(bl.GlNumber,''))),'') IS NULL
LEFT JOIN dbo.GLFunds gl ON UPPER(LTRIM(RTRIM(gl.GlNumber)))=UPPER(LTRIM(RTRIM(ISNULL(bl.GlNumber,''))))
LEFT JOIN dbo.Invoices i ON i.BudgetLineId=bl.BudgetLineId;
GO