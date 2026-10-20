SELECT JiraKey, ProjectKey, AccountableExec, Status,
  CASE WHEN ProjectKey = 'DMGT' THEN 'OK' ELSE 'BLOCKED' END AS ProjectKeyCheck,
  CASE WHEN AccountableExec = 'Zahoor Ul Islam (IT Dept)' THEN 'OK' ELSE 'BLOCKED' END AS ExecCheck,
  CASE WHEN ISNULL(Status,'') IN ('FAST TRACK. ADDL INFO REQUIRED','Doability – Addl.Info','DO - BRD PREPARATION - STRATEGIC',
       'DO INCOMPLETE / ADD. INFO REQUIRED','Live – Pending Business Feedback','IT BP REVIEW','Demand On Hold','Deferred',
       'Live','Tech No Capacity','Completed','Cancelled') THEN 'BLOCKED' ELSE 'OK' END AS StatusCheck
FROM dbo.JiraIssues
WHERE JiraKey = 'DMGT-XXXX'