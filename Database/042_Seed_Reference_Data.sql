-- Run against the target database created by dbo.sp_ReplicateDatabaseObjects (it copies schema only, not data).
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- The web client uses fixed SecurityQuestionId values 1-3.
SET IDENTITY_INSERT dbo.SecurityQuestions ON;
IF NOT EXISTS(SELECT 1 FROM dbo.SecurityQuestions WHERE SecurityQuestionId=1) INSERT dbo.SecurityQuestions(SecurityQuestionId,Question,IsActive) VALUES(1,N'What was the name of your first school?',1);
IF NOT EXISTS(SELECT 1 FROM dbo.SecurityQuestions WHERE SecurityQuestionId=2) INSERT dbo.SecurityQuestions(SecurityQuestionId,Question,IsActive) VALUES(2,N'In which city were you born?',1);
IF NOT EXISTS(SELECT 1 FROM dbo.SecurityQuestions WHERE SecurityQuestionId=3) INSERT dbo.SecurityQuestions(SecurityQuestionId,Question,IsActive) VALUES(3,N'What is the name of your childhood best friend?',1);
SET IDENTITY_INSERT dbo.SecurityQuestions OFF;
GO

IF NOT EXISTS(SELECT 1 FROM dbo.Roles WHERE Name=N'Requestor') INSERT dbo.Roles(Name) VALUES(N'Requestor');
IF NOT EXISTS(SELECT 1 FROM dbo.Roles WHERE Name=N'Reviewer') INSERT dbo.Roles(Name) VALUES(N'Reviewer');
IF NOT EXISTS(SELECT 1 FROM dbo.Roles WHERE Name=N'Approver') INSERT dbo.Roles(Name) VALUES(N'Approver');
IF NOT EXISTS(SELECT 1 FROM dbo.Roles WHERE Name=N'Master') INSERT dbo.Roles(Name) VALUES(N'Master');
IF NOT EXISTS(SELECT 1 FROM dbo.Roles WHERE Name=N'Admin') INSERT dbo.Roles(Name) VALUES(N'Admin');
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
