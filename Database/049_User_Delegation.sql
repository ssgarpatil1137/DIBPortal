USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF OBJECT_ID('dbo.UserDelegations','U') IS NULL
BEGIN
    CREATE TABLE dbo.UserDelegations
    (
        DelegationId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_UserDelegations PRIMARY KEY,
        DelegatorUserId INT NOT NULL CONSTRAINT FK_UserDelegations_Delegator REFERENCES dbo.Users(UserId),
        DelegateUserId INT NOT NULL CONSTRAINT FK_UserDelegations_Delegate REFERENCES dbo.Users(UserId),
        StartDate DATE NOT NULL,
        EndDate DATE NULL,
        CreatedUtc DATETIME2 NOT NULL CONSTRAINT DF_UserDelegations_CreatedUtc DEFAULT SYSUTCDATETIME(),
        CreatedBy NVARCHAR(254) NOT NULL,
        UpdatedUtc DATETIME2 NOT NULL CONSTRAINT DF_UserDelegations_UpdatedUtc DEFAULT SYSUTCDATETIME(),
        UpdatedBy NVARCHAR(254) NOT NULL,
        RevokedUtc DATETIME2 NULL,
        RevokedBy NVARCHAR(254) NULL,
        CONSTRAINT CK_UserDelegations_NotSelf CHECK (DelegatorUserId<>DelegateUserId),
        CONSTRAINT CK_UserDelegations_Dates CHECK (EndDate IS NULL OR EndDate>=StartDate)
    );
    -- One current (non-revoked) delegation per user prevents duplicate active delegations.
    CREATE UNIQUE INDEX UX_UserDelegations_CurrentDelegator ON dbo.UserDelegations(DelegatorUserId) WHERE RevokedUtc IS NULL;
    CREATE INDEX IX_UserDelegations_Delegate ON dbo.UserDelegations(DelegateUserId) WHERE RevokedUtc IS NULL;
END;
GO

-- Delegate-performed decisions keep ActionBy = actual actor and record the original assignee here.
IF COL_LENGTH('dbo.WorkflowHistory','OnBehalfOf') IS NULL
BEGIN
    ALTER TABLE dbo.WorkflowHistory ADD OnBehalfOf NVARCHAR(254) NULL;
END;
GO

-- Delegations in effect today between two active portal users; expiry and revocation take effect immediately.
CREATE OR ALTER VIEW dbo.vw_ActiveDelegations AS
SELECT d.DelegationId,d.DelegatorUserId,o.Email DelegatorEmail,o.DisplayName DelegatorName,
 d.DelegateUserId,g.Email DelegateEmail,g.DisplayName DelegateName,d.StartDate,d.EndDate,
 CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.UserRoles ur JOIN dbo.Roles r ON r.RoleId=ur.RoleId WHERE ur.UserId=o.UserId AND r.Name='Reviewer') THEN 1 ELSE 0 END AS bit) DelegatorCanReview,
 CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.UserRoles ur JOIN dbo.Roles r ON r.RoleId=ur.RoleId WHERE ur.UserId=o.UserId AND r.Name='Approver') THEN 1 ELSE 0 END AS bit) DelegatorCanApprove
FROM dbo.UserDelegations d
JOIN dbo.Users o ON o.UserId=d.DelegatorUserId
JOIN dbo.Users g ON g.UserId=d.DelegateUserId
WHERE d.RevokedUtc IS NULL
 AND d.StartDate<=CAST(GETDATE() AS date)
 AND (d.EndDate IS NULL OR d.EndDate>=CAST(GETDATE() AS date))
 AND o.IsActive=1 AND o.PortalAccess=1
 AND g.IsActive=1 AND g.PortalAccess=1;
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetWorkflowHistory @PetId int
AS
BEGIN
 SET NOCOUNT ON;
 SELECT wh.WorkflowHistoryId, wh.FromStatus, wh.ToStatus, COALESCE(u.DisplayName, wh.ActionBy) ActionByName,
  CASE WHEN wh.OnBehalfOf IS NULL THEN NULL ELSE COALESCE(ob.DisplayName, wh.OnBehalfOf) END OnBehalfOfName,
  wh.Comments, wh.ActionUtc
 FROM dbo.WorkflowHistory wh
 LEFT JOIN dbo.Users u ON u.Email=wh.ActionBy
 LEFT JOIN dbo.Users ob ON ob.Email=wh.OnBehalfOf
 WHERE wh.PetId=@PetId ORDER BY wh.ActionUtc;
END;
GO

IF DATABASE_PRINCIPAL_ID('dfm_app') IS NOT NULL
BEGIN
    GRANT SELECT ON dbo.UserDelegations TO dfm_app;
    GRANT INSERT ON dbo.UserDelegations TO dfm_app;
    GRANT UPDATE ON dbo.UserDelegations TO dfm_app;
    GRANT SELECT ON dbo.vw_ActiveDelegations TO dfm_app;
END;
GO
