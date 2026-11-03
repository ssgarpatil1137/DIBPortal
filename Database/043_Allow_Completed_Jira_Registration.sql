-- Run against the application database (e.g. DFM_PROD). Allows Jira issues in 'Completed' status to be registered.
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetJiraRegistrationCandidates @ProjectKey nvarchar(20), @AccountableExec nvarchar(200)
AS
BEGIN
 SET NOCOUNT ON;
 SELECT ParentJiraID, * FROM dbo.JiraIssues
 WHERE ProjectKey = @ProjectKey
   AND AccountableExec = @AccountableExec
   AND ISNULL(Status,'') NOT IN ('FAST TRACK. ADDL INFO REQUIRED','Doability – Addl.Info','DO - BRD PREPARATION - STRATEGIC','DO INCOMPLETE / ADD. INFO REQUIRED','Live – Pending Business Feedback','IT BP REVIEW','Demand On Hold','Deferred','Live','Tech No Capacity','Cancelled')
 ORDER BY JiraUpdated DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetJiraProjectPlan @ProjectKey nvarchar(20), @AccountableExec nvarchar(200)
AS
BEGIN
 SET NOCOUNT ON;
 SELECT * FROM dbo.JiraIssues WHERE ParentJiraID IN (
   SELECT JiraID FROM dbo.JiraIssues
   WHERE ProjectKey = @ProjectKey
     AND AccountableExec = @AccountableExec
     AND ISNULL(Status,'') NOT IN ('FAST TRACK. ADDL INFO REQUIRED','Doability – Addl.Info','DO - BRD PREPARATION - STRATEGIC','DO INCOMPLETE / ADD. INFO REQUIRED','Live – Pending Business Feedback','IT BP REVIEW','Demand On Hold','Deferred','Live','Tech No Capacity','Cancelled')
 )
 ORDER BY JiraUpdated DESC;
END;
GO
