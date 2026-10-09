USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

DECLARE @MasterAdminEmail nvarchar(254) = N'master.admin@dfm.ae';
DECLARE @MasterAdminName nvarchar(200) = N'Master Admin';
DECLARE @ApproverEmail nvarchar(254) = N'approver@dfm.ae';
DECLARE @ApproverName nvarchar(200) = N'PET Approver';
DECLARE @ReviewerEmail nvarchar(254) = N'reviewer@dfm.ae';
DECLARE @ReviewerName nvarchar(200) = N'PET Reviewer';

IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE Name = N'Requestor') INSERT dbo.Roles(Name) VALUES(N'Requestor');
IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE Name = N'Reviewer') INSERT dbo.Roles(Name) VALUES(N'Reviewer');
IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE Name = N'Approver') INSERT dbo.Roles(Name) VALUES(N'Approver');
IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE Name = N'Admin') INSERT dbo.Roles(Name) VALUES(N'Admin');

MERGE dbo.Users AS target
USING (VALUES
 (LOWER(@MasterAdminEmail), @MasterAdminName),
 (LOWER(@ApproverEmail), @ApproverName),
 (LOWER(@ReviewerEmail), @ReviewerName)
) AS source(Email, DisplayName)
ON target.Email = source.Email
WHEN MATCHED THEN
 UPDATE SET DisplayName = source.DisplayName, IsActive = 1, UpdatedUtc = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
 INSERT(Email, DisplayName, IsActive, RequiresPasswordSetup)
 VALUES(source.Email, source.DisplayName, 1, 1);

INSERT dbo.UserRoles(UserId, RoleId)
SELECT u.UserId, r.RoleId
FROM dbo.Users u
CROSS JOIN dbo.Roles r
WHERE u.Email IN (LOWER(@MasterAdminEmail), LOWER(@ApproverEmail), LOWER(@ReviewerEmail))
  AND r.Name = N'Requestor'
  AND NOT EXISTS (SELECT 1 FROM dbo.UserRoles ur WHERE ur.UserId = u.UserId AND ur.RoleId = r.RoleId);

DELETE ur
FROM dbo.UserRoles ur
JOIN dbo.Users u ON u.UserId = ur.UserId
JOIN dbo.Roles r ON r.RoleId = ur.RoleId
WHERE u.Email IN (LOWER(@MasterAdminEmail), LOWER(@ApproverEmail), LOWER(@ReviewerEmail))
  AND r.Name IN (N'Reviewer', N'Approver', N'Admin', N'Master');

INSERT dbo.UserRoles(UserId, RoleId)
SELECT u.UserId, r.RoleId
FROM dbo.Users u
JOIN dbo.Roles r ON
 (u.Email = LOWER(@MasterAdminEmail) AND r.Name = N'Admin') OR
 (u.Email = LOWER(@ApproverEmail) AND r.Name = N'Approver') OR
 (u.Email = LOWER(@ReviewerEmail) AND r.Name = N'Reviewer');

SELECT u.Email, u.DisplayName,
 STUFF((SELECT N', ' + r.Name
        FROM dbo.UserRoles ur
        JOIN dbo.Roles r ON r.RoleId = ur.RoleId
        WHERE ur.UserId = u.UserId
        ORDER BY CASE r.Name WHEN N'Requestor' THEN 1 WHEN N'Reviewer' THEN 2 WHEN N'Approver' THEN 3 WHEN N'Admin' THEN 4 WHEN N'Master' THEN 5 ELSE 6 END
        FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 2, N'') AS Roles,
 u.RequiresPasswordSetup
FROM dbo.Users u
WHERE u.Email IN (LOWER(@MasterAdminEmail), LOWER(@ApproverEmail), LOWER(@ReviewerEmail))
ORDER BY u.DisplayName;
GO