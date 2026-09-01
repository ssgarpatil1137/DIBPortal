-- =====================================================================
-- DFM_BPM  –  Core Schema (Tables)
-- Run AFTER 01_CreateDatabase.sql
-- =====================================================================
USE DFM_BPM;
GO

-- ===================================================================
-- 1. USER MANAGEMENT
-- ===================================================================

IF OBJECT_ID('dbo.UserRoles','U') IS NULL
CREATE TABLE dbo.UserRoles (
    RoleID      INT IDENTITY(1,1) PRIMARY KEY,
    RoleName    NVARCHAR(50)  NOT NULL UNIQUE,
    Description NVARCHAR(200) NULL,
    IsActive    BIT NOT NULL DEFAULT(1),
    CreatedDate DATETIME NOT NULL DEFAULT(GETDATE())
);
GO

IF OBJECT_ID('dbo.AppUsers','U') IS NULL
CREATE TABLE dbo.AppUsers (
    UserID         INT IDENTITY(1,1) PRIMARY KEY,
    Username       NVARCHAR(100) NOT NULL UNIQUE,
    PasswordHash   NVARCHAR(256) NULL,
    PasswordSalt   NVARCHAR(256) NULL,
    FullName       NVARCHAR(150) NOT NULL,
    Email          NVARCHAR(150) NULL,
    Department     NVARCHAR(100) NULL,
    RoleID         INT NOT NULL REFERENCES dbo.UserRoles(RoleID),
    IsEnabled      BIT NOT NULL DEFAULT(1),
    CreatedDate    DATETIME NOT NULL DEFAULT(GETDATE()),
    LastLoginDate  DATETIME NULL,
    CreatedBy      NVARCHAR(100) NULL
);
GO

-- Reviewer / Approver role assignments per-user (multi-role)
IF OBJECT_ID('dbo.UserRoleAssignments','U') IS NULL
CREATE TABLE dbo.UserRoleAssignments (
    AssignmentID INT IDENTITY(1,1) PRIMARY KEY,
    Username     NVARCHAR(100) NOT NULL,
    RoleType     NVARCHAR(30)  NOT NULL,   -- Requestor | Reviewer | Approver | Admin
    CreatedDate  DATETIME NOT NULL DEFAULT(GETDATE()),
    CreatedBy    NVARCHAR(100) NULL,
    CONSTRAINT UQ_URA UNIQUE (Username, RoleType)
);
GO

-- Page Registry (list of navigable pages)
IF OBJECT_ID('dbo.PageRegistry','U') IS NULL
CREATE TABLE dbo.PageRegistry (
    PageID    INT IDENTITY(1,1) PRIMARY KEY,
    PageName  NVARCHAR(100) NOT NULL UNIQUE,
    PageUrl   NVARCHAR(300) NOT NULL,
    Category  NVARCHAR(100) NULL,
    SortOrder INT NOT NULL DEFAULT(0),
    IsActive  BIT NOT NULL DEFAULT(1)
);
GO

-- Page access control per role
IF OBJECT_ID('dbo.PageAccess','U') IS NULL
CREATE TABLE dbo.PageAccess (
    AccessID  INT IDENTITY(1,1) PRIMARY KEY,
    RoleID    INT NOT NULL REFERENCES dbo.UserRoles(RoleID),
    PageID    INT NOT NULL REFERENCES dbo.PageRegistry(PageID),
    CanView   BIT NOT NULL DEFAULT(1),
    CONSTRAINT UQ_PageAccess UNIQUE (RoleID, PageID)
);
GO

IF OBJECT_ID('dbo.UserSettings','U') IS NULL
CREATE TABLE dbo.UserSettings (
    SettingID    INT IDENTITY(1,1) PRIMARY KEY,
    Username     NVARCHAR(100) NOT NULL UNIQUE,
    ThemeName    NVARCHAR(50)  NOT NULL DEFAULT('ocean'),
    FontSize     NVARCHAR(20)  NOT NULL DEFAULT('Large'),
    DefaultPage  NVARCHAR(200) NULL,
    Notifications BIT NOT NULL DEFAULT(1),
    UpdatedDate  DATETIME NOT NULL DEFAULT(GETDATE())
);
GO

-- ===================================================================
-- 2. ORACLE-SYNCED MASTER DATA  (read-only from Oracle BPM)
-- ===================================================================

-- CAPEX master (synced from DIBPROD1.MEMO_CAPEX_OPEX where TYPE='Capex')
IF OBJECT_ID('dbo.CapexMaster','U') IS NULL
CREATE TABLE dbo.CapexMaster (
    CapexID         NVARCHAR(100) NOT NULL PRIMARY KEY,
    BudgetedAmount  DECIMAL(18,2) NOT NULL DEFAULT(0),
    UtilizedAmount  DECIMAL(18,2) NOT NULL DEFAULT(0),
    AvailableAmount DECIMAL(18,2) NOT NULL DEFAULT(0),
    LockedAmount    DECIMAL(18,2) NOT NULL DEFAULT(0),
    GLNumbers       NVARCHAR(MAX) NULL,
    LastSyncDate    DATETIME NULL,
    IsActive        BIT NOT NULL DEFAULT(1)
);
GO

-- OPEX master (synced from DIBPROD1.MEMO_CAPEX_OPEX where TYPE='Opex')
IF OBJECT_ID('dbo.OpexMaster','U') IS NULL
CREATE TABLE dbo.OpexMaster (
    OpexID          NVARCHAR(100) NOT NULL PRIMARY KEY,
    BudgetedAmount  DECIMAL(18,2) NOT NULL DEFAULT(0),
    UtilizedAmount  DECIMAL(18,2) NOT NULL DEFAULT(0),
    AvailableAmount DECIMAL(18,2) NOT NULL DEFAULT(0),
    LockedAmount    DECIMAL(18,2) NOT NULL DEFAULT(0),
    Contracts       NVARCHAR(MAX) NULL,   -- comma-sep contract numbers
    LastSyncDate    DATETIME NULL,
    IsActive        BIT NOT NULL DEFAULT(1)
);
GO

-- GL master (synced from DIBPROD1.MEMO_GL_DETAILS)
IF OBJECT_ID('dbo.GLMaster','U') IS NULL
CREATE TABLE dbo.GLMaster (
    GLNumber            NVARCHAR(50)  NOT NULL PRIMARY KEY,
    GLDescription       NVARCHAR(500) NULL,
    GLOpenedDate        DATETIME NULL,
    BudgetedAmount      DECIMAL(18,2) NOT NULL DEFAULT(0),
    BPMLockedAmount     DECIMAL(18,2) NOT NULL DEFAULT(0),
    AMSLockedAmount     DECIMAL(18,2) NOT NULL DEFAULT(0),
    UtilizedAmount      DECIMAL(18,2) NOT NULL DEFAULT(0),
    BalanceAmount       DECIMAL(18,2) NOT NULL DEFAULT(0),
    CapitalizedAmount   DECIMAL(18,2) NOT NULL DEFAULT(0),
    InvoiceProcessedAmt DECIMAL(18,2) NOT NULL DEFAULT(0),
    LastSyncDate        DATETIME NULL,
    IsActive            BIT NOT NULL DEFAULT(1)
);
GO

-- Vendor master (synced from DIBPROD1.MEMO_LPO_VENDOR_MASTER)
IF OBJECT_ID('dbo.VendorMaster','U') IS NULL
CREATE TABLE dbo.VendorMaster (
    VendorCode   NVARCHAR(50)  NOT NULL PRIMARY KEY,
    VendorName   NVARCHAR(300) NOT NULL,
    LastSyncDate DATETIME NULL,
    IsActive     BIT NOT NULL DEFAULT(1)
);
GO

-- ===================================================================
-- 3. BPM DATA  (synced from Oracle – hierarchy: Project > PET/Memo > LPO > Invoice)
-- ===================================================================

-- Projects (synced from DIBPROD1.MEMO_PROJECT_DETAILS)
IF OBJECT_ID('dbo.BPM_Projects','U') IS NULL
CREATE TABLE dbo.BPM_Projects (
    ProjectID           NVARCHAR(100) NOT NULL PRIMARY KEY,
    ProjectName         NVARCHAR(500) NULL,
    ProjectManager      NVARCHAR(200) NULL,
    ProjectManagerEmail NVARCHAR(200) NULL,
    ProjectAmount       DECIMAL(18,2) NOT NULL DEFAULT(0),
    ProjectStartDate    DATETIME NULL,
    ProjectEndDate      DATETIME NULL,
    ProjectDescription  NVARCHAR(MAX) NULL,
    UtilizedAmt         DECIMAL(18,2) NOT NULL DEFAULT(0),
    BalanceAmt          DECIMAL(18,2) NOT NULL DEFAULT(0),
    BPMLockedAmt        DECIMAL(18,2) NOT NULL DEFAULT(0),
    AMSLockedAmt        DECIMAL(18,2) NOT NULL DEFAULT(0),
    CapexID             NVARCHAR(100) NULL,
    BusinessArea        NVARCHAR(200) NULL,
    ProjectStatus       NVARCHAR(100) NULL,
    ExecutionEndDate    DATETIME NULL,
    LastSyncDate        DATETIME NULL
);
GO

-- PET management (synced from DIBPROD1.PET_MANAGEMENT)
IF OBJECT_ID('dbo.BPM_PET','U') IS NULL
CREATE TABLE dbo.BPM_PET (
    PETReferenceNo   NVARCHAR(100) NOT NULL PRIMARY KEY,
    Description      NVARCHAR(MAX) NULL,
    PETApprovedAmt   DECIMAL(18,2) NOT NULL DEFAULT(0),
    BPMLockedAmount  DECIMAL(18,2) NOT NULL DEFAULT(0),
    Utilized         DECIMAL(18,2) NOT NULL DEFAULT(0),
    Balance          DECIMAL(18,2) NOT NULL DEFAULT(0),
    ProjectID        NVARCHAR(100) NULL,
    LastSyncDate     DATETIME NULL
);
GO

-- PET vertical approval details (synced from DIBPROD1.MEMO_PET_VRTICAL_APPR_DTLS)
IF OBJECT_ID('dbo.BPM_PETVertical','U') IS NULL
CREATE TABLE dbo.BPM_PETVertical (
    ID              INT IDENTITY(1,1) PRIMARY KEY,
    WiName          NVARCHAR(100) NULL,
    VerticalName    NVARCHAR(200) NULL,
    CostComponent   NVARCHAR(200) NULL,
    SubComponent    NVARCHAR(200) NULL,
    EstimatedCost   DECIMAL(18,2) NOT NULL DEFAULT(0),
    PetAssignedStatus NVARCHAR(100) NULL,
    PetMemoRefNo    NVARCHAR(100) NULL,
    Utilized        DECIMAL(18,2) NOT NULL DEFAULT(0),
    Locked          DECIMAL(18,2) NOT NULL DEFAULT(0),
    Balance         DECIMAL(18,2) NOT NULL DEFAULT(0),
    LastSyncDate    DATETIME NULL
);
GO

-- Contract facts (synced from Q1 / DIBPROD1.MEMO_CA_CONTRACT_DETAILS)
IF OBJECT_ID('dbo.BPM_Contract','U') IS NULL
CREATE TABLE dbo.BPM_Contract (
    WiName              NVARCHAR(100) NOT NULL PRIMARY KEY,
    Reference           NVARCHAR(500) NULL,
    Department          NVARCHAR(200) NULL,
    InitiationDate      DATETIME NULL,
    InitiatorName       NVARCHAR(200) NULL,
    EFormNo             NVARCHAR(100) NULL,
    CurrentStage        NVARCHAR(200) NULL,
    Currency            NVARCHAR(10) NULL,
    LCAmount            DECIMAL(18,2) NOT NULL DEFAULT(0),
    FCAmount            DECIMAL(18,2) NOT NULL DEFAULT(0),
    BPMLockedAmount     DECIMAL(18,2) NOT NULL DEFAULT(0),
    AMSLockedAmount     DECIMAL(18,2) NOT NULL DEFAULT(0),
    UtilizedAmount      DECIMAL(18,2) NOT NULL DEFAULT(0),
    ContractBalance     DECIMAL(18,2) NOT NULL DEFAULT(0),
    OpexID              NVARCHAR(100) NULL,
    VendorName          NVARCHAR(300) NULL,
    RequestType         NVARCHAR(100) NULL,
    RequestMode         NVARCHAR(100) NULL,
    ContractNo          NVARCHAR(100) NULL,
    ContractStartDate   DATETIME NULL,
    ContractEndDate     DATETIME NULL,
    ContractStatus      NVARCHAR(100) NULL,
    BPMLastStatus       NVARCHAR(100) NULL,
    LastActionBy        NVARCHAR(200) NULL,
    PendingWith         NVARCHAR(200) NULL,
    LastApprover        NVARCHAR(200) NULL,
    LastActionDate      DATETIME NULL,
    TechFinanceStatus   NVARCHAR(100) NULL,
    LastSyncDate        DATETIME NULL
);
GO

-- GL master facts (synced from Q2)
IF OBJECT_ID('dbo.BPM_GL','U') IS NULL
CREATE TABLE dbo.BPM_GL (
    GLNumber            NVARCHAR(50)  NOT NULL PRIMARY KEY,
    GLDescription       NVARCHAR(500) NULL,
    GLOpenedDate        DATETIME NULL,
    BudgetedAmount      DECIMAL(18,2) NOT NULL DEFAULT(0),
    BPMLockedAmount     DECIMAL(18,2) NOT NULL DEFAULT(0),
    AMSLockedAmount     DECIMAL(18,2) NOT NULL DEFAULT(0),
    UtilizedAmount      DECIMAL(18,2) NOT NULL DEFAULT(0),
    BalanceAmount       DECIMAL(18,2) NOT NULL DEFAULT(0),
    CapitalizedAmount   DECIMAL(18,2) NOT NULL DEFAULT(0),
    InvoiceProcessedAmt DECIMAL(18,2) NOT NULL DEFAULT(0),
    LastSyncDate        DATETIME NULL
);
GO

-- LPO facts (synced from Q3)
IF OBJECT_ID('dbo.BPM_LPO','U') IS NULL
CREATE TABLE dbo.BPM_LPO (
    WiName              NVARCHAR(100) NOT NULL PRIMARY KEY,
    LPODesc             NVARCHAR(500) NULL,
    LPONo               NVARCHAR(100) NULL,
    Department          NVARCHAR(200) NULL,
    InitiationDate      DATETIME NULL,
    CurrentStage        NVARCHAR(200) NULL,
    InitiatorName       NVARCHAR(200) NULL,
    EFormNo             NVARCHAR(100) NULL,
    VendorName          NVARCHAR(300) NULL,
    LCAmount            DECIMAL(18,2) NOT NULL DEFAULT(0),
    Currency            NVARCHAR(10) NULL,
    FCAmount            DECIMAL(18,2) NOT NULL DEFAULT(0),
    GLNumber            NVARCHAR(50) NULL,
    LPOStatus           NVARCHAR(100) NULL,
    BPMStatus           NVARCHAR(100) NULL,
    BudgetAmount        DECIMAL(18,2) NOT NULL DEFAULT(0),
    BPMLockedAmount     DECIMAL(18,2) NOT NULL DEFAULT(0),
    AMSLockedAmount     DECIMAL(18,2) NOT NULL DEFAULT(0),
    UtilizedAmount      DECIMAL(18,2) NOT NULL DEFAULT(0),
    AvailableBalance    DECIMAL(18,2) NOT NULL DEFAULT(0),
    LastApprover        NVARCHAR(200) NULL,
    ActionDate          DATETIME NULL,
    TechFinanceStatus   NVARCHAR(100) NULL,
    LastSyncDate        DATETIME NULL
);
GO

-- Invoice facts (synced from Q4)
IF OBJECT_ID('dbo.BPM_Invoice','U') IS NULL
CREATE TABLE dbo.BPM_Invoice (
    WiName              NVARCHAR(100) NULL,
    InvoiceType         NVARCHAR(100) NULL,
    Department          NVARCHAR(200) NULL,
    InitiationDate      DATETIME NULL,
    InitiatorName       NVARCHAR(200) NULL,
    EFormNo             NVARCHAR(100) NULL,
    VendorName          NVARCHAR(300) NULL,
    InvoiceNumber       NVARCHAR(100) NULL,
    LCAmount            DECIMAL(18,2) NOT NULL DEFAULT(0),
    Currency            NVARCHAR(10) NULL,
    FCAmount            DECIMAL(18,2) NOT NULL DEFAULT(0),
    InvoiceDate         DATETIME NULL,
    InvoiceRefNo        NVARCHAR(100) NULL,
    InvoiceRefDesc      NVARCHAR(500) NULL,
    AMSInvoiceStatus    NVARCHAR(100) NULL,
    BPMLastStatus       NVARCHAR(100) NULL,
    LastActionBy        NVARCHAR(200) NULL,
    LastDecision        NVARCHAR(100) NULL,
    PendingAt           NVARCHAR(200) NULL,
    PendingWith         NVARCHAR(200) NULL,
    ActionDate          DATETIME NULL,
    LastSyncDate        DATETIME NULL
    --CONSTRAINT PK_BPM_Invoice PRIMARY KEY (WiName)
);
GO

-- CAPEX/OPEX transaction details (Q13/Q14)
IF OBJECT_ID('dbo.BPM_CapexOpexDetails','U') IS NULL
CREATE TABLE dbo.BPM_CapexOpexDetails (
    ID              INT IDENTITY(1,1) PRIMARY KEY,
    ItemType        NVARCHAR(20) NULL,   -- Capex | Opex
    ItemID          NVARCHAR(100) NULL,
    ItemDescription NVARCHAR(500) NULL,
    BudgetedAmount  DECIMAL(18,2) NOT NULL DEFAULT(0),
    UtilizedAmount  DECIMAL(18,2) NOT NULL DEFAULT(0),
    LockedAmount    DECIMAL(18,2) NOT NULL DEFAULT(0),
    AvailableAmount DECIMAL(18,2) NOT NULL DEFAULT(0),
    WiName          NVARCHAR(100) NULL,
    ClaimAmount     DECIMAL(18,2) NOT NULL DEFAULT(0),
    BalClaimAmt     DECIMAL(18,2) NOT NULL DEFAULT(0),
    OldClaimAmount  DECIMAL(18,2) NOT NULL DEFAULT(0),
    PIDCapexID      NVARCHAR(100) NULL,
    ProjectID       NVARCHAR(100) NULL,
    ProjectName     NVARCHAR(500) NULL,
    PetReference    NVARCHAR(100) NULL,
    PetApprovedAmt  DECIMAL(18,2) NOT NULL DEFAULT(0),
    VendorName      NVARCHAR(300) NULL,
    InitiatorDept   NVARCHAR(200) NULL,
    EFormDate       DATETIME NULL,
    LastSyncDate    DATETIME NULL
);
GO
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_BPM_COD_ItemType'
      AND object_id = OBJECT_ID('dbo.BPM_CapexOpexDetails')
)
BEGIN
  CREATE INDEX IX_BPM_COD_ItemType ON dbo.BPM_CapexOpexDetails(ItemType, ItemID);

END
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_BPM_COD_Project'
      AND object_id = OBJECT_ID('dbo.BPM_CapexOpexDetails')
)
BEGIN
 CREATE INDEX IX_BPM_COD_Project ON dbo.BPM_CapexOpexDetails(ProjectID);

END


GO

-- ===================================================================
-- 4. LOCAL PET WORKFLOW  (created in this application)
-- ===================================================================

-- PET form header (one per submission)
IF OBJECT_ID('dbo.PetForm','U') IS NULL
CREATE TABLE dbo.PetForm (
    PetFormID       INT IDENTITY(1,1) PRIMARY KEY,
    PetRefNo        AS ('PET-' + RIGHT('00000' + CAST(PetFormID AS VARCHAR(10)), 5)) PERSISTED,
    ProjectID       NVARCHAR(100) NOT NULL,   -- from BPM_Projects
    CapexOpexType   NVARCHAR(10) NOT NULL,    -- CAPEX | OPEX
    BudgetSourceID  NVARCHAR(100) NULL,        -- CapexID or OpexID
    Title           NVARCHAR(500) NULL,
    Description     NVARCHAR(MAX) NULL,
    Vertical        NVARCHAR(200) NULL,
    Applications    NVARCHAR(500) NULL,
    ReviewerUsername NVARCHAR(100) NULL,       -- NULL = skip reviewer, go direct to approver
    ApproverUsername NVARCHAR(100) NOT NULL,
    Status          NVARCHAR(30) NOT NULL DEFAULT('Draft'),
    -- Draft | PendingReview | PendingApproval | Approved | Rejected | SentBack
    Version         INT NOT NULL DEFAULT(1),
    SubmittedDate   DATETIME NULL,
    ReviewedDate    DATETIME NULL,
    ApprovedDate    DATETIME NULL,
    ReviewComments  NVARCHAR(MAX) NULL,
    ApprovalComments NVARCHAR(MAX) NULL,
    CreatedBy       NVARCHAR(100) NOT NULL,
    CreatedDate     DATETIME NOT NULL DEFAULT(GETDATE()),
    ModifiedBy      NVARCHAR(100) NULL,
    ModifiedDate    DATETIME NULL
);
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_PetForm_Project'
      AND object_id = OBJECT_ID('dbo.PetForm')
)
BEGIN
 CREATE INDEX IX_PetForm_Project ON dbo.PetForm(ProjectID);

END
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_PetForm_Status'
      AND object_id = OBJECT_ID('dbo.PetForm')
)
BEGIN
 CREATE INDEX IX_PetForm_Status ON dbo.PetForm(Status);
END


GO

-- PET line items
IF OBJECT_ID('dbo.PetLineItem','U') IS NULL
CREATE TABLE dbo.PetLineItem (
    LineID          INT IDENTITY(1,1) PRIMARY KEY,
    PetFormID       INT NOT NULL REFERENCES dbo.PetForm(PetFormID),
    SerialNo        INT NOT NULL DEFAULT(1),
    Department      NVARCHAR(100) NULL,
    ExpHead         NVARCHAR(20) NULL,   -- CAPEX | OPEX
    Topic           NVARCHAR(300) NULL,
    VendorName      NVARCHAR(300) NULL,
    Description     NVARCHAR(MAX) NULL,
    CostType        NVARCHAR(200) NULL,
    Units           DECIMAL(18,4) NOT NULL DEFAULT(0),
    UnitPrice       DECIMAL(18,4) NOT NULL DEFAULT(0),
    BaseCurrency    NVARCHAR(10) NULL DEFAULT('AED'),
    AmtFCY          DECIMAL(18,2) NOT NULL DEFAULT(0),
    AmtLCY          DECIMAL(18,2) NOT NULL DEFAULT(0),
    ContingencyPct  DECIMAL(9,4) NOT NULL DEFAULT(0),
    FinalAmtLCY     DECIMAL(18,2) NOT NULL DEFAULT(0),
    GLNumber        NVARCHAR(50) NULL,
    Comments        NVARCHAR(MAX) NULL,
    CreatedBy       NVARCHAR(100) NULL,
    CreatedDate     DATETIME NOT NULL DEFAULT(GETDATE())
);
GO
--CREATE INDEX IX_PetLine_Form ON dbo.PetLineItem(PetFormID);
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_PetLine_Form'
      AND object_id = OBJECT_ID('dbo.PetLineItem')
)
BEGIN
 CREATE INDEX IX_PetLine_Form ON dbo.PetLineItem(PetFormID);
END

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_PetForm_Status'
      AND object_id = OBJECT_ID('dbo.PetForm')
)
BEGIN
 CREATE INDEX IX_PetForm_Status ON dbo.PetForm(Status);
END
go
-- PET workflow history
IF OBJECT_ID('dbo.PetWorkflowHistory','U') IS NULL
CREATE TABLE dbo.PetWorkflowHistory (
    HistID      INT IDENTITY(1,1) PRIMARY KEY,
    PetFormID   INT NOT NULL REFERENCES dbo.PetForm(PetFormID),
    Action      NVARCHAR(50) NOT NULL,  -- Submit | Review | Approve | Reject | SendBack | Resubmit
    ActionBy    NVARCHAR(100) NOT NULL,
    ActionDate  DATETIME NOT NULL DEFAULT(GETDATE()),
    Comments    NVARCHAR(MAX) NULL,
    FromStatus  NVARCHAR(30) NULL,
    ToStatus    NVARCHAR(30) NULL
);
GO

-- Attachments for PET
IF OBJECT_ID('dbo.PetAttachments','U') IS NULL
CREATE TABLE dbo.PetAttachments (
    AttachmentID  INT IDENTITY(1,1) PRIMARY KEY,
    PetFormID     INT NOT NULL REFERENCES dbo.PetForm(PetFormID),
    FileName      NVARCHAR(260) NOT NULL,
    ContentType   NVARCHAR(100) NULL,
    FileContent   VARBINARY(MAX) NOT NULL,
    UploadedBy    NVARCHAR(100) NULL,
    UploadedAt    DATETIME NOT NULL DEFAULT(GETDATE())
);
GO

-- ===================================================================
-- 5. SYNC LOG & NOTIFICATIONS
-- ===================================================================

IF OBJECT_ID('dbo.SyncLog','U') IS NULL
CREATE TABLE dbo.SyncLog (
    SyncID      INT IDENTITY(1,1) PRIMARY KEY,
    SyncType    NVARCHAR(50) NOT NULL,   -- FullSync | DeltaSync | CapexOnly | OpexOnly | GLOnly | VendorOnly | BPMData
    StartTime   DATETIME NOT NULL DEFAULT(GETDATE()),
    EndTime     DATETIME NULL,
    Status      NVARCHAR(20) NOT NULL DEFAULT('Running'),  -- Running | Success | Failed
    RecordsIn   INT NOT NULL DEFAULT(0),
    RecordsUp   INT NOT NULL DEFAULT(0),
    ErrorMsg    NVARCHAR(MAX) NULL,
    TriggeredBy NVARCHAR(100) NULL
);
GO

IF OBJECT_ID('dbo.Notifications','U') IS NULL
CREATE TABLE dbo.Notifications (
    NotificationID INT IDENTITY(1,1) PRIMARY KEY,
    Recipient      NVARCHAR(100) NOT NULL,
    Subject        NVARCHAR(300) NOT NULL,
    Message        NVARCHAR(MAX) NULL,
    LinkUrl        NVARCHAR(500) NULL,
    IsRead         BIT NOT NULL DEFAULT(0),
    CreatedDate    DATETIME NOT NULL DEFAULT(GETDATE()),
    PetFormID      INT NULL,
    NotifType      NVARCHAR(50) NULL
);
GO
--CREATE INDEX IX_Notif_Recipient ON dbo.Notifications(Recipient, IsRead);
--GO


IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_Notif_Recipient'
      AND object_id = OBJECT_ID('dbo.Notifications')
)
BEGIN
 CREATE INDEX IX_Notif_Recipient ON dbo.Notifications(Recipient, IsRead);

END


-- ===================================================================
-- 6. JIRA ISSUES  (synced from JIRA)
-- ===================================================================
IF OBJECT_ID('dbo.JiraConfig','U') IS NULL
CREATE TABLE dbo.JiraConfig (
    ConfigID    INT IDENTITY(1,1) PRIMARY KEY,
    BaseUrl     NVARCHAR(300) NULL,
    UserEmail   NVARCHAR(150) NULL,
    ApiToken    NVARCHAR(300) NULL,
    ProjectKey  NVARCHAR(50)  NULL,
    UpdatedDate DATETIME NOT NULL DEFAULT(GETDATE())
);
GO


IF OBJECT_ID('dbo.JiraIssues','U') IS NULL
CREATE TABLE [dbo].[JiraIssues](
	[JiraID] [nvarchar](50) NULL,
	[Summary] [nvarchar](500) NULL,
	[ProjectName] [nvarchar](300) NULL,
	[StartDate] [nvarchar](50) NULL,
	[EndDate] [nvarchar](50) NULL,
	[OverallStatus] [nvarchar](100) NULL,
	[ProjectStage] [nvarchar](100) NULL,
	[ProjectType] [nvarchar](100) NULL,
	[DemandType] [nvarchar](100) NULL,
	[ProjectRAG] [nvarchar](50) NULL,
	[Department] [nvarchar](200) NULL,
	[Manager] [nvarchar](150) NULL,
	[TechLead] [nvarchar](150) NULL,
	[Sponsor] [nvarchar](150) NULL,
	[Stakeholder] [nvarchar](200) NULL,
	[Classification] [nvarchar](100) NULL,
	[Objectives] [nvarchar](max) NULL,
	[CustomFieldsJson] [nvarchar](max) NULL,
	[UpdatedDate] [datetime] NOT NULL,
	[Status] [nvarchar](100) NULL,
	[IssueType] [nvarchar](100) NULL,
	[Assignee] [nvarchar](200) NULL,
	[Reporter] [nvarchar](200) NULL,
	[AccountableExecLead] [nvarchar](200) NULL,
	[SmeLead] [nvarchar](200) NULL,
	[AccountableExec] [nvarchar](200) NULL,
	[IdhPortfolioHead] [nvarchar](200) NULL,
	[AssignedProjectManager] [nvarchar](200) NULL,
	[DemandOwner] [nvarchar](200) NULL,
	[ChiefNameMapping] [nvarchar](200) NULL,
	[TargetCompletionDate] [datetime] NULL,
	[ProposedDemandPickupDate] [datetime] NULL,
	[JiraCreated] [datetime] NULL,
	[JiraUpdated] [datetime] NULL,
	[ProjectKey] [nvarchar](20) NULL,
	[ParentJiraID] [nvarchar](50) NULL,
	[Platform] [nvarchar](200) NULL,
	[Actual_Go_Live_Date] [datetime] NULL,
	[Target_Completion_Date] [datetime] NULL,
	[Proposed_Demand_Pick_up_Date] [datetime] NULL,
	[Proposed_Baseline_0_End_Date] [datetime] NULL,
	[Proposed_Baseline_0_Start_Date] [datetime] NULL,
	[Proposed_Baseline_0_submission_Date] [datetime] NULL,
	[Primary_Classification] [nvarchar](200) NULL,
	[PlatformVertical] [nvarchar](200) NULL,
	[PlatformName] [nvarchar](200) NULL,
	[SecondaryPlatform] [nvarchar](200) NULL,
	[ActivityRagStatus] [nvarchar](50) NULL,
	[ScheduleRag] [nvarchar](50) NULL,
	[BudgetRag] [nvarchar](50) NULL,
	[RaidRag] [nvarchar](50) NULL,
	[OverallProjectRag] [nvarchar](50) NULL,
	[Priority] [nvarchar](50) NULL,
	[CreatedDate] [datetime] NULL,
	[JiraIssues] [nvarchar](2000) NULL,
	[JiraKey] [nvarchar](50) NOT NULL,
	[ProjectManager] [nvarchar](2000) NULL,
	[EmployeeEmail] [nvarchar](200) NULL,
	[EmployeeName] [nvarchar](200) NULL,
	[ProjectPerformingDept] [nvarchar](200) NULL,
	[ProjectSponsorDept] [nvarchar](200) NULL,
	[DemandDepartment] [nvarchar](200) NULL,
	[RequesterDept] [nvarchar](200) NULL,
	[ProjectDept] [nvarchar](200) NULL,
	[DemandSegment] [nvarchar](200) NULL,
	[DemandTitle] [nvarchar](500) NULL,
	[RegulatoryObservation] [nvarchar](max) NULL,
	[BaselineStartDate] [datetime] NULL,
	[BaselineEndDate] [datetime] NULL,
	[Baseline1ActualStart] [datetime] NULL,
	[Baseline0PlannedStart] [datetime] NULL,
	[Baseline0PlannedEnd] [datetime] NULL,
	[Baseline0ActualEnd] [datetime] NULL,
	[Baseline1ActualGoLive] [datetime] NULL,
	[Baseline0ActualStart] [datetime] NULL,
	[Baseline1ActualEnd] [datetime] NULL,
	[RolloutStatus] [nvarchar](100) NULL,
	[EpicStatus] [nvarchar](100) NULL,
	[BrdStatus] [nvarchar](100) NULL,
	[ScriptStatus] [nvarchar](100) NULL,
	[StatusGrey] [nvarchar](100) NULL,
	[StatusReason] [nvarchar](200) NULL,
	[InitiativeStatus] [nvarchar](100) NULL,
	[ProjectOverallStatus] [nvarchar](100) NULL,
	[CbtpBrdStatus] [nvarchar](100) NULL,
	[FsdStatus] [nvarchar](100) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
--ALTER TABLE [dbo].[JiraIssues] ADD  DEFAULT (getdate()) FOR [UpdatedDate]

PRINT 'DFM_BPM schema created successfully.';
GO
