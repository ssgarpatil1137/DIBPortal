USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
-- Additive, idempotent: adds the exact business field names used by the JIRA
-- demand-details JS config (Js/1.js) so DFM.OfflineSync can sync them 1:1.
IF COL_LENGTH('dbo.JiraIssues','Created') IS NULL ALTER TABLE dbo.JiraIssues ADD Created datetime NULL;
IF COL_LENGTH('dbo.JiraIssues','ProjectId') IS NULL ALTER TABLE dbo.JiraIssues ADD ProjectId nvarchar(50) NULL;
IF COL_LENGTH('dbo.JiraIssues','DemandId') IS NULL ALTER TABLE dbo.JiraIssues ADD DemandId nvarchar(50) NULL;
IF COL_LENGTH('dbo.JiraIssues','Size') IS NULL ALTER TABLE dbo.JiraIssues ADD [Size] nvarchar(50) NULL;
IF COL_LENGTH('dbo.JiraIssues','ProjectDepartment') IS NULL ALTER TABLE dbo.JiraIssues ADD ProjectDepartment nvarchar(200) NULL;
IF COL_LENGTH('dbo.JiraIssues','EndDate') IS NULL ALTER TABLE dbo.JiraIssues ADD EndDate datetime NULL;
IF COL_LENGTH('dbo.JiraIssues','ActivityActualStartDate') IS NULL ALTER TABLE dbo.JiraIssues ADD ActivityActualStartDate datetime NULL;
IF COL_LENGTH('dbo.JiraIssues','ActivityActualEndDate') IS NULL ALTER TABLE dbo.JiraIssues ADD ActivityActualEndDate datetime NULL;
IF COL_LENGTH('dbo.JiraIssues','ActivityPlannedStartDate') IS NULL ALTER TABLE dbo.JiraIssues ADD ActivityPlannedStartDate datetime NULL;
IF COL_LENGTH('dbo.JiraIssues','ActivityPlannedEndDate') IS NULL ALTER TABLE dbo.JiraIssues ADD ActivityPlannedEndDate datetime NULL;
-- activityStartDate/activityEndDate mirror the Actual pair per the JS config comment.
IF COL_LENGTH('dbo.JiraIssues','ActivityStartDate') IS NULL ALTER TABLE dbo.JiraIssues ADD ActivityStartDate datetime NULL;
IF COL_LENGTH('dbo.JiraIssues','ActivityEndDate') IS NULL ALTER TABLE dbo.JiraIssues ADD ActivityEndDate datetime NULL;
IF COL_LENGTH('dbo.JiraIssues','ActivityResponsible') IS NULL ALTER TABLE dbo.JiraIssues ADD ActivityResponsible nvarchar(200) NULL;
IF COL_LENGTH('dbo.JiraIssues','Attachments') IS NULL ALTER TABLE dbo.JiraIssues ADD Attachments nvarchar(max) NULL;
IF COL_LENGTH('dbo.JiraIssues','StakeholderFields') IS NULL ALTER TABLE dbo.JiraIssues ADD StakeholderFields nvarchar(max) NULL;
GO
