using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading.Tasks;
using System.Web;
using System.Web.Http;
using DFM.Web.Infrastructure;
using DFM.Web.Models;

namespace DFM.Web.Controllers
{
    [ApiAuthorize, RoutePrefix("api/portfolio")]
    public class PortfolioController : ApiController
    {
        private static readonly string[] DepartmentOptions = { "Business", "CET", "CIO Office", "Core", "CRM", "CTO", "Data", "EA&I", "EIS", "Governance", "Risk", "RTB", "Test Gov." };
        private static readonly string[] UnitTypeOptions = { "Nos", "Man Days", "Man Months", "Calender Months", "Fixed Scope" };
        private static readonly string[] CostTypeOptions = {
            "Hardware Purchase", "Hardware Rental", "Hardware AMC", "Software License Purchase", "Software License Subscription", "Software License AMC", "Escrow Agreement",
            "Project Management Services", "Business Analysis", "Architecture /Design", "SME Consulting Services", "Training", "in Months", "Application/Interface Development",
            "Software Customization", "Software Installation & Configuration", "Hardware Installation & Configuration", "Annual Support Operations", "OA Functional Testing",
            "QA Integration Testing", "QA Performance Testing", "QA Load Testing", "QA Test Automation", "SEC Penetration Testing", "UAT Functional Testing",
            "Professional Certification", "Quality Assurance (External)", "Travel & Accommodation", "Premises Rent", "Premises Fit out"
        };

        [HttpGet, Route("dashboard")]
        public IHttpActionResult Dashboard(string projectKey = "DMGT", string accountableExec = "Zahoor Ul Islam (IT Dept)")
        {
            var canReview = User.IsInRole("Reviewer");
            var canApprove = User.IsInRole("Approver");
            return Ok(new {
                metrics = Db.Query("SELECT * FROM vw_ManagementDashboard"),
                projects = Db.Query(@"SELECT p.*,
                    ISNULL(petCounts.ApprovedPetCount,0) ApprovedPetCount,
                    ISNULL(petCounts.PendingReviewPetCount,0) PendingReviewPetCount,
                    ISNULL(petCounts.PendingApprovalPetCount,0) PendingApprovalPetCount,
                    ISNULL(petCounts.RejectedPetCount,0) RejectedPetCount,
                    ISNULL(petCounts.SentBackPetCount,0) SentBackPetCount
                    FROM dbo.vw_ProjectPortfolio p
                    OUTER APPLY (SELECT
                        SUM(CASE WHEN x.Status='Approved' THEN 1 ELSE 0 END) ApprovedPetCount,
                        SUM(CASE WHEN x.Status='Pending Review' THEN 1 ELSE 0 END) PendingReviewPetCount,
                        SUM(CASE WHEN x.Status='Pending Approval' THEN 1 ELSE 0 END) PendingApprovalPetCount,
                        SUM(CASE WHEN x.Status='Rejected' THEN 1 ELSE 0 END) RejectedPetCount,
                        SUM(CASE WHEN x.Status='Sent Back' THEN 1 ELSE 0 END) SentBackPetCount
                        FROM dbo.PETRequests x WHERE x.ProjectId=p.ProjectId) petCounts
                    ORDER BY p.CreatedUtc DESC"),
                approvalPets = Db.Query(@"SELECT pet.* FROM dbo.PETRequests pet JOIN dbo.Projects p ON p.ProjectId=pet.ProjectId CROSS APPLY (SELECT DisplayName FROM dbo.Users WHERE Email=@user) currentUser WHERE (@canReview=1 AND pet.Status='Pending Review' AND (LOWER(ISNULL(pet.ReviewerEmail,''))=LOWER(@user) OR (ISNULL(pet.ReviewerEmail,'')='' AND LTRIM(RTRIM(ISNULL(p.AccountableExecLead,'')))=LTRIM(RTRIM(ISNULL(currentUser.DisplayName,'')))))) OR (@canApprove=1 AND pet.Status='Pending Approval' AND (LOWER(ISNULL(pet.ApproverEmail,''))=LOWER(@user) OR (ISNULL(pet.ApproverEmail,'')='' AND LTRIM(RTRIM(ISNULL(p.AccountableExec,'')))=LTRIM(RTRIM(ISNULL(currentUser.DisplayName,'')))))) ORDER BY pet.CreatedUtc DESC", P("@user", User.Identity.Name), P("@canReview", canReview), P("@canApprove", canApprove)),
                budgets = Db.Query("EXEC dbo.sp_GetBudgetSources"),
                jira = Db.Query("EXEC dbo.sp_GetJiraRegistrationCandidates @projectKey,@exec", P("@projectKey", projectKey), P("@exec", accountableExec)),
                budgetUsage = Db.Query("SELECT * FROM vw_CapexProjectUtilization ORDER BY BudgetSource,ApprovedUtc DESC")
            });
        }

        [HttpGet, Route("projects/{projectId:int}")]
        public IHttpActionResult Project(int projectId)
        {
            var sets = Db.QueryMultiple("EXEC dbo.sp_GetProjectDetail @id", new SqlParameter("@id", projectId));
            var budgetLines = sets[3];
            AttachBudgetLineSourceSpendItems(budgetLines);
            var attachments = sets[5];
            attachments.AddRange(Db.Query(@"SELECT AttachmentId,EntityType,EntityId,OriginalName,ContentType,FileSize,UploadedUtc
                FROM dbo.Attachments
                                WHERE (EntityType IN ('BudgetLineCAM','BudgetLineLPO')
                                    AND EntityId IN (SELECT b.BudgetLineId FROM dbo.BudgetLines b JOIN dbo.PETRequests p ON p.PetId=b.PetId WHERE p.ProjectId=@ProjectId))
                                    OR (EntityType='InvoiceDocument'
                                    AND EntityId IN (SELECT i.InvoiceId FROM dbo.Invoices i JOIN dbo.BudgetLines b ON b.BudgetLineId=i.BudgetLineId JOIN dbo.PETRequests p ON p.PetId=b.PetId WHERE p.ProjectId=@ProjectId))", P("@ProjectId", projectId)));
            return Ok(new {
                project = sets[0].FirstOrDefault(),
                pets = sets[1],
                spendItems = sets[2],
                budgetLines = budgetLines,
                invoices = sets[4],
                attachments = attachments
            });
        }

        [ApiAuthorize("Master"), HttpGet, Route("roles")]
        public IHttpActionResult Roles()
        {
            var users = Db.Query(@"SELECT u.UserId,u.Email,u.DisplayName,u.IsActive,
                STUFF((SELECT ',' + r.Name FROM dbo.UserRoles ur JOIN dbo.Roles r ON r.RoleId=ur.RoleId WHERE ur.UserId=u.UserId FOR XML PATH('')),1,1,'') Roles
                FROM dbo.Users u ORDER BY u.DisplayName,u.Email");
            var roles = Db.Query("SELECT Name FROM dbo.Roles WHERE Name <> 'Requestor' ORDER BY CASE Name WHEN 'Reviewer' THEN 1 WHEN 'Approver' THEN 2 WHEN 'Admin' THEN 3 WHEN 'Master' THEN 4 ELSE 5 END,Name");
            return Ok(new { users = users, roles = roles.Select(row => Convert.ToString(row["Name"])).ToArray() });
        }

        [ApiAuthorize("Master"), HttpPost, Route("roles")]
        public IHttpActionResult SaveRoles(RoleAssignmentRequest value)
        {
            if (value == null || value.UserId <= 0) return BadRequest("User is required.");
            var requestedRoles = new HashSet<string>(value.Roles ?? new string[0], StringComparer.OrdinalIgnoreCase);
            requestedRoles.Remove("Requestor");
            requestedRoles.Remove("Master");
            if (requestedRoles.Count > 1) return BadRequest("Select only one elevated role: Reviewer, Approver, or Admin.");
            try
            {
                Db.Execute(@"DELETE ur FROM dbo.UserRoles ur JOIN dbo.Roles r ON r.RoleId=ur.RoleId WHERE ur.UserId=@user AND r.Name IN ('Reviewer','Approver','Admin','Master');
                    INSERT dbo.UserRoles(UserId,RoleId) SELECT @user,RoleId FROM dbo.Roles WHERE Name='Requestor' AND NOT EXISTS(SELECT 1 FROM dbo.UserRoles WHERE UserId=@user AND RoleId=dbo.Roles.RoleId);
                    INSERT dbo.UserRoles(UserId,RoleId) SELECT @user,RoleId FROM dbo.Roles WHERE Name IN ('Reviewer','Approver','Admin') AND CHARINDEX(',' + Name + ',', @roles) > 0;",
                    P("@user", value.UserId), P("@roles", "," + string.Join(",", requestedRoles.ToArray()) + ","));
                return Ok();
            }
            catch (SqlException ex) { return BadRequest(ex.Message); }
        }

        [HttpGet, Route("currencies")]
        public IHttpActionResult Currencies()
        {
            try { return Ok(Db.Query("SELECT CurrencyID CurrencyId,Code,Name,RateToLocal,IsActive FROM dbo.Currencies ORDER BY Code")); }
            catch (SqlException ex) { return BadRequest(ex.Message); }
        }

        [ApiAuthorize("Admin", "Master"), HttpPost, Route("currencies")]
        public IHttpActionResult SaveCurrency(CurrencyRequest value)
        {
            if (value == null) return BadRequest("Currency details are required.");
            value.Code = (value.Code ?? "").Trim().ToUpperInvariant();
            value.Name = (value.Name ?? "").Trim();
            if (value.Code.Length == 0) return BadRequest("Currency code is required.");
            if (value.Name.Length == 0) return BadRequest("Currency name is required.");
            if (value.RateToLocal <= 0) return BadRequest("Rate to local must be greater than zero.");
            try
            {
                return Ok(Db.Query(@"DECLARE @SavedCurrencyId INT = NULLIF(@CurrencyId,0);
                    IF @SavedCurrencyId IS NULL
                    BEGIN INSERT dbo.Currencies(Code,Name,RateToLocal,IsActive) VALUES(@Code,@Name,@RateToLocal,@IsActive); SET @SavedCurrencyId=CONVERT(INT,SCOPE_IDENTITY()); END
                    ELSE UPDATE dbo.Currencies SET Code=@Code,Name=@Name,RateToLocal=@RateToLocal,IsActive=@IsActive WHERE CurrencyID=@SavedCurrencyId;
                    SELECT CurrencyID CurrencyId,Code,Name,RateToLocal,IsActive FROM dbo.Currencies WHERE CurrencyID=@SavedCurrencyId",
                    P("@CurrencyId", value.CurrencyId ?? 0), P("@Code", value.Code), P("@Name", value.Name), P("@RateToLocal", value.RateToLocal), P("@IsActive", value.IsActive)).FirstOrDefault());
            }
            catch (SqlException ex) { return BadRequest(ex.Message); }
        }

        [HttpGet, Route("pets/{petId:int}/history")]
        public IHttpActionResult History(int petId)
        {
            return Ok(Db.Query("EXEC dbo.sp_GetWorkflowHistory @id", new SqlParameter("@id", petId)));
        }

        [ApiAuthorize("Requestor", "Master"), HttpPost, Route("projects")]
        public IHttpActionResult SaveProject(ProjectRequest value)
        {
            if (value == null || string.IsNullOrWhiteSpace(value.ProjectName)) return BadRequest("Project name is required.");
            try
            {
                var requiresPet = true;
                var skipReview = false;
                var workflowFlags = Db.Query("SELECT CASE WHEN COL_LENGTH('dbo.Projects','RequiresPet') IS NOT NULL AND COL_LENGTH('dbo.Projects','SkipReview') IS NOT NULL THEN 1 ELSE 0 END HasWorkflowFlags").FirstOrDefault();
                if (value.ProjectId.HasValue && workflowFlags != null && Convert.ToInt32(workflowFlags["HasWorkflowFlags"]) == 1)
                {
                    var existing = Db.Query("SELECT RequiresPet,SkipReview FROM dbo.Projects WHERE ProjectId=@ProjectId", P("@ProjectId", value.ProjectId)).FirstOrDefault();
                    if (existing != null && existing["RequiresPet"] != null) requiresPet = Convert.ToBoolean(existing["RequiresPet"]);
                    if (existing != null && existing["SkipReview"] != null) skipReview = Convert.ToBoolean(existing["SkipReview"]);
                }
                List<Dictionary<string, object>> rows;
                try
                {
                    rows = Db.Query("EXEC dbo.sp_SaveProject @ProjectId,@IsJira,@JiraKey,@Name,@Type,@Lead,@Executive,@Sme,@Size,@Manager,@BudgetType,@BudgetSource,@RequiresPet,@SkipReview,@User", P("@ProjectId", value.ProjectId), P("@IsJira", value.IsJira), P("@JiraKey", value.JiraKey), P("@Name", value.ProjectName), P("@Type", value.ProjectType), P("@Lead", value.AccountableExecLead), P("@Executive", value.AccountableExec), P("@Sme", value.SmeLead), P("@Size", value.ProjectSize), P("@Manager", value.ProjectManager), P("@BudgetType", value.BudgetType), P("@BudgetSource", value.BudgetSourceId), P("@RequiresPet", requiresPet), P("@SkipReview", skipReview), P("@User", User.Identity.Name));
                }
                catch (SqlException ex)
                {
                    if (!ProcedureParameterError(ex)) throw;
                    rows = Db.Query("EXEC dbo.sp_SaveProject @ProjectId,@IsJira,@JiraKey,@Name,@Type,@Lead,@Executive,@Sme,@Size,@Manager,@BudgetType,@BudgetSource,@User", P("@ProjectId", value.ProjectId), P("@IsJira", value.IsJira), P("@JiraKey", value.JiraKey), P("@Name", value.ProjectName), P("@Type", value.ProjectType), P("@Lead", value.AccountableExecLead), P("@Executive", value.AccountableExec), P("@Sme", value.SmeLead), P("@Size", value.ProjectSize), P("@Manager", value.ProjectManager), P("@BudgetType", value.BudgetType), P("@BudgetSource", value.BudgetSourceId), P("@User", User.Identity.Name));
                }
                return Ok(rows.FirstOrDefault());
            }
            catch (SqlException ex) { return BadRequest(ex.Message); }
        }

        [ApiAuthorize("Requestor", "Master"), HttpDelete, Route("projects/{projectId:int}")]
        public IHttpActionResult DeleteProject(int projectId)
        {
            try { Db.Execute("EXEC dbo.sp_DeleteProject @ProjectId,@User", P("@ProjectId", projectId), P("@User", User.Identity.Name)); return Ok(); }
            catch (SqlException ex) { return BadRequest(ex.Message); }
        }

        [ApiAuthorize("Requestor", "Master"), HttpDelete, Route("pets/{petId:int}")]
        public IHttpActionResult DeletePet(int petId)
        {
            try { Db.Execute("EXEC dbo.sp_DeletePet @PetId,@User", P("@PetId", petId), P("@User", User.Identity.Name)); return Ok(); }
            catch (SqlException ex) { return BadRequest(ex.Message); }
        }

        [ApiAuthorize("Requestor", "Master"), HttpPost, Route("pets")]
        public IHttpActionResult SavePet(PetRequest value)
        {
            if (value == null) return BadRequest("PET details are required.");
            try
            {
                if (value.PetId.HasValue)
                {
                    var existing = Db.Query("SELECT ProjectId,Status FROM dbo.PETRequests WHERE PetId=@PetId", P("@PetId", value.PetId)).FirstOrDefault();
                    if (existing == null) return BadRequest("PET request was not found.");
                    var existingStatus = Convert.ToString(existing["Status"]).Trim();
                    if (!EditablePetStatus(existingStatus)) return BadRequest("PET requests can be edited only while Pending Review or Sent Back.");
                }
                if (value.SpendItems != null && value.SpendItems.Count > 0)
                {
                    foreach (var item in value.SpendItems) ValidatePetRequiredDropdowns(item);
                    value.RequestedAmount = value.SpendItems.Sum(item => item.FinalAed > 0 ? item.FinalAed : item.AedAmount * (1 + item.ContingencyPercent / 100));
                }
                AmountValidation.ValidatePetRequestAmount(value.ProjectId, value.PetId, value.RequestedAmount);
                var isSentBack = false;
                if (value.PetId.HasValue)
                {
                    var sentBack = Db.Query("SELECT Status FROM dbo.PETRequests WHERE PetId=@PetId AND Status='Sent Back'", P("@PetId", value.PetId)).FirstOrDefault();
                    isSentBack = sentBack != null;
                    if (isSentBack && string.IsNullOrWhiteSpace(value.Comments)) return BadRequest("Requester comments / amendment notes are required before resubmitting.");
                }
                var saved = SavePetRow(value, isSentBack).FirstOrDefault();
                var petId = value.PetId ?? Convert.ToInt32(saved["PetId"]);
                if (value.SpendItems != null && value.SpendItems.Count > 0) SyncPetSpendItems(petId, value.SpendItems);
                return Ok(saved);
            }
            catch (SqlException ex) { return BadRequest(ex.Message); }
            catch (Exception ex) { return BadRequest(ex.Message); }
        }

        private static decimal CurrencyRateToLocal(string code, decimal fallbackRate)
        {
            var currencyCode = string.IsNullOrWhiteSpace(code) ? "AED" : code.Trim().ToUpperInvariant();
            var row = Db.Query("SELECT RateToLocal FROM dbo.Currencies WHERE UPPER(Code)=@Code", P("@Code", currencyCode)).FirstOrDefault();
            if (row != null && row["RateToLocal"] != null)
            {
                var rate = Convert.ToDecimal(row["RateToLocal"]);
                if (rate > 0) return rate;
            }
            return fallbackRate > 0 ? fallbackRate : 1;
        }

        private static void UpdateApprovedPetVendors(int petId, List<SpendItemRequest> items, string vendorName)
        {
            if (items != null && items.Count > 0)
            {
                foreach (var item in items)
                {
                    if (!item.SpendItemId.HasValue) continue;
                    if (string.IsNullOrWhiteSpace(item.Vendor)) throw new ArgumentException("Vendor is required on each PET line.");
                    Db.Execute("UPDATE dbo.SpendItems SET Vendor=@Vendor WHERE PetId=@PetId AND SpendItemId=@SpendItemId", P("@Vendor", item.Vendor), P("@PetId", petId), P("@SpendItemId", item.SpendItemId));
                }
                return;
            }
            if (string.IsNullOrWhiteSpace(vendorName)) throw new ArgumentException("Vendor is required.");
            Db.Execute("UPDATE dbo.SpendItems SET Vendor=@VendorName WHERE PetId=@PetId", P("@VendorName", vendorName), P("@PetId", petId));
        }

        private List<Dictionary<string, object>> SavePetRow(PetRequest value, bool isSentBack)
        {
            var sql = isSentBack ? "EXEC dbo.sp_SavePet @PetId,@ProjectId,@Code,@Amount,@Currency,@User,@VendorName,@Comments,@ReviewRequired" : "EXEC dbo.sp_SavePet @PetId,@ProjectId,@Code,@Amount,@Currency,@User,@VendorName,NULL,@ReviewRequired";
            var parameters = isSentBack
                ? new[] { P("@PetId", value.PetId), P("@ProjectId", value.ProjectId), P("@Code", value.Code), P("@Amount", value.RequestedAmount), P("@Currency", value.Currency), P("@User", User.Identity.Name), P("@VendorName", value.VendorName), P("@Comments", value.Comments), P("@ReviewRequired", value.ReviewRequired) }
                : new[] { P("@PetId", value.PetId), P("@ProjectId", value.ProjectId), P("@Code", value.Code), P("@Amount", value.RequestedAmount), P("@Currency", value.Currency), P("@User", User.Identity.Name), P("@VendorName", value.VendorName), P("@ReviewRequired", value.ReviewRequired) };
            try { return Db.Query(sql, parameters); }
            catch (SqlException ex)
            {
                if (!ProcedureParameterError(ex)) throw;
                sql = isSentBack ? "EXEC dbo.sp_SavePet @PetId,@ProjectId,@Code,@Amount,@Currency,@User,@VendorName,@Comments" : "EXEC dbo.sp_SavePet @PetId,@ProjectId,@Code,@Amount,@Currency,@User,@VendorName";
                parameters = isSentBack
                    ? new[] { P("@PetId", value.PetId), P("@ProjectId", value.ProjectId), P("@Code", value.Code), P("@Amount", value.RequestedAmount), P("@Currency", value.Currency), P("@User", User.Identity.Name), P("@VendorName", value.VendorName), P("@Comments", value.Comments) }
                    : new[] { P("@PetId", value.PetId), P("@ProjectId", value.ProjectId), P("@Code", value.Code), P("@Amount", value.RequestedAmount), P("@Currency", value.Currency), P("@User", User.Identity.Name), P("@VendorName", value.VendorName) };
                return Db.Query(sql, parameters);
            }
        }

        [ApiAuthorize("Requestor", "Master"), HttpPost, Route("spend-items")]
        public IHttpActionResult SaveSpendItem(SpendItemRequest value)
        {
            if (value == null || string.IsNullOrWhiteSpace(value.Vendor)) return BadRequest("Vendor is required.");
            try { RequireEditablePetStatus(value.PetId); }
            catch (ArgumentException ex) { return BadRequest(ex.Message); }
            try { ValidatePetRequiredDropdowns(value); }
            catch (ArgumentException ex) { return BadRequest(ex.Message); }
            EnsureSpendLineId(value);
            var foreignAmount = value.Units * value.UnitPrice;
            var rate = CurrencyRateToLocal(value.Currency, value.ExchangeRate);
            value.ExchangeRate = rate;
            var aedAmount = foreignAmount * rate;
            try { AmountValidation.ValidateSpendItemAmount(value.PetId, value.SpendItemId, aedAmount * (1 + value.ContingencyPercent / 100)); return Ok(SaveSpendItemRow(value, foreignAmount, aedAmount)); }
            catch (SqlException ex) { return BadRequest(ex.Message); }
            catch (ArgumentException ex) { return BadRequest(ex.Message); }
        }

        private static void SyncPetSpendItems(int petId, List<SpendItemRequest> items)
        {
            EnsureSpendLineIds(items);
            var ids = items.Where(item => item.SpendItemId.HasValue).Select(item => item.SpendItemId.Value).Distinct().ToList();
            var parameters = new List<SqlParameter> { P("@PetId", petId) };
            var keepClause = "";
            if (ids.Count > 0)
            {
                var names = ids.Select((id, index) => "@Existing" + index).ToArray();
                for (var index = 0; index < ids.Count; index++) parameters.Add(P(names[index], ids[index]));
                keepClause = " AND s.SpendItemId NOT IN (" + string.Join(",", names) + ")";
            }
            Db.Execute("DELETE s FROM dbo.SpendItems s JOIN dbo.PETRequests pet ON pet.PetId=s.PetId JOIN dbo.Projects p ON p.ProjectId=pet.ProjectId WHERE s.PetId=@PetId" + keepClause + " AND (pet.Status IN('Draft','Pending Review','Sent Back') OR (pet.Status='Pending Approval' AND p.SkipReview=1))", parameters.ToArray());
            foreach (var item in items)
            {
                item.PetId = petId;
                var foreignAmount = item.Units * item.UnitPrice;
                var exchangeRate = CurrencyRateToLocal(item.Currency, item.ExchangeRate);
                item.ExchangeRate = exchangeRate;
                var aedAmount = foreignAmount * exchangeRate;
                SaveSpendItemRow(item, foreignAmount, aedAmount);
            }
        }

        private static void RequireEditablePetStatus(int petId)
        {
            var existing = Db.Query("SELECT Status FROM dbo.PETRequests WHERE PetId=@PetId", P("@PetId", petId)).FirstOrDefault();
            if (existing == null) throw new ArgumentException("PET request was not found.");
            if (!EditablePetStatus(Convert.ToString(existing["Status"]))) throw new ArgumentException("PET requests can be edited only while Pending Review or Sent Back.");
        }

        private static bool EditablePetStatus(string status)
        {
            return string.Equals(status, "Pending Review", StringComparison.OrdinalIgnoreCase) || string.Equals(status, "Sent Back", StringComparison.OrdinalIgnoreCase);
        }

        private static void EnsureSpendLineIds(IEnumerable<SpendItemRequest> items)
        {
            var usedLineIds = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var item in items.Where(item => item != null))
            {
                var lineId = (item.LineId ?? "").Trim();
                if (string.IsNullOrWhiteSpace(lineId) || usedLineIds.Contains(lineId)) lineId = GeneratedLineId(usedLineIds);
                item.LineId = lineId;
                usedLineIds.Add(lineId);
            }
        }

        private static void EnsureSpendLineId(SpendItemRequest item)
        {
            if (item != null && string.IsNullOrWhiteSpace(item.LineId)) item.LineId = GeneratedLineId(new HashSet<string>(StringComparer.OrdinalIgnoreCase));
        }

        private static string GeneratedLineId(HashSet<string> usedLineIds)
        {
            string lineId;
            do
            {
                lineId = "LINE-" + DateTime.UtcNow.ToString("yyyyMMddHHmmssfff") + "-" + Guid.NewGuid().ToString("N").Substring(0, 6).ToUpperInvariant();
            } while (usedLineIds.Contains(lineId));
            return lineId;
        }

        private static Dictionary<string, object> SaveSpendItemRow(SpendItemRequest value, decimal foreignAmount, decimal aedAmount)
        {
            try
            {
                return Db.Query("EXEC dbo.sp_SaveSpendItem @Id,@Pet,@Head,@Topic,@Vendor,@CostType,@UnitType,@Units,@UnitPrice,@Currency,@Foreign,@Aed,@Contingency,@Gl,@Department,@Description,@YearlyRecurrence,@LineId,@SrNo,@LineDate", P("@Id", value.SpendItemId), P("@Pet", value.PetId), P("@Head", value.Head), P("@Topic", value.Topic), P("@Vendor", value.Vendor), P("@CostType", value.CostType), P("@UnitType", value.UnitType), P("@Units", value.Units), P("@UnitPrice", value.UnitPrice), P("@Currency", value.Currency), P("@Foreign", foreignAmount), P("@Aed", aedAmount), P("@Contingency", value.ContingencyPercent), P("@Gl", value.GlNumber), P("@Department", value.Department), P("@Description", value.Description), P("@YearlyRecurrence", value.YearlyRecurrence), P("@LineId", value.LineId), P("@SrNo", value.SerialNo), P("@LineDate", value.LineDate)).FirstOrDefault();
            }
            catch (SqlException ex)
            {
                if (!ProcedureParameterError(ex)) throw;
                return Db.Query("EXEC dbo.sp_SaveSpendItem @Id,@Pet,@Head,@Topic,@Vendor,@CostType,@UnitType,@Units,@UnitPrice,@Currency,@Foreign,@Aed,@Contingency,@Gl", P("@Id", value.SpendItemId), P("@Pet", value.PetId), P("@Head", value.Head), P("@Topic", value.Topic), P("@Vendor", value.Vendor), P("@CostType", value.CostType), P("@UnitType", value.UnitType), P("@Units", value.Units), P("@UnitPrice", value.UnitPrice), P("@Currency", value.Currency), P("@Foreign", foreignAmount), P("@Aed", aedAmount), P("@Contingency", value.ContingencyPercent), P("@Gl", value.GlNumber)).FirstOrDefault();
            }
        }

        [ApiAuthorize("Reviewer"), HttpPost, Route("pets/{petId:int}/review")]
        public IHttpActionResult Review(int petId, DecisionRequest value) { var validation = ValidateDecision(value, true); if (validation != null) return BadRequest(validation); try { ExecutePetDecision(petId, "Review", value, User.Identity.Name); return Ok(); } catch (SqlException ex) { return BadRequest(ex.Message); } }

        [ApiAuthorize("Approver"), HttpPost, Route("pets/{petId:int}/approve")]
        public IHttpActionResult Approve(int petId, DecisionRequest value) { var validation = ValidateDecision(value, true); if (validation != null) return BadRequest(validation); try { ExecutePetDecision(petId, "Approval", value, User.Identity.Name); return Ok(); } catch (SqlException ex) { return BadRequest(ex.Message); } }

        [ApiAuthorize("Requestor", "Master"), HttpPost, Route("budget-lines")]
        public IHttpActionResult SaveBudgetLine(BudgetLineRequest value)
        {
            try
            {
                if (value == null) return BadRequest("Budget Line details are required.");
                if (!value.BudgetLineId.HasValue)
                {
                    var approvedPet = Db.Query("SELECT PetId FROM dbo.PETRequests WHERE PetId=@PetId AND Status='Approved'", P("@PetId", value.PetId)).FirstOrDefault();
                    if (approvedPet == null) return BadRequest("Budget Lines can be added only after the selected PET is approved.");
                }
                object lpoStatus = null;
                if (value.BudgetLineId.HasValue)
                {
                    var existing = Db.Query("SELECT PetId,LpoStatus FROM dbo.BudgetLines WHERE BudgetLineId=@Id", P("@Id", value.BudgetLineId)).FirstOrDefault();
                    if (existing != null)
                    {
                        value.PetId = Convert.ToInt32(existing["PetId"]);
                        lpoStatus = existing["LpoStatus"];
                    }
                }
                var sourceSpendItemIds = BudgetLineSourceSpendItemIds(value);
                if (sourceSpendItemIds.Count > 0)
                {
                    ValidateBudgetLineSourceSpendItems(value.PetId, sourceSpendItemIds);
                }
                value.Vendor = NormalizeEditableVendor(value.Vendor);
                AmountValidation.ValidateBudgetLineAmount(value.PetId, value.BudgetLineId, value.Cost, sourceSpendItemIds);
                var saved = Db.Query("EXEC dbo.sp_SaveBudgetLine @Id,@Pet,@Vendor,@Justification,@Cost,@Currency,@Gl,@PetRef,@CamId,@CamStatus,@CamComments,@LpoRequest,@LpoStatus,@LpoComments,@User,@CamCreatedDate,@CamApprovedDate,@LpoIssueDate", P("@Id", value.BudgetLineId), P("@Pet", value.PetId), P("@Vendor", value.Vendor), P("@Justification", value.Justification), P("@Cost", value.Cost), P("@Currency", value.Currency), P("@Gl", value.GlNumber), P("@PetRef", value.PetReference), P("@CamId", value.CamId), P("@CamStatus", value.CamStatus), P("@CamComments", value.CamComments), P("@LpoRequest", value.LpoRequest), P("@LpoStatus", lpoStatus), P("@LpoComments", value.LpoComments), P("@User", User.Identity.Name), P("@CamCreatedDate", value.CamCreatedDate), P("@CamApprovedDate", value.CamApprovedDate), P("@LpoIssueDate", value.LpoIssueDate)).FirstOrDefault();
                var budgetLineId = value.BudgetLineId ?? Convert.ToInt32(saved["BudgetLineId"]);
                if (value.SourceSpendItemIds != null) SyncBudgetLineSourceSpendItems(budgetLineId, sourceSpendItemIds);
                return Ok(saved);
            }
            catch (SqlException ex) { return BadRequest(ex.Message); }
            catch (Exception ex) { return BadRequest(ex.Message); }
        }

        [ApiAuthorize("Requestor", "Master"), HttpDelete, Route("budget-lines/{budgetLineId:int}")]
        public IHttpActionResult DeleteBudgetLine(int budgetLineId)
        {
            try { Db.Execute("EXEC dbo.sp_DeleteBudgetLine @BudgetLineId,@User", P("@BudgetLineId", budgetLineId), P("@User", User.Identity.Name)); return Ok(); }
            catch (SqlException ex) { return BadRequest(ex.Message); }
        }

        [ApiAuthorize("Requestor", "Master"), HttpPost, Route("invoices")]
        public IHttpActionResult SaveInvoice(InvoiceRequest value)
        {
            try { return Ok(Db.Query("EXEC dbo.sp_SaveInvoice @Id,@Line,@Vendor,@Justification,@Gl,@Number,@Amount,@Status,@PaymentDate,@User", P("@Id", value.InvoiceId), P("@Line", value.BudgetLineId), P("@Vendor", value.VendorName), P("@Justification", value.Justification), P("@Gl", value.GlNumber), P("@Number", value.InvoiceNumber), P("@Amount", value.InvoiceAmount), P("@Status", value.InvoiceStatus), P("@PaymentDate", value.PaymentDate), P("@User", User.Identity.Name)).FirstOrDefault()); }
            catch (SqlException ex) { return BadRequest(ex.Message); }
            catch (Exception ex) { return BadRequest(ex.Message); }
        }

        [ApiAuthorize("Requestor", "Master"), HttpDelete, Route("invoices/{invoiceId:int}")]
        public IHttpActionResult DeleteInvoice(int invoiceId)
        {
            try { Db.Execute("EXEC dbo.sp_DeleteInvoice @InvoiceId,@User", P("@InvoiceId", invoiceId), P("@User", User.Identity.Name)); return Ok(); }
            catch (SqlException ex) { return BadRequest(ex.Message); }
        }

        [ApiAuthorize("Master"), HttpPut, Route("budgets/{budgetSourceId:int}")]
        public IHttpActionResult UpdateBudget(int budgetSourceId, dynamic value) { Db.Execute("EXEC dbo.sp_UpdateBudget @Id,@Description,@Budget,@Utilization,@Available,@User", P("@Id", budgetSourceId), P("@Description", (string)value.description), P("@Budget", (decimal)value.budget), P("@Utilization", (decimal)value.utilization), P("@Available", (decimal)value.availableBudget), P("@User", User.Identity.Name)); return Ok(); }

        [ApiAuthorize("Requestor", "Master"), HttpPost, Route("attachments/{entityType}/{entityId:int}")]
        public async Task<IHttpActionResult> UploadAttachment(string entityType, int entityId)
        {
            try
            {
                if (!Request.Content.IsMimeMultipartContent()) return Content(HttpStatusCode.UnsupportedMediaType, "Use multipart/form-data.");
                var root = HttpContext.Current.Server.MapPath("~/App_Data/Attachments"); Directory.CreateDirectory(root);
                var provider = await Request.Content.ReadAsMultipartAsync(new MultipartFormDataStreamProvider(root));
                if (provider.FileData.Count == 0) return BadRequest("Choose at least one supporting document first.");
                foreach (var file in provider.FileData)
                {
                    var original = file.Headers.ContentDisposition == null ? null : file.Headers.ContentDisposition.FileName;
                    var originalName = AttachmentColumnValue(Path.GetFileName((original ?? "").Trim('"')), 260, "supporting-document");
                    var storedName = AttachmentColumnValue(Path.GetFileName(file.LocalFileName), 260, Guid.NewGuid().ToString("N"));
                    var contentType = AttachmentColumnValue(file.Headers.ContentType == null ? MimeMapping.GetMimeMapping(originalName) : file.Headers.ContentType.MediaType, 150, "application/octet-stream");
                    Db.Execute("EXEC dbo.sp_InsertAttachment @type,@id,@original,@stored,@content,@size,@user", P("@type", AttachmentColumnValue(AttachmentEntityType(entityType), 30, "PET")), P("@id", entityId), P("@original", originalName), P("@stored", storedName), P("@content", contentType), P("@size", new FileInfo(file.LocalFileName).Length), P("@user", AttachmentColumnValue(User.Identity.Name, 254, "system")));
                }
                return Ok();
            }
            catch (SqlException ex) { return BadRequest(ex.Message); }
            catch (IOException ex) { return BadRequest(ex.Message); }
            catch (UnauthorizedAccessException ex) { return BadRequest(ex.Message); }
            catch (HttpException ex) { return BadRequest(ex.Message); }
            catch (Exception ex) { return BadRequest("Unable to upload supporting document. " + ex.Message); }
        }

        private static string AttachmentEntityType(string entityType)
        {
            if (entityType != null && entityType.Equals("pet", StringComparison.OrdinalIgnoreCase)) return "PET";
            return entityType;
        }

        private static string AttachmentColumnValue(string value, int maxLength, string fallback)
        {
            var text = string.IsNullOrWhiteSpace(value) ? fallback : value.Trim();
            return text.Length <= maxLength ? text : text.Substring(0, maxLength);
        }

        [HttpGet, Route("attachments/{attachmentId:long}")]
        public IHttpActionResult DownloadAttachment(long attachmentId, bool inline = false)
        {
            var row = Db.Query("SELECT OriginalName,StoredName,ContentType FROM dbo.Attachments WHERE AttachmentId=@AttachmentId", P("@AttachmentId", attachmentId)).FirstOrDefault();
            if (row == null) return NotFound();
            var root = HttpContext.Current.Server.MapPath("~/App_Data/Attachments");
            var path = Path.Combine(root, Convert.ToString(row["StoredName"]));
            if (!File.Exists(path)) return NotFound();
            var originalName = Convert.ToString(row["OriginalName"]);
            var response = Request.CreateResponse(HttpStatusCode.OK);
            response.Content = new StreamContent(File.OpenRead(path));
            response.Content.Headers.ContentType = new MediaTypeHeaderValue(AttachmentContentType(row["ContentType"], originalName));
            response.Content.Headers.ContentDisposition = new ContentDispositionHeaderValue(inline ? "inline" : "attachment") { FileName = originalName };
            return ResponseMessage(response);
        }

        private static string AttachmentContentType(object storedContentType, string originalName)
        {
            var contentType = Convert.ToString(storedContentType);
            if (!string.IsNullOrWhiteSpace(contentType) && !contentType.Equals("application/octet-stream", StringComparison.OrdinalIgnoreCase)) return contentType;
            return MimeMapping.GetMimeMapping(originalName ?? "attachment");
        }

        [ApiAuthorize("Requestor", "Master"), HttpPost, Route("bulk/pet/{projectId:int}/preview")]
        public async Task<IHttpActionResult> PreviewPetBulk(int projectId)
        {
            try
            {
                return Ok(new { rows = await ReadPetPreviewRows() });
            }
            catch (Exception ex) { return BadRequest(ex.Message); }
        }

        [ApiAuthorize("Requestor", "Master"), HttpPost, Route("bulk/pet/{projectId:int}/rows")]
        public IHttpActionResult BulkPetRows(int projectId, List<PetUploadRowRequest> rows)
        {
            try
            {
                var imported = CsvBulkImporter.ImportPetRows(projectId, rows, User.Identity.Name);
                return Ok(new { imported = imported });
            }
            catch (SqlException ex) { return BadRequest(ex.Message); }
            catch (Exception ex) { return BadRequest(ex.Message); }
        }

        [ApiAuthorize("Requestor", "Master"), HttpPost, Route("bulk/{kind}/{parentId:int}")]
        public async Task<IHttpActionResult> Bulk(string kind, int parentId)
        {
            if (!new[] { "pet", "budget", "invoice" }.Contains(kind, StringComparer.OrdinalIgnoreCase)) return BadRequest("Unknown template type.");
            try
            {
                int imported;
                if (Request.Content.IsMimeMultipartContent())
                {
                    var provider = await Request.Content.ReadAsMultipartAsync(new MultipartMemoryStreamProvider());
                    var file = provider.Contents.FirstOrDefault(content => content.Headers.ContentDisposition != null && !string.IsNullOrWhiteSpace(content.Headers.ContentDisposition.FileName));
                    if (file == null) return BadRequest("Choose a file to import.");
                    var fileName = file.Headers.ContentDisposition.FileName.Trim('"');
                    var extension = Path.GetExtension(fileName).ToLowerInvariant();
                    if (extension == ".xlsx" || extension == ".xlsm")
                    {
                        var rows = SpreadsheetTableReader.Read(await file.ReadAsStreamAsync());
                        imported = CsvBulkImporter.ImportRows(kind, parentId, rows, User.Identity.Name, "Excel workbook");
                    }
                    else
                    {
                        imported = CsvBulkImporter.Import(kind, parentId, await file.ReadAsStringAsync(), User.Identity.Name);
                    }
                }
                else
                {
                    var csv = await Request.Content.ReadAsStringAsync();
                    imported = CsvBulkImporter.Import(kind, parentId, csv, User.Identity.Name);
                }
                return Ok(new { imported = imported });
            }
            catch (SqlException ex) { return BadRequest(ex.Message); }
            catch (Exception ex) { return BadRequest(ex.Message); }
        }

        private async Task<List<List<string>>> ReadImportRows()
        {
            if (!Request.Content.IsMimeMultipartContent()) return CsvBulkImporter.Parse(await Request.Content.ReadAsStringAsync());
            var provider = await Request.Content.ReadAsMultipartAsync(new MultipartMemoryStreamProvider());
            var file = provider.Contents.FirstOrDefault(content => content.Headers.ContentDisposition != null && !string.IsNullOrWhiteSpace(content.Headers.ContentDisposition.FileName));
            if (file == null) throw new ArgumentException("Choose a file to import.");
            var fileName = file.Headers.ContentDisposition.FileName.Trim('"');
            var extension = Path.GetExtension(fileName).ToLowerInvariant();
            if (extension == ".xlsx" || extension == ".xlsm") return SpreadsheetTableReader.Read(await file.ReadAsStreamAsync());
            return CsvBulkImporter.Parse(await file.ReadAsStringAsync());
        }

        private async Task<List<PetUploadRowRequest>> ReadPetPreviewRows()
        {
            if (!Request.Content.IsMimeMultipartContent()) return CsvBulkImporter.PreviewPetRows(CsvBulkImporter.Parse(await Request.Content.ReadAsStringAsync()), "uploaded file");
            var provider = await Request.Content.ReadAsMultipartAsync(new MultipartMemoryStreamProvider());
            var file = provider.Contents.FirstOrDefault(content => content.Headers.ContentDisposition != null && !string.IsNullOrWhiteSpace(content.Headers.ContentDisposition.FileName));
            if (file == null) throw new ArgumentException("Choose a file to import.");
            var fileName = file.Headers.ContentDisposition.FileName.Trim('"');
            var extension = Path.GetExtension(fileName).ToLowerInvariant();
            if (extension != ".xlsx" && extension != ".xlsm") return CsvBulkImporter.PreviewPetRows(CsvBulkImporter.Parse(await file.ReadAsStringAsync()), fileName);
            Exception lastError = null;
            foreach (var worksheetRows in SpreadsheetTableReader.ReadWorksheets(await file.ReadAsStreamAsync()))
            {
                try { return CsvBulkImporter.PreviewPetRows(worksheetRows, fileName); }
                catch (Exception ex) { lastError = ex; }
            }
            throw lastError ?? new ArgumentException("The Excel workbook does not contain PET template rows.");
        }

        private static SqlParameter P(string name, object value) { return new SqlParameter(name, Db.Value(value)); }

        private static void ValidatePetRequiredDropdowns(SpendItemRequest value)
        {
            if (value == null) throw new ArgumentException("PET line item details are required.");
            var department = NormalizeDepartment(value.Department);
            if (department == null) throw new ArgumentException("Department is required.");
            var unitType = MatchOption(value.UnitType, UnitTypeOptions);
            if (unitType == null) throw new ArgumentException("Unit Type is required.");
            var costType = MatchOption(value.CostType, CostTypeOptions);
            if (costType == null) throw new ArgumentException("Cost Type is required.");
            if (value.YearlyRecurrence.HasValue && (value.YearlyRecurrence.Value < 1 || value.YearlyRecurrence.Value > 5)) value.YearlyRecurrence = null;
            value.Department = department;
            value.UnitType = unitType;
            value.CostType = costType;
        }

        private static string NormalizeDepartment(string value)
        {
            var department = MatchOption(value, DepartmentOptions);
            var trimmed = (value ?? "").Trim();
            return department ?? (string.IsNullOrWhiteSpace(trimmed) ? null : trimmed);
        }

        private static string MatchOption(string value, IEnumerable<string> options)
        {
            var key = OptionKey(value);
            return options.FirstOrDefault(option => OptionKey(option) == key);
        }

        private static string OptionKey(string value)
        {
            var key = new string((value ?? "").Trim().ToLowerInvariant().Where(char.IsLetterOrDigit).ToArray());
            return key == "eal" ? "eai" : key;
        }

        private static string NormalizeEditableVendor(string vendor)
        {
            var selected = (vendor ?? "").Trim();
            if (selected.Length == 0) throw new ArgumentException("Vendor Name is required.");
            return selected;
        }

        private static List<int> BudgetLineSourceSpendItemIds(BudgetLineRequest value)
        {
            var ids = (value.SourceSpendItemIds ?? new List<int>()).Where(id => id > 0).Distinct().ToList();
            if (ids.Count > 1) throw new ArgumentException("Select only one PET line for this Budget Line.");
            return ids;
        }

        private static void ValidateBudgetLineSourceSpendItems(int petId, List<int> sourceSpendItemIds)
        {
            var parameters = new List<SqlParameter> { P("@PetId", petId) };
            var names = sourceSpendItemIds.Select((id, index) => "@SpendItem" + index).ToArray();
            for (var index = 0; index < sourceSpendItemIds.Count; index++) parameters.Add(P(names[index], sourceSpendItemIds[index]));
            var row = Db.Query("SELECT COUNT(1) SelectedCount FROM dbo.SpendItems WHERE PetId=@PetId AND SpendItemId IN (" + string.Join(",", names) + ")", parameters.ToArray()).FirstOrDefault();
            if (row == null || Convert.ToInt32(row["SelectedCount"]) != sourceSpendItemIds.Count) throw new ArgumentException("Selected PET line must belong to the selected PET Request.");
        }

        private static bool BudgetLineSpendItemSelectionAvailable()
        {
            var row = Db.Query("SELECT CASE WHEN OBJECT_ID('dbo.BudgetLineSpendItems','U') IS NULL THEN 0 ELSE 1 END HasTable").FirstOrDefault();
            return row != null && Convert.ToInt32(row["HasTable"]) == 1;
        }

        private static void SyncBudgetLineSourceSpendItems(int budgetLineId, List<int> sourceSpendItemIds)
        {
            if (!BudgetLineSpendItemSelectionAvailable()) return;
            var parameters = new List<SqlParameter> { P("@BudgetLineId", budgetLineId) };
            var names = sourceSpendItemIds.Select((id, index) => "@SpendItem" + index).ToArray();
            for (var index = 0; index < sourceSpendItemIds.Count; index++) parameters.Add(P(names[index], sourceSpendItemIds[index]));
            var sql = "DELETE FROM dbo.BudgetLineSpendItems WHERE BudgetLineId=@BudgetLineId";
            if (sourceSpendItemIds.Count > 0) sql += "; INSERT dbo.BudgetLineSpendItems(BudgetLineId,SpendItemId) SELECT @BudgetLineId,s.SpendItemId FROM dbo.SpendItems s JOIN dbo.BudgetLines b ON b.BudgetLineId=@BudgetLineId AND b.PetId=s.PetId WHERE s.SpendItemId IN (" + string.Join(",", names) + ")";
            Db.Execute(sql, parameters.ToArray());
        }

        private static void AttachBudgetLineSourceSpendItems(List<Dictionary<string, object>> budgetLines)
        {
            if (budgetLines == null || budgetLines.Count == 0 || !BudgetLineSpendItemSelectionAvailable()) return;
            var budgetLineIds = budgetLines.Select(row => Convert.ToInt32(row["BudgetLineId"])).Distinct().ToList();
            var parameters = new List<SqlParameter>();
            var names = budgetLineIds.Select((id, index) => "@BudgetLine" + index).ToArray();
            for (var index = 0; index < budgetLineIds.Count; index++) parameters.Add(P(names[index], budgetLineIds[index]));
            var rows = Db.Query(@"SELECT bsi.BudgetLineId,
                STUFF((SELECT ',' + CONVERT(nvarchar(20), innerBsi.SpendItemId)
                    FROM dbo.BudgetLineSpendItems innerBsi
                    WHERE innerBsi.BudgetLineId=bsi.BudgetLineId
                    ORDER BY innerBsi.SpendItemId
                    FOR XML PATH(''), TYPE).value('.','nvarchar(max)'),1,1,'') SourceSpendItemIds
                FROM dbo.BudgetLineSpendItems bsi
                WHERE bsi.BudgetLineId IN (" + string.Join(",", names) + @")
                GROUP BY bsi.BudgetLineId", parameters.ToArray());
            foreach (var row in rows)
            {
                var budgetLineId = Convert.ToInt32(row["BudgetLineId"]);
                var line = budgetLines.FirstOrDefault(item => Convert.ToInt32(item["BudgetLineId"]) == budgetLineId);
                if (line != null) line["SourceSpendItemIds"] = row["SourceSpendItemIds"];
            }
        }

        private static void ExecutePetDecision(int petId, string stage, DecisionRequest value, string user)
        {
            try
            {
                Db.Execute("EXEC dbo.sp_PetDecision @PetId,@Stage,@Approve,@Comments,@User,@BudgetSourceId,@Decision", P("@PetId", petId), P("@Stage", stage), P("@Approve", value.Approve), P("@Comments", value.Comments), P("@User", user), P("@BudgetSourceId", value.BudgetSourceId), P("@Decision", value.Decision));
            }
            catch (SqlException ex)
            {
                if (!ProcedureParameterError(ex) || value.Decision.Equals("SendBack", StringComparison.OrdinalIgnoreCase)) throw;
                Db.Execute("EXEC dbo.sp_PetDecision @PetId,@Stage,@Approve,@Comments,@User,@BudgetSourceId", P("@PetId", petId), P("@Stage", stage), P("@Approve", value.Approve), P("@Comments", value.Comments), P("@User", user), P("@BudgetSourceId", value.BudgetSourceId));
            }
        }

        private static bool ProcedureParameterError(SqlException ex)
        {
            return ex.Errors.Cast<SqlError>().Any(error => error.Number == 8144 || error.Number == 201);
        }

        private static string ValidateDecision(DecisionRequest value, bool finalApproval)
        {
            if (value == null) return "Decision details are required.";
            var decision = string.IsNullOrWhiteSpace(value.Decision) ? (value.Approve ? "Approve" : "RejectCancel") : value.Decision;
            if (!new[] { "Approve", "SendBack", "RejectCancel" }.Contains(decision, StringComparer.OrdinalIgnoreCase)) return "Select a valid decision.";
            if ((decision.Equals("SendBack", StringComparison.OrdinalIgnoreCase) || decision.Equals("RejectCancel", StringComparison.OrdinalIgnoreCase)) && string.IsNullOrWhiteSpace(value.Comments)) return "Comments / reason is required for this decision.";
            if (finalApproval && decision.Equals("Approve", StringComparison.OrdinalIgnoreCase) && !value.BudgetSourceId.HasValue) return "Select a CapEx source before approval.";
            value.Decision = decision;
            value.Approve = decision.Equals("Approve", StringComparison.OrdinalIgnoreCase);
            return null;
        }
    }
}
