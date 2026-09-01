using System;
using System.Data;
using System.Text;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using DFM_BPM.App_Code.DAL;
using DFM_BPM.App_Code.Helpers;

namespace DFM_BPM.Forms
{
    public partial class PetWorkflow : Page
    {
        private const string StagedLinesKey = "StagedSpendLines";
        private const string NextStagedLineIdKey = "NextStagedSpendLineId";

        // ===== State =====
        protected int CurrentPetFormId
        {
            get { int v; return int.TryParse(hfPetFormId.Value, out v) ? v : 0; }
            set { hfPetFormId.Value = value.ToString(); }
        }

        protected string PetRefNo    { get; private set; }
        protected string ReviewerName { get; private set; }
        protected string ApproverName { get; private set; }
        protected bool   IsEditable   { get; private set; }
        protected string CurrencyRatesJson { get; private set; }
        protected bool CanEditSpendLines { get { return IsEditable && AuthHelper.IsRequestor; } }

        /// <summary>Username of the PET's original Requestor (creator).</summary>
        protected string RequestorUsername { get; private set; }
        /// <summary>Full name of the Requestor (falls back to username if not resolvable).</summary>
        protected string RequestorFullName { get; private set; }
        /// <summary>Formatted date/time the PET was created.</summary>
        protected string RequestedDate { get; private set; }

        /// <summary>Budget/Invoice tab is visible for any saved PET (read-only until Approved).</summary>
        protected bool ShowBudgetTab { get; private set; }
        /// <summary>Only the original Requestor (or an Admin) can add/edit/delete Budget Lines &amp; Invoices, and only once Approved.</summary>
        protected bool CanManageBudget { get; private set; }

        protected bool IsProjectLocked
        {
            get { return Request.QueryString["lockProject"] == "1" && !string.IsNullOrEmpty(Request.QueryString["project"]); }
        }

        protected bool HostCloseOnInnerModalClose
        {
            get { return Request.QueryString["hostClose"] == "1"; }
        }

        /// <summary>Delete Spend Request button/action is only available while the request is still Draft or
        /// Pending Review/Approval — once Approved (or Rejected/Sent Back/Deleted) it can no longer be deleted.</summary>
        protected bool CanDeletePet
        {
            get
            {
                return CurrentPetFormId > 0 && WorkflowDAL.IsPetDeletable(CurrentStatus);
            }
        }

        /// <summary>Human-readable reason why Budget/Invoice is currently read-only, or null when it's editable.</summary>
        protected string BudgetReadOnlyReason
        {
            get
            {
                if (CanManageBudget || CurrentPetFormId <= 0) return null;
                if (CurrentStatus != "Approved")
                    return "Budget / Invoice can be added only once this PET is Approved. Current stage: " + FriendlyStatus(CurrentStatus) + ".";
                if (!string.Equals(RequestorUsername, AuthHelper.CurrentUserShort, StringComparison.OrdinalIgnoreCase))
                    return "Only the original Requestor (" + RequestorUsername + ") can manage Budget / Invoice for this PET.";
                return "Read-only.";
            }
        }

        private static string FriendlyStatus(string status)
        {
            switch (status)
            {
                case "PendingReview":   return "Pending Review";
                case "PendingApproval": return "Pending Approval";
                case "SentBack":        return "Sent Back to Requestor";
                default:                return status;
            }
        }

        private string ActiveTab     { get { return ViewState["activeTab"] as string ?? "pet"; }  set { ViewState["activeTab"] = value; } }
        protected string CurrentStatus { get { return ViewState["petStatus"] as string ?? "Draft"; } set { ViewState["petStatus"] = value; } }

        protected string TabActive(string tab) { return ActiveTab == tab ? "active" : ""; }
        protected string TabPane(string tab)   { return ActiveTab == tab ? "active" : ""; }

        protected string StepClass(int step)
        {
            int cur = GetCurrentStep();
            if (step < cur)  return "done";
            if (step == cur) return "active";
            return "";
        }

        private int GetCurrentStep()
        {
            switch (CurrentStatus)
            {
                case "Draft":           return 1;
                case "SentBack":        return 1;
                case "PendingReview":   return 2;
                case "PendingApproval": return 3;
                case "Approved":        return ShowBudgetTab ? 5 : 4;
                case "Rejected":        return 3;
                default:                return 1;
            }
        }

        // ===== Lifecycle =====
        protected void Page_Load(object sender, EventArgs e)
        {
            // File download
            int dlId;
            if (int.TryParse(Request.QueryString["dl"], out dlId) && dlId > 0)
            {
                string fileName, contentType;
                byte[] data = WorkflowDAL.DownloadAttachment(dlId, out fileName, out contentType);
                if (data != null)
                {
                    Response.Clear();
                    Response.ContentType = string.IsNullOrEmpty(contentType) ? "application/octet-stream" : contentType;
                    Response.AddHeader("Content-Disposition", "attachment; filename=\"" + HttpUtility.UrlPathEncode(fileName) + "\"");
                    Response.BinaryWrite(data);
                    Response.End();
                }
                return;
            }

            if (!IsPostBack)
            {
                LoadDropdowns();
                LoadCurrencies();

                int qid;
                if (int.TryParse(Request.QueryString["id"], out qid) && qid > 0)
                {
                    CurrentPetFormId = qid;
                    LoadForm(qid);
                    if (!string.IsNullOrEmpty(Request.QueryString["tab"]))
                    {
                        ActiveTab = Request.QueryString["tab"];
                        hfActiveTab.Value = ActiveTab;
                    }
                    OpenDeepLinkEditor();
                    if (Session["PetNextStep"] != null)
                    {
                        ShowNextStep(Session["PetNextStep"].ToString());
                        Session.Remove("PetNextStep");
                    }
                }
                else
                {
                    IsEditable = true;
                    ShowBudgetTab = false;
                    CanManageBudget = false;
                    pnlLines.Visible          = false;
                    pnlLinesGrid.Visible      = AuthHelper.IsRequestor;
                    pnlProjectDetails.Visible = false;
                    pnlNoProject.Visible      = true;
                    pnlDecision.Visible       = false;
                    pnlApproverImpact.Visible = false;
                    BindLines(0);

                    // Arrived from Project Registration's "Create Spend Request" action — pre-select the project.
                    string presetProject = Request.QueryString["project"];
                    if (!string.IsNullOrEmpty(presetProject) && ddlProject.Items.FindByValue(presetProject) != null)
                    {
                        ddlProject.SelectedValue = presetProject;
                        ddlProject_Changed(this, EventArgs.Empty);
                    }
                }
            }
            else
            {
                // Restore active tab from hidden field set by JS on tab click
                if (!string.IsNullOrEmpty(hfActiveTab.Value))
                    ActiveTab = hfActiveTab.Value;

                // Re-apply editable state on postback
                if (CurrentPetFormId == 0)
                {
                    IsEditable = true; // New form not yet saved
                    pnlLinesGrid.Visible = AuthHelper.IsRequestor;
                    BindLines(0);
                }
                else if (CurrentPetFormId > 0)
                {
                    DataRow f = WorkflowDAL.GetPetForm(CurrentPetFormId);
                    if (f != null) ApplyFormState(f);
                }
                LoadCurrencies();
            }
            ApplyHeaderEditableState();
        }

        /// <summary>
        /// Recomputes every state property derived from the PetForm row (status, editability, requestor
        /// details, budget permissions). Called from both the initial load (LoadForm) and every postback,
        /// so values like PetRefNo/Requestor don't reset to blank after a postback.
        /// </summary>
        private void ApplyFormState(DataRow f)
        {
            CurrentStatus     = f["Status"].ToString();
            PetRefNo          = f["PetRefNo"]         == DBNull.Value ? null : f["PetRefNo"].ToString();
            ReviewerName      = f["ReviewerUsername"] == DBNull.Value ? null : f["ReviewerUsername"].ToString();
            ApproverName      = f["ApproverUsername"] == DBNull.Value ? null : f["ApproverUsername"].ToString();
            RequestorUsername = f["CreatedBy"]         == DBNull.Value ? null : f["CreatedBy"].ToString();
            RequestedDate     = f["CreatedDate"]       == DBNull.Value ? "" : Convert.ToDateTime(f["CreatedDate"]).ToString("dd-MMM-yyyy HH:mm");

            IsEditable = (CurrentStatus == "Draft" || CurrentStatus == "SentBack" || CurrentStatus == "Rejected")
                       && string.Equals(RequestorUsername, AuthHelper.CurrentUserShort, StringComparison.OrdinalIgnoreCase);
            ShowBudgetTab   = true;
            CanManageBudget = CurrentStatus == "Approved" && (AuthHelper.IsAdmin ||
                string.Equals(RequestorUsername, AuthHelper.CurrentUserShort, StringComparison.OrdinalIgnoreCase));

            RequestorFullName = RequestorUsername;
            try
            {
                DataRow reqUser = UserDAL.GetUser(RequestorUsername);
                if (reqUser != null && reqUser["FullName"] != DBNull.Value)
                    RequestorFullName = reqUser["FullName"].ToString();
            }
            catch { /* fall back to username if lookup fails */ }

            ApplyHeaderEditableState();
        }

        /// <summary>Greys out (disables) the header fields whenever the form is not editable by the current user.</summary>
        private void ApplyHeaderEditableState()
        {
            ddlProject.Enabled      = IsEditable && !IsProjectLocked;
            ddlType.Enabled         = IsEditable;
            ddlBudgetSource.Enabled = IsEditable;
            ddlReviewer.Enabled     = IsEditable;
            ddlApprover.Enabled     = IsEditable;
            txtTitle.Enabled        = IsEditable;
        }

        // ===== Dropdowns =====
        private void LoadDropdowns()
        {
            // Project selection is now restricted to the Project Registration master — a PET can only be
            // created against an already-registered project (JIRA or Non-JIRA alike).
            DataTable dtP = ProjectDAL.GetRegisteredProjectDropdown();
            ddlProject.DataSource     = dtP;
            ddlProject.DataTextField  = "DisplayName";
            ddlProject.DataValueField = "ProjectID";
            ddlProject.DataBind();
            ddlProject.Items.Insert(0, new ListItem("-- Select Registered Project --", ""));

            // Reviewers
            DataTable dtRev = MastersDAL.GetReviewers();
            ddlReviewer.DataSource     = dtRev;
            ddlReviewer.DataTextField  = "FullName";
            ddlReviewer.DataValueField = "Username";
            ddlReviewer.DataBind();
            ddlReviewer.Items.Insert(0, new ListItem("-- Select Reviewer --", ""));

            // Approvers
            DataTable dtApp = MastersDAL.GetApprovers();
            ddlApprover.DataSource     = dtApp;
            ddlApprover.DataTextField  = "FullName";
            ddlApprover.DataValueField = "Username";
            ddlApprover.DataBind();
            ddlApprover.Items.Insert(0, new ListItem("-- Select Approver --", ""));

            // BPM project dropdown removed (now using registered Projects only)

        }

        private void LoadCurrencies()
        {
            DataTable dt = MastersDAL.GetCurrencies();
            var sb = new StringBuilder("{");
            foreach (DataRow r in dt.Rows)
            {
                if (sb.Length > 1) sb.Append(",");
                sb.AppendFormat("\"{0}\":{1}", r["Code"], r["RateToLocal"].ToString().Replace(",", "."));
            }
            sb.Append("}");
            CurrencyRatesJson = sb.ToString();

            // Line item currency dropdown
            ddlLineCcy.DataSource     = dt;
            ddlLineCcy.DataTextField  = "Code";
            ddlLineCcy.DataValueField = "Code";
            ddlLineCcy.DataBind();

            // Cost types
            DataTable ct = MastersDAL.GetCostTypes();
            ddlLineCostType.DataSource     = ct;
            ddlLineCostType.DataTextField  = "Category";
            ddlLineCostType.DataValueField = "Category";
            ddlLineCostType.DataBind();
            ddlLineCostType.Items.Insert(0, new ListItem("-- Select --", ""));

            // Vendors – store VendorName so it shows correctly in the grid
            DataTable vd = MastersDAL.GetVendorDropdown();
            ddlLineVendor.DataSource     = vd;
            ddlLineVendor.DataTextField  = "Name";
            ddlLineVendor.DataValueField = "Name";
            ddlLineVendor.DataBind();
            ddlLineVendor.Items.Insert(0, new ListItem("-- Select --", ""));

            // GL numbers
            DataTable gl = MastersDAL.GetGLDropdown();
            ddlLineGL.DataSource     = gl;
            ddlLineGL.DataTextField  = "Name";
            ddlLineGL.DataValueField = "ID";
            ddlLineGL.DataBind();
            ddlLineGL.Items.Insert(0, new ListItem("-- None --", ""));
        }

        /// <summary>Populate Currency dropdown used by the Budget Line popup modal.</summary>
        private void LoadBudgetDropdowns()
        {
            DataTable ccy = MastersDAL.GetCurrencies();
            ddlBgtCcy.DataSource     = ccy;
            ddlBgtCcy.DataTextField  = "Code";
            ddlBgtCcy.DataValueField = "Code";
            ddlBgtCcy.DataBind();
        }

        // ===== Load existing form =====
        private void LoadForm(int id)
        {
            DataRow f = WorkflowDAL.GetPetForm(id);
            if (f == null) { Response.Redirect("~/Forms/PetWorkflow.aspx"); return; }

            ApplyFormState(f);

            // Bind form controls — ProjectID must reference an already-registered Project (see ProjectDAL)
            string projectId = f["ProjectID"] == DBNull.Value ? null : f["ProjectID"].ToString();
            bool isNonJira = false;
            DataRow proj = string.IsNullOrEmpty(projectId) ? null : ProjectDAL.GetProjectById(projectId);
            if (proj != null)
            {
                isNonJira = proj["IsNonJiraProject"] != DBNull.Value && Convert.ToBoolean(proj["IsNonJiraProject"]);
                txtProjectName.Text = proj["ProjectName"] == DBNull.Value ? "" : proj["ProjectName"].ToString();
            }
            SetDdl(ddlProject, projectId ?? "");
            SetDdl(ddlType,     f, "CapexOpexType");
            SetDdl(ddlReviewer, f, "ReviewerUsername");
            SetDdl(ddlApprover, f, "ApproverUsername");
            txtTitle.Text = f["Title"] == DBNull.Value ? "" : f["Title"].ToString();

            // Load budget source dropdown for the type
            LoadBudgetSourceDropdown(f["CapexOpexType"] == DBNull.Value ? null : f["CapexOpexType"].ToString());
            SetDdl(ddlBudgetSource, f, "BudgetSourceID");

            // Show budget amounts
            ShowBudgetAmounts(
                f["CapexOpexType"]  == DBNull.Value ? null : f["CapexOpexType"].ToString(),
                f["BudgetSourceID"] == DBNull.Value ? null : f["BudgetSourceID"].ToString());

            // Lines
            pnlLines.Visible = true;
            pnlLinesGrid.Visible = true;
            BindLines(id);

            // Attachments
            BindAttachments();

            // Project details tab (JIRA-based)
            LoadProjectDetails(projectId, isNonJira);

            // Project Overview — the Project is the main item: all PET forms (incl. Draft) + Budget/Invoice for it
            LoadProjectOverview(projectId);

            // Approval tab
            LoadApprovalTab(f);

            // Sizing (1 per Project, shared with Project Registration — editable any time)
            LoadSizingForProject(projectId);

            // Budget / Invoice (tab is visible for any saved PET; editing is gated by CanManageBudget)
            LoadBudgetDropdowns();
            BindBudgetLines(id);

            // Cost summary (Total PET Cost / Invoice Cost / Settled / Pending) shown in the CAPEX/OPEX panels
            LoadPetCostSummary(id);
        }

        private void LoadProjectDetails(string jiraId, bool isNonJira)
        {
            if (string.IsNullOrEmpty(jiraId))
            {
                pnlProjectDetails.Visible = false; pnlNoProject.Visible = true;
                litNoProjectMsg.Text = "Select a JIRA ID / Project (or enter a Non-JIRA Project ID) in the Request tab first.";
                return;
            }
            if (isNonJira)
            {
                pnlProjectDetails.Visible = false; pnlNoProject.Visible = true;
                litNoProjectMsg.Text = "This is a Non-JIRA project &mdash; no additional JIRA metadata is available.";
                return;
            }

            pnlNoProject.Visible      = false;
            pnlProjectDetails.Visible = true;

            DataRow j = MastersDAL.GetJiraById(jiraId);
            if (j != null)
            {
                litProjId.Text             = Server.HtmlEncode(Convert.ToString(j["JiraID"]));
                litJProjectName.Text       = Server.HtmlEncode(Convert.ToString(j["Summary"]));
                litJProjectType.Text       = Server.HtmlEncode(Convert.ToString(j["ProjectType"]));
                litJStage.Text             = Server.HtmlEncode(Convert.ToString(j["ProjectStage"]));
                litJRag.Text               = Server.HtmlEncode(Convert.ToString(j["ProjectRAG"]));
                litJDemand.Text            = Server.HtmlEncode(Convert.ToString(j["DemandType"]));
                litJDept.Text              = Server.HtmlEncode(Convert.ToString(j["Department"]));
                litJClassification.Text    = Server.HtmlEncode(Convert.ToString(j["Classification"]));
                litJPlatform.Text          = Server.HtmlEncode(Convert.ToString(j["Platform"]));
                litJPlatformVertical.Text  = Server.HtmlEncode(Convert.ToString(j["PlatformVertical"]));
                litJIssueType.Text         = Server.HtmlEncode(Convert.ToString(j["IssueType"]));
                litJMgr.Text               = Server.HtmlEncode(Convert.ToString(j["Manager"]));
                litJTech.Text              = Server.HtmlEncode(Convert.ToString(j["TechLead"]));
                litJSponsor.Text           = Server.HtmlEncode(Convert.ToString(j["Sponsor"]));
                litJStakeholder.Text       = Server.HtmlEncode(Convert.ToString(j["Stakeholder"]));
                litJAssignee.Text          = Server.HtmlEncode(Convert.ToString(j["Assignee"]));
                litJReporter.Text          = Server.HtmlEncode(Convert.ToString(j["Reporter"]));
                litJCreated.Text           = j["CreatedDate"] == DBNull.Value ? "" : Convert.ToDateTime(j["CreatedDate"]).ToString("dd-MMM-yyyy");
                litJUpdated.Text           = j["UpdatedDate"] == DBNull.Value ? "" : Convert.ToDateTime(j["UpdatedDate"]).ToString("dd-MMM-yyyy");
                litJStart.Text             = Server.HtmlEncode(Convert.ToString(j["StartDate"]));
                litJEnd.Text               = Server.HtmlEncode(Convert.ToString(j["EndDate"]));
                // Extended JIRA fields
                litJAccExecLead.Text       = Server.HtmlEncode(Convert.ToString(j["AccountableExecLead"]));
                litJSmeLead.Text           = Server.HtmlEncode(Convert.ToString(j["SmeLead"]));
                litJAccExec.Text           = Server.HtmlEncode(Convert.ToString(j["AccountableExec"]));
                litJPortfolioHead.Text     = Server.HtmlEncode(Convert.ToString(j["IdhPortfolioHead"]));
                litJAssignedPM.Text        = Server.HtmlEncode(Convert.ToString(j["AssignedProjectManager"]));
                litJDemandOwner.Text       = Server.HtmlEncode(Convert.ToString(j["DemandOwner"]));
                litJChief.Text             = Server.HtmlEncode(Convert.ToString(j["ChiefNameMapping"]));
                litJPrimaryClass.Text      = Server.HtmlEncode(Convert.ToString(j["Primary_Classification"]));
                litJProjPerformingDept.Text = Server.HtmlEncode(Convert.ToString(j["ProjectPerformingDept"]));
                litJProjSponsorDept.Text   = Server.HtmlEncode(Convert.ToString(j["ProjectSponsorDept"]));
                litJDemandDept.Text        = Server.HtmlEncode(Convert.ToString(j["DemandDepartment"]));
                litJRequesterDept.Text     = Server.HtmlEncode(Convert.ToString(j["RequesterDept"]));
                litJProjectDept.Text       = Server.HtmlEncode(Convert.ToString(j["ProjectDept"]));
                litJDemandSegment.Text     = Server.HtmlEncode(Convert.ToString(j["DemandSegment"]));
                litJDemandTitle.Text       = Server.HtmlEncode(Convert.ToString(j["DemandTitle"]));
                litJRegulatoryObs.Text     = Server.HtmlEncode(Convert.ToString(j["RegulatoryObservation"]));
                litJRolloutStatus.Text     = Server.HtmlEncode(Convert.ToString(j["RolloutStatus"]));
                litJEpicStatus.Text        = Server.HtmlEncode(Convert.ToString(j["EpicStatus"]));
                litJBrdStatus.Text         = Server.HtmlEncode(Convert.ToString(j["BrdStatus"]));
                litJScriptStatus.Text      = Server.HtmlEncode(Convert.ToString(j["ScriptStatus"]));
                litJStatusGrey.Text        = Server.HtmlEncode(Convert.ToString(j["StatusGrey"]));
                litJStatusReason.Text      = Server.HtmlEncode(Convert.ToString(j["StatusReason"]));
                litJInitiativeStatus.Text  = Server.HtmlEncode(Convert.ToString(j["InitiativeStatus"]));
                litJProjectOverallStatus.Text = Server.HtmlEncode(Convert.ToString(j["ProjectOverallStatus"]));
                litJCbtpBrdStatus.Text     = Server.HtmlEncode(Convert.ToString(j["CbtpBrdStatus"]));
                litJFsdStatus.Text         = Server.HtmlEncode(Convert.ToString(j["FsdStatus"]));
                // Baseline date fields
                litJBaselineStart.Text     = j["BaselineStartDate"]    == DBNull.Value ? "" : Convert.ToDateTime(j["BaselineStartDate"]).ToString("dd-MMM-yyyy");
                litJBaselineEnd.Text       = j["BaselineEndDate"]      == DBNull.Value ? "" : Convert.ToDateTime(j["BaselineEndDate"]).ToString("dd-MMM-yyyy");
                litJBl1ActualStart.Text    = j["Baseline1ActualStart"] == DBNull.Value ? "" : Convert.ToDateTime(j["Baseline1ActualStart"]).ToString("dd-MMM-yyyy");
                litJBl1ActualEnd.Text      = j["Baseline1ActualEnd"]   == DBNull.Value ? "" : Convert.ToDateTime(j["Baseline1ActualEnd"]).ToString("dd-MMM-yyyy");
                litJBl0PlannedStart.Text   = j["Baseline0PlannedStart"]== DBNull.Value ? "" : Convert.ToDateTime(j["Baseline0PlannedStart"]).ToString("dd-MMM-yyyy");
                litJBl0PlannedEnd.Text     = j["Baseline0PlannedEnd"]  == DBNull.Value ? "" : Convert.ToDateTime(j["Baseline0PlannedEnd"]).ToString("dd-MMM-yyyy");
                litJBl0ActualStart.Text    = j["Baseline0ActualStart"] == DBNull.Value ? "" : Convert.ToDateTime(j["Baseline0ActualStart"]).ToString("dd-MMM-yyyy");
                litJBl0ActualEnd.Text      = j["Baseline0ActualEnd"]   == DBNull.Value ? "" : Convert.ToDateTime(j["Baseline0ActualEnd"]).ToString("dd-MMM-yyyy");
                litJBl1ActualGoLive.Text   = j["Baseline1ActualGoLive"]== DBNull.Value ? "" : Convert.ToDateTime(j["Baseline1ActualGoLive"]).ToString("dd-MMM-yyyy");

                // Also populate project name readonly textbox
                txtProjectName.Text = Convert.ToString(j["Summary"]);
            }

            gvCapexAmt.DataSource = WorkflowDAL.GetCapexAmountsForProject(jiraId);
            gvCapexAmt.DataBind();
            gvOpexAmt.DataSource  = WorkflowDAL.GetOpexAmountsForProject(jiraId);
            gvOpexAmt.DataBind();
            gvGLAmt.DataSource    = WorkflowDAL.GetGLAmountsForProject(jiraId);
            gvGLAmt.DataBind();
        }

        private void LoadApprovalTab(DataRow f)
        {
            string status    = f["Status"] == DBNull.Value ? "" : f["Status"].ToString();
            string reviewer  = f["ReviewerUsername"] == DBNull.Value ? null : f["ReviewerUsername"].ToString();
            string approver  = f["ApproverUsername"] == DBNull.Value ? null : f["ApproverUsername"].ToString();
            string requestor = f["CreatedBy"] == DBNull.Value ? "" : f["CreatedBy"].ToString();

            litApprRequestor.Text = Server.HtmlEncode(requestor);
            litApprReviewer.Text  = Server.HtmlEncode(string.IsNullOrEmpty(reviewer) ? "N/A" : reviewer);
            litApprApprover.Text  = Server.HtmlEncode(approver ?? "");
            litApprStatus.Text    = Server.HtmlEncode(status);

            // Show budget source info
            string bType = f["CapexOpexType"] == DBNull.Value ? "" : f["CapexOpexType"].ToString();
            string bSrc  = f["BudgetSourceID"] == DBNull.Value ? "" : f["BudgetSourceID"].ToString();
            if (!string.IsNullOrEmpty(bSrc))
            {
                string bDesc = "";
                if (bType == "CAPEX") { DataRow br = MastersDAL.GetCapexById(bSrc); if (br != null) bDesc = br["Description"] == DBNull.Value ? "" : br["Description"].ToString(); }
                else if (bType == "OPEX") { DataRow br = MastersDAL.GetOpexById(bSrc); if (br != null) bDesc = br["Description"] == DBNull.Value ? "" : br["Description"].ToString(); }
                string bIcon = bType == "CAPEX" ? "bi-currency-dollar" : "bi-receipt";
                string bColor = bType == "CAPEX" ? "#2563eb" : "#059669";
                litApprBudgetInfo.Text = string.Format(
                    "<div style='background:#f0f9ff;border:1px solid #bae6fd;border-radius:8px;padding:10px 16px;margin:10px 0;font-size:.88em;'>" +
                    "<i class='bi {0}' style='color:{1};margin-right:6px;'></i>" +
                    "<strong>{2} Budget:</strong> <span style='color:#1e3a5f;font-weight:700;'>{3}</span>" +
                    "{4}</div>",
                    bIcon, bColor,
                    Server.HtmlEncode(bType),
                    Server.HtmlEncode(bSrc),
                    string.IsNullOrEmpty(bDesc) ? "" : " &mdash; " + Server.HtmlEncode(bDesc));
            }

            // Show decision panel if this user must act
            bool isReviewer = !string.IsNullOrEmpty(reviewer) && string.Equals(reviewer, AuthHelper.CurrentUserShort, StringComparison.OrdinalIgnoreCase);
            bool isApprover = !string.IsNullOrEmpty(approver) && string.Equals(approver, AuthHelper.CurrentUserShort, StringComparison.OrdinalIgnoreCase);

            bool showDecision = (status == "PendingReview" && isReviewer)
                             || (status == "PendingApproval" && isApprover);

            pnlDecision.Visible = showDecision;
            if (showDecision)
            {
                litDecisionTitle.Text = isReviewer ? "Review Decision" : "Approval Decision";
                btnApprove.Text       = isReviewer ? "Recommend (Send to Approver)" : "Approve";
                btnReject.Visible     = isApprover;
            }

            // Approver impact panel
            pnlApproverImpact.Visible = showDecision && isApprover;
            if (pnlApproverImpact.Visible)
            {
                string budgetType = f["CapexOpexType"] == DBNull.Value ? null : f["CapexOpexType"].ToString();
                string sourceId   = f["BudgetSourceID"] == DBNull.Value ? null : f["BudgetSourceID"].ToString();
                object reqRaw = Db.Scalar(
                    "SELECT ISNULL(SUM(FinalAmtLCY),0) FROM dbo.PetLineItem WHERE PetFormID=@p",
                    Db.P("@p", CurrentPetFormId));
                decimal requested = reqRaw == null || reqRaw == DBNull.Value ? 0m : Convert.ToDecimal(reqRaw);

                decimal utilized = 0m, locked = 0m, avail = 0m;
                if (budgetType == "CAPEX" && !string.IsNullOrEmpty(sourceId))
                {
                    DataRow r = MastersDAL.GetCapexById(sourceId);
                    if (r != null) {
                        utilized = Dec(r, "UtilizedAmount");
                        locked   = Dec(r, "LockedAmount");
                        avail    = Dec(r, "AvailableAmount");
                    }
                }
                else if (budgetType == "OPEX" && !string.IsNullOrEmpty(sourceId))
                {
                    DataRow r = MastersDAL.GetOpexById(sourceId);
                    if (r != null) {
                        utilized = Dec(r, "UtilizedAmount");
                        locked   = Dec(r, "LockedAmount");
                        avail    = Dec(r, "AvailableAmount");
                    }
                }

                litImpactRequested.Text     = requested.ToString("N2");
                litImpactCurrentUtil.Text   = utilized.ToString("N2");
                litImpactCurrentLocked.Text = locked.ToString("N2");
                litImpactAvail.Text         = avail.ToString("N2");
                litImpactAfter.Text         = (avail - requested).ToString("N2");
            }

            // History
            gvHistory.DataSource = WorkflowDAL.GetHistory(CurrentPetFormId);
            gvHistory.DataBind();
        }

        // ===== Budget source dropdown =====
        private void LoadBudgetSourceDropdown(string type)
        {
            ddlBudgetSource.Items.Clear();
            ddlBudgetSource.Items.Add(new ListItem("-- Select --", ""));
            if (type == "CAPEX")
            {
                foreach (DataRow r in MastersDAL.GetCapexDropdown().Rows)
                    ddlBudgetSource.Items.Add(new ListItem(r["Name"].ToString(), r["ID"].ToString()));
            }
            else if (type == "OPEX")
            {
                foreach (DataRow r in MastersDAL.GetOpexDropdown().Rows)
                    ddlBudgetSource.Items.Add(new ListItem(r["Name"].ToString(), r["ID"].ToString()));
            }
        }

        private void ShowBudgetAmounts(string type, string sourceId)
        {
            pnlCapexAmt.Visible = false;
            pnlOpexAmt.Visible  = false;

            if (type == "CAPEX" && !string.IsNullOrEmpty(sourceId))
            {
                DataRow r = MastersDAL.GetCapexById(sourceId);
                if (r != null)
                {
                    litCapexSourceId.Text  = Server.HtmlEncode(sourceId);
                    litCapexBudget.Text    = Dec(r, "BudgetedAmount").ToString("N2");
                    litCapexUtil.Text      = Dec(r, "UtilizedAmount").ToString("N2");
                    litCapexLocked.Text    = Dec(r, "LockedAmount").ToString("N2");
                    litCapexAvail.Text     = Dec(r, "AvailableAmount").ToString("N2");
                    pnlCapexAmt.Visible    = true;
                }
            }
            else if (type == "OPEX" && !string.IsNullOrEmpty(sourceId))
            {
                DataRow r = MastersDAL.GetOpexById(sourceId);
                if (r != null)
                {
                    litOpexSourceId.Text  = Server.HtmlEncode(sourceId);
                    litOpexBudget.Text    = Dec(r, "BudgetedAmount").ToString("N2");
                    litOpexUtil.Text      = Dec(r, "UtilizedAmount").ToString("N2");
                    litOpexLocked.Text    = Dec(r, "LockedAmount").ToString("N2");
                    litOpexAvail.Text     = Dec(r, "AvailableAmount").ToString("N2");
                    litOpexContracts.Text = Server.HtmlEncode(Convert.ToString(r["Contracts"]));
                    pnlOpexAmt.Visible    = true;
                }
            }
        }

        /// <summary>Total PET cost (line items) vs. Invoice cost/settled/pending, shown in the CAPEX/OPEX panels.</summary>
        private void LoadPetCostSummary(int petFormId)
        {
            decimal totalPetCost = Convert.ToDecimal(Db.Scalar(
                "SELECT ISNULL(SUM(FinalAmtLCY),0) FROM dbo.PetLineItem WHERE PetFormID=@p", Db.P("@p", petFormId)));

            DataTable invoices = WorkflowDAL.GetBudgetInvoicesForPet(petFormId);
            decimal invoiceCost = 0, invoiceSettled = 0;
            foreach (DataRow r in invoices.Rows)
            {
                decimal amt = Dec(r, "InvoiceAmount");
                invoiceCost += amt;
                string st = r["InvoiceStatus"] == DBNull.Value ? "" : r["InvoiceStatus"].ToString();
                if (st == "Paid" || st == "Processed / Archived") invoiceSettled += amt;
            }
            decimal pending = invoiceCost - invoiceSettled;

            litCapexTotalPetCost.Text   = totalPetCost.ToString("N2");
            litCapexInvoiceCost.Text    = invoiceCost.ToString("N2");
            litCapexInvoiceSettled.Text = invoiceSettled.ToString("N2");
            litCapexInvoicePending.Text = pending.ToString("N2");

            litOpexTotalPetCost.Text   = totalPetCost.ToString("N2");
            litOpexInvoiceCost.Text    = invoiceCost.ToString("N2");
            litOpexInvoiceSettled.Text = invoiceSettled.ToString("N2");
            litOpexInvoicePending.Text = pending.ToString("N2");
        }

        // ===== PET Lines =====
        private void BindLines(int id)
        {
            DataTable dt = id > 0 ? WorkflowDAL.GetPetLines(id) : GetStagedLines();
            gvLines.DataSource = dt;
            gvLines.DataBind();
            litLineCount.Text = dt.Rows.Count.ToString();
            decimal totLCY = 0, totFinal = 0;
            foreach (DataRow r in dt.Rows) { totLCY += Dec(r,"AmtLCY"); totFinal += Dec(r,"FinalAmtLCY"); }
            litTotalLCY.Text   = totLCY.ToString("N2");
            litTotalFinal.Text = totFinal.ToString("N2");
        }

        private DataTable GetStagedLines()
        {
            DataTable dt = ViewState[StagedLinesKey] as DataTable;
            if (dt == null)
            {
                dt = CreateLineTable();
                ViewState[StagedLinesKey] = dt;
            }
            return dt;
        }

        private static DataTable CreateLineTable()
        {
            DataTable dt = new DataTable();
            dt.Columns.Add("LineID", typeof(int));
            dt.Columns.Add("SerialNo", typeof(int));
            dt.Columns.Add("Department", typeof(string));
            dt.Columns.Add("ExpHead", typeof(string));
            dt.Columns.Add("Topic", typeof(string));
            dt.Columns.Add("VendorName", typeof(string));
            dt.Columns.Add("Description", typeof(string));
            dt.Columns.Add("CostType", typeof(string));
            dt.Columns.Add("Units", typeof(decimal));
            dt.Columns.Add("UnitPrice", typeof(decimal));
            dt.Columns.Add("BaseCurrency", typeof(string));
            dt.Columns.Add("AmtFCY", typeof(decimal));
            dt.Columns.Add("AmtLCY", typeof(decimal));
            dt.Columns.Add("ContingencyPct", typeof(decimal));
            dt.Columns.Add("FinalAmtLCY", typeof(decimal));
            dt.Columns.Add("GLNumber", typeof(string));
            dt.Columns.Add("Comments", typeof(string));
            return dt;
        }

        private int GetNextStagedLineId()
        {
            object raw = ViewState[NextStagedLineIdKey];
            int nextId = raw == null ? -1 : Convert.ToInt32(raw);
            ViewState[NextStagedLineIdKey] = nextId - 1;
            return nextId;
        }

        private static DataRow FindLineById(DataTable dt, int lineId)
        {
            foreach (DataRow row in dt.Rows)
                if (Convert.ToInt32(row["LineID"]) == lineId) return row;
            return null;
        }

        private static void RenumberLines(DataTable dt)
        {
            int serialNo = 1;
            foreach (DataRow row in dt.Rows)
                row["SerialNo"] = serialNo++;
        }

        private void ClearLineForm()
        {
            hfEditLineId.Value = "";
            btnSaveLine.Text = "Add Spend Line";
            btnCancelLine.Visible = false;
            ddlExpHead.SelectedIndex = 0;
            txtLineTopic.Text = txtLineDesc.Text = "";
            txtLineUnits.Text = "1";
            txtLineUnitPrice.Text = txtLineAmtFCY.Text = txtLineAmtLCY.Text = "0";
            txtLineConting.Text = "0";
            if (ddlLineVendor.Items.Count > 0)   ddlLineVendor.SelectedIndex   = 0;
            if (ddlLineCostType.Items.Count > 0) ddlLineCostType.SelectedIndex = 0;
            if (ddlLineGL.Items.Count > 0)       ddlLineGL.SelectedIndex       = 0;
            if (ddlLineCcy.Items.FindByValue("AED") != null) ddlLineCcy.SelectedValue = "AED";
        }

        private string PostedValue(ListControl control)
        {
            string posted = Request.Form[control.UniqueID];
            return posted == null ? control.SelectedValue : posted;
        }

        private bool ValidateLineInput(string topic, string vendor, string costType, decimal units, decimal price)
        {
            if (string.IsNullOrEmpty(topic)) { ShowMsg("Topic / Item is required for the spend line."); return false; }
            if (string.IsNullOrEmpty(vendor)) { ShowMsg("Vendor is required for the spend line."); return false; }
            if (string.IsNullOrEmpty(costType)) { ShowMsg("Cost Type is required for the spend line."); return false; }
            if (units <= 0) { ShowMsg("Units must be greater than zero."); return false; }
            if (price <= 0) { ShowMsg("Unit Price must be greater than zero."); return false; }
            return true;
        }

        // ===== Event handlers =====
        protected void ddlProject_Changed(object sender, EventArgs e)
        {
            string projectId = ddlProject.SelectedValue;
            bool isNonJira = false;
            if (!string.IsNullOrEmpty(projectId))
            {
                DataRow proj = ProjectDAL.GetProjectById(projectId);
                if (proj != null)
                {
                    isNonJira = proj["IsNonJiraProject"] != DBNull.Value && Convert.ToBoolean(proj["IsNonJiraProject"]);
                    txtProjectName.Text = proj["ProjectName"] == DBNull.Value ? "" : proj["ProjectName"].ToString();
                }
            }
            else
            {
                txtProjectName.Text = "";
            }
            LoadProjectDetails(projectId, isNonJira);
            LoadProjectOverview(projectId);
        }

        /// <summary>The Project is the main item: show every PET form (incl. Draft) and every Budget/Invoice
        /// line raised against it, so the requestor/reviewer/approver can see the full picture at a glance.</summary>
        private void LoadProjectOverview(string jiraId)
        {
            pnlProjectOverview.Visible = !string.IsNullOrEmpty(jiraId);
            if (string.IsNullOrEmpty(jiraId)) return;

            gvProjectPets.DataSource = WorkflowDAL.GetPetFormsDashboard(jiraId, null, null, null, null);
            gvProjectPets.DataBind();

            gvProjectBudget.DataSource = WorkflowDAL.GetBudgetLinesByProject(jiraId);
            gvProjectBudget.DataBind();

            gvProjectInvoices.DataSource = WorkflowDAL.GetInvoicesByProject(jiraId);
            gvProjectInvoices.DataBind();
        }

        protected void ddlType_Changed(object sender, EventArgs e)
        {
            LoadBudgetSourceDropdown(ddlType.SelectedValue);
        }

        protected void ddlBudgetSource_Changed(object sender, EventArgs e)
        {
            ShowBudgetAmounts(ddlType.SelectedValue, ddlBudgetSource.SelectedValue);
        }

        protected void ddlLineCcy_Changed(object sender, EventArgs e) { /* recalc done in JS */ }

        protected void btnSaveHeader_Click(object sender, EventArgs e)
        {
            if (!CanEditSpendLines)
            {
                ShowMsg("Only users with the Requestor role can save Spend Requests and Spend Lines.");
                return;
            }

            string lockedProject = Request.QueryString["project"];
            string projectId = IsProjectLocked && !string.IsNullOrEmpty(lockedProject) ? lockedProject : ddlProject.SelectedValue;
            if (string.IsNullOrEmpty(projectId))
            {
                ShowMsg("A registered Project is required. Register it first via the Project Registration page.");
                return;
            }

            // Project identity (name / JIRA vs Non-JIRA) is owned by the Project Registration master now —
            // resolve it here rather than collecting it again on this form.
            DataRow proj = ProjectDAL.GetProjectById(projectId);
            bool isNonJira = proj != null && proj["IsNonJiraProject"] != DBNull.Value && Convert.ToBoolean(proj["IsNonJiraProject"]);
            string projectName = proj != null && proj["ProjectName"] != DBNull.Value ? proj["ProjectName"].ToString() : null;

            string reviewerVal = ddlReviewer.SelectedValue == "" ? null : ddlReviewer.SelectedValue;
            string approverVal = ddlApprover.SelectedValue == "" ? null : ddlApprover.SelectedValue;
            string budgetSrc   = ddlBudgetSource.SelectedValue == "" ? null : ddlBudgetSource.SelectedValue;

            if (string.IsNullOrEmpty(reviewerVal)) { ShowMsg("Reviewer is required before saving the Spend Request."); return; }
            if (string.IsNullOrEmpty(approverVal)) { ShowMsg("Approver is required before saving the Spend Request."); return; }

            if (CurrentPetFormId == 0)
            {
                DataTable stagedLines = GetStagedLines();
                int newId = WorkflowDAL.CreatePetFormWithLines(
                    projectId, ddlType.SelectedValue,
                    budgetSrc, txtTitle.Text.Trim(), "",
                    reviewerVal, approverVal, AuthHelper.CurrentUserShort,
                    isNonJira, projectName, stagedLines);
                ViewState[StagedLinesKey] = null;
                ViewState[NextStagedLineIdKey] = null;
                CurrentPetFormId = newId;
                Session["PetNextStep"] = "Spend Request saved. Next: add line items, attach supporting documents if needed, then submit it for approval.";
                Response.Redirect("~/Forms/PetWorkflow.aspx?id=" + newId);
                return;
            }
            else
            {
                WorkflowDAL.UpdatePetForm(CurrentPetFormId,
                    projectId, ddlType.SelectedValue,
                    budgetSrc, txtTitle.Text.Trim(), "",
                    reviewerVal, approverVal, AuthHelper.CurrentUserShort,
                    isNonJira, projectName);
            }

            ShowNextStep("Spend Request saved. Next: review or add line items, attach documents if needed, then submit it for approval.");
            pnlLines.Visible = true;
            pnlLinesGrid.Visible = true;
            ShowBudgetAmounts(ddlType.SelectedValue, ddlBudgetSource.SelectedValue);
            BindLines(CurrentPetFormId);
            LoadProjectDetails(projectId, isNonJira);
            BindAttachments();
        }

        protected void btnAddLine_Click(object sender, EventArgs e)
        {
            if (!CanEditSpendLines) return;
            ClearLineForm();
        }

        protected void btnCancelLine_Click(object sender, EventArgs e)
        {
            if (!CanEditSpendLines) return;
            ClearLineForm();
            BindLines(CurrentPetFormId);
        }

        protected void btnSaveLine_Click(object sender, EventArgs e)
        {
            if (!CanEditSpendLines)
            {
                ShowMsg("Only users with the Requestor role can add or update Spend Lines.");
                return;
            }

            string expHead = PostedValue(ddlExpHead);
            string topic = txtLineTopic.Text.Trim();
            string vendor = PostedValue(ddlLineVendor);
            string costType = PostedValue(ddlLineCostType);
            string currency = PostedValue(ddlLineCcy);
            string glNumber = PostedValue(ddlLineGL);
            decimal units = Dec(txtLineUnits.Text);
            decimal price = Dec(txtLineUnitPrice.Text);
            decimal fcy   = units * price;
            decimal rate  = GetRate(currency);
            decimal lcy   = fcy * rate;
            decimal cont  = Dec(txtLineConting.Text);
            decimal final = lcy * (1 + cont / 100);

            if (string.IsNullOrEmpty(expHead)) expHead = "CAPEX";
            if (string.IsNullOrEmpty(currency)) currency = "AED";
            if (string.IsNullOrEmpty(glNumber)) glNumber = null;
            if (!ValidateLineInput(topic, vendor, costType, units, price)) return;

            int editId;
            if (int.TryParse(hfEditLineId.Value, out editId) && editId > 0)
            {
                // Edit existing line
                WorkflowDAL.UpdatePetLine(
                    editId, "", expHead,
                    topic, vendor,
                    txtLineDesc.Text.Trim(), costType,
                    units, price, currency,
                    fcy, lcy, cont, final,
                    glNumber,
                    "", AuthHelper.CurrentUserShort);
            }
            else
            {
                if (CurrentPetFormId == 0)
                {
                    DataTable stagedLines = GetStagedLines();
                    int stagedId;
                    DataRow stagedRow = null;
                    if (int.TryParse(hfEditLineId.Value, out stagedId) && stagedId < 0)
                        stagedRow = FindLineById(stagedLines, stagedId);
                    if (stagedRow == null)
                    {
                        stagedRow = stagedLines.NewRow();
                        stagedRow["LineID"] = GetNextStagedLineId();
                        stagedLines.Rows.Add(stagedRow);
                    }

                    stagedRow["SerialNo"] = stagedLines.Rows.IndexOf(stagedRow) + 1;
                    stagedRow["Department"] = "";
                    stagedRow["ExpHead"] = expHead;
                    stagedRow["Topic"] = topic;
                    stagedRow["VendorName"] = vendor;
                    stagedRow["Description"] = txtLineDesc.Text.Trim();
                    stagedRow["CostType"] = costType;
                    stagedRow["Units"] = units;
                    stagedRow["UnitPrice"] = price;
                    stagedRow["BaseCurrency"] = currency;
                    stagedRow["AmtFCY"] = fcy;
                    stagedRow["AmtLCY"] = lcy;
                    stagedRow["ContingencyPct"] = cont;
                    stagedRow["FinalAmtLCY"] = final;
                    stagedRow["GLNumber"] = string.IsNullOrEmpty(glNumber) ? (object)DBNull.Value : glNumber;
                    stagedRow["Comments"] = "";
                    RenumberLines(stagedLines);
                }
                else
                {
                    // New persisted line
                    int nextSerial = Convert.ToInt32(Db.Scalar(
                        "SELECT ISNULL(MAX(SerialNo),0)+1 FROM dbo.PetLineItem WHERE PetFormID=@f",
                        Db.P("@f", CurrentPetFormId)));

                    WorkflowDAL.SavePetLine(
                        CurrentPetFormId, nextSerial,
                        "", expHead,
                        topic, vendor,
                        txtLineDesc.Text.Trim(), costType,
                        units, price, currency,
                        fcy, lcy, cont, final,
                        glNumber,
                        "", AuthHelper.CurrentUserShort);
                }
            }

            ClearLineForm();
            BindLines(CurrentPetFormId);
            ShowNextStep(CurrentPetFormId == 0
                ? "Spend line staged. Next: add another line if required, then click Save Request to commit the request and all staged lines."
                : "Line item saved. Next: add another line item if required, or go to Approval and submit the Spend Request.");
        }

        protected void gvLines_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            if (e.CommandName == "DelLine" && CanEditSpendLines)
            {
                int lineId = Convert.ToInt32(e.CommandArgument);
                if (CurrentPetFormId == 0)
                {
                    DataTable stagedLines = GetStagedLines();
                    DataRow stagedRow = FindLineById(stagedLines, lineId);
                    if (stagedRow != null) stagedLines.Rows.Remove(stagedRow);
                    RenumberLines(stagedLines);
                }
                else
                {
                    WorkflowDAL.DeletePetLine(lineId);
                }
                BindLines(CurrentPetFormId);
            }
            else if (e.CommandName == "EditLine" && CanEditSpendLines)
            {
                int lineId = Convert.ToInt32(e.CommandArgument);
                DataRow r = CurrentPetFormId == 0
                    ? FindLineById(GetStagedLines(), lineId)
                    : Db.QueryRow("SELECT * FROM dbo.PetLineItem WHERE LineID=@id", Db.P("@id", lineId));
                if (r == null) return;

                hfEditLineId.Value = lineId.ToString();
                btnSaveLine.Text = "Update Spend Line";
                btnCancelLine.Visible = true;
                SetDdl(ddlExpHead,       r["ExpHead"]     == DBNull.Value ? "CAPEX" : r["ExpHead"].ToString());
                txtLineTopic.Text      = r["Topic"]       == DBNull.Value ? "" : r["Topic"].ToString();
                txtLineDesc.Text       = r["Description"] == DBNull.Value ? "" : r["Description"].ToString();
                SetDdl(ddlLineVendor,   r["VendorName"]   == DBNull.Value ? "" : r["VendorName"].ToString());
                SetDdl(ddlLineCostType, r["CostType"]     == DBNull.Value ? "" : r["CostType"].ToString());
                string gl = r["GLNumber"] == DBNull.Value ? "" : r["GLNumber"].ToString();
                SetDdl(ddlLineGL, gl);
                SetDdl(ddlLineCcy, r["BaseCurrency"] == DBNull.Value ? "AED" : r["BaseCurrency"].ToString());
                txtLineUnits.Text     = r["Units"]         == DBNull.Value ? "1"    : Convert.ToDecimal(r["Units"]).ToString("N2");
                txtLineUnitPrice.Text = r["UnitPrice"]     == DBNull.Value ? "0"    : Convert.ToDecimal(r["UnitPrice"]).ToString("N2");
                txtLineAmtFCY.Text    = r["AmtFCY"]        == DBNull.Value ? "0"    : Convert.ToDecimal(r["AmtFCY"]).ToString("N2");
                txtLineAmtLCY.Text    = r["AmtLCY"]        == DBNull.Value ? "0"    : Convert.ToDecimal(r["AmtLCY"]).ToString("N2");
                txtLineConting.Text   = r["ContingencyPct"]== DBNull.Value ? "0"    : Convert.ToDecimal(r["ContingencyPct"]).ToString("N2");
            }
        }

        protected void gvLines_PageIndexChanging(object sender, System.Web.UI.WebControls.GridViewPageEventArgs e)
        {
            gvLines.PageIndex = e.NewPageIndex;
            BindLines(CurrentPetFormId);
        }

        // ===== Attachments =====
        private void BindAttachments()
        {
            if (CurrentPetFormId <= 0) return;
            DataTable dt = WorkflowDAL.GetAttachments(CurrentPetFormId);
            rptAttachments.DataSource = dt;
            rptAttachments.DataBind();
            pnlAttachments.Visible = true;
        }

        protected void btnUploadAttachment_Click(object sender, EventArgs e)
        {
            if (CurrentPetFormId == 0) { ShowMsg("Save the form header first."); return; }
            if (!fuAttachment.HasFile)  { ShowMsg("Please select a file."); return; }

            string fileName    = System.IO.Path.GetFileName(fuAttachment.FileName);
            string contentType = fuAttachment.PostedFile.ContentType;
            byte[] content     = fuAttachment.FileBytes;

            WorkflowDAL.SaveAttachment(CurrentPetFormId, fileName, contentType, content, AuthHelper.CurrentUserShort);
            BindAttachments();
            ForceHideLoaderScript();
        }

        protected void rptAttachments_ItemCommand(object source, RepeaterCommandEventArgs e)
        {
            if (e.CommandName == "DelAttach" && IsEditable)
            {
                WorkflowDAL.DeleteAttachment(Convert.ToInt32(e.CommandArgument));
                BindAttachments();
            }
        }

        protected void btnSubmitPet_Click(object sender, EventArgs e)
        {
            if (CurrentPetFormId == 0) { ShowMsg("Save the form header first."); return; }
            DataRow f = WorkflowDAL.GetPetForm(CurrentPetFormId);
            if (f == null) { ShowMsg("Spend Request not found."); return; }
            if (f["ApproverUsername"] == DBNull.Value || string.IsNullOrEmpty(Convert.ToString(f["ApproverUsername"])))
            { ShowMsg("Select an Approver in the header above (and Save) before submitting for approval."); return; }
            int lineCount = Convert.ToInt32(Db.Scalar("SELECT COUNT(*) FROM dbo.PetLineItem WHERE PetFormID=@f", Db.P("@f", CurrentPetFormId)));
            if (lineCount == 0) { ShowMsg("Please add at least one line item before submitting."); return; }

            WorkflowDAL.SubmitPet(CurrentPetFormId, AuthHelper.CurrentUserShort, txtSubmitComments.Text.Trim());
            Session["PetNextStep"] = "Spend Request submitted successfully. Next: the reviewer will review it and route it to the approver.";
            Response.Redirect("~/Forms/PetWorkflow.aspx?id=" + CurrentPetFormId);
        }

        // ===== Approval buttons =====
        protected void btnApprove_Click(object sender, EventArgs e)
        {
            DataRow f = WorkflowDAL.GetPetForm(CurrentPetFormId);
            if (f == null) return;
            string status = f["Status"].ToString();
            if (status == "PendingReview")
            {
                WorkflowDAL.ReviewPet(CurrentPetFormId, AuthHelper.CurrentUserShort, "Approve", txtDecisionComments.Text.Trim());
                Session["PetNextStep"] = "Review submitted successfully. Next: the approver will approve or send back this Spend Request.";
            }
            else if (status == "PendingApproval")
            {
                WorkflowDAL.ApprovePet(CurrentPetFormId, AuthHelper.CurrentUserShort, "Approved", txtDecisionComments.Text.Trim());
                Session["PetNextStep"] = "Spend Request approved successfully. Next: the requestor can manage Budget and Invoice details.";
            }
            Response.Redirect("~/Forms/PetWorkflow.aspx?id=" + CurrentPetFormId);
        }

        protected void btnReject_Click(object sender, EventArgs e)
        {
            WorkflowDAL.ApprovePet(CurrentPetFormId, AuthHelper.CurrentUserShort, "Rejected", txtDecisionComments.Text.Trim());
            Session["PetNextStep"] = "Spend Request rejected successfully. Next: the requestor can review the comments and create a revised request if needed.";
            Response.Redirect("~/Forms/PetWorkflow.aspx?id=" + CurrentPetFormId);
        }

        protected void btnSendBack_Click(object sender, EventArgs e)
        {
            DataRow f = WorkflowDAL.GetPetForm(CurrentPetFormId);
            if (f == null) return;
            string status = f["Status"].ToString();
            if (status == "PendingReview")
                WorkflowDAL.ReviewPet(CurrentPetFormId, AuthHelper.CurrentUserShort, "SentBack", txtDecisionComments.Text.Trim());
            else if (status == "PendingApproval")
                WorkflowDAL.ApprovePet(CurrentPetFormId, AuthHelper.CurrentUserShort, "SentBack", txtDecisionComments.Text.Trim());
            Session["PetNextStep"] = "Spend Request sent back successfully. Next: the requestor should update it and submit again.";
            Response.Redirect("~/Forms/PetWorkflow.aspx?id=" + CurrentPetFormId);
        }

        protected void btnDeletePet_Click(object sender, EventArgs e)
        {
            if (CurrentPetFormId <= 0) return;
            // Only the requestor (creator) can delete
            DataRow f = WorkflowDAL.GetPetForm(CurrentPetFormId);
            if (f == null) return;
            if (!string.Equals(f["CreatedBy"].ToString(), AuthHelper.CurrentUserShort, StringComparison.OrdinalIgnoreCase)) return;
            // Server-side guard mirrors the button's visibility rule — only Draft / Pending Review / Pending Approval
            string status = f["Status"] == DBNull.Value ? "" : f["Status"].ToString();
            if (!WorkflowDAL.IsPetDeletable(status)) return;
            WorkflowDAL.DeletePetForm(CurrentPetFormId, AuthHelper.CurrentUserShort);
            Response.Redirect("~/Default.aspx");
        }

        // BPM Hierarchy tab removed — project data now comes from JIRA.

        // ===== Project Sizing (1 per registered Project, shared with Project Registration — editable any time) =====
        protected void btnSizingSave_Click(object sender, EventArgs e)
        {
            string projectId = ddlProject.SelectedValue;
            if (string.IsNullOrEmpty(projectId))
            {
                ShowMsg("Select a registered Project first.");
                return;
            }

            decimal q1, q2, q3, q4, q5, q6, q7;
            if (!decimal.TryParse(Request.Form["sz_hfQ1"], out q1) ||
                !decimal.TryParse(Request.Form["sz_hfQ2"], out q2) ||
                !decimal.TryParse(Request.Form["sz_hfQ3"], out q3) ||
                !decimal.TryParse(Request.Form["sz_hfQ4"], out q4) ||
                !decimal.TryParse(Request.Form["sz_hfQ5"], out q5) ||
                !decimal.TryParse(Request.Form["sz_hfQ6"], out q6) ||
                !decimal.TryParse(Request.Form["sz_hfQ7"], out q7))
            {
                ShowMsg("Please complete all 7 criteria before saving.");
                return;
            }

            decimal weighted = q1 * 0.20m + q2 * 0.20m + q3 * 0.15m + q4 * 0.15m
                             + q5 * 0.15m + q6 * 0.10m + q7 * 0.05m;

            string sizeResult;
            if      (weighted <= 1.5m) sizeResult = "XS";
            else if (weighted <= 2.3m) sizeResult = "S";
            else if (weighted <= 3.2m) sizeResult = "M";
            else if (weighted <= 4.1m) sizeResult = "L";
            else                       sizeResult = "XL";

            string capacityMap;
            switch (sizeResult)
            {
                case "XS": capacityMap = "< 100 hrs";        break;
                case "S":  capacityMap = "100 - 500 hrs";    break;
                case "M":  capacityMap = "500 - 2,000 hrs";  break;
                case "L":  capacityMap = "2,000 - 5,000 hrs"; break;
                default:   capacityMap = "> 5,000 hrs";       break;
            }

            ProjectDAL.SaveProjectSizing(projectId, q1, q2, q3, q4, q5, q6, q7,
                weighted, sizeResult, capacityMap, AuthHelper.CurrentUserShort);

            ActiveTab = "sizing";
            hfActiveTab.Value = "sizing";
            LoadSizingForProject(projectId);
            ShowNextStep("Sizing saved. Size: " + sizeResult + "  (Weighted score: " + weighted.ToString("F4") + "). Next: continue the Spend Request details or submit for approval when line items are ready.");
        }

        /// <summary>Loads the single (upsert-model) sizing record for a registered Project -- shared 1:1 with
        /// Project Registration's own Sizing tab, so whichever screen last saved it is what both screens show.
        /// Pre-selects the saved radio answers via JS so re-opening shows exactly what was previously chosen.</summary>
        private void LoadSizingForProject(string projectId)
        {
            if (string.IsNullOrEmpty(projectId)) return;
            DataRow sz = ProjectDAL.GetProjectSizing(projectId);
            if (sz == null) return;

            string sr = sz["SizeResult"] == DBNull.Value ? "" : sz["SizeResult"].ToString();
            decimal ws = sz["TotalWeightedScore"] == DBNull.Value ? 0m : Convert.ToDecimal(sz["TotalWeightedScore"]);
            if (!string.IsNullOrEmpty(sr))
            {
                litSizingResultBadge.Text =
                    "<span class='ps-size-badge size-" + sr.ToLower() + "'>" + Server.HtmlEncode(sr) + "</span>" +
                    " <small style='color:#64748b;'>Score: " + ws.ToString("F4") + "</small>";
                litProjectSize.Text =
                    "<span class='ps-size-badge size-" + sr.ToLower() + "'>" + Server.HtmlEncode(sr) + "</span>";
            }

            string scores = string.Format("{0},{1},{2},{3},{4},{5},{6}",
                sz["Q1Score"] == DBNull.Value ? "0" : sz["Q1Score"].ToString(),
                sz["Q2Score"] == DBNull.Value ? "0" : sz["Q2Score"].ToString(),
                sz["Q3Score"] == DBNull.Value ? "0" : sz["Q3Score"].ToString(),
                sz["Q4Score"] == DBNull.Value ? "0" : sz["Q4Score"].ToString(),
                sz["Q5Score"] == DBNull.Value ? "0" : sz["Q5Score"].ToString(),
                sz["Q6Score"] == DBNull.Value ? "0" : sz["Q6Score"].ToString(),
                sz["Q7Score"] == DBNull.Value ? "0" : sz["Q7Score"].ToString());

            string script = string.Format(
                "var _szEdit=[{0}];" +
                "for(var q=1;q<=7;q++){{" +
                "  var radios=document.getElementsByName('sz_q'+q);" +
                "  for(var i=0;i<radios.length;i++){{" +
                "    if(parseFloat(radios[i].value)===_szEdit[q-1]){{radios[i].checked=true;break;}}" +
                "  }}" +
                "}}" +
                "if(typeof szScore==='function')szScore();", scores);
            ClientScript.RegisterStartupScript(this.GetType(), "szLoadSaved", script, true);
        }

        // ===== Helpers =====
        private void ShowMsg(string msg) { lblMsg.Text = msg; lblMsg.CssClass = "alert alert-info"; lblMsg.Visible = true; }

        private void ShowNextStep(string msg)
        {
            lblMsg.Text = msg;
            lblMsg.CssClass = "next-step-message";
            lblMsg.Visible = true;
            string safe = System.Web.HttpUtility.JavaScriptStringEncode(msg);
            string script = "(function(){var t=document.createElement('div');t.className='next-step-toast';t.innerHTML='" + safe + "';document.body.appendChild(t);setTimeout(function(){if(t&&t.parentNode)t.parentNode.removeChild(t);},7000);})();";
            ScriptManager.RegisterStartupScript(this, GetType(), "nextStepToast" + DateTime.Now.Ticks.ToString(), script, true);
        }

        /// <summary>
        /// Defensive fix for the "loader overlay stuck after file upload" issue: file-upload postbacks
        /// (CSV import, attachments) can be slow, and — since this app has no ScriptManager/UpdatePanel —
        /// nothing guarantees the loader hides again on some browsers (e.g. bfcache restores). Explicitly
        /// force it closed once the new response has finished loading, instead of requiring a manual refresh.
        /// </summary>
        private void ForceHideLoaderScript()
        {
            ClientScript.RegisterStartupScript(this.GetType(), "forceHideLoader",
                "window.addEventListener('load', function(){ if (typeof hideLoader === 'function') hideLoader(); });", true);
        }

        private static void SetDdl(DropDownList ddl, DataRow row, string col)
        {
            if (row == null || row[col] == DBNull.Value) return;
            string v = row[col].ToString();
            var item = ddl.Items.FindByValue(v);
            if (item != null) ddl.SelectedValue = v;
        }

        private static void SetDdl(DropDownList ddl, string value)
        {
            var item = ddl.Items.FindByValue(value ?? "");
            if (item != null) ddl.SelectedValue = value;
        }

        private static decimal Dec(DataRow r, string col)
        {
            if (r[col] == DBNull.Value) return 0m;
            decimal v; return decimal.TryParse(r[col].ToString(), out v) ? v : 0m;
        }
        private static decimal Dec(string s) { decimal v; return decimal.TryParse(s ?? "0", out v) ? v : 0m; }

        private decimal GetRate(string code)
        {
            DataRow r = Db.QueryRow("SELECT RateToLocal FROM dbo.PetCurrency WHERE Code=@c", Db.P("@c", code));
            if (r == null) return 1m;
            decimal v; return decimal.TryParse(r["RateToLocal"].ToString(), out v) ? v : 1m;
        }

        // ===================================================================
        // CSV IMPORT – PET Form.csv
        // Columns: Department,ID,Exp. Head,Topic,Vendor,Description,Cost Type,
        //          Unit Type,Unit(s),Unit Price,Base CY,Amt. FCY,Amt. LCY,
        //          Cont. %,Final Amt LCY,Yearly Recurrence
        // ===================================================================
        protected void btnImportPetCsv_Click(object sender, EventArgs e)
        {
            ActiveTab = "import";
            int petId = CurrentPetFormId;
            if (petId <= 0) { lblImportStatus.Text = "Save the PET header first before importing lines."; return; }
            if (!fuPetCsv.HasFile || !fuPetCsv.FileName.ToLower().EndsWith(".csv"))
            { lblImportStatus.Text = "Please select a valid .csv file."; return; }

            try
            {
                var lines = new System.IO.StreamReader(fuPetCsv.FileContent).ReadToEnd()
                    .Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);

                var preview = new DataTable();
                foreach (var h in new[] { "Department","ExpHead","Topic","Vendor","Description","CostType","Units","UnitPrice","BaseCY","AmtFCY","AmtLCY","ContPct","FinalAmtLCY","Recurrence" })
                    preview.Columns.Add(h);

                int imported = 0, skipped = 0;
                int serialNo = 1;
                bool headerParsed = false;
                int[] colIdx = null;

                foreach (var rawLine in lines)
                {
                    var cols = SplitCsvLine(rawLine);

                    // Auto-detect header row
                    if (!headerParsed)
                    {
                        if (cols.Count >= 10 && cols[0].ToLower().Contains("dept") ||
                            (cols.Count >= 5 && cols[1].ToLower() == "id"))
                        {
                            colIdx = new int[16];
                            for (int i = 0; i < cols.Count; i++)
                            {
                                string h = cols[i].ToLower().Trim();
                                if (h.Contains("dept"))             colIdx[0] = i;
                                else if (h == "id")                 colIdx[1] = i;
                                else if (h.Contains("exp"))         colIdx[2] = i;
                                else if (h.Contains("topic"))       colIdx[3] = i;
                                else if (h.Contains("vendor"))      colIdx[4] = i;
                                else if (h.Contains("desc"))        colIdx[5] = i;
                                else if (h.Contains("cost"))        colIdx[6] = i;
                                else if (h.Contains("unit t"))      colIdx[7] = i;
                                else if (h == "unit(s)" || h == "units") colIdx[8] = i;
                                else if (h.Contains("price"))       colIdx[9] = i;
                                else if (h.Contains("base"))        colIdx[10] = i;
                                else if (h.Contains("fcy"))         colIdx[11] = i;
                                else if (h.Contains("lcy") && !h.Contains("final")) colIdx[12] = i;
                                else if (h.Contains("cont"))        colIdx[13] = i;
                                else if (h.Contains("final"))       colIdx[14] = i;
                                else if (h.Contains("recurr"))      colIdx[15] = i;
                            }
                            headerParsed = true;
                            continue;
                        }
                        else { headerParsed = true; } // no header row; treat as data from col 0
                    }

                    if (cols.Count < 5) { skipped++; continue; }

                    string dept    = colIdx != null ? SafeCol(cols, colIdx[0]) : "";
                    string expHead = colIdx != null ? SafeCol(cols, colIdx[2]) : SafeCol(cols, 2);
                    string topic   = colIdx != null ? SafeCol(cols, colIdx[3]) : SafeCol(cols, 3);
                    string vendor  = colIdx != null ? SafeCol(cols, colIdx[4]) : SafeCol(cols, 4);
                    string desc    = colIdx != null ? SafeCol(cols, colIdx[5]) : SafeCol(cols, 5);
                    string costTy  = colIdx != null ? SafeCol(cols, colIdx[6]) : SafeCol(cols, 6);
                    string units   = colIdx != null ? SafeCol(cols, colIdx[8]) : SafeCol(cols, 8);
                    string uPrice  = colIdx != null ? SafeCol(cols, colIdx[9]) : SafeCol(cols, 9);
                    string baseCy  = colIdx != null ? SafeCol(cols, colIdx[10]) : SafeCol(cols, 10);
                    string amtFcy  = colIdx != null ? SafeCol(cols, colIdx[11]) : SafeCol(cols, 11);
                    string amtLcy  = colIdx != null ? SafeCol(cols, colIdx[12]) : SafeCol(cols, 12);
                    string contPct = colIdx != null ? SafeCol(cols, colIdx[13]) : SafeCol(cols, 13);
                    string final   = colIdx != null ? SafeCol(cols, colIdx[14]) : SafeCol(cols, 14);
                    string recur   = colIdx != null ? SafeCol(cols, colIdx[15]) : SafeCol(cols, 15);

                    // Skip blank rows
                    if (string.IsNullOrWhiteSpace(expHead) && string.IsNullOrWhiteSpace(desc) &&
                        string.IsNullOrWhiteSpace(amtLcy)) { skipped++; continue; }

                    WorkflowDAL.SavePetLine(
                        petId, serialNo++,
                        dept, expHead, topic, vendor, desc, costTy,
                        Dec(units), Dec(uPrice), string.IsNullOrEmpty(baseCy) ? "AED" : baseCy,
                        Dec(amtFcy), Dec(amtLcy), Dec(contPct), Dec(final),
                        null, recur, AuthHelper.CurrentUserShort);

                    preview.Rows.Add(dept, expHead, topic, vendor, desc, costTy, units, uPrice, baseCy, amtFcy, amtLcy, contPct, final, recur);
                    imported++;
                }

                lblImportStatus.Text = string.Format("Imported {0} lines, skipped {1}.", imported, skipped);
                pnlImportPreview.Visible = (preview.Rows.Count > 0);
                gvImportPreview.DataSource = preview;
                gvImportPreview.DataBind();
                BindLines(petId); // refresh grid
            }
            catch (Exception ex)
            {
                lblImportStatus.Text = "Error: " + ex.Message;
            }
            ForceHideLoaderScript();
        }

        protected void btnDownloadTemplate_Click(object sender, EventArgs e)
        {
            Response.Clear();
            Response.ContentType = "text/csv";
            Response.AddHeader("Content-Disposition", "attachment; filename=PET_Form_Template.csv");
            Response.Write("Department,ID,Exp. Head,Topic,Vendor,Description,Cost Type,Unit Type,Unit(s),Unit Price,Base CY,Amt. FCY,Amt. LCY,Cont. %,Final Amt LCY,Yearly Recurrence\r\n");
            Response.Write("IT Dept,1,Hardware,Laptops,Dell,Dell Laptop 16G,Capex,PC,10,5000,AED,50000,50000,5,52500,No\r\n");
            Response.End();
        }

        protected void btnExportPetLines_Click(object sender, EventArgs e)
        {
            if (CurrentPetFormId <= 0) return;
            ExcelHelper.ExportCsv(WorkflowDAL.GetPetLines(CurrentPetFormId),
                "PET_Lines_" + SafeFileName(PetRefNo ?? CurrentPetFormId.ToString()), Response);
        }

        // ===================================================================
        // BUDGET LINE ITEMS  (available once the PET is Approved)
        // ===================================================================

        private void BindBudgetLines(int petFormId)
        {
            DataTable dt = WorkflowDAL.GetBudgetLines(petFormId);
            gvBudgetLines.DataSource = dt;
            gvBudgetLines.DataBind();
            litBudgetLineCount.Text = dt.Rows.Count.ToString();
            decimal totCost = 0, totInv = 0;
            foreach (DataRow r in dt.Rows) { totCost += Dec(r, "Cost"); totInv += Dec(r, "InvoiceTotal"); }
            litBudgetTotalCost.Text      = totCost.ToString("N2");
            litBudgetTotalInvoiced.Text  = totInv.ToString("N2");
            BindAllInvoices(petFormId);
        }

        /// <summary>Persistent (non-modal) grid of every invoice raised against any Budget Line under this PET —
        /// shown directly beneath the Budget Lines table so invoices are visible without opening a popup.</summary>
        private void BindAllInvoices(int petFormId)
        {
            gvAllInvoices.DataSource = WorkflowDAL.GetBudgetInvoicesForPet(petFormId);
            gvAllInvoices.DataBind();
        }

        protected void btnAddBudgetLine_Click(object sender, EventArgs e)
        {
            if (!CanManageBudget) return;
            hfEditBudgetLineId.Value = "";
            litBudgetModalTitle.Text = "New Budget Row";
            txtBgtJustification.Text = "";
            txtBgtCost.Text = "0";
            txtBgtPetRef.Text = PetRefNo;
            txtBgtCamId.Text = txtBgtCamStatus.Text = txtBgtCamComments.Text = "";
            txtBgtLpoRequest.Text = txtBgtLpoStatus.Text = txtBgtLpoComments.Text = "";
            txtBgtVendor.Text = "";
            txtBgtGL.Text = "";
            if (ddlBgtCcy.Items.FindByValue("AED") != null) ddlBgtCcy.SelectedValue = "AED";
            ActiveTab = "budget"; hfActiveTab.Value = "budget";
            ScriptManager.RegisterStartupScript(this, GetType(), "showBudgetModal",
                "$(function(){ $('#budgetLineModal').modal('show'); });", true);
        }

        protected void btnSaveBudgetLine_Click(object sender, EventArgs e)
        {
            if (!CanManageBudget)
            {
                if (HostCloseOnInnerModalClose) RegisterCloseHostFrameScript();
                return;
            }
            if (CurrentPetFormId == 0) { ShowMsg("Save the PET header first."); return; }
            decimal cost = Dec(txtBgtCost.Text);
            string vendor = txtBgtVendor.Text.Trim();
            string gl = txtBgtGL.Text.Trim();
            if (gl == "") gl = null;

            int editId;
            if (int.TryParse(hfEditBudgetLineId.Value, out editId) && editId > 0)
            {
                WorkflowDAL.UpdateBudgetLine(editId, vendor, txtBgtJustification.Text.Trim(),
                    cost, ddlBgtCcy.SelectedValue, gl, txtBgtPetRef.Text.Trim(),
                    txtBgtCamId.Text.Trim(), txtBgtCamStatus.Text.Trim(), txtBgtCamComments.Text.Trim(),
                    txtBgtLpoRequest.Text.Trim(), txtBgtLpoStatus.Text.Trim(), txtBgtLpoComments.Text.Trim(),
                    AuthHelper.CurrentUserShort);
            }
            else
            {
                int nextSerial = Convert.ToInt32(Db.Scalar(
                    "SELECT ISNULL(MAX(SerialNo),0)+1 FROM dbo.PetBudgetLine WHERE PetFormID=@f", Db.P("@f", CurrentPetFormId)));
                WorkflowDAL.SaveBudgetLine(CurrentPetFormId, nextSerial, vendor, txtBgtJustification.Text.Trim(),
                    cost, ddlBgtCcy.SelectedValue, gl, txtBgtPetRef.Text.Trim(),
                    txtBgtCamId.Text.Trim(), txtBgtCamStatus.Text.Trim(), txtBgtCamComments.Text.Trim(),
                    txtBgtLpoRequest.Text.Trim(), txtBgtLpoStatus.Text.Trim(), txtBgtLpoComments.Text.Trim(),
                    AuthHelper.CurrentUserShort);
            }

            hfEditBudgetLineId.Value = "";
            ActiveTab = "budget"; hfActiveTab.Value = "budget";
            BindBudgetLines(CurrentPetFormId);
            if (HostCloseOnInnerModalClose)
            {
                RegisterCloseHostFrameScript();
                return;
            }
            ShowNextStep("Budget row saved. Next: add or update invoice details for this budget line when available.");
        }

        protected void gvBudgetLines_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            ActiveTab = "budget"; hfActiveTab.Value = "budget";

            if (e.CommandName == "ManageInvoices")
            {
                OpenInvoiceModal(Convert.ToInt32(e.CommandArgument));
                return;
            }

            if (!CanManageBudget) return;

            if (e.CommandName == "DelBudget")
            {
                WorkflowDAL.DeleteBudgetLine(Convert.ToInt32(e.CommandArgument));
                BindBudgetLines(CurrentPetFormId);
            }
            else if (e.CommandName == "PopupEdit")
            {
                OpenBudgetLineEditor(Convert.ToInt32(e.CommandArgument));
            }
        }

        private void OpenDeepLinkEditor()
        {
            int invoiceId = QueryInt("invoiceId");
            int invoiceLineId = QueryInt("invoiceLine", "invoiceLineId");
            if (invoiceLineId <= 0 && invoiceId > 0)
                invoiceLineId = QueryInt("budgetLine", "budgetLineId");
            if (invoiceLineId > 0)
            {
                ActiveTab = "budget";
                hfActiveTab.Value = "budget";
                OpenInvoiceModal(invoiceLineId, invoiceId);
                return;
            }

            int budgetLineId = QueryInt("budgetLine", "budgetLineId");
            if (budgetLineId > 0)
            {
                ActiveTab = "budget";
                hfActiveTab.Value = "budget";
                if (!OpenBudgetLineEditor(budgetLineId))
                    RegisterCloseHostFrameScript();
            }
        }

        private void RegisterCloseHostFrameScript()
        {
            ScriptManager.RegisterStartupScript(this, GetType(), "closeHostFrame",
                "(function(){ try { if (window.parent && window.parent !== window && window.parent.prCloseDetailFrame) { window.parent.prCloseDetailFrame(); } else if (window.parent && window.parent !== window && window.parent.jQuery) { window.parent.jQuery('#projectSpendRequestModal').modal('hide'); } } catch (e) { } })();", true);
        }

        private int QueryInt(params string[] names)
        {
            for (int i = 0; i < names.Length; i++)
            {
                int value;
                if (int.TryParse(Request.QueryString[names[i]], out value) && value > 0)
                    return value;
            }
            return 0;
        }

        private bool OpenBudgetLineEditor(int budgetLineId)
        {
            DataRow r = WorkflowDAL.GetBudgetLine(budgetLineId);
            if (r == null) return false;

            hfEditBudgetLineId.Value = budgetLineId.ToString();
            litBudgetModalTitle.Text = (CanManageBudget ? "Edit" : "View") + " Budget Row #" + (r["SerialNo"] == DBNull.Value ? budgetLineId.ToString() : r["SerialNo"].ToString());
            txtBgtVendor.Text = r["VendorName"] == DBNull.Value ? "" : r["VendorName"].ToString();
            txtBgtJustification.Text = r["Justification"] == DBNull.Value ? "" : r["Justification"].ToString();
            txtBgtCost.Text = Dec(r, "Cost").ToString("N2");
            SetDdl(ddlBgtCcy, r["Currency"] == DBNull.Value ? "AED" : r["Currency"].ToString());
            txtBgtGL.Text = r["GLNumber"] == DBNull.Value ? "" : r["GLNumber"].ToString();
            txtBgtPetRef.Text       = r["PetRef"]      == DBNull.Value ? "" : r["PetRef"].ToString();
            txtBgtCamId.Text        = r["CamId"]       == DBNull.Value ? "" : r["CamId"].ToString();
            txtBgtCamStatus.Text    = r["CamStatus"]   == DBNull.Value ? "" : r["CamStatus"].ToString();
            txtBgtCamComments.Text  = r["CamComments"] == DBNull.Value ? "" : r["CamComments"].ToString();
            txtBgtLpoRequest.Text   = r["LpoRequest"]  == DBNull.Value ? "" : r["LpoRequest"].ToString();
            txtBgtLpoStatus.Text    = r["LpoStatus"]   == DBNull.Value ? "" : r["LpoStatus"].ToString();
            txtBgtLpoComments.Text  = r["LpoComments"] == DBNull.Value ? "" : r["LpoComments"].ToString();
            ApplyBudgetLineModalEditableState();

            ScriptManager.RegisterStartupScript(this, GetType(), "showBudgetModal",
                "$(function(){ $('#budgetLineModal').modal('show'); });", true);
            return true;
        }

        private void ApplyBudgetLineModalEditableState()
        {
            bool editable = CanManageBudget;
            txtBgtVendor.ReadOnly = !editable;
            txtBgtJustification.ReadOnly = !editable;
            txtBgtCost.ReadOnly = !editable;
            ddlBgtCcy.Enabled = editable;
            txtBgtGL.ReadOnly = !editable;
            txtBgtPetRef.ReadOnly = !editable;
            txtBgtCamId.ReadOnly = !editable;
            txtBgtCamStatus.ReadOnly = !editable;
            txtBgtCamComments.ReadOnly = !editable;
            txtBgtLpoRequest.ReadOnly = !editable;
            txtBgtLpoStatus.ReadOnly = !editable;
            txtBgtLpoComments.ReadOnly = !editable;
            btnSaveBudgetLine.Visible = editable;
        }

        protected void gvBudgetLines_RowEditing(object sender, GridViewEditEventArgs e)
        {
            if (!CanManageBudget) return;
            gvBudgetLines.EditIndex = e.NewEditIndex;
            ActiveTab = "budget"; hfActiveTab.Value = "budget";
            BindBudgetLines(CurrentPetFormId);
        }

        protected void gvBudgetLines_RowCancelingEdit(object sender, GridViewCancelEditEventArgs e)
        {
            gvBudgetLines.EditIndex = -1;
            ActiveTab = "budget"; hfActiveTab.Value = "budget";
            BindBudgetLines(CurrentPetFormId);
        }

        protected void gvBudgetLines_RowUpdating(object sender, GridViewUpdateEventArgs e)
        {
            if (!CanManageBudget) return;
            GridViewRow row = gvBudgetLines.Rows[e.RowIndex];
            int id = Convert.ToInt32(gvBudgetLines.DataKeys[e.RowIndex].Value);

            string vendor      = ((TextBox)row.FindControl("txtEVendor")).Text.Trim();
            string just        = ((TextBox)row.FindControl("txtEJustification")).Text.Trim();
            decimal cost       = Dec(((TextBox)row.FindControl("txtECost")).Text);
            string ccy         = ((TextBox)row.FindControl("txtECcy")).Text.Trim();
            string gl          = ((TextBox)row.FindControl("txtEGL")).Text.Trim();
            string petRef      = ((TextBox)row.FindControl("txtEPetRef")).Text.Trim();
            string camId       = ((TextBox)row.FindControl("txtECamId")).Text.Trim();
            string camStatus   = ((TextBox)row.FindControl("txtECamStatus")).Text.Trim();
            string camComments = ((TextBox)row.FindControl("txtECamComments")).Text.Trim();
            string lpoRequest  = ((TextBox)row.FindControl("txtELpoRequest")).Text.Trim();
            string lpoStatus   = ((TextBox)row.FindControl("txtELpoStatus")).Text.Trim();
            string lpoComments = ((TextBox)row.FindControl("txtELpoComments")).Text.Trim();

            WorkflowDAL.UpdateBudgetLine(id, vendor, just, cost,
                string.IsNullOrEmpty(ccy) ? "AED" : ccy, string.IsNullOrEmpty(gl) ? null : gl,
                petRef, camId, camStatus, camComments, lpoRequest, lpoStatus, lpoComments,
                AuthHelper.CurrentUserShort);

            gvBudgetLines.EditIndex = -1;
            ActiveTab = "budget"; hfActiveTab.Value = "budget";
            BindBudgetLines(CurrentPetFormId);
        }

        // ===== Budget Invoices (multiple invoices per Budget Line — managed via a popup opened from the "Invoices" link) =====

        private void OpenInvoiceModal(int budgetLineId)
        {
            OpenInvoiceModal(budgetLineId, 0);
        }

        private void OpenInvoiceModal(int budgetLineId, int editInvoiceId)
        {
            hfActiveBudgetLineId.Value = budgetLineId.ToString();
            DataRow bl = WorkflowDAL.GetBudgetLine(budgetLineId);
            litInvoiceModalVendor.Text = bl != null && bl["VendorName"] != DBNull.Value
                ? Server.HtmlEncode(bl["VendorName"].ToString()) : "";
            litInvoiceModalJustification.Text = bl != null && bl["Justification"] != DBNull.Value
                ? Server.HtmlEncode(bl["Justification"].ToString()) : "";
            litInvoiceModalGL.Text = bl != null && bl["GLNumber"] != DBNull.Value
                ? Server.HtmlEncode(bl["GLNumber"].ToString()) : "";
            DataTable invoices = WorkflowDAL.GetBudgetInvoices(budgetLineId);
            if (editInvoiceId > 0 && CanManageBudget)
                gvInvoices.EditIndex = FindInvoiceEditIndex(invoices, editInvoiceId);
            gvInvoices.DataSource = invoices;
            gvInvoices.DataBind();
            BindBudgetLines(CurrentPetFormId);
            ActiveTab = "budget"; hfActiveTab.Value = "budget";
            ScriptManager.RegisterStartupScript(this, GetType(), "showInvoiceModal",
                "$(function(){ $('#invoiceModal').modal('show'); });", true);
        }

        private int FindInvoiceEditIndex(DataTable invoices, int invoiceId)
        {
            if (invoices == null) return -1;
            for (int i = 0; i < invoices.Rows.Count; i++)
            {
                if (invoices.Rows[i]["InvoiceID"] != DBNull.Value && Convert.ToInt32(invoices.Rows[i]["InvoiceID"]) == invoiceId)
                    return i;
            }
            return -1;
        }

        private void BindInvoicesForLine(int budgetLineId)
        {
            gvInvoices.DataSource = WorkflowDAL.GetBudgetInvoices(budgetLineId);
            gvInvoices.DataBind();
        }

        protected void gvAllInvoices_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            ActiveTab = "budget"; hfActiveTab.Value = "budget";
            if (e.CommandName == "ManageInvoices")
                OpenInvoiceModal(Convert.ToInt32(e.CommandArgument));
        }

        protected void gvInvoices_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            if (!CanManageBudget) return;
            int budgetLineId;
            int.TryParse(hfActiveBudgetLineId.Value, out budgetLineId);
            if (budgetLineId <= 0) return;

            if (e.CommandName == "AddInvoice")
            {
                // The Add controls live in whichever template actually rendered the command — FooterTemplate
                // when invoices already exist, EmptyDataTemplate when this is the first invoice for the line.
                // gvInvoices.FooterRow is null in the latter case, so resolve via the command source's own
                // NamingContainer instead (works for both templates).
                Control src = ((Control)e.CommandSource).NamingContainer;
                TextBox txtNo   = (TextBox)src.FindControl("txtNewInvNo");
                TextBox txtAmt  = (TextBox)src.FindControl("txtNewInvAmount");
                DropDownList ddlSt = (DropDownList)src.FindControl("ddlNewInvStatus");
                TextBox txtDate = (TextBox)src.FindControl("txtNewInvPaymentDate");

                DateTime? payDate = null;
                DateTime dt;
                if (DateTime.TryParse(txtDate.Text, out dt)) payDate = dt;

                WorkflowDAL.SaveBudgetInvoice(budgetLineId, txtNo.Text.Trim(), Dec(txtAmt.Text),
                    ddlSt.SelectedValue, payDate, AuthHelper.CurrentUserShort);

                OpenInvoiceModal(budgetLineId);
            }
            else if (e.CommandName == "DelInvoice")
            {
                WorkflowDAL.DeleteBudgetInvoice(Convert.ToInt32(e.CommandArgument));
                OpenInvoiceModal(budgetLineId);
            }
        }

        protected void gvInvoices_RowEditing(object sender, GridViewEditEventArgs e)
        {
            if (!CanManageBudget) return;
            gvInvoices.EditIndex = e.NewEditIndex;
            int budgetLineId;
            int.TryParse(hfActiveBudgetLineId.Value, out budgetLineId);
            if (budgetLineId > 0) OpenInvoiceModal(budgetLineId);
        }

        protected void gvInvoices_RowCancelingEdit(object sender, GridViewCancelEditEventArgs e)
        {
            gvInvoices.EditIndex = -1;
            int budgetLineId;
            int.TryParse(hfActiveBudgetLineId.Value, out budgetLineId);
            if (budgetLineId > 0) OpenInvoiceModal(budgetLineId);
        }

        protected void gvInvoices_RowUpdating(object sender, GridViewUpdateEventArgs e)
        {
            if (!CanManageBudget) return;
            int invoiceId = Convert.ToInt32(gvInvoices.DataKeys[e.RowIndex].Value);
            GridViewRow row = gvInvoices.Rows[e.RowIndex];

            string invNo      = ((TextBox)row.FindControl("txtEInvNo")).Text.Trim();
            decimal amt        = Dec(((TextBox)row.FindControl("txtEInvAmount")).Text);
            string status      = ((DropDownList)row.FindControl("ddlEInvStatus")).SelectedValue;
            string dateTxt     = ((TextBox)row.FindControl("txtEInvPaymentDate")).Text.Trim();
            DateTime? payDate = null;
            DateTime dt;
            if (DateTime.TryParse(dateTxt, out dt)) payDate = dt;

            WorkflowDAL.UpdateBudgetInvoice(invoiceId, invNo, amt, status, payDate, AuthHelper.CurrentUserShort);

            gvInvoices.EditIndex = -1;
            int budgetLineId;
            int.TryParse(hfActiveBudgetLineId.Value, out budgetLineId);
            if (budgetLineId > 0) OpenInvoiceModal(budgetLineId);
        }

        // ===================================================================
        // CSV IMPORT / EXPORT / TEMPLATE — Budget Lines
        // Columns: Vendor,Justification,Cost,Currency,GL,PetRef,CamId,CamStatus,
        //          CamComments,LpoRequest,LpoStatus,LpoComments
        // ===================================================================
        protected void btnImportBudgetCsv_Click(object sender, EventArgs e)
        {
            if (!CanManageBudget) return;
            ActiveTab = "budget"; hfActiveTab.Value = "budget";
            int petId = CurrentPetFormId;
            if (petId <= 0) { lblBudgetImportStatus.Text = "Save the PET header first."; return; }
            if (!fuBudgetCsv.HasFile || !fuBudgetCsv.FileName.ToLower().EndsWith(".csv"))
            { lblBudgetImportStatus.Text = "Please select a valid .csv file."; return; }

            try
            {
                var lines = new System.IO.StreamReader(fuBudgetCsv.FileContent).ReadToEnd()
                    .Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);

                var preview = new DataTable();
                foreach (var h in new[] { "Vendor", "Justification", "Cost", "Currency", "GL", "PetRef",
                                           "CamId", "CamStatus", "CamComments", "LpoRequest", "LpoStatus", "LpoComments" })
                    preview.Columns.Add(h);

                int serialNo = Convert.ToInt32(Db.Scalar(
                    "SELECT ISNULL(MAX(SerialNo),0)+1 FROM dbo.PetBudgetLine WHERE PetFormID=@f", Db.P("@f", petId)));
                int imported = 0, skipped = 0;
                bool headerParsed = false;

                foreach (var rawLine in lines)
                {
                    var cols = SplitCsvLine(rawLine);

                    if (!headerParsed)
                    {
                        headerParsed = true;
                        if (cols.Count > 0 && cols[0].Trim().ToLower() == "vendor") continue; // skip header row
                    }

                    if (cols.Count < 2) { skipped++; continue; }

                    string vendor      = SafeCol(cols, 0);
                    string justif      = SafeCol(cols, 1);
                    string cost        = SafeCol(cols, 2);
                    string ccy         = SafeCol(cols, 3);
                    string gl          = SafeCol(cols, 4);
                    string petRef      = SafeCol(cols, 5);
                    string camId       = SafeCol(cols, 6);
                    string camStatus   = SafeCol(cols, 7);
                    string camComments = SafeCol(cols, 8);
                    string lpoRequest  = SafeCol(cols, 9);
                    string lpoStatus   = SafeCol(cols, 10);
                    string lpoComments = SafeCol(cols, 11);

                    if (string.IsNullOrWhiteSpace(vendor) && string.IsNullOrWhiteSpace(justif) && string.IsNullOrWhiteSpace(cost))
                    { skipped++; continue; }

                    WorkflowDAL.SaveBudgetLine(petId, serialNo++, vendor, justif, Dec(cost),
                        string.IsNullOrEmpty(ccy) ? "AED" : ccy, string.IsNullOrEmpty(gl) ? null : gl,
                        petRef, camId, camStatus, camComments, lpoRequest, lpoStatus, lpoComments,
                        AuthHelper.CurrentUserShort);

                    preview.Rows.Add(vendor, justif, cost, ccy, gl, petRef, camId, camStatus, camComments, lpoRequest, lpoStatus, lpoComments);
                    imported++;
                }

                lblBudgetImportStatus.Text = string.Format("Imported {0} rows, skipped {1}.", imported, skipped);
                pnlBudgetImportPreview.Visible = preview.Rows.Count > 0;
                gvBudgetImportPreview.DataSource = preview;
                gvBudgetImportPreview.DataBind();
                BindBudgetLines(petId);
            }
            catch (Exception ex)
            {
                lblBudgetImportStatus.Text = "Error: " + ex.Message;
            }
            ForceHideLoaderScript();
        }

        protected void btnDownloadBudgetTemplate_Click(object sender, EventArgs e)
        {
            Response.Clear();
            Response.ContentType = "text/csv";
            Response.AddHeader("Content-Disposition", "attachment; filename=Budget_Line_Template.csv");
            Response.Write("Vendor,Justification,Cost,Currency,GL,PetRef,CamId,CamStatus,CamComments,LpoRequest,LpoStatus,LpoComments\r\n");
            Response.Write("HPS,Annual license renewal,50000,AED,124356789,PET-0001,131111,Approved,Approved,1231,Issued,Issued\r\n");
            Response.End();
        }

        protected void btnExportBudgetLines_Click(object sender, EventArgs e)
        {
            if (CurrentPetFormId <= 0) return;
            ExcelHelper.ExportCsv(WorkflowDAL.GetBudgetLines(CurrentPetFormId),
                "Budget_Lines_" + SafeFileName(PetRefNo ?? CurrentPetFormId.ToString()), Response);
        }

        protected void btnExportInvoices_Click(object sender, EventArgs e)
        {
            if (CurrentPetFormId <= 0) return;
            ExcelHelper.ExportCsv(WorkflowDAL.GetBudgetInvoicesForPet(CurrentPetFormId),
                "Invoices_" + SafeFileName(PetRefNo ?? CurrentPetFormId.ToString()), Response);
        }

        /// <summary>Strips characters that are unsafe for use in a Content-Disposition filename.</summary>
        private static string SafeFileName(string s)
        {
            if (string.IsNullOrEmpty(s)) return "Export";
            var sb = new System.Text.StringBuilder();
            foreach (char c in s) sb.Append(char.IsLetterOrDigit(c) || c == '-' || c == '_' ? c : '_');
            return sb.ToString();
        }

        private static string SafeCol(System.Collections.Generic.List<string> cols, int idx)
        {
            return (idx >= 0 && idx < cols.Count) ? cols[idx].Trim() : "";
        }

        private static System.Collections.Generic.List<string> SplitCsvLine(string line)
        {
            var result = new System.Collections.Generic.List<string>();
            bool inQuotes = false;
            var current = new System.Text.StringBuilder();
            foreach (char c in line)
            {
                if (c == '"') { inQuotes = !inQuotes; }
                else if (c == ',' && !inQuotes) { result.Add(current.ToString()); current.Clear(); }
                else { current.Append(c); }
            }
            result.Add(current.ToString());
            return result;
        }
    }
}


