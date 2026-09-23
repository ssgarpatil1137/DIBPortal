USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

ALTER TABLE dbo.Projects ALTER COLUMN BudgetType nvarchar(10) NULL;
ALTER TABLE dbo.Projects ALTER COLUMN BudgetSourceId int NULL;
IF COL_LENGTH('dbo.Projects','ProjectSizingScores') IS NULL
 ALTER TABLE dbo.Projects ADD ProjectSizingScores nvarchar(max) NULL;
GO

CREATE OR ALTER VIEW dbo.vw_ProjectPortfolio AS
SELECT p.ProjectId,p.ProjectCode,p.JiraKey,p.ProjectName,p.ProjectType,p.AccountableExecLead,p.AccountableExec,p.SmeLead,p.ProjectSize,p.ProjectSizingScores,p.ProjectManager,p.RequestorEmail,COALESCE(u.DisplayName,p.RequestorEmail) RequestorName,p.BudgetType,p.BudgetSourceId,p.RequiresPet,p.SkipReview,p.Status,p.CreatedUtc,
 b.ExternalId BudgetSource,b.Budget,b.Utilization,
 CAST(ISNULL(b.Budget,0)-ISNULL((SELECT SUM(x.RequestedAmount) FROM dbo.PETRequests x WHERE x.ProjectId=p.ProjectId AND ISNULL(x.Status,'')<>'Rejected'),0) AS decimal(19,2)) AvailableBudget,
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

CREATE OR ALTER PROCEDURE dbo.sp_SaveProject
 @ProjectId int=NULL,@IsJira bit,@JiraKey nvarchar(50)=NULL,@Name nvarchar(500),@Type nvarchar(100)=NULL,
 @Lead nvarchar(200),@Executive nvarchar(200),@Sme nvarchar(200)=NULL,@Size nvarchar(50)=NULL,@SizingScores nvarchar(max)=NULL,@Manager nvarchar(200)=NULL,
 @BudgetType nvarchar(10)=NULL,@BudgetSource int=NULL,@RequiresPet bit=1,@SkipReview bit=0,@User nvarchar(254)
AS
BEGIN
 SET NOCOUNT ON;
 SET @BudgetType=NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@BudgetType,'')))),'');
 IF @BudgetType IS NOT NULL AND @BudgetType NOT IN ('CAPEX','OPEX') THROW 50001,'Select CAPEX or OPEX.',1;
 IF (@BudgetType IS NULL AND @BudgetSource IS NOT NULL) OR (@BudgetType IS NOT NULL AND @BudgetSource IS NULL)
  THROW 50001,'Select CAPEX or OPEX and a matching budget source.',1;
 IF @BudgetType IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.BudgetSources WHERE BudgetSourceId=@BudgetSource AND BudgetType=@BudgetType)
  THROW 50001,'Budget source does not match CAPEX/OPEX selection.',1;
 IF @RequiresPet=0 BEGIN SET @BudgetType=NULL; SET @BudgetSource=NULL; SET @SkipReview=0; END;
 IF EXISTS(SELECT 1 FROM dbo.Users u JOIN dbo.UserRoles ur ON ur.UserId=u.UserId JOIN dbo.Roles r ON r.RoleId=ur.RoleId WHERE u.Email=@User AND r.Name='Approver')
    AND NOT EXISTS(SELECT 1 FROM dbo.Users u JOIN dbo.UserRoles ur ON ur.UserId=u.UserId JOIN dbo.Roles r ON r.RoleId=ur.RoleId WHERE u.Email=@User AND r.Name IN ('Reviewer','Admin','Master'))
  THROW 50002,'Approver can view only.',1;
 IF @ProjectId IS NULL AND NULLIF(LTRIM(RTRIM(ISNULL(@JiraKey,''))),'') IS NOT NULL AND EXISTS(SELECT 1 FROM dbo.Projects WHERE UPPER(LTRIM(RTRIM(ISNULL(JiraKey,''))))=UPPER(LTRIM(RTRIM(@JiraKey))))
  THROW 50003,'This JIRA project is already registered.',1;
 IF @ProjectId IS NULL AND NULLIF(LTRIM(RTRIM(ISNULL(@JiraKey,''))),'') IS NULL AND EXISTS(SELECT 1 FROM dbo.Projects WHERE LOWER(LTRIM(RTRIM(ProjectName)))=LOWER(LTRIM(RTRIM(@Name))))
  THROW 50004,'This project is already registered.',1;
 IF @ProjectId IS NULL
 BEGIN
  INSERT dbo.Projects(IsJira,JiraKey,ProjectName,ProjectType,AccountableExecLead,AccountableExec,SmeLead,ProjectSize,ProjectSizingScores,ProjectManager,RequestorEmail,BudgetType,BudgetSourceId,RequiresPet,SkipReview,Status)
  VALUES(@IsJira,NULLIF(@JiraKey,''),@Name,@Type,@Lead,@Executive,@Sme,@Size,@SizingScores,@Manager,@User,@BudgetType,@BudgetSource,@RequiresPet,@SkipReview,CASE WHEN @RequiresPet=0 THEN 'Registered' ELSE 'Active' END);
  SET @ProjectId=SCOPE_IDENTITY();
 END
 ELSE
  UPDATE dbo.Projects SET IsJira=@IsJira,JiraKey=NULLIF(@JiraKey,''),ProjectName=@Name,ProjectType=@Type,AccountableExecLead=@Lead,AccountableExec=@Executive,SmeLead=@Sme,ProjectSize=@Size,ProjectSizingScores=@SizingScores,ProjectManager=@Manager,BudgetType=@BudgetType,BudgetSourceId=@BudgetSource,RequiresPet=@RequiresPet,SkipReview=@SkipReview,Status=CASE WHEN @RequiresPet=0 THEN 'Registered' ELSE Status END,UpdatedUtc=SYSUTCDATETIME()
  WHERE ProjectId=@ProjectId AND (RequestorEmail=@User OR EXISTS(SELECT 1 FROM dbo.Users u JOIN dbo.UserRoles ur ON ur.UserId=u.UserId JOIN dbo.Roles r ON r.RoleId=ur.RoleId WHERE u.Email=@User AND r.Name='Master'));
 SELECT ProjectId,ProjectCode FROM dbo.Projects WHERE ProjectId=@ProjectId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_DeleteProject @ProjectId int, @User nvarchar(254)
AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM dbo.Users u JOIN dbo.UserRoles ur ON ur.UserId=u.UserId JOIN dbo.Roles r ON r.RoleId=ur.RoleId WHERE u.Email=@User AND r.Name='Approver')
    AND NOT EXISTS(SELECT 1 FROM dbo.Users u JOIN dbo.UserRoles ur ON ur.UserId=u.UserId JOIN dbo.Roles r ON r.RoleId=ur.RoleId WHERE u.Email=@User AND r.Name IN ('Reviewer','Admin','Master'))
  THROW 50013,'Approver can view only.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.Projects p WHERE p.ProjectId=@ProjectId AND (p.RequestorEmail=@User OR EXISTS(SELECT 1 FROM dbo.Users u JOIN dbo.UserRoles ur ON ur.UserId=u.UserId JOIN dbo.Roles r ON r.RoleId=ur.RoleId WHERE u.Email=@User AND r.Name IN ('Reviewer','Master'))))
  THROW 50013,'You are not allowed to delete this project.',1;
 IF EXISTS(SELECT 1 FROM dbo.PETRequests WHERE ProjectId=@ProjectId)
  THROW 50014,'This project has PET requests; delete them first.',1;
 DELETE FROM dbo.Attachments WHERE EntityType='Project' AND EntityId=@ProjectId;
 DELETE FROM dbo.Projects WHERE ProjectId=@ProjectId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_SavePet @PetId int=NULL,@ProjectId int,@Code nvarchar(50),@Amount decimal(19,2),@Currency char(3),@User nvarchar(254),@VendorName nvarchar(300)=NULL,@Comments nvarchar(2000)=NULL,@ReviewRequired bit=NULL
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @SkipReview bit,@RequiresPet bit,@InitialStatus nvarchar(50),@Status nvarchar(50),@ReviewerEmail nvarchar(254),@ApproverEmail nvarchar(254),@ResubmitStatus nvarchar(50),@EffectiveReviewRequired bit,@BudgetType nvarchar(10),@BudgetSource int;
 SELECT @SkipReview=p.SkipReview,@RequiresPet=p.RequiresPet,@ReviewerEmail=reviewer.Email,@ApproverEmail=approver.Email,@BudgetType=p.BudgetType,@BudgetSource=p.BudgetSourceId
 FROM dbo.Projects p
 LEFT JOIN dbo.Users reviewer ON LTRIM(RTRIM(reviewer.DisplayName))=LTRIM(RTRIM(p.AccountableExecLead))
 LEFT JOIN dbo.Users approver ON LTRIM(RTRIM(approver.DisplayName))=LTRIM(RTRIM(p.AccountableExec))
 WHERE p.ProjectId=@ProjectId;
 IF ISNULL(@RequiresPet,0)=0 THROW 50008,'This project does not require PET registration.',1;
 IF NULLIF(LTRIM(RTRIM(ISNULL(@BudgetType,''))),'') IS NULL OR @BudgetSource IS NULL THROW 50009,'Select CAPEX or OPEX and a budget source before adding PET.',1;
 SET @EffectiveReviewRequired=CASE WHEN @ReviewRequired IS NULL THEN CASE WHEN ISNULL(@SkipReview,0)=1 THEN 0 ELSE 1 END ELSE @ReviewRequired END;
 SET @InitialStatus=CASE WHEN @EffectiveReviewRequired=0 THEN 'Pending Approval' ELSE 'Pending Review' END;
 IF @PetId IS NULL
 BEGIN
  INSERT dbo.PETRequests(ProjectId,Code,RequestedAmount,Currency,Status,ReviewerEmail,ApproverEmail,ReviewRequired,CreatedBy) VALUES(@ProjectId,@Code,@Amount,@Currency,@InitialStatus,@ReviewerEmail,@ApproverEmail,@EffectiveReviewRequired,@User);
  SET @PetId=SCOPE_IDENTITY();
  INSERT dbo.WorkflowHistory(PetId,ToStatus,ActionBy,Comments) VALUES(@PetId,@InitialStatus,@User,CASE WHEN @EffectiveReviewRequired=0 THEN 'Reviewer skipped for this PET request.' ELSE NULL END);
 END
 ELSE
 BEGIN
  SELECT @Status=Status,@EffectiveReviewRequired=ReviewRequired FROM dbo.PETRequests WHERE PetId=@PetId AND ProjectId=@ProjectId;
  SET @EffectiveReviewRequired=CASE WHEN @ReviewRequired IS NULL THEN ISNULL(@EffectiveReviewRequired,CASE WHEN ISNULL(@SkipReview,0)=1 THEN 0 ELSE 1 END) ELSE @ReviewRequired END;
  IF @Status='Sent Back'
  BEGIN
   IF NULLIF(LTRIM(RTRIM(ISNULL(@Comments,''))),'') IS NULL THROW 50012,'Requester comments / amendment notes are required before resubmitting.',1;
   SET @ResubmitStatus=CASE WHEN @EffectiveReviewRequired=1 THEN 'Pending Review' ELSE 'Pending Approval' END;
   UPDATE dbo.PETRequests SET Code=@Code,RequestedAmount=@Amount,Currency=@Currency,Status=@ResubmitStatus,ReviewRequired=@EffectiveReviewRequired,ReviewerEmail=COALESCE(NULLIF(ReviewerEmail,''),@ReviewerEmail),ApproverEmail=COALESCE(NULLIF(ApproverEmail,''),@ApproverEmail),UpdatedUtc=SYSUTCDATETIME() WHERE PetId=@PetId;
   INSERT dbo.WorkflowHistory(PetId,FromStatus,ToStatus,ActionBy,Comments) VALUES(@PetId,@Status,@ResubmitStatus,@User,@Comments);
  END
  ELSE
  BEGIN
   IF @Status IN('Draft','Pending Review','Pending Approval') UPDATE dbo.PETRequests SET Code=@Code,RequestedAmount=@Amount,Currency=@Currency,ReviewerEmail=COALESCE(NULLIF(ReviewerEmail,''),@ReviewerEmail),ApproverEmail=COALESCE(NULLIF(ApproverEmail,''),@ApproverEmail),UpdatedUtc=SYSUTCDATETIME() WHERE PetId=@PetId;
   IF @Status='Approved' UPDATE dbo.PETRequests SET VendorName=@VendorName,UpdatedUtc=SYSUTCDATETIME() WHERE PetId=@PetId;
  END
 END
 UPDATE dbo.Projects SET Status=CASE WHEN ISNULL(@ResubmitStatus,ISNULL(@Status,@InitialStatus))='Pending Approval' THEN 'PET Approval' WHEN ISNULL(@ResubmitStatus,ISNULL(@Status,@InitialStatus))='Sent Back' THEN 'PET Sent Back' ELSE 'PET Review' END,UpdatedUtc=SYSUTCDATETIME() WHERE ProjectId=@ProjectId AND ISNULL(@Status,'')<>'Approved';
 SELECT PetId,Status FROM dbo.PETRequests WHERE PetId=@PetId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_SaveInvoice @Id int=NULL,@Line int,@Vendor nvarchar(300),@Justification nvarchar(1000)=NULL,@Gl nvarchar(50)=NULL,@Number nvarchar(100),@Amount decimal(19,2),@Status nvarchar(50),@PaymentDate date=NULL,@User nvarchar(254)
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @BudgetLineCost decimal(19,2), @ExistingInvoiceTotal decimal(19,2);
 SELECT @BudgetLineCost=Cost FROM dbo.BudgetLines WHERE BudgetLineId=@Line;
 IF @BudgetLineCost IS NULL THROW 50035,'Budget Line was not found.',1;
 IF @Amount<=0 THROW 50036,'A positive Invoice amount is required.',1;
 SELECT @ExistingInvoiceTotal=ISNULL(SUM(InvoiceAmount),0) FROM dbo.Invoices WHERE BudgetLineId=@Line AND (@Id IS NULL OR InvoiceId<>@Id);
 IF @Amount > @BudgetLineCost-ISNULL(@ExistingInvoiceTotal,0) THROW 50037,'Invoice amount exceeds the available Budget Line balance.',1;
 IF @Id IS NULL BEGIN INSERT dbo.Invoices(BudgetLineId,VendorName,Justification,GlNumber,InvoiceNumber,InvoiceAmount,InvoiceStatus,PaymentDate,CreatedBy) VALUES(@Line,@Vendor,@Justification,@Gl,@Number,@Amount,@Status,@PaymentDate,@User); SET @Id=SCOPE_IDENTITY(); END
 ELSE UPDATE dbo.Invoices SET VendorName=@Vendor,Justification=@Justification,GlNumber=@Gl,InvoiceNumber=@Number,InvoiceAmount=@Amount,InvoiceStatus=@Status,PaymentDate=@PaymentDate,UpdatedUtc=SYSUTCDATETIME() WHERE InvoiceId=@Id;
 SELECT InvoiceId FROM dbo.Invoices WHERE InvoiceId=@Id;
END;
GO