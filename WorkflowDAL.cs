using System;
using System.Data;
using System.Data.SqlClient;

namespace DFM_BPM.App_Code.DAL
{
    /// <summary>
    /// Data access for the PET workflow (local forms, not Oracle).
    /// Hierarchy: Project (BPM) → PET Form → PET Line Items → Approval → BPM CAM data
    /// </summary>
    public static class WorkflowDAL
    {
        // ===================================================================
        // PET FORM CRUD
        // ===================================================================

        public static DataTable GetPetForms(string createdBy = null, string status = null)
        {
            string sql = @"SELECT p.PetFormID, p.PetRefNo, p.ProjectID, p.CapexOpexType,
                                  p.BudgetSourceID, p.Title, p.Status, p.ReviewerUsername,
                                  p.ApproverUsername, p.Version, p.SubmittedDate,
                                  p.ReviewedDate, p.ApprovedDate, p.CreatedBy, p.CreatedDate,
                                  p.IsNonJiraProject, ISNULL(j.Summary, p.ProjectName) AS ProjectName
                           FROM dbo.PetForm p
                           LEFT JOIN dbo.JiraIssues j ON j.JiraID = p.ProjectID
                           WHERE 1=1";
            var ps = new System.Collections.Generic.List<System.Data.SqlClient.SqlParameter>();
            sql += " AND p.Status<>'Deleted'";
            if (!string.IsNullOrEmpty(createdBy)) { sql += " AND p.CreatedBy=@cb"; ps.Add(Db.P("@cb", createdBy)); }
            if (!string.IsNullOrEmpty(status))    { sql += " AND p.Status=@st";   ps.Add(Db.P("@st", status));    }
            sql += " ORDER BY p.PetFormID DESC";
            return Db.Query(sql, ps.ToArray());
        }

        /// <summary>Dashboard query with optional JIRA project / type / status / date / view filters.</summary>
        public static DataTable GetPetFormsDashboard(
            string jiraFilter, string typeFilter, string statusFilter,
            DateTime? fromDate, DateTime? toDate,
            string viewFilter = null, string viewUser = null)
        {
            string sql = @"SELECT p.PetFormID, p.PetRefNo, p.ProjectID, p.CapexOpexType,
                                  p.BudgetSourceID, p.Title, p.Status, p.CreatedBy,
                                  p.CreatedDate, p.ApproverUsername, p.SubmittedDate, p.Version,
                                  p.IsNonJiraProject, ISNULL(j.Summary, p.ProjectName) AS ProjectName,
                                  ISNULL((SELECT SUM(li.FinalAmtLCY) FROM dbo.PetLineItem li
                                          WHERE li.PetFormID=p.PetFormID),0) AS TotalRequestedAED
                           FROM dbo.PetForm p
                           LEFT JOIN dbo.JiraIssues j ON j.JiraID = p.ProjectID
                           WHERE 1=1";
            var ps = new System.Collections.Generic.List<System.Data.SqlClient.SqlParameter>();
            if (!string.IsNullOrEmpty(jiraFilter))  { sql += " AND p.ProjectID=@jp"; ps.Add(Db.P("@jp", jiraFilter)); }
            if (!string.IsNullOrEmpty(typeFilter))  { sql += " AND p.CapexOpexType=@tp"; ps.Add(Db.P("@tp", typeFilter)); }
            if (string.IsNullOrEmpty(statusFilter))
                sql += " AND p.Status<>'Deleted'";
            else
                { sql += " AND p.Status=@st"; ps.Add(Db.P("@st", statusFilter)); }
            if (fromDate.HasValue) { sql += " AND p.CreatedDate >= @fd"; ps.Add(Db.P("@fd", fromDate.Value)); }
            if (toDate.HasValue)   { sql += " AND p.CreatedDate < @td"; ps.Add(Db.P("@td", toDate.Value.Date.AddDays(1))); }
            if (viewFilter == "MYAPPROVAL" && !string.IsNullOrEmpty(viewUser))
            {
                sql += " AND ((p.ReviewerUsername=@vu AND p.Status='PendingReview')" +
                       " OR (p.ApproverUsername=@vu AND p.Status='PendingApproval'))";
                ps.Add(Db.P("@vu", viewUser));
            }
            else if (viewFilter == "MYREQUESTS" && !string.IsNullOrEmpty(viewUser))
            {
                sql += " AND p.CreatedBy=@vu";
                ps.Add(Db.P("@vu", viewUser));
            }
            sql += " ORDER BY p.PetFormID DESC";
            return Db.Query(sql, ps.ToArray());
        }


        public static DataTable GetPetFormsForApprover(string username)
        {
            return Db.Query(@"SELECT p.PetFormID, p.PetRefNo, p.ProjectID, p.Title, p.Status,
                                     p.CapexOpexType, p.CreatedBy, p.CreatedDate, p.SubmittedDate,
                                     p.IsNonJiraProject, ISNULL(j.Summary, p.ProjectName) AS ProjectName
                              FROM dbo.PetForm p
                              LEFT JOIN dbo.JiraIssues j ON j.JiraID = p.ProjectID
                                                            WHERE ((p.ReviewerUsername=@u AND p.Status='PendingReview')
                                                                    OR (p.ApproverUsername=@u AND p.Status='PendingApproval'))
                              ORDER BY p.PetFormID DESC",
                Db.P("@u", username));
        }

        public static DataRow GetPetForm(int petFormId)
        {
            return Db.QueryRow(@"SELECT p.*, ISNULL(j.Summary, p.ProjectName) AS EffectiveProjectName, j.Assignee AS ProjectManager
                                 FROM dbo.PetForm p
                                 LEFT JOIN dbo.JiraIssues j ON j.JiraID = p.ProjectID
                                 WHERE p.PetFormID=@id",
                Db.P("@id", petFormId));
        }

        public static int CreatePetForm(string projectId, string capexOpexType, string budgetSourceId,
                                        string title, string description, string reviewerUsername,
                                        string approverUsername, string createdBy,
                                        bool isNonJiraProject = false, string projectName = null)
        {
            return Convert.ToInt32(Db.Scalar(@"
                INSERT INTO dbo.PetForm
                    (ProjectID, CapexOpexType, BudgetSourceID, Title, Description,
                     ReviewerUsername, ApproverUsername, Status, CreatedBy, IsNonJiraProject, ProjectName)
                OUTPUT INSERTED.PetFormID
                VALUES
                    (@pid, @cot, @bsid, @ti, @de, @rev, @app, 'Draft', @cb, @nj, @pn)",
                Db.P("@pid", projectId), Db.P("@cot", capexOpexType),
                Db.P("@bsid", budgetSourceId ?? (object)DBNull.Value),
                Db.P("@ti", title ?? ""), Db.P("@de", description ?? ""),
                Db.P("@rev", reviewerUsername ?? (object)DBNull.Value),
                Db.P("@app", string.IsNullOrEmpty(approverUsername) ? (object)DBNull.Value : approverUsername),
                Db.P("@cb", createdBy), Db.P("@nj", isNonJiraProject),
                Db.P("@pn", string.IsNullOrEmpty(projectName) ? (object)DBNull.Value : projectName)));
        }

        public static int CreatePetFormWithLines(string projectId, string capexOpexType, string budgetSourceId,
                                        string title, string description, string reviewerUsername,
                                        string approverUsername, string createdBy,
                                        bool isNonJiraProject, string projectName, DataTable lines)
        {
            using (var connection = new SqlConnection(Db.ConnectionString))
            {
                connection.Open();
                using (var transaction = connection.BeginTransaction())
                {
                    try
                    {
                        int petFormId;
                        using (var command = new SqlCommand(@"
                            INSERT INTO dbo.PetForm
                                (ProjectID, CapexOpexType, BudgetSourceID, Title, Description,
                                 ReviewerUsername, ApproverUsername, Status, CreatedBy, IsNonJiraProject, ProjectName)
                            OUTPUT INSERTED.PetFormID
                            VALUES
                                (@pid, @cot, @bsid, @ti, @de, @rev, @app, 'Draft', @cb, @nj, @pn)", connection, transaction))
                        {
                            command.Parameters.AddRange(new[] {
                                Db.P("@pid", projectId),
                                Db.P("@cot", capexOpexType),
                                Db.P("@bsid", budgetSourceId ?? (object)DBNull.Value),
                                Db.P("@ti", title ?? ""),
                                Db.P("@de", description ?? ""),
                                Db.P("@rev", reviewerUsername ?? (object)DBNull.Value),
                                Db.P("@app", string.IsNullOrEmpty(approverUsername) ? (object)DBNull.Value : approverUsername),
                                Db.P("@cb", createdBy),
                                Db.P("@nj", isNonJiraProject),
                                Db.P("@pn", string.IsNullOrEmpty(projectName) ? (object)DBNull.Value : projectName)
                            });
                            petFormId = Convert.ToInt32(command.ExecuteScalar());
                        }

                        if (lines != null)
                        {
                            int serialNo = 1;
                            foreach (DataRow lineRow in lines.Rows)
                            {
                                using (var command = new SqlCommand(@"
                                    INSERT INTO dbo.PetLineItem
                                        (PetFormID, SerialNo, Department, ExpHead, Topic, VendorName, Description,
                                         CostType, Units, UnitPrice, BaseCurrency, AmtFCY, AmtLCY, ContingencyPct,
                                         FinalAmtLCY, GLNumber, Comments, CreatedBy)
                                    VALUES (@fid, @sn, @dep, @eh, @to, @vn, @de, @ct,
                                            @un, @up, @cu, @af, @al, @cp, @fl, @gl, @co, @cb)", connection, transaction))
                                {
                                    command.Parameters.AddRange(new[] {
                                        Db.P("@fid", petFormId),
                                        Db.P("@sn", serialNo++),
                                        Db.P("@dep", LineValue(lineRow, "Department")),
                                        Db.P("@eh", LineValue(lineRow, "ExpHead")),
                                        Db.P("@to", LineValue(lineRow, "Topic")),
                                        Db.P("@vn", LineValue(lineRow, "VendorName")),
                                        Db.P("@de", LineValue(lineRow, "Description")),
                                        Db.P("@ct", LineValue(lineRow, "CostType")),
                                        Db.P("@un", LineValue(lineRow, "Units")),
                                        Db.P("@up", LineValue(lineRow, "UnitPrice")),
                                        Db.P("@cu", LineValue(lineRow, "BaseCurrency")),
                                        Db.P("@af", LineValue(lineRow, "AmtFCY")),
                                        Db.P("@al", LineValue(lineRow, "AmtLCY")),
                                        Db.P("@cp", LineValue(lineRow, "ContingencyPct")),
                                        Db.P("@fl", LineValue(lineRow, "FinalAmtLCY")),
                                        Db.P("@gl", LineValue(lineRow, "GLNumber")),
                                        Db.P("@co", LineValue(lineRow, "Comments")),
                                        Db.P("@cb", createdBy)
                                    });
                                    command.ExecuteNonQuery();
                                }
                            }
                        }

                        transaction.Commit();
                        return petFormId;
                    }
                    catch
                    {
                        transaction.Rollback();
                        throw;
                    }
                }
            }
        }

        private static object LineValue(DataRow row, string columnName)
        {
            if (row == null || !row.Table.Columns.Contains(columnName) || row[columnName] == DBNull.Value)
                return DBNull.Value;
            return row[columnName];
        }

        public static void UpdatePetForm(int petFormId, string projectId, string capexOpexType,
                                         string budgetSourceId, string title, string description,
                                         string reviewerUsername, string approverUsername, string modifiedBy,
                                         bool isNonJiraProject = false, string projectName = null)
        {
            Db.Exec(@"UPDATE dbo.PetForm SET ProjectID=@pid, CapexOpexType=@cot, BudgetSourceID=@bsid,
                      Title=@ti, Description=@de, ReviewerUsername=@rev, ApproverUsername=@app,
                      IsNonJiraProject=@nj, ProjectName=@pn,
                      ModifiedBy=@mb, ModifiedDate=GETDATE()
                      WHERE PetFormID=@id AND Status='Draft'",
                Db.P("@pid", projectId), Db.P("@cot", capexOpexType),
                Db.P("@bsid", budgetSourceId ?? (object)DBNull.Value),
                Db.P("@ti", title ?? ""), Db.P("@de", description ?? ""),
                Db.P("@rev", reviewerUsername ?? (object)DBNull.Value),
                Db.P("@app", string.IsNullOrEmpty(approverUsername) ? (object)DBNull.Value : approverUsername),
                Db.P("@nj", isNonJiraProject),
                Db.P("@pn", string.IsNullOrEmpty(projectName) ? (object)DBNull.Value : projectName),
                Db.P("@mb", modifiedBy), Db.P("@id", petFormId));
        }

        /// <summary>Status values for which a Spend Request may still be deleted (soft delete) — once
        /// Approved (or Rejected/SentBack/Deleted) it can no longer be removed. Shared by PetWorkflow.aspx's
        /// own Delete button and Default.aspx's per-row Delete buttons so the rule stays consistent.</summary>
        public static bool IsPetDeletable(string status)
        {
            return status == "Draft" || status == "PendingReview" || status == "PendingApproval";
        }

        // ===================================================================
        // PET LINE ITEMS
        // ===================================================================

        public static DataTable GetPetLines(int petFormId)
        {
            return Db.Query(@"SELECT LineID, SerialNo, Department, ExpHead, Topic, VendorName,
                                     Description, CostType, Units, UnitPrice, BaseCurrency,
                                     AmtFCY, AmtLCY, ContingencyPct, FinalAmtLCY, GLNumber, Comments
                              FROM dbo.PetLineItem WHERE PetFormID=@id ORDER BY SerialNo",
                Db.P("@id", petFormId));
        }

        public static int SavePetLine(int petFormId, int serialNo, string dept, string expHead,
                                       string topic, string vendor, string description, string costType,
                                       decimal units, decimal unitPrice, string currency,
                                       decimal amtFcy, decimal amtLcy, decimal contingencyPct,
                                       decimal finalAmtLcy, string glNumber, string comments, string createdBy)
        {
            return Convert.ToInt32(Db.Scalar(@"
                INSERT INTO dbo.PetLineItem
                    (PetFormID, SerialNo, Department, ExpHead, Topic, VendorName, Description,
                     CostType, Units, UnitPrice, BaseCurrency, AmtFCY, AmtLCY, ContingencyPct,
                     FinalAmtLCY, GLNumber, Comments, CreatedBy)
                OUTPUT INSERTED.LineID
                VALUES (@fid, @sn, @dep, @eh, @to, @vn, @de, @ct,
                        @un, @up, @cu, @af, @al, @cp, @fl, @gl, @co, @cb)",
                Db.P("@fid", petFormId), Db.P("@sn", serialNo), Db.P("@dep", dept ?? ""),
                Db.P("@eh", expHead ?? ""), Db.P("@to", topic ?? ""), Db.P("@vn", vendor ?? ""),
                Db.P("@de", description ?? ""), Db.P("@ct", costType ?? ""),
                Db.P("@un", units), Db.P("@up", unitPrice), Db.P("@cu", currency ?? "AED"),
                Db.P("@af", amtFcy), Db.P("@al", amtLcy), Db.P("@cp", contingencyPct),
                Db.P("@fl", finalAmtLcy), Db.P("@gl", glNumber ?? (object)DBNull.Value),
                Db.P("@co", comments ?? ""), Db.P("@cb", createdBy)));
        }

        public static void DeletePetLine(int lineId)
        {
            Db.Exec("DELETE FROM dbo.PetLineItem WHERE LineID=@id", Db.P("@id", lineId));
        }

        public static void UpdatePetLine(int lineId, string dept, string expHead,
            string topic, string vendor, string description, string costType,
            decimal units, decimal unitPrice, string currency,
            decimal amtFcy, decimal amtLcy, decimal contingencyPct, decimal finalAmtLcy,
            string glNumber, string comments, string modifiedBy)
        {
            Db.Exec(@"UPDATE dbo.PetLineItem
                      SET Department=@dep, ExpHead=@eh, Topic=@to, VendorName=@vn,
                          Description=@de, CostType=@ct, Units=@un, UnitPrice=@up,
                          BaseCurrency=@cu, AmtFCY=@af, AmtLCY=@al, ContingencyPct=@cp,
                          FinalAmtLCY=@fl, GLNumber=@gl, Comments=@co
                      WHERE LineID=@id",
                Db.P("@dep", dept ?? ""), Db.P("@eh", expHead ?? ""), Db.P("@to", topic ?? ""),
                Db.P("@vn", vendor ?? ""), Db.P("@de", description ?? ""), Db.P("@ct", costType ?? ""),
                Db.P("@un", units), Db.P("@up", unitPrice), Db.P("@cu", currency ?? "AED"),
                Db.P("@af", amtFcy), Db.P("@al", amtLcy), Db.P("@cp", contingencyPct),
                Db.P("@fl", finalAmtLcy), Db.P("@gl", glNumber ?? (object)DBNull.Value),
                Db.P("@co", comments ?? ""), Db.P("@id", lineId));
        }

        // ===================================================================
        // WORKFLOW ACTIONS
        // ===================================================================

        public static void DeletePetForm(int petFormId, string deletedBy)
        {
            DataRow f = GetPetForm(petFormId);
            if (f == null) return;
            string fromStatus = f["Status"] == DBNull.Value ? "" : f["Status"].ToString();
            Db.Exec(@"UPDATE dbo.PetForm SET Status='Deleted', ModifiedBy=@by, ModifiedDate=GETDATE() WHERE PetFormID=@id",
                Db.P("@by", deletedBy), Db.P("@id", petFormId));
            LogHistory(petFormId, "Deleted", deletedBy, fromStatus, "Deleted", "PET form deleted by requestor.");
        }

        public static void SubmitPet(int petFormId, string actionBy, string comments)
        {
            DataRow f = GetPetForm(petFormId);
            if (f == null) return;

            string reviewer = f["ReviewerUsername"] == DBNull.Value ? null : f["ReviewerUsername"].ToString();
            string newStatus = string.IsNullOrEmpty(reviewer) ? "PendingApproval" : "PendingReview";

            Db.Exec(@"UPDATE dbo.PetForm SET Status=@s, SubmittedDate=GETDATE(), Version=Version+1,
                      ModifiedBy=@by, ModifiedDate=GETDATE() WHERE PetFormID=@id",
                Db.P("@s", newStatus), Db.P("@by", actionBy), Db.P("@id", petFormId));

            LogHistory(petFormId, "Submit", actionBy, "Draft", newStatus, comments);

            // Email notification — actioner (requestor) is sender; To = reviewer or approver; CC = requestor
            try
            {
                string toUser  = string.IsNullOrEmpty(reviewer) ? f["ApproverUsername"].ToString() : reviewer;
                string ccUser  = f["CreatedBy"].ToString();
                string toEmail = DFM_BPM.App_Code.DAL.EmailDAL.GetUserEmail(toUser);
                string ccEmail = DFM_BPM.App_Code.DAL.EmailDAL.GetUserEmail(ccUser);
                if (!string.IsNullOrEmpty(toEmail))
                {
                    DataRow[] lines   = GetPetLines(petFormId).Select();
                    DataRow[] history = GetHistory(petFormId).Select();
                    string body = DFM_BPM.App_Code.Helpers.EmailHelper.BuildPetEmailBody(
                        "PET Submitted — Action Required",
                        actionBy, comments, f, lines, history);
                    string subj = string.Format("PET Submitted: {0}", f["PetRefNo"]);
                    DFM_BPM.App_Code.Helpers.EmailHelper.SendPetEmail("Submit", petFormId, toEmail, ccEmail ?? "", subj, body, actionBy);
                }
            }
            catch { /* email failure must not break workflow */ }

            // Legacy in-app notification
            string target = string.IsNullOrEmpty(reviewer) ? f["ApproverUsername"].ToString() : reviewer;
            string url = "~/Forms/PetWorkflow.aspx?id=" + petFormId;
            UserDAL.SendNotification(target, "PET Pending: " + f["PetRefNo"],
                "A new PET has been submitted for your action.", url, petFormId, "ApprovalRequest");
        }

        public static void ReviewPet(int petFormId, string actionBy, string decision, string comments)
        {
            // decision: Approve (send to approver) | SentBack (return to requestor)
            DataRow f = GetPetForm(petFormId);
            if (f == null) return;
            string newStatus = decision == "Approve" ? "PendingApproval" : "SentBack";

            Db.Exec(@"UPDATE dbo.PetForm SET Status=@s, ReviewedDate=GETDATE(), ReviewComments=@rc,
                      ModifiedBy=@by, ModifiedDate=GETDATE() WHERE PetFormID=@id",
                Db.P("@s", newStatus), Db.P("@rc", comments ?? ""),
                Db.P("@by", actionBy), Db.P("@id", petFormId));

            LogHistory(petFormId, "Review_" + decision, actionBy, "PendingReview", newStatus, comments);

            // Email notification — actioner = reviewer; To = next step owner; CC = others
            try
            {
                string toUser  = decision == "Approve" ? f["ApproverUsername"].ToString() : f["CreatedBy"].ToString();
                string ccUsers = decision == "Approve"
                    ? f["CreatedBy"].ToString() + "," + actionBy
                    : actionBy;
                string toEmail = DFM_BPM.App_Code.DAL.EmailDAL.GetUserEmail(toUser);
                if (!string.IsNullOrEmpty(toEmail))
                {
                    string ccEmail = BuildCcList(ccUsers);
                    DataRow[] lines   = GetPetLines(petFormId).Select();
                    DataRow[] history = GetHistory(petFormId).Select();
                    string eventTitle = decision == "Approve"
                        ? "PET Reviewed — Pending Approval"
                        : "PET Sent Back to Requestor";
                    string body = DFM_BPM.App_Code.Helpers.EmailHelper.BuildPetEmailBody(eventTitle, actionBy, comments, f, lines, history);
                    string subj = string.Format("{0}: {1}", eventTitle, f["PetRefNo"]);
                    DFM_BPM.App_Code.Helpers.EmailHelper.SendPetEmail("Review_" + decision, petFormId, toEmail, ccEmail, subj, body, actionBy);
                }
            }
            catch { /* email failure must not break workflow */ }

            string target = decision == "Approve"
                ? f["ApproverUsername"].ToString()
                : f["CreatedBy"].ToString();
            UserDAL.SendNotification(target, "PET " + (decision == "Approve" ? "Ready for Approval" : "Sent Back") + ": " + f["PetRefNo"],
                comments, "~/Forms/PetWorkflow.aspx?id=" + petFormId, petFormId,
                decision == "Approve" ? "ApprovalRequest" : "RouteBack");
        }

        public static void ApprovePet(int petFormId, string actionBy, string decision, string comments)
        {
            // decision: Approved | Rejected | SentBack
            DataRow f = GetPetForm(petFormId);
            if (f == null) return;
            string newStatus = decision == "Approved" ? "Approved"
                             : decision == "Rejected" ? "Rejected" : "SentBack";

            Db.Exec(@"UPDATE dbo.PetForm SET Status=@s, ApprovedDate=GETDATE(), ApprovalComments=@ac,
                      ModifiedBy=@by, ModifiedDate=GETDATE() WHERE PetFormID=@id",
                Db.P("@s", newStatus), Db.P("@ac", comments ?? ""),
                Db.P("@by", actionBy), Db.P("@id", petFormId));

            LogHistory(petFormId, "Approve_" + decision, actionBy, "PendingApproval", newStatus, comments);

            // Lock budget amount in CAPEX/OPEX master when approved
            if (newStatus == "Approved")
            {
                string budgetType = f["CapexOpexType"] == DBNull.Value ? null : f["CapexOpexType"].ToString();
                string sourceId   = f["BudgetSourceID"] == DBNull.Value ? null : f["BudgetSourceID"].ToString();
                decimal amt = Convert.ToDecimal(Db.Scalar(
                    "SELECT ISNULL(SUM(FinalAmtLCY),0) FROM dbo.PetLineItem WHERE PetFormID=@p",
                    Db.P("@p", petFormId)));
                if (!string.IsNullOrEmpty(budgetType) && !string.IsNullOrEmpty(sourceId) && amt > 0m)
                {
                    if (budgetType == "CAPEX")
                    {
                        MastersDAL.ArchiveCapexHistory(sourceId, actionBy);
                        Db.Exec(@"UPDATE dbo.CapexMaster
                                  SET LockedAmount = ISNULL(LockedAmount,0) + @amt,
                                      BudgetAfterLockedAmount = ISNULL(BudgetedAmount,0) - (ISNULL(LockedAmount,0) + @amt),
                                      NetBalance = ISNULL(AvailableAmount,0) - (ISNULL(LockedAmount,0) + @amt),
                                      ModifiedBy=@by, ModifiedDate=GETDATE()
                                  WHERE CapexID=@id",
                            Db.P("@amt", amt), Db.P("@by", actionBy), Db.P("@id", sourceId));
                    }
                    else if (budgetType == "OPEX")
                    {
                        MastersDAL.ArchiveOpexHistory(sourceId, actionBy);
                        Db.Exec(@"UPDATE dbo.OpexMaster
                                  SET LockedAmount = ISNULL(LockedAmount,0) + @amt,
                                      BudgetAfterLockedAmount = ISNULL(BudgetedAmount,0) - (ISNULL(LockedAmount,0) + @amt),
                                      NetBalance = ISNULL(AvailableAmount,0) - (ISNULL(LockedAmount,0) + @amt),
                                      ModifiedBy=@by, ModifiedDate=GETDATE()
                                  WHERE OpexID=@id",
                            Db.P("@amt", amt), Db.P("@by", actionBy), Db.P("@id", sourceId));
                    }
                }
            }

            UserDAL.SendNotification(f["CreatedBy"].ToString(),
                "PET " + decision + ": " + f["PetRefNo"], comments,
                "~/Forms/PetWorkflow.aspx?id=" + petFormId, petFormId, decision);

            // Email notification — actioner = approver; To = requestor; CC = approver (+ reviewer if set)
            try
            {
                string toUser  = f["CreatedBy"].ToString();
                string ccUsers = actionBy;
                string reviewer2 = f["ReviewerUsername"] == DBNull.Value ? null : f["ReviewerUsername"].ToString();
                if (!string.IsNullOrEmpty(reviewer2)) ccUsers += "," + reviewer2;
                string toEmail = DFM_BPM.App_Code.DAL.EmailDAL.GetUserEmail(toUser);
                if (!string.IsNullOrEmpty(toEmail))
                {
                    string ccEmail = BuildCcList(ccUsers);
                    DataRow[] lines   = GetPetLines(petFormId).Select();
                    DataRow[] history = GetHistory(petFormId).Select();
                    string eventTitle = decision == "Approved" ? "PET Approved"
                                      : decision == "Rejected" ? "PET Rejected"
                                      : "PET Sent Back for Revision";
                    string body = DFM_BPM.App_Code.Helpers.EmailHelper.BuildPetEmailBody(eventTitle, actionBy, comments, f, lines, history);
                    string subj = string.Format("{0}: {1}", eventTitle, f["PetRefNo"]);
                    DFM_BPM.App_Code.Helpers.EmailHelper.SendPetEmail("Approve_" + decision, petFormId, toEmail, ccEmail, subj, body, actionBy);
                }
            }
            catch { /* email failure must not break workflow */ }
        }

        public static void LogHistory(int petFormId, string action, string actionBy, string from, string to, string comments)
        {
            Db.Exec(@"INSERT INTO dbo.PetWorkflowHistory(PetFormID, Action, ActionBy, FromStatus, ToStatus, Comments)
                      VALUES(@f, @a, @by, @fs, @ts, @c)",
                Db.P("@f", petFormId), Db.P("@a", action), Db.P("@by", actionBy),
                Db.P("@fs", from), Db.P("@ts", to), Db.P("@c", comments ?? ""));
        }

        public static DataTable GetHistory(int petFormId)
        {
            return Db.Query(@"SELECT Action, ActionBy, ActionDate, FromStatus, ToStatus, Comments
                              FROM dbo.PetWorkflowHistory WHERE PetFormID=@id ORDER BY HistID",
                Db.P("@id", petFormId));
        }

        // Resolve a comma-separated list of usernames into a comma-separated list of emails.
        private static string BuildCcList(string usernamesCsv)
        {
            if (string.IsNullOrEmpty(usernamesCsv)) return "";
            var parts = usernamesCsv.Split(new[] { ',', ';' }, StringSplitOptions.RemoveEmptyEntries);
            var emails = new System.Collections.Generic.List<string>();
            foreach (string u in parts)
            {
                string e = EmailDAL.GetUserEmail(u.Trim());
                if (!string.IsNullOrEmpty(e)) emails.Add(e);
            }
            return string.Join(",", emails.ToArray());
        }

        // ===================================================================
        // BPM CAM HIERARCHY (from Oracle-synced data)
        // ===================================================================

        public static DataSet GetHierarchy(string projectId)
        {
            return Db.QuerySPMulti("dbo.sp_GetHierarchy",
                Db.P("@ProjectID", projectId ?? (object)DBNull.Value));
        }

        public static DataTable GetBPMPetForProject(string projectId)
        {
            return Db.Query(@"SELECT PETReferenceNo, Description, PETApprovedAmt, BPMLockedAmount,
                                     Utilized, Balance, ProjectID
                              FROM dbo.BPM_PET WHERE ProjectID=@p ORDER BY PETReferenceNo",
                Db.P("@p", projectId));
        }

        public static DataTable GetLPOForProject(string projectId)
        {
            return Db.Query(@"SELECT l.WiName, l.LPONo, l.LPODesc, l.VendorName, l.LCAmount,
                                     l.LPOStatus, l.BudgetAmount, l.AvailableBalance, l.GLNumber
                              FROM dbo.BPM_LPO l
                              INNER JOIN dbo.GLMaster g ON l.GLNumber = g.GLNumber
                              INNER JOIN dbo.BPM_Projects p ON p.CapexID LIKE '%' + g.GLNumber + '%'
                              WHERE p.ProjectID = @pid",
                Db.P("@pid", projectId));
        }

        public static DataTable GetInvoiceForLPO(string lpoNo)
        {
            return Db.Query(@"SELECT WiName, InvoiceNumber, InvoiceType, VendorName,
                                     LCAmount, AMSInvoiceStatus, InvoiceDate
                              FROM dbo.BPM_Invoice WHERE InvoiceRefNo=@n ORDER BY InvoiceDate",
                Db.P("@n", lpoNo));
        }

        // ===================================================================
        // CAPEX/OPEX amounts for a project
        // ===================================================================

        public static DataTable GetCapexAmountsForProject(string projectId)
        {
            return Db.Query(@"SELECT cod.ItemID, cod.ItemDescription, SUM(cod.BudgetedAmount) AS BudgetedAmount,
                                     SUM(cod.UtilizedAmount) AS UtilizedAmount, SUM(cod.LockedAmount) AS LockedAmount,
                                     SUM(cod.AvailableAmount) AS AvailableAmount, SUM(cod.ClaimAmount) AS ClaimAmount
                              FROM dbo.BPM_CapexOpexDetails cod
                              WHERE cod.ProjectID = @pid AND cod.ItemType = 'Capex'
                              GROUP BY cod.ItemID, cod.ItemDescription ORDER BY cod.ItemID",
                Db.P("@pid", projectId));
        }

        public static DataTable GetOpexAmountsForProject(string projectId)
        {
            return Db.Query(@"SELECT cod.ItemID, cod.ItemDescription, SUM(cod.BudgetedAmount) AS BudgetedAmount,
                                     SUM(cod.UtilizedAmount) AS UtilizedAmount, SUM(cod.LockedAmount) AS LockedAmount,
                                     SUM(cod.AvailableAmount) AS AvailableAmount, SUM(cod.ClaimAmount) AS ClaimAmount
                              FROM dbo.BPM_CapexOpexDetails cod
                              WHERE cod.ProjectID = @pid AND cod.ItemType = 'Opex'
                              GROUP BY cod.ItemID, cod.ItemDescription ORDER BY cod.ItemID",
                Db.P("@pid", projectId));
        }

        public static DataTable GetGLAmountsForProject(string projectId)
        {
            return Db.Query(@"SELECT g.GLNumber, g.GLDescription, g.BudgetedAmount,
                                     g.BPMLockedAmount, g.AMSLockedAmount, g.UtilizedAmount, g.BalanceAmount
                              FROM dbo.GLMaster g
                              INNER JOIN dbo.BPM_Projects p ON p.CapexID LIKE '%' + g.GLNumber + '%'
                              WHERE p.ProjectID = @pid",
                Db.P("@pid", projectId));
        }

        // ===================================================================
        // Attachments
        // ===================================================================
        public static void SaveAttachment(int petFormId, string fileName, string contentType, byte[] content, string uploadedBy)
        {
            Db.Exec(@"INSERT INTO dbo.PetAttachments(PetFormID, FileName, ContentType, FileContent, UploadedBy)
                      VALUES(@f, @fn, @ct, @fc, @by)",
                Db.P("@f",  petFormId),
                Db.P("@fn", fileName),
                Db.P("@ct", contentType),
                Db.P("@fc", content),
                Db.P("@by", uploadedBy));
        }

        public static DataTable GetAttachments(int petFormId)
        {
            return Db.Query(
                "SELECT AttachmentID, FileName, ContentType, UploadedBy, UploadedAt FROM dbo.PetAttachments WHERE PetFormID=@f ORDER BY UploadedAt",
                Db.P("@f", petFormId));
        }

        public static byte[] DownloadAttachment(int attachmentId, out string fileName, out string contentType)
        {
            DataRow r = Db.QueryRow(
                "SELECT FileName, ContentType, FileContent FROM dbo.PetAttachments WHERE AttachmentID=@id",
                Db.P("@id", attachmentId));
            if (r == null) { fileName = ""; contentType = "application/octet-stream"; return null; }
            fileName    = r["FileName"].ToString();
            contentType = r["ContentType"] != DBNull.Value ? r["ContentType"].ToString() : "application/octet-stream";
            return (byte[])r["FileContent"];
        }

        public static void DeleteAttachment(int attachmentId)
        {
            Db.Exec("DELETE FROM dbo.PetAttachments WHERE AttachmentID=@id", Db.P("@id", attachmentId));
        }

        public static DataTable GetInvoicesForProject(string projectId)
        {
            return Db.Query(@"SELECT i.WiName AS EFormNo, i.InvoiceNumber, i.InvoiceType, i.VendorName,
                                     i.LCAmount, i.AMSInvoiceStatus, i.InvoiceDate
                              FROM dbo.BPM_Invoice i
                              WHERE i.WiName IN (
                                  SELECT l.WiName FROM dbo.BPM_LPO l
                                  INNER JOIN dbo.GLMaster g ON l.GLNumber = g.GLNumber
                                  INNER JOIN dbo.BPM_Projects p ON p.CapexID LIKE '%' + g.GLNumber + '%'
                                  WHERE p.ProjectID = @pid)
                              ORDER BY i.InvoiceDate DESC",
                Db.P("@pid", projectId));
        }

        // ===================================================================
        // BUDGET LINE ITEMS  (added by Requestor once a PET is Approved)
        // ===================================================================

        public static DataTable GetBudgetLines(int petFormId)
        {
            return Db.Query(@"SELECT bl.BudgetLineID, bl.PetFormID, bl.SerialNo, bl.VendorName, bl.Justification,
                                     bl.Cost, bl.Currency, bl.GLNumber, bl.PetRef, bl.CamId, bl.CamStatus,
                                     bl.CamComments, bl.LpoRequest, bl.LpoStatus, bl.LpoComments,
                                     bl.CreatedBy, bl.CreatedDate,
                                     ISNULL((SELECT COUNT(*) FROM dbo.PetBudgetInvoice i WHERE i.BudgetLineID=bl.BudgetLineID),0) AS InvoiceCount,
                                     ISNULL((SELECT SUM(i.InvoiceAmount) FROM dbo.PetBudgetInvoice i WHERE i.BudgetLineID=bl.BudgetLineID),0) AS InvoiceTotal
                              FROM dbo.PetBudgetLine bl
                              WHERE bl.PetFormID=@id
                              ORDER BY bl.SerialNo",
                Db.P("@id", petFormId));
        }

        public static DataRow GetBudgetLine(int budgetLineId)
        {
            return Db.QueryRow("SELECT * FROM dbo.PetBudgetLine WHERE BudgetLineID=@id", Db.P("@id", budgetLineId));
        }

        public static int SaveBudgetLine(int petFormId, int serialNo, string vendor, string justification,
            decimal cost, string currency, string glNumber, string petRef, string camId, string camStatus,
            string camComments, string lpoRequest, string lpoStatus, string lpoComments, string createdBy)
        {
            return Convert.ToInt32(Db.Scalar(@"
                INSERT INTO dbo.PetBudgetLine
                    (PetFormID, SerialNo, VendorName, Justification, Cost, Currency, GLNumber, PetRef,
                     CamId, CamStatus, CamComments, LpoRequest, LpoStatus, LpoComments, CreatedBy)
                OUTPUT INSERTED.BudgetLineID
                VALUES (@fid, @sn, @vn, @ju, @co, @cu, @gl, @pr, @ci, @cs, @cc, @lr, @ls, @lc, @cb)",
                Db.P("@fid", petFormId), Db.P("@sn", serialNo), Db.P("@vn", vendor ?? ""), Db.P("@ju", justification ?? ""),
                Db.P("@co", cost), Db.P("@cu", currency ?? "AED"), Db.P("@gl", glNumber ?? (object)DBNull.Value),
                Db.P("@pr", petRef ?? ""), Db.P("@ci", camId ?? ""), Db.P("@cs", camStatus ?? ""),
                Db.P("@cc", camComments ?? ""), Db.P("@lr", lpoRequest ?? ""), Db.P("@ls", lpoStatus ?? ""),
                Db.P("@lc", lpoComments ?? ""), Db.P("@cb", createdBy)));
        }

        public static void UpdateBudgetLine(int budgetLineId, string vendor, string justification,
            decimal cost, string currency, string glNumber, string petRef, string camId, string camStatus,
            string camComments, string lpoRequest, string lpoStatus, string lpoComments, string modifiedBy)
        {
            Db.Exec(@"UPDATE dbo.PetBudgetLine
                      SET VendorName=@vn, Justification=@ju, Cost=@co, Currency=@cu, GLNumber=@gl,
                          PetRef=@pr, CamId=@ci, CamStatus=@cs, CamComments=@cc,
                          LpoRequest=@lr, LpoStatus=@ls, LpoComments=@lc,
                          ModifiedBy=@mb, ModifiedDate=GETDATE()
                      WHERE BudgetLineID=@id",
                Db.P("@vn", vendor ?? ""), Db.P("@ju", justification ?? ""), Db.P("@co", cost),
                Db.P("@cu", currency ?? "AED"), Db.P("@gl", glNumber ?? (object)DBNull.Value),
                Db.P("@pr", petRef ?? ""), Db.P("@ci", camId ?? ""), Db.P("@cs", camStatus ?? ""),
                Db.P("@cc", camComments ?? ""), Db.P("@lr", lpoRequest ?? ""), Db.P("@ls", lpoStatus ?? ""),
                Db.P("@lc", lpoComments ?? ""), Db.P("@mb", modifiedBy ?? ""), Db.P("@id", budgetLineId));
        }

        public static void DeleteBudgetLine(int budgetLineId)
        {
            Db.Exec("DELETE FROM dbo.PetBudgetInvoice WHERE BudgetLineID=@id", Db.P("@id", budgetLineId));
            Db.Exec("DELETE FROM dbo.PetBudgetLine WHERE BudgetLineID=@id", Db.P("@id", budgetLineId));
        }

        /// <summary>All budget lines created by a given user, across all their PET forms (for Default.aspx).</summary>
        public static DataTable GetBudgetLinesByUser(string username)
        {
            return Db.Query(@"SELECT bl.BudgetLineID, bl.PetFormID, p.PetRefNo, bl.VendorName, bl.Justification,
                                     bl.Cost, bl.Currency, bl.GLNumber, bl.CamStatus, bl.LpoStatus, bl.CreatedDate,
                                     ISNULL((SELECT SUM(i.InvoiceAmount) FROM dbo.PetBudgetInvoice i WHERE i.BudgetLineID=bl.BudgetLineID),0) AS InvoiceTotal
                              FROM dbo.PetBudgetLine bl
                              INNER JOIN dbo.PetForm p ON p.PetFormID = bl.PetFormID
                              WHERE p.CreatedBy=@u
                              ORDER BY bl.BudgetLineID DESC",
                Db.P("@u", username));
        }

        /// <summary>All PET line items across all PET forms for a given Project (including Draft).</summary>
        public static DataTable GetPetLinesByProject(string projectId)
        {
            return Db.Query(@"SELECT li.LineID, li.SerialNo, li.ExpHead, li.Topic, li.VendorName,
                                     li.CostType, li.Units, li.UnitPrice, li.BaseCurrency,
                                     li.AmtFCY, li.AmtLCY, li.ContingencyPct, li.FinalAmtLCY,
                                     li.GLNumber, p.PetRefNo, p.PetFormID
                              FROM dbo.PetLineItem li
                              INNER JOIN dbo.PetForm p ON p.PetFormID = li.PetFormID
                              WHERE p.ProjectID=@pid AND p.Status<>'Deleted'
                              ORDER BY p.PetFormID, li.SerialNo",
                Db.P("@pid", projectId));
        }

        /// <summary>All budget lines raised against any PET form under a given Project (the Project is the main item).</summary>
        public static DataTable GetBudgetLinesByProject(string projectId)
        {
            return Db.Query(@"SELECT bl.BudgetLineID, bl.PetFormID, bl.SerialNo, p.PetRefNo, bl.VendorName, bl.Justification,
                                     bl.Cost, bl.Currency, bl.GLNumber, bl.PetRef, bl.CamId, bl.CamStatus,
                                     bl.CamComments, bl.LpoRequest, bl.LpoStatus, bl.LpoComments, bl.CreatedDate,
                                     ISNULL((SELECT COUNT(*) FROM dbo.PetBudgetInvoice i WHERE i.BudgetLineID=bl.BudgetLineID),0) AS InvoiceCount,
                                     ISNULL((SELECT SUM(i.InvoiceAmount) FROM dbo.PetBudgetInvoice i WHERE i.BudgetLineID=bl.BudgetLineID),0) AS InvoiceTotal
                              FROM dbo.PetBudgetLine bl
                              INNER JOIN dbo.PetForm p ON p.PetFormID = bl.PetFormID
                              WHERE p.ProjectID=@pid AND p.Status<>'Deleted'
                              ORDER BY bl.BudgetLineID DESC",
                Db.P("@pid", projectId));
        }

        /// <summary>All invoices raised against any PET form under a given Project (the Project is the main item).</summary>
        public static DataTable GetInvoicesByProject(string projectId)
        {
            return Db.Query(@"SELECT i.InvoiceID, i.InvoiceNo, i.InvoiceAmount, i.InvoiceStatus, i.PaymentDate,
                                     bl.BudgetLineID, bl.VendorName, bl.Justification, bl.GLNumber, p.PetFormID, p.PetRefNo
                              FROM dbo.PetBudgetInvoice i
                              INNER JOIN dbo.PetBudgetLine bl ON bl.BudgetLineID = i.BudgetLineID
                              INNER JOIN dbo.PetForm p ON p.PetFormID = bl.PetFormID
                              WHERE p.ProjectID=@pid AND p.Status<>'Deleted'
                              ORDER BY i.InvoiceID DESC",
                Db.P("@pid", projectId));
        }

        public static DataTable GetProjectBudgetTracker(string projectId)
        {
            return Db.Query(@"SELECT bl.BudgetLineID,
                                     bl.VendorName AS Vendor,
                                     bl.Justification,
                                     bl.Cost,
                                     bl.Currency,
                                     bl.GLNumber,
                                     COALESCE(NULLIF(bl.PetRef,''), p.PetRefNo, '') AS PetID,
                                     bl.CamId,
                                     bl.CamStatus,
                                     bl.CamComments,
                                     bl.LpoRequest,
                                     bl.LpoStatus,
                                     bl.LpoComments,
                                     i.InvoiceNo,
                                     i.InvoiceAmount,
                                     i.InvoiceStatus,
                                     i.PaymentDate
                              FROM dbo.PetBudgetLine bl
                              INNER JOIN dbo.PetForm p ON p.PetFormID = bl.PetFormID
                              LEFT JOIN dbo.PetBudgetInvoice i ON i.BudgetLineID = bl.BudgetLineID
                              WHERE p.ProjectID=@pid AND p.Status<>'Deleted'
                              ORDER BY bl.BudgetLineID DESC, i.InvoiceID DESC",
                Db.P("@pid", projectId));
        }

        public static DataRow GetProjectFinancialSummary(string projectId)
        {
            return Db.QueryRow(@"SELECT
                    ISNULL((SELECT SUM(li.FinalAmtLCY)
                        FROM dbo.PetLineItem li
                        INNER JOIN dbo.PetForm p ON p.PetFormID = li.PetFormID
                        WHERE p.ProjectID=@pid AND p.Status='Approved'),0) AS ApprovedSpendRequestTotal,
                    ISNULL((SELECT SUM(bl.Cost)
                        FROM dbo.PetBudgetLine bl
                        INNER JOIN dbo.PetForm p ON p.PetFormID = bl.PetFormID
                        WHERE p.ProjectID=@pid AND p.Status<>'Deleted'),0) AS BudgetTotal,
                    ISNULL((SELECT SUM(i.InvoiceAmount)
                        FROM dbo.PetBudgetInvoice i
                        INNER JOIN dbo.PetBudgetLine bl ON bl.BudgetLineID = i.BudgetLineID
                        INNER JOIN dbo.PetForm p ON p.PetFormID = bl.PetFormID
                        WHERE p.ProjectID=@pid AND p.Status<>'Deleted'),0) AS InvoiceTotal,
                    ISNULL((SELECT SUM(i.InvoiceAmount)
                        FROM dbo.PetBudgetInvoice i
                        INNER JOIN dbo.PetBudgetLine bl ON bl.BudgetLineID = i.BudgetLineID
                        INNER JOIN dbo.PetForm p ON p.PetFormID = bl.PetFormID
                        WHERE p.ProjectID=@pid AND p.Status<>'Deleted'
                          AND i.InvoiceStatus IN ('Paid','Processed / Archived')),0) AS InvoiceSettledTotal",
                Db.P("@pid", projectId));
                }

            public static DataTable GetProjectWiseKpiSummary(string projectId = null)
            {
                string sql = @"SELECT p.ProjectID, p.ProjectName,
                    ISNULL((SELECT COUNT(*) FROM dbo.PetForm pf
                        WHERE pf.ProjectID=p.ProjectID AND pf.Status<>'Deleted'),0) AS SpendRequestCount,
                    ISNULL((SELECT COUNT(*) FROM dbo.PetForm pf
                        WHERE pf.ProjectID=p.ProjectID AND pf.Status='PendingReview'),0) AS PendingReviewerCount,
                    ISNULL((SELECT COUNT(*) FROM dbo.PetForm pf
                        WHERE pf.ProjectID=p.ProjectID AND pf.Status='PendingApproval'),0) AS PendingApproverCount,
                    ISNULL((SELECT COUNT(*) FROM dbo.PetForm pf
                        WHERE pf.ProjectID=p.ProjectID AND pf.Status='Approved'),0) AS ApprovedCount,
                    ISNULL((SELECT COUNT(*) FROM dbo.PetBudgetLine bl
                        INNER JOIN dbo.PetForm pf ON pf.PetFormID = bl.PetFormID
                        WHERE pf.ProjectID=p.ProjectID AND pf.Status<>'Deleted'),0) AS BudgetingCount,
                    ISNULL((SELECT SUM(bl.Cost) FROM dbo.PetBudgetLine bl
                        INNER JOIN dbo.PetForm pf ON pf.PetFormID = bl.PetFormID
                        WHERE pf.ProjectID=p.ProjectID AND pf.Status<>'Deleted'),0) AS BudgetTotal,
                    ISNULL((SELECT COUNT(*) FROM dbo.PetBudgetInvoice i
                        INNER JOIN dbo.PetBudgetLine bl ON bl.BudgetLineID = i.BudgetLineID
                        INNER JOIN dbo.PetForm pf ON pf.PetFormID = bl.PetFormID
                        WHERE pf.ProjectID=p.ProjectID AND pf.Status<>'Deleted'),0) AS InvoiceCount,
                    ISNULL((SELECT COUNT(*) FROM dbo.PetBudgetInvoice i
                        INNER JOIN dbo.PetBudgetLine bl ON bl.BudgetLineID = i.BudgetLineID
                        INNER JOIN dbo.PetForm pf ON pf.PetFormID = bl.PetFormID
                        WHERE pf.ProjectID=p.ProjectID AND pf.Status<>'Deleted'
                          AND i.InvoiceStatus IN ('Paid','Processed / Archived')),0) AS InvoiceSettledCount,
                    ISNULL((SELECT COUNT(*) FROM dbo.PetBudgetInvoice i
                        INNER JOIN dbo.PetBudgetLine bl ON bl.BudgetLineID = i.BudgetLineID
                        INNER JOIN dbo.PetForm pf ON pf.PetFormID = bl.PetFormID
                        WHERE pf.ProjectID=p.ProjectID AND pf.Status<>'Deleted'
                          AND (i.InvoiceStatus IS NULL OR i.InvoiceStatus NOT IN ('Paid','Processed / Archived'))),0) AS InvoicePendingCount
                FROM dbo.Project p
                WHERE (@pid IS NULL OR p.ProjectID=@pid)
                ORDER BY p.ProjectName";
                return Db.Query(sql, Db.P("@pid", string.IsNullOrEmpty(projectId) ? (object)DBNull.Value : projectId));
            }

        // ===================================================================
        // BUDGET INVOICES  (multiple invoices per Budget Line)
        // ===================================================================

        public static DataTable GetBudgetInvoices(int budgetLineId)
        {
            return Db.Query(@"SELECT InvoiceID, BudgetLineID, InvoiceNo, InvoiceAmount, InvoiceStatus,
                                     PaymentDate, CreatedBy, CreatedDate
                              FROM dbo.PetBudgetInvoice WHERE BudgetLineID=@id ORDER BY InvoiceID",
                Db.P("@id", budgetLineId));
        }

        /// <summary>All invoices for every budget line under a PET form — used both for the persistent
        /// Invoices grid (Budget/Invoice tab) and for CSV export.</summary>
        public static DataTable GetBudgetInvoicesForPet(int petFormId)
        {
            return Db.Query(@"SELECT bl.BudgetLineID, bl.SerialNo, bl.VendorName, bl.Justification, bl.GLNumber,
                                     i.InvoiceID, i.InvoiceNo, i.InvoiceAmount, i.InvoiceStatus, i.PaymentDate,
                                     i.CreatedBy, i.CreatedDate
                              FROM dbo.PetBudgetInvoice i
                              INNER JOIN dbo.PetBudgetLine bl ON bl.BudgetLineID = i.BudgetLineID
                              WHERE bl.PetFormID=@id
                              ORDER BY bl.SerialNo, i.InvoiceID",
                Db.P("@id", petFormId));
        }

        public static int SaveBudgetInvoice(int budgetLineId, string invoiceNo, decimal invoiceAmount,
            string invoiceStatus, DateTime? paymentDate, string createdBy)
        {
            return Convert.ToInt32(Db.Scalar(@"
                INSERT INTO dbo.PetBudgetInvoice
                    (BudgetLineID, InvoiceNo, InvoiceAmount, InvoiceStatus, PaymentDate, CreatedBy)
                OUTPUT INSERTED.InvoiceID
                VALUES (@bl, @no, @am, @st, @pd, @cb)",
                Db.P("@bl", budgetLineId), Db.P("@no", invoiceNo ?? ""), Db.P("@am", invoiceAmount),
                Db.P("@st", invoiceStatus ?? ""), Db.P("@pd", (object)paymentDate ?? DBNull.Value),
                Db.P("@cb", createdBy)));
        }

        public static void UpdateBudgetInvoice(int invoiceId, string invoiceNo, decimal invoiceAmount,
            string invoiceStatus, DateTime? paymentDate, string modifiedBy)
        {
            Db.Exec(@"UPDATE dbo.PetBudgetInvoice
                      SET InvoiceNo=@no, InvoiceAmount=@am, InvoiceStatus=@st, PaymentDate=@pd,
                          ModifiedBy=@mb, ModifiedDate=GETDATE()
                      WHERE InvoiceID=@id",
                Db.P("@no", invoiceNo ?? ""), Db.P("@am", invoiceAmount), Db.P("@st", invoiceStatus ?? ""),
                Db.P("@pd", (object)paymentDate ?? DBNull.Value), Db.P("@mb", modifiedBy ?? ""), Db.P("@id", invoiceId));
        }

        public static void DeleteBudgetInvoice(int invoiceId)
        {
            Db.Exec("DELETE FROM dbo.PetBudgetInvoice WHERE InvoiceID=@id", Db.P("@id", invoiceId));
        }
    }
}
