USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE Name = N'Admin')
 INSERT dbo.Roles(Name) VALUES(N'Admin');
GO
INSERT dbo.UserRoles(UserId, RoleId)
SELECT u.UserId, r.RoleId
FROM dbo.Users u
CROSS JOIN dbo.Roles r
WHERE r.Name = N'Requestor'
  AND NOT EXISTS (SELECT 1 FROM dbo.UserRoles ur WHERE ur.UserId = u.UserId AND ur.RoleId = r.RoleId);
GO
INSERT dbo.UserRoles(UserId, RoleId)
SELECT ur.UserId, admin.RoleId
FROM dbo.UserRoles ur
JOIN dbo.Roles masterRole ON masterRole.RoleId = ur.RoleId AND masterRole.Name = N'Master'
JOIN dbo.Roles admin ON admin.Name = N'Admin'
WHERE NOT EXISTS (SELECT 1 FROM dbo.UserRoles existing WHERE existing.UserId = ur.UserId AND existing.RoleId = admin.RoleId);
GO
IF COL_LENGTH('dbo.Projects','RequiresPet') IS NULL
 ALTER TABLE dbo.Projects ADD RequiresPet bit NOT NULL CONSTRAINT DF_Projects_RequiresPet DEFAULT 1, SkipReview bit NOT NULL CONSTRAINT DF_Projects_SkipReview DEFAULT 0;
GO
ALTER TABLE dbo.Projects ALTER COLUMN BudgetType nvarchar(10) NULL;
ALTER TABLE dbo.Projects ALTER COLUMN BudgetSourceId int NULL;
GO
CREATE OR ALTER PROCEDURE dbo.sp_SaveProject
 @ProjectId int=NULL,@IsJira bit,@JiraKey nvarchar(50)=NULL,@Name nvarchar(500),@Type nvarchar(100)=NULL,
 @Lead nvarchar(200),@Executive nvarchar(200),@Sme nvarchar(200)=NULL,@Size nvarchar(50)=NULL,@Manager nvarchar(200)=NULL,
 @BudgetType nvarchar(10)=NULL,@BudgetSource int=NULL,@RequiresPet bit=1,@SkipReview bit=0,@User nvarchar(254)
AS
BEGIN
 SET NOCOUNT ON;
 IF @RequiresPet=1 AND NOT EXISTS(SELECT 1 FROM dbo.BudgetSources WHERE BudgetSourceId=@BudgetSource AND BudgetType=@BudgetType)
  THROW 50001,'Budget source does not match CAPEX/OPEX selection.',1;
 IF @RequiresPet=0 BEGIN SET @BudgetType=NULL; SET @BudgetSource=NULL; SET @SkipReview=0; END;
 IF @ProjectId IS NULL
 BEGIN
  INSERT dbo.Projects(IsJira,JiraKey,ProjectName,ProjectType,AccountableExecLead,AccountableExec,SmeLead,ProjectSize,ProjectManager,RequestorEmail,BudgetType,BudgetSourceId,RequiresPet,SkipReview,Status)
  VALUES(@IsJira,NULLIF(@JiraKey,''),@Name,@Type,@Lead,@Executive,@Sme,@Size,@Manager,@User,@BudgetType,@BudgetSource,@RequiresPet,@SkipReview,CASE WHEN @RequiresPet=0 THEN 'Registered' ELSE 'Active' END);
  SET @ProjectId=SCOPE_IDENTITY();
 END
 ELSE
  UPDATE dbo.Projects SET IsJira=@IsJira,JiraKey=NULLIF(@JiraKey,''),ProjectName=@Name,ProjectType=@Type,AccountableExecLead=@Lead,AccountableExec=@Executive,SmeLead=@Sme,ProjectSize=@Size,ProjectManager=@Manager,BudgetType=@BudgetType,BudgetSourceId=@BudgetSource,RequiresPet=@RequiresPet,SkipReview=@SkipReview,Status=CASE WHEN @RequiresPet=0 THEN 'Registered' ELSE Status END,UpdatedUtc=SYSUTCDATETIME()
  WHERE ProjectId=@ProjectId AND (RequestorEmail=@User OR EXISTS(SELECT 1 FROM dbo.Users u JOIN dbo.UserRoles ur ON ur.UserId=u.UserId JOIN dbo.Roles r ON r.RoleId=ur.RoleId WHERE u.Email=@User AND r.Name IN ('Admin','Master')));
 SELECT ProjectId,ProjectCode FROM dbo.Projects WHERE ProjectId=@ProjectId;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_UpdateBudget @Id int,@Description nvarchar(1000),@Budget decimal(19,2),@Utilization decimal(19,2),@Available decimal(19,2),@User nvarchar(254) AS
BEGIN
 IF NOT EXISTS(SELECT 1 FROM dbo.Users u JOIN dbo.UserRoles ur ON ur.UserId=u.UserId JOIN dbo.Roles r ON r.RoleId=ur.RoleId WHERE u.Email=@User AND r.Name IN ('Admin','Master')) THROW 50006,'Only Admin can edit CAPEX/OPEX.',1;
 UPDATE dbo.BudgetSources SET Description=@Description,Budget=@Budget,Utilization=@Utilization,AvailableBudget=@Available,UpdatedUtc=SYSUTCDATETIME() WHERE BudgetSourceId=@Id;
 INSERT dbo.AuditLog(EntityType,EntityId,ActionName,UserEmail) VALUES('BudgetSource',@Id,'Update',@User);
END;
GO
