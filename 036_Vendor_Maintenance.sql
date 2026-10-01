USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF OBJECT_ID('dbo.Vendors','U') IS NULL
BEGIN
    CREATE TABLE dbo.Vendors
    (
        VendorId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Vendors PRIMARY KEY,
        Name NVARCHAR(300) NOT NULL,
        NormalizedName AS UPPER(LTRIM(RTRIM(Name))) PERSISTED,
        IsActive BIT NOT NULL CONSTRAINT DF_Vendors_IsActive DEFAULT(1),
        CreatedUtc DATETIME2 NOT NULL CONSTRAINT DF_Vendors_CreatedUtc DEFAULT SYSUTCDATETIME(),
        UpdatedUtc DATETIME2 NOT NULL CONSTRAINT DF_Vendors_UpdatedUtc DEFAULT SYSUTCDATETIME()
    );
    CREATE UNIQUE INDEX UX_Vendors_NormalizedName ON dbo.Vendors(NormalizedName);
END;
GO

IF DATABASE_PRINCIPAL_ID('dfm_app') IS NOT NULL
BEGIN
    GRANT SELECT ON dbo.Vendors TO dfm_app;
    GRANT INSERT ON dbo.Vendors TO dfm_app;
    GRANT UPDATE ON dbo.Vendors TO dfm_app;
END;
GO