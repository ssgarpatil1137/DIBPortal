USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF OBJECT_ID('dbo.Attachments','U') IS NULL
BEGIN
 CREATE TABLE dbo.Attachments
 (
  AttachmentId bigint IDENTITY PRIMARY KEY,
  EntityType nvarchar(30) NOT NULL,
  EntityId int NOT NULL,
  OriginalName nvarchar(260) NOT NULL,
  StoredName nvarchar(260) NOT NULL,
  ContentType nvarchar(150) NOT NULL,
  FileSize bigint NOT NULL,
  UploadedBy nvarchar(254) NOT NULL,
  UploadedUtc datetime2 NOT NULL CONSTRAINT DF_Attachments_UploadedUtc DEFAULT SYSUTCDATETIME()
 );
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_InsertAttachment
 @EntityType nvarchar(30), @EntityId int, @OriginalName nvarchar(260), @StoredName nvarchar(260),
 @ContentType nvarchar(150), @FileSize bigint, @UploadedBy nvarchar(254)
AS
BEGIN
 SET NOCOUNT ON;
 INSERT dbo.Attachments(EntityType,EntityId,OriginalName,StoredName,ContentType,FileSize,UploadedBy)
 VALUES(LEFT(ISNULL(NULLIF(LTRIM(RTRIM(@EntityType)),''),'PET'),30),@EntityId,LEFT(ISNULL(NULLIF(LTRIM(RTRIM(@OriginalName)),''),'supporting-document'),260),LEFT(ISNULL(NULLIF(LTRIM(RTRIM(@StoredName)),''),CONVERT(nvarchar(32),NEWID())),260),LEFT(ISNULL(NULLIF(LTRIM(RTRIM(@ContentType)),''),'application/octet-stream'),150),@FileSize,LEFT(ISNULL(NULLIF(LTRIM(RTRIM(@UploadedBy)),''),'system'),254));
END;
GO

IF DATABASE_PRINCIPAL_ID('dfm_app') IS NOT NULL
BEGIN
 GRANT EXECUTE ON dbo.sp_InsertAttachment TO dfm_app;
 GRANT SELECT ON dbo.Attachments TO dfm_app;
 GRANT INSERT ON dbo.Attachments TO dfm_app;
END;
GO
