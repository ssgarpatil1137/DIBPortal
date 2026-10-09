USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
-- Additive, idempotent: adds the JIRA fields present in the JIRA/PET Form CSV exports
-- (Title/Status/.../Comment 2) that had no matching dbo.JiraIssues column yet.
IF COL_LENGTH('dbo.JiraIssues','Labels') IS NULL ALTER TABLE dbo.JiraIssues ADD Labels nvarchar(500) NULL;
IF COL_LENGTH('dbo.JiraIssues','Resolution') IS NULL ALTER TABLE dbo.JiraIssues ADD Resolution nvarchar(100) NULL;
IF COL_LENGTH('dbo.JiraIssues','ProjectMethodology') IS NULL ALTER TABLE dbo.JiraIssues ADD ProjectMethodology nvarchar(200) NULL;
IF COL_LENGTH('dbo.JiraIssues','AssignedVerticalUnit') IS NULL ALTER TABLE dbo.JiraIssues ADD AssignedVerticalUnit nvarchar(200) NULL;
IF COL_LENGTH('dbo.JiraIssues','DagDecision') IS NULL ALTER TABLE dbo.JiraIssues ADD DagDecision nvarchar(200) NULL;
IF COL_LENGTH('dbo.JiraIssues','Stage') IS NULL ALTER TABLE dbo.JiraIssues ADD Stage nvarchar(100) NULL;
IF COL_LENGTH('dbo.JiraIssues','ItqaReview') IS NULL ALTER TABLE dbo.JiraIssues ADD ItqaReview nvarchar(200) NULL;
IF COL_LENGTH('dbo.JiraIssues','ReportingDashboard') IS NULL ALTER TABLE dbo.JiraIssues ADD ReportingDashboard nvarchar(200) NULL;
-- "Chief Mapping" is a distinct JIRA field from "Chief Name Mapping" (already ChiefNameMapping).
IF COL_LENGTH('dbo.JiraIssues','ChiefMapping') IS NULL ALTER TABLE dbo.JiraIssues ADD ChiefMapping nvarchar(200) NULL;
-- "Secondary Classification" is a distinct JIRA field from "Primary Classification" (already Primary_Classification/Classification).
IF COL_LENGTH('dbo.JiraIssues','SecondaryClassification') IS NULL ALTER TABLE dbo.JiraIssues ADD SecondaryClassification nvarchar(200) NULL;
IF COL_LENGTH('dbo.JiraIssues','Watchers') IS NULL ALTER TABLE dbo.JiraIssues ADD Watchers nvarchar(max) NULL;
IF COL_LENGTH('dbo.JiraIssues','RequestAssignee') IS NULL ALTER TABLE dbo.JiraIssues ADD RequestAssignee nvarchar(200) NULL;
IF COL_LENGTH('dbo.JiraIssues','Justification') IS NULL ALTER TABLE dbo.JiraIssues ADD Justification nvarchar(max) NULL;
IF COL_LENGTH('dbo.JiraIssues','JustificationEvidenceAttached') IS NULL ALTER TABLE dbo.JiraIssues ADD JustificationEvidenceAttached nvarchar(200) NULL;
IF COL_LENGTH('dbo.JiraIssues','Attachment1') IS NULL ALTER TABLE dbo.JiraIssues ADD Attachment1 nvarchar(500) NULL;
IF COL_LENGTH('dbo.JiraIssues','Attachment2') IS NULL ALTER TABLE dbo.JiraIssues ADD Attachment2 nvarchar(500) NULL;
IF COL_LENGTH('dbo.JiraIssues','DemandOriginalCreationDate') IS NULL ALTER TABLE dbo.JiraIssues ADD DemandOriginalCreationDate datetime NULL;
-- Execution-stage planned/actual date fields (Design/Development/UAT/Live), matching the CSV headers 1:1.
IF COL_LENGTH('dbo.JiraIssues','ProjectExecutionStart') IS NULL ALTER TABLE dbo.JiraIssues ADD ProjectExecutionStart datetime NULL;
IF COL_LENGTH('dbo.JiraIssues','ProjectExecutionEnd') IS NULL ALTER TABLE dbo.JiraIssues ADD ProjectExecutionEnd datetime NULL;
IF COL_LENGTH('dbo.JiraIssues','ItDeliveryDate') IS NULL ALTER TABLE dbo.JiraIssues ADD ItDeliveryDate datetime NULL;
IF COL_LENGTH('dbo.JiraIssues','UatSignOffDate') IS NULL ALTER TABLE dbo.JiraIssues ADD UatSignOffDate datetime NULL;
IF COL_LENGTH('dbo.JiraIssues','DesignPlannedStart') IS NULL ALTER TABLE dbo.JiraIssues ADD DesignPlannedStart datetime NULL;
IF COL_LENGTH('dbo.JiraIssues','DesignActualStart') IS NULL ALTER TABLE dbo.JiraIssues ADD DesignActualStart datetime NULL;
IF COL_LENGTH('dbo.JiraIssues','DesignActualEnd') IS NULL ALTER TABLE dbo.JiraIssues ADD DesignActualEnd datetime NULL;
IF COL_LENGTH('dbo.JiraIssues','DevelopmentPlannedStart') IS NULL ALTER TABLE dbo.JiraIssues ADD DevelopmentPlannedStart datetime NULL;
IF COL_LENGTH('dbo.JiraIssues','DevelopmentActualStart') IS NULL ALTER TABLE dbo.JiraIssues ADD DevelopmentActualStart datetime NULL;
IF COL_LENGTH('dbo.JiraIssues','DevelopmentPlannedEnd') IS NULL ALTER TABLE dbo.JiraIssues ADD DevelopmentPlannedEnd datetime NULL;
IF COL_LENGTH('dbo.JiraIssues','DevelopmentActualEnd') IS NULL ALTER TABLE dbo.JiraIssues ADD DevelopmentActualEnd datetime NULL;
IF COL_LENGTH('dbo.JiraIssues','UatPlannedStart') IS NULL ALTER TABLE dbo.JiraIssues ADD UatPlannedStart datetime NULL;
IF COL_LENGTH('dbo.JiraIssues','UatActualStart') IS NULL ALTER TABLE dbo.JiraIssues ADD UatActualStart datetime NULL;
IF COL_LENGTH('dbo.JiraIssues','UatPlannedEnd') IS NULL ALTER TABLE dbo.JiraIssues ADD UatPlannedEnd datetime NULL;
IF COL_LENGTH('dbo.JiraIssues','UatActualEnd') IS NULL ALTER TABLE dbo.JiraIssues ADD UatActualEnd datetime NULL;
IF COL_LENGTH('dbo.JiraIssues','LivePlannedStart') IS NULL ALTER TABLE dbo.JiraIssues ADD LivePlannedStart datetime NULL;
IF COL_LENGTH('dbo.JiraIssues','LiveActualStart') IS NULL ALTER TABLE dbo.JiraIssues ADD LiveActualStart datetime NULL;
IF COL_LENGTH('dbo.JiraIssues','LivePlannedEnd') IS NULL ALTER TABLE dbo.JiraIssues ADD LivePlannedEnd datetime NULL;
GO
