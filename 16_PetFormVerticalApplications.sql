-- ============================================================
-- 16_PetFormVerticalApplications.sql
-- Adds Requestor-entered PET header fields used by Create PET Request.
-- ============================================================
USE DFM_BPM;
GO

IF COL_LENGTH('dbo.PetForm','Vertical') IS NULL
    ALTER TABLE dbo.PetForm ADD Vertical NVARCHAR(200) NULL;
GO

IF COL_LENGTH('dbo.PetForm','Applications') IS NULL
    ALTER TABLE dbo.PetForm ADD Applications NVARCHAR(500) NULL;
GO

PRINT '16_PetFormVerticalApplications.sql completed successfully.';
GO