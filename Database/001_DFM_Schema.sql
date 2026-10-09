SET XACT_ABORT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
IF DB_ID(N'DFM') IS NULL CREATE DATABASE DFM;
GO
USE DFM;
GO
CREATE TABLE dbo.Roles(RoleId int IDENTITY PRIMARY KEY, Name nvarchar(30) NOT NULL UNIQUE);
INSERT dbo.Roles(Name) VALUES(N'Requestor'),(N'Reviewer'),(N'Approver'),(N'Master');
CREATE TABLE dbo.SecurityQuestions(SecurityQuestionId int IDENTITY PRIMARY KEY, Question nvarchar(250) NOT NULL, IsActive bit NOT NULL DEFAULT 1);
INSERT dbo.SecurityQuestions(Question) VALUES(N'What was the name of your first school?'),(N'In which city were you born?'),(N'What is the name of your childhood best friend?');
CREATE TABLE dbo.Users(
 UserId int IDENTITY PRIMARY KEY, Email nvarchar(254) NOT NULL UNIQUE, DisplayName nvarchar(200) NOT NULL,
 DirectoryAccount nvarchar(200) NULL, DirectoryObjectGuid uniqueidentifier NULL, IsActive bit NOT NULL DEFAULT 1,
 RequiresPasswordSetup bit NOT NULL DEFAULT 1, PasswordSalt varbinary(64) NULL, PasswordHash varbinary(64) NULL,
 SecurityQuestionId int NULL REFERENCES dbo.SecurityQuestions(SecurityQuestionId), SecurityAnswerSalt varbinary(64) NULL,
 SecurityAnswerHash varbinary(64) NULL, LastDirectorySyncUtc datetime2 NULL, CreatedUtc datetime2 NOT NULL DEFAULT SYSUTCDATETIME(), UpdatedUtc datetime2 NOT NULL DEFAULT SYSUTCDATETIME());
CREATE UNIQUE INDEX UX_Users_DirectoryObjectGuid ON dbo.Users(DirectoryObjectGuid) WHERE DirectoryObjectGuid IS NOT NULL;
CREATE TABLE dbo.UserRoles(UserId int NOT NULL REFERENCES dbo.Users(UserId), RoleId int NOT NULL REFERENCES dbo.Roles(RoleId), PRIMARY KEY(UserId,RoleId));
CREATE TABLE dbo.UserSessions(SessionId bigint IDENTITY PRIMARY KEY, UserId int NOT NULL REFERENCES dbo.Users(UserId), TokenHash varbinary(32) NOT NULL UNIQUE, ExpiresUtc datetime2 NOT NULL, CreatedUtc datetime2 NOT NULL DEFAULT SYSUTCDATETIME());
CREATE TABLE dbo.PasswordResetTokens(ResetTokenId bigint IDENTITY PRIMARY KEY, UserId int NOT NULL REFERENCES dbo.Users(UserId), TokenHash varbinary(32) NOT NULL, ExpiresUtc datetime2 NOT NULL, UsedUtc datetime2 NULL);
GO
CREATE TABLE dbo.JiraIssues(
 JiraIssueId bigint IDENTITY PRIMARY KEY, JiraID nvarchar(50) NOT NULL, JiraKey nvarchar(50) NOT NULL UNIQUE,
 Summary nvarchar(500) NULL, Status nvarchar(100) NULL, OverallStatus nvarchar(100) NULL, Priority nvarchar(50) NULL,
 IssueType nvarchar(100) NULL, ProjectType nvarchar(100) NULL, ProjectKey nvarchar(20) NULL, ProjectName nvarchar(300) NULL,
 ParentJiraID nvarchar(50) NULL, Platform nvarchar(200) NULL, PlatformVertical nvarchar(200) NULL, PlatformName nvarchar(200) NULL,
 SecondaryPlatform nvarchar(200) NULL, ActivityRagStatus nvarchar(50) NULL, ScheduleRag nvarchar(50) NULL, BudgetRag nvarchar(50) NULL,
 RaidRag nvarchar(50) NULL, OverallProjectRag nvarchar(50) NULL, ProjectRAG nvarchar(50) NULL, ChiefNameMapping nvarchar(200) NULL,
 Manager nvarchar(200) NULL, TechLead nvarchar(200) NULL, AccountableExecLead nvarchar(200) NULL, SmeLead nvarchar(200) NULL,
 AccountableExec nvarchar(200) NULL, Sponsor nvarchar(200) NULL, Stakeholder nvarchar(200) NULL, Assignee nvarchar(200) NULL,
 Reporter nvarchar(200) NULL, AssignedProjectManager nvarchar(200) NULL, IdhPortfolioHead nvarchar(200) NULL, DemandOwner nvarchar(200) NULL,
 DemandType nvarchar(100) NULL, TargetCompletionDate datetime NULL, Target_Completion_Date datetime NULL, ProposedDemandPickupDate datetime NULL,
 Proposed_Demand_Pick_up_Date datetime NULL, Actual_Go_Live_Date datetime NULL, Proposed_Baseline_0_End_Date datetime NULL,
 Proposed_Baseline_0_Start_Date datetime NULL, Proposed_Baseline_0_submission_Date datetime NULL, Primary_Classification nvarchar(200) NULL,
 Classification nvarchar(200) NULL, Department nvarchar(200) NULL, JiraCreated datetime NULL, JiraUpdated datetime NULL, CreatedDate datetime NULL,
 UpdatedDate datetime NULL, EmployeeEmail nvarchar(200) NULL, EmployeeName nvarchar(200) NULL, ProjectPerformingDept nvarchar(200) NULL,
 ProjectSponsorDept nvarchar(200) NULL, DemandDepartment nvarchar(200) NULL, RequesterDept nvarchar(200) NULL, ProjectDept nvarchar(200) NULL,
 DemandSegment nvarchar(200) NULL, DemandTitle nvarchar(500) NULL, RegulatoryObservation nvarchar(max) NULL, BaselineStartDate datetime NULL,
 BaselineEndDate datetime NULL, Baseline1ActualStart datetime NULL, Baseline0PlannedStart datetime NULL, Baseline0PlannedEnd datetime NULL,
 Baseline0ActualEnd datetime NULL, Baseline1ActualGoLive datetime NULL, Baseline0ActualStart datetime NULL, Baseline1ActualEnd datetime NULL,
 RolloutStatus nvarchar(100) NULL, EpicStatus nvarchar(100) NULL, BrdStatus nvarchar(100) NULL, ScriptStatus nvarchar(100) NULL,
 StatusGrey nvarchar(100) NULL, StatusReason nvarchar(200) NULL, InitiativeStatus nvarchar(100) NULL, ProjectOverallStatus nvarchar(100) NULL,
 CbtpBrdStatus nvarchar(100) NULL, FsdStatus nvarchar(100) NULL, Requirements nvarchar(max) NULL, PortfolioExecutiveSummary nvarchar(max) NULL,
 RawJson nvarchar(max) NULL, SyncedUtc datetime2 NOT NULL DEFAULT SYSUTCDATETIME());
CREATE INDEX IX_JiraIssues_Updated ON dbo.JiraIssues(JiraUpdated DESC);
CREATE TABLE dbo.JiraIssueFields(JiraIssueFieldId bigint IDENTITY PRIMARY KEY, JiraKey nvarchar(50) NOT NULL, SectionName nvarchar(100) NOT NULL, FieldName nvarchar(200) NOT NULL, FieldValue nvarchar(max) NULL, SyncedUtc datetime2 NOT NULL DEFAULT SYSUTCDATETIME(), UNIQUE(JiraKey,SectionName,FieldName));
CREATE TABLE dbo.JiraSyncLog(JiraSyncLogId bigint IDENTITY PRIMARY KEY, StartedUtc datetime2 NOT NULL, FinishedUtc datetime2 NULL, Status nvarchar(30) NOT NULL, Pulled int NOT NULL DEFAULT 0, Inserted int NOT NULL DEFAULT 0, Updated int NOT NULL DEFAULT 0, Failed int NOT NULL DEFAULT 0, Error nvarchar(max) NULL);
CREATE TABLE dbo.JiraConfig(ConfigKey nvarchar(100) PRIMARY KEY, ConfigValue nvarchar(max) NULL, UpdatedUtc datetime2 NOT NULL DEFAULT SYSUTCDATETIME());
GO
CREATE TABLE dbo.BudgetSources(
 BudgetSourceId int IDENTITY PRIMARY KEY, BudgetType nvarchar(10) NOT NULL CHECK(BudgetType IN(N'CAPEX',N'OPEX')),
 ExternalId nvarchar(100) NOT NULL, Description nvarchar(1000) NULL, Budget decimal(19,2) NOT NULL DEFAULT 0,
 Utilization decimal(19,2) NOT NULL DEFAULT 0, AvailableBudget decimal(19,2) NOT NULL DEFAULT 0, LockedAmount decimal(19,2) NOT NULL DEFAULT 0,
 BudgetAfterLocked decimal(19,2) NOT NULL DEFAULT 0, ClaimAmount decimal(19,2) NOT NULL DEFAULT 0, NetBalance decimal(19,2) NOT NULL DEFAULT 0,
 SourceFile nvarchar(500) NULL, LastSyncUtc datetime2 NULL, UpdatedUtc datetime2 NOT NULL DEFAULT SYSUTCDATETIME(), UNIQUE(BudgetType,ExternalId));
CREATE TABLE dbo.Projects(
 ProjectId int IDENTITY PRIMARY KEY, ProjectCode AS ('PRJ-'+RIGHT('000000'+CONVERT(varchar(6),ProjectId),6)) PERSISTED,
 IsJira bit NOT NULL, JiraKey nvarchar(50) NULL REFERENCES dbo.JiraIssues(JiraKey), ProjectName nvarchar(500) NOT NULL,
 ProjectType nvarchar(100) NULL, AccountableExecLead nvarchar(200) NOT NULL, AccountableExec nvarchar(200) NOT NULL, SmeLead nvarchar(200) NULL,
 ProjectSize nvarchar(50) NULL, ProjectManager nvarchar(200) NULL, RequestorEmail nvarchar(254) NOT NULL, BudgetType nvarchar(10) NOT NULL,
 BudgetSourceId int NOT NULL REFERENCES dbo.BudgetSources(BudgetSourceId), Status nvarchar(50) NOT NULL DEFAULT N'Draft',
 CreatedUtc datetime2 NOT NULL DEFAULT SYSUTCDATETIME(), UpdatedUtc datetime2 NOT NULL DEFAULT SYSUTCDATETIME());
CREATE INDEX IX_Projects_Requestor ON dbo.Projects(RequestorEmail,CreatedUtc DESC);
CREATE TABLE dbo.PETRequests(
 PetId int IDENTITY PRIMARY KEY, ProjectId int NOT NULL REFERENCES dbo.Projects(ProjectId), Code nvarchar(50) NOT NULL UNIQUE,
 RequestedAmount decimal(19,2) NOT NULL CHECK(RequestedAmount>0), Currency char(3) NOT NULL DEFAULT 'AED', Status nvarchar(50) NOT NULL DEFAULT N'Draft',
 ReviewerEmail nvarchar(254) NULL, ReviewComments nvarchar(2000) NULL, ReviewedUtc datetime2 NULL, ApproverEmail nvarchar(254) NULL,
 ApprovalComments nvarchar(2000) NULL, ApprovedUtc datetime2 NULL, RejectedUtc datetime2 NULL, CreatedBy nvarchar(254) NOT NULL,
 CreatedUtc datetime2 NOT NULL DEFAULT SYSUTCDATETIME(), UpdatedUtc datetime2 NOT NULL DEFAULT SYSUTCDATETIME());
CREATE TABLE dbo.SpendItems(
 SpendItemId int IDENTITY PRIMARY KEY, PetId int NOT NULL REFERENCES dbo.PETRequests(PetId), Head nvarchar(200) NULL, Topic nvarchar(300) NULL,
 Vendor nvarchar(300) NOT NULL, CostType nvarchar(100) NULL, UnitType nvarchar(50) NULL, Units decimal(19,4) NOT NULL DEFAULT 1,
 UnitPrice decimal(19,2) NOT NULL, Currency char(3) NOT NULL, ForeignAmount decimal(19,2) NOT NULL, AedAmount decimal(19,2) NOT NULL,
 ContingencyPercent decimal(9,4) NOT NULL DEFAULT 0, FinalAedAmount AS (AedAmount*(1+(ContingencyPercent/100))) PERSISTED,
 GlNumber nvarchar(50) NULL, CreatedUtc datetime2 NOT NULL DEFAULT SYSUTCDATETIME());
CREATE TABLE dbo.WorkflowHistory(WorkflowHistoryId bigint IDENTITY PRIMARY KEY, PetId int NOT NULL REFERENCES dbo.PETRequests(PetId), FromStatus nvarchar(50) NULL, ToStatus nvarchar(50) NOT NULL, ActionBy nvarchar(254) NOT NULL, Comments nvarchar(2000) NULL, ActionUtc datetime2 NOT NULL DEFAULT SYSUTCDATETIME());
CREATE TABLE dbo.BudgetLines(
 BudgetLineId int IDENTITY PRIMARY KEY, PetId int NOT NULL REFERENCES dbo.PETRequests(PetId), Vendor nvarchar(300) NOT NULL,
 Justification nvarchar(1000) NULL, Cost decimal(19,2) NOT NULL, Currency char(3) NOT NULL DEFAULT 'AED', GlNumber nvarchar(50) NULL,
 PetReference nvarchar(100) NULL, CamId nvarchar(100) NULL, CamStatus nvarchar(50) NULL, CamComments nvarchar(1000) NULL,
 LpoRequest nvarchar(100) NULL, LpoStatus nvarchar(50) NULL, LpoComments nvarchar(1000) NULL, CreatedBy nvarchar(254) NOT NULL,
 CreatedUtc datetime2 NOT NULL DEFAULT SYSUTCDATETIME(), UpdatedUtc datetime2 NOT NULL DEFAULT SYSUTCDATETIME());
CREATE TABLE dbo.Invoices(
 InvoiceId int IDENTITY PRIMARY KEY, BudgetLineId int NOT NULL REFERENCES dbo.BudgetLines(BudgetLineId), VendorName nvarchar(300) NOT NULL,
 Justification nvarchar(1000) NULL, GlNumber nvarchar(50) NULL, InvoiceNumber nvarchar(100) NOT NULL, InvoiceAmount decimal(19,2) NOT NULL,
 InvoiceStatus nvarchar(50) NOT NULL DEFAULT N'Raised', PaymentDate date NULL, CreatedBy nvarchar(254) NOT NULL,
 CreatedUtc datetime2 NOT NULL DEFAULT SYSUTCDATETIME(), UpdatedUtc datetime2 NOT NULL DEFAULT SYSUTCDATETIME(), UNIQUE(BudgetLineId,InvoiceNumber));
CREATE TABLE dbo.Attachments(AttachmentId bigint IDENTITY PRIMARY KEY, EntityType nvarchar(30) NOT NULL, EntityId int NOT NULL, OriginalName nvarchar(260) NOT NULL, StoredName nvarchar(260) NOT NULL, ContentType nvarchar(150) NOT NULL, FileSize bigint NOT NULL, UploadedBy nvarchar(254) NOT NULL, UploadedUtc datetime2 NOT NULL DEFAULT SYSUTCDATETIME());
CREATE TABLE dbo.AuditLog(AuditLogId bigint IDENTITY PRIMARY KEY, EntityType nvarchar(50) NOT NULL, EntityId int NULL, ActionName nvarchar(50) NOT NULL, UserEmail nvarchar(254) NOT NULL, Detail nvarchar(max) NULL, ActionUtc datetime2 NOT NULL DEFAULT SYSUTCDATETIME());
GO
CREATE OR ALTER VIEW dbo.vw_JiraProjectPicker AS SELECT JiraIssueId,JiraKey,Summary,Status,IssueType,ProjectType,AccountableExecLead,AccountableExec,SmeLead,AssignedProjectManager,ProjectRAG,Platform,DemandType,DemandDepartment,DemandSegment,Requirements,PortfolioExecutiveSummary,JiraCreated,JiraUpdated FROM dbo.JiraIssues;
GO
CREATE OR ALTER VIEW dbo.vw_ProjectPortfolio AS
SELECT p.ProjectId,p.ProjectCode,p.JiraKey,p.ProjectName,p.ProjectType,p.AccountableExecLead,p.AccountableExec,p.SmeLead,p.ProjectSize,p.ProjectManager,p.RequestorEmail,p.BudgetType,p.BudgetSourceId,p.Status,p.CreatedUtc,
 b.ExternalId BudgetSource,b.Budget,b.Utilization,b.AvailableBudget,
 (SELECT COUNT(*) FROM dbo.PETRequests x WHERE x.ProjectId=p.ProjectId) PetCount,
 (SELECT COUNT(*) FROM dbo.PETRequests x WHERE x.ProjectId=p.ProjectId AND x.Status='Approved') ApprovedPetCount,
 (SELECT ISNULL(SUM(x.InvoiceAmount),0) FROM dbo.Invoices x JOIN dbo.BudgetLines bl ON bl.BudgetLineId=x.BudgetLineId JOIN dbo.PETRequests pet ON pet.PetId=bl.PetId WHERE pet.ProjectId=p.ProjectId) InvoicedAmount
FROM dbo.Projects p JOIN dbo.BudgetSources b ON b.BudgetSourceId=p.BudgetSourceId;
GO
CREATE OR ALTER VIEW dbo.vw_ManagementDashboard AS
SELECT (SELECT COUNT(*) FROM dbo.Projects) ProjectsRegistered,
 (SELECT COUNT(*) FROM dbo.PETRequests WHERE Status='Approved') PetsApproved,
 (SELECT COUNT(*) FROM dbo.PETRequests WHERE Status IN('Pending Review','Pending Approval')) PetsOnTrack,
 (SELECT COUNT(*) FROM dbo.PETRequests WHERE Status='Rejected') PetsRejected,
 (SELECT COUNT(*) FROM dbo.Invoices) InvoicesRaised,
 (SELECT COUNT(*) FROM dbo.Invoices WHERE InvoiceStatus IN('Raised','Outstanding','Received')) InvoicesOutstanding,
 (SELECT COUNT(*) FROM dbo.Invoices WHERE InvoiceStatus IN('Settled','Paid')) InvoicesSettled,
 (SELECT ISNULL(SUM(Budget),0) FROM dbo.BudgetSources WHERE BudgetType='CAPEX') CapexBudget,
 (SELECT ISNULL(SUM(Utilization),0) FROM dbo.BudgetSources WHERE BudgetType='CAPEX') CapexUtilized,
 (SELECT ISNULL(SUM(Budget),0) FROM dbo.BudgetSources WHERE BudgetType='OPEX') OpexBudget,
 (SELECT ISNULL(SUM(Utilization),0) FROM dbo.BudgetSources WHERE BudgetType='OPEX') OpexUtilized;
GO
CREATE OR ALTER PROCEDURE dbo.sp_SyncDirectoryUser @Email nvarchar(254),@DisplayName nvarchar(200),@AccountName nvarchar(200),@ObjectGuid uniqueidentifier,@DefaultRole nvarchar(30) AS
BEGIN SET NOCOUNT ON;
 MERGE dbo.Users AS t USING(SELECT LOWER(@Email) Email) s ON t.Email=s.Email
 WHEN MATCHED THEN UPDATE SET DisplayName=@DisplayName,DirectoryAccount=@AccountName,DirectoryObjectGuid=@ObjectGuid,IsActive=1,LastDirectorySyncUtc=SYSUTCDATETIME(),UpdatedUtc=SYSUTCDATETIME()
 WHEN NOT MATCHED THEN INSERT(Email,DisplayName,DirectoryAccount,DirectoryObjectGuid,LastDirectorySyncUtc) VALUES(LOWER(@Email),@DisplayName,@AccountName,@ObjectGuid,SYSUTCDATETIME());
 DECLARE @UserId int=(SELECT UserId FROM dbo.Users WHERE Email=LOWER(@Email)),@RoleId int=(SELECT RoleId FROM dbo.Roles WHERE Name=@DefaultRole);
 IF NOT EXISTS(SELECT 1 FROM dbo.UserRoles WHERE UserId=@UserId AND RoleId=@RoleId) INSERT dbo.UserRoles VALUES(@UserId,@RoleId);
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_SaveProject @ProjectId int=NULL,@IsJira bit,@JiraKey nvarchar(50)=NULL,@Name nvarchar(500),@Type nvarchar(100)=NULL,@Lead nvarchar(200),@Executive nvarchar(200),@Sme nvarchar(200)=NULL,@Size nvarchar(50)=NULL,@Manager nvarchar(200)=NULL,@BudgetType nvarchar(10),@BudgetSource int,@User nvarchar(254) AS
BEGIN SET NOCOUNT ON;
 IF NOT EXISTS(SELECT 1 FROM dbo.BudgetSources WHERE BudgetSourceId=@BudgetSource AND BudgetType=@BudgetType) THROW 50001,'Budget source does not match CAPEX/OPEX selection.',1;
 IF @ProjectId IS NULL BEGIN INSERT dbo.Projects(IsJira,JiraKey,ProjectName,ProjectType,AccountableExecLead,AccountableExec,SmeLead,ProjectSize,ProjectManager,RequestorEmail,BudgetType,BudgetSourceId) VALUES(@IsJira,NULLIF(@JiraKey,''),@Name,@Type,@Lead,@Executive,@Sme,@Size,@Manager,@User,@BudgetType,@BudgetSource); SET @ProjectId=SCOPE_IDENTITY(); END
 ELSE UPDATE dbo.Projects SET IsJira=@IsJira,JiraKey=NULLIF(@JiraKey,''),ProjectName=@Name,ProjectType=@Type,AccountableExecLead=@Lead,AccountableExec=@Executive,SmeLead=@Sme,ProjectSize=@Size,ProjectManager=@Manager,BudgetType=@BudgetType,BudgetSourceId=@BudgetSource,UpdatedUtc=SYSUTCDATETIME() WHERE ProjectId=@ProjectId AND (RequestorEmail=@User OR EXISTS(SELECT 1 FROM dbo.Users u JOIN dbo.UserRoles ur ON ur.UserId=u.UserId JOIN dbo.Roles r ON r.RoleId=ur.RoleId WHERE u.Email=@User AND r.Name='Master'));
 SELECT ProjectId,ProjectCode FROM dbo.Projects WHERE ProjectId=@ProjectId;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_SavePet @PetId int=NULL,@ProjectId int,@Code nvarchar(50),@Amount decimal(19,2),@Currency char(3),@User nvarchar(254) AS
BEGIN SET NOCOUNT ON;
 IF @PetId IS NULL BEGIN INSERT dbo.PETRequests(ProjectId,Code,RequestedAmount,Currency,Status,CreatedBy) VALUES(@ProjectId,@Code,@Amount,@Currency,'Pending Review',@User); SET @PetId=SCOPE_IDENTITY(); INSERT dbo.WorkflowHistory(PetId,ToStatus,ActionBy) VALUES(@PetId,'Pending Review',@User); END
 ELSE UPDATE dbo.PETRequests SET Code=@Code,RequestedAmount=@Amount,Currency=@Currency,UpdatedUtc=SYSUTCDATETIME() WHERE PetId=@PetId AND Status IN('Draft','Pending Review');
 UPDATE dbo.Projects SET Status='PET Review',UpdatedUtc=SYSUTCDATETIME() WHERE ProjectId=@ProjectId; SELECT PetId,Status FROM dbo.PETRequests WHERE PetId=@PetId;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_PetDecision @PetId int,@Stage nvarchar(20),@Approve bit,@Comments nvarchar(2000),@User nvarchar(254) AS
BEGIN SET XACT_ABORT ON; BEGIN TRAN;
 DECLARE @Old nvarchar(50),@New nvarchar(50),@Amount decimal(19,2),@BudgetSource int,@Available decimal(19,2),@ProjectId int;
 SELECT @Old=pet.Status,@Amount=pet.RequestedAmount,@ProjectId=pet.ProjectId,@BudgetSource=p.BudgetSourceId FROM dbo.PETRequests pet WITH(UPDLOCK) JOIN dbo.Projects p ON p.ProjectId=pet.ProjectId WHERE pet.PetId=@PetId;
 IF @Stage='Review' AND @Old<>'Pending Review' THROW 50002,'PET is not awaiting review.',1;
 IF @Stage='Approval' AND @Old<>'Pending Approval' THROW 50003,'PET is not awaiting approval.',1;
 SET @New=CASE WHEN @Approve=0 THEN 'Rejected' WHEN @Stage='Review' THEN 'Pending Approval' ELSE 'Approved' END;
 IF @New='Approved' BEGIN SELECT @Available=AvailableBudget FROM dbo.BudgetSources WITH(UPDLOCK) WHERE BudgetSourceId=@BudgetSource; IF @Available<@Amount THROW 50004,'Insufficient remaining budget.',1; UPDATE dbo.BudgetSources SET Utilization=Utilization+@Amount,AvailableBudget=AvailableBudget-@Amount,NetBalance=NetBalance-@Amount,UpdatedUtc=SYSUTCDATETIME() WHERE BudgetSourceId=@BudgetSource; END
 UPDATE dbo.PETRequests SET Status=@New,ReviewerEmail=CASE WHEN @Stage='Review' THEN @User ELSE ReviewerEmail END,ReviewComments=CASE WHEN @Stage='Review' THEN @Comments ELSE ReviewComments END,ReviewedUtc=CASE WHEN @Stage='Review' THEN SYSUTCDATETIME() ELSE ReviewedUtc END,ApproverEmail=CASE WHEN @Stage='Approval' THEN @User ELSE ApproverEmail END,ApprovalComments=CASE WHEN @Stage='Approval' THEN @Comments ELSE ApprovalComments END,ApprovedUtc=CASE WHEN @New='Approved' THEN SYSUTCDATETIME() ELSE ApprovedUtc END,RejectedUtc=CASE WHEN @New='Rejected' THEN SYSUTCDATETIME() ELSE RejectedUtc END,UpdatedUtc=SYSUTCDATETIME() WHERE PetId=@PetId;
 UPDATE dbo.Projects SET Status=CASE WHEN @New='Approved' THEN 'Approved' WHEN @New='Rejected' THEN 'PET Rejected' ELSE 'PET Approval' END,UpdatedUtc=SYSUTCDATETIME() WHERE ProjectId=@ProjectId;
 INSERT dbo.WorkflowHistory(PetId,FromStatus,ToStatus,ActionBy,Comments) VALUES(@PetId,@Old,@New,@User,@Comments); COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_SaveBudgetLine @Id int=NULL,@Pet int,@Vendor nvarchar(300),@Justification nvarchar(1000)=NULL,@Cost decimal(19,2),@Currency char(3),@Gl nvarchar(50)=NULL,@PetRef nvarchar(100)=NULL,@CamId nvarchar(100)=NULL,@CamStatus nvarchar(50)=NULL,@CamComments nvarchar(1000)=NULL,@LpoRequest nvarchar(100)=NULL,@LpoStatus nvarchar(50)=NULL,@LpoComments nvarchar(1000)=NULL,@User nvarchar(254) AS
BEGIN SET NOCOUNT ON; IF NOT EXISTS(SELECT 1 FROM dbo.PETRequests WHERE PetId=@Pet AND Status IN('Pending Review','Pending Approval','Approved')) THROW 50005,'Budget lines can be added after PET submission.',1;
 IF @Id IS NULL BEGIN INSERT dbo.BudgetLines(PetId,Vendor,Justification,Cost,Currency,GlNumber,PetReference,CamId,CamStatus,CamComments,LpoRequest,LpoStatus,LpoComments,CreatedBy) VALUES(@Pet,@Vendor,@Justification,@Cost,@Currency,@Gl,@PetRef,@CamId,@CamStatus,@CamComments,@LpoRequest,@LpoStatus,@LpoComments,@User); SET @Id=SCOPE_IDENTITY(); END ELSE UPDATE dbo.BudgetLines SET Vendor=@Vendor,Justification=@Justification,Cost=@Cost,Currency=@Currency,GlNumber=@Gl,PetReference=@PetRef,CamId=@CamId,CamStatus=@CamStatus,CamComments=@CamComments,LpoRequest=@LpoRequest,LpoStatus=@LpoStatus,LpoComments=@LpoComments,UpdatedUtc=SYSUTCDATETIME() WHERE BudgetLineId=@Id; SELECT BudgetLineId FROM dbo.BudgetLines WHERE BudgetLineId=@Id; END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_SaveInvoice @Id int=NULL,@Line int,@Vendor nvarchar(300),@Justification nvarchar(1000)=NULL,@Gl nvarchar(50)=NULL,@Number nvarchar(100),@Amount decimal(19,2),@Status nvarchar(50),@PaymentDate date=NULL,@User nvarchar(254) AS
BEGIN SET NOCOUNT ON; IF @Id IS NULL BEGIN INSERT dbo.Invoices(BudgetLineId,VendorName,Justification,GlNumber,InvoiceNumber,InvoiceAmount,InvoiceStatus,PaymentDate,CreatedBy) VALUES(@Line,@Vendor,@Justification,@Gl,@Number,@Amount,@Status,@PaymentDate,@User); SET @Id=SCOPE_IDENTITY(); END ELSE UPDATE dbo.Invoices SET VendorName=@Vendor,Justification=@Justification,GlNumber=@Gl,InvoiceNumber=@Number,InvoiceAmount=@Amount,InvoiceStatus=@Status,PaymentDate=@PaymentDate,UpdatedUtc=SYSUTCDATETIME() WHERE InvoiceId=@Id; SELECT InvoiceId FROM dbo.Invoices WHERE InvoiceId=@Id; END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_UpdateBudget @Id int,@Description nvarchar(1000),@Budget decimal(19,2),@Utilization decimal(19,2),@Available decimal(19,2),@User nvarchar(254) AS
BEGIN IF NOT EXISTS(SELECT 1 FROM dbo.Users u JOIN dbo.UserRoles ur ON ur.UserId=u.UserId JOIN dbo.Roles r ON r.RoleId=ur.RoleId WHERE u.Email=@User AND r.Name='Master') THROW 50006,'Only Master can edit CAPEX/OPEX.',1; UPDATE dbo.BudgetSources SET Description=@Description,Budget=@Budget,Utilization=@Utilization,AvailableBudget=@Available,UpdatedUtc=SYSUTCDATETIME() WHERE BudgetSourceId=@Id; INSERT dbo.AuditLog(EntityType,EntityId,ActionName,UserEmail) VALUES('BudgetSource',@Id,'Update',@User); END;
GO
