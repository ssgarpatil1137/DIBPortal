USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF COL_LENGTH('dbo.Users','PortalAccess') IS NULL
BEGIN
 ALTER TABLE dbo.Users ADD PortalAccess bit NOT NULL CONSTRAINT DF_Users_PortalAccess DEFAULT(1) WITH VALUES;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_SyncDirectoryUser @Email nvarchar(254),@DisplayName nvarchar(200),@AccountName nvarchar(200),@ObjectGuid uniqueidentifier,@DefaultRole nvarchar(30) AS
BEGIN SET NOCOUNT ON;
 MERGE dbo.Users AS t USING(SELECT LOWER(@Email) Email) s ON t.Email=s.Email
 WHEN MATCHED THEN UPDATE SET DisplayName=@DisplayName,DirectoryAccount=@AccountName,DirectoryObjectGuid=@ObjectGuid,LastDirectorySyncUtc=SYSUTCDATETIME(),UpdatedUtc=SYSUTCDATETIME()
 WHEN NOT MATCHED THEN INSERT(Email,DisplayName,DirectoryAccount,DirectoryObjectGuid,PortalAccess,LastDirectorySyncUtc) VALUES(LOWER(@Email),@DisplayName,@AccountName,@ObjectGuid,1,SYSUTCDATETIME());
 DECLARE @UserId int=(SELECT UserId FROM dbo.Users WHERE Email=LOWER(@Email)),@RoleId int=(SELECT RoleId FROM dbo.Roles WHERE Name=@DefaultRole);
 IF NOT EXISTS(SELECT 1 FROM dbo.UserRoles WHERE UserId=@UserId AND RoleId=@RoleId) INSERT dbo.UserRoles VALUES(@UserId,@RoleId);
END;
GO