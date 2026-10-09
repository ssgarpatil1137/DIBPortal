USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF OBJECT_ID('dbo.Currencies','U') IS NULL
BEGIN
    CREATE TABLE dbo.Currencies
    (
        CurrencyID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Currencies PRIMARY KEY,
        Code NVARCHAR(10) NOT NULL,
        Name NVARCHAR(100) NOT NULL,
        RateToLocal DECIMAL(18,6) NOT NULL CONSTRAINT DF_Currencies_RateToLocal DEFAULT(1),
        IsActive BIT NOT NULL CONSTRAINT DF_Currencies_IsActive DEFAULT(1),
        CONSTRAINT UQ_Currencies_Code UNIQUE(Code),
        CONSTRAINT CK_Currencies_RateToLocal_Positive CHECK(RateToLocal > 0)
    );
END;
GO

IF OBJECT_ID('dbo.Currencies','U') IS NOT NULL
BEGIN
    IF NOT EXISTS(SELECT 1 FROM dbo.Currencies WHERE Code='AED') INSERT dbo.Currencies(Code,Name,RateToLocal,IsActive) VALUES('AED','UAE Dirham',1,1);
    IF NOT EXISTS(SELECT 1 FROM dbo.Currencies WHERE Code='USD') INSERT dbo.Currencies(Code,Name,RateToLocal,IsActive) VALUES('USD','US Dollar',3.672500,1);
    IF NOT EXISTS(SELECT 1 FROM dbo.Currencies WHERE Code='EUR') INSERT dbo.Currencies(Code,Name,RateToLocal,IsActive) VALUES('EUR','Euro',4.050000,1);
    IF NOT EXISTS(SELECT 1 FROM dbo.Currencies WHERE Code='GBP') INSERT dbo.Currencies(Code,Name,RateToLocal,IsActive) VALUES('GBP','British Pound',4.650000,1);
    IF NOT EXISTS(SELECT 1 FROM dbo.Currencies WHERE Code='INR') INSERT dbo.Currencies(Code,Name,RateToLocal,IsActive) VALUES('INR','Indian Rupee',0.044000,1);
    IF NOT EXISTS(SELECT 1 FROM dbo.Currencies WHERE Code='SAR') INSERT dbo.Currencies(Code,Name,RateToLocal,IsActive) VALUES('SAR','Saudi Riyal',0.979000,1);
END;
GO