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
        private static readonly string[] DepartmentOptions = { "Business", "CET", "CIO Office", "Core", "CRM", "CTO", "Data", "EA&l", "EIS", "Governance", "Risk", "RTB", "Test Gov." };
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
            return Ok(new {
                metrics = Db.Query("SELECT * FROM vw_ManagementDashboard"),
                projects = Db.Query("SELECT * FROM vw_ProjectPortfolio ORDER BY CreatedUtc DESC"),
                approvalPets = Db.Query(@"SELECT pet.* FROM dbo.PETRequests pet JOIN dbo.Projects p ON p.ProjectId=pet.ProjectId CROSS APPLY (SELECT DisplayName FROM dbo.Users WHERE Email=@user) currentUser WHERE (pet.Status='Pending Review' AND (LOWER(ISNULL(pet.ReviewerEmail,''))=LOWER(@user) OR (ISNULL(pet.ReviewerEmail,'')='' AND LTRIM(RTRIM(ISNULL(p.AccountableExecLead,'')))=LTRIM(RTRIM(ISNULL(currentUser.DisplayName,'')))))) OR (pet.Status='Pending Approval' AND (LOWER(ISNULL(pet.ApproverEmail,''))=LOWER(@user) OR (ISNULL(pet.ApproverEmail,'')='' AND LTRIM(RTRIM(ISNULL(p.AccountableExec,'')))=LTRIM(RTRIM(ISNULL(currentUser.DisplayName,'')))))) ORDER BY pet.CreatedUtc DESC", P("@user", User.Identity.Name)),
                budgets = Db.Query("EXEC dbo.sp_GetBudgetSources"),
                jira = Db.Query("EXEC dbo.sp_GetJiraRegistrationCandidates @projectKey,@exec", P("@projectKey", projectKey), P("@exec", accountableExec)),
                budgetUsage = Db.Query("SELECT * FROM vw_CapexProjectUtilization ORDER BY BudgetSource,ApprovedUtc DESC")
            });
        }

        [HttpGet, Route("projects/{projectId:int}")]
        public IHttpActionResult Project(int projectId)
        {
            var sets = Db.QueryMultiple("EXEC dbo.sp_GetProjectDetail @id", new SqlParameter("@id", projectId));
            var attachments = sets[5];
            attachments.AddRange(Db.Query(@"SELECT AttachmentId,EntityType,EntityId,OriginalName,ContentType,FileSize,UploadedUtc
                FROM dbo.Attachments
                                WHERE (EntityType IN ('BudgetLineCAM','BudgetLineMemo','BudgetLineLPO')
                                    AND EntityId IN (SELECT b.BudgetLineId FROM dbo.BudgetLines b JOIN dbo.PETRequests p ON p.PetId=b.PetId WHERE p.ProjectId=@ProjectId))
                                    OR (EntityType='InvoiceDocument'
                                    AND EntityId IN (SELECT i.InvoiceId FROM dbo.Invoices i JOIN dbo.BudgetLines b ON b.BudgetLineId=i.BudgetLineId JOIN dbo.PETRequests p ON p.PetId=b.PetId WHERE p.ProjectId=@ProjectId))", P("@ProjectId", projectId)));
            return Ok(new {
                project = sets[0].FirstOrDefault(),
                pets = sets[1],
                spendItems = sets[2],
                budgetLines = sets[3],
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
                    if (value.VendorNameOnly || string.Equals(existingStatus, "Approved", StringComparison.OrdinalIgnoreCase))
                    {
                        if (!string.Equals(existingStatus, "Approved", StringComparison.OrdinalIgnoreCase)) return BadRequest("Only approved PET requests allow vendor-name-only editing.");
                        Db.Execute("UPDATE dbo.SpendItems SET Vendor=@VendorName WHERE PetId=@PetId", P("@VendorName", value.VendorName), P("@PetId", value.PetId));
                        return Ok(new { PetId = value.PetId, Status = "Approved" });
                    }
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
            try { ValidatePetRequiredDropdowns(value); }
            catch (ArgumentException ex) { return BadRequest(ex.Message); }
            var foreignAmount = value.ForeignAmount == 0 ? value.Units * value.UnitPrice : value.ForeignAmount;
            if (!string.Equals(value.Currency, "AED", StringComparison.OrdinalIgnoreCase) && value.AedAmount == 0 && value.ExchangeRate == 0) return BadRequest("Exchange Rate or AED Amount is required for non-AED PET line items.");
            var rate = value.ExchangeRate == 0 ? 1 : value.ExchangeRate;
            var aedAmount = value.AedAmount == 0 ? (string.Equals(value.Currency, "AED", StringComparison.OrdinalIgnoreCase) ? foreignAmount : foreignAmount * rate) : value.AedAmount;
            try { AmountValidation.ValidateSpendItemAmount(value.PetId, value.SpendItemId, aedAmount * (1 + value.ContingencyPercent / 100)); return Ok(SaveSpendItemRow(value, foreignAmount, aedAmount)); }
            catch (SqlException ex) { return BadRequest(ex.Message); }
            catch (ArgumentException ex) { return BadRequest(ex.Message); }
        }

        private static void SyncPetSpendItems(int petId, List<SpendItemRequest> items)
        {
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
                var amount = item.FinalAed > 0 ? item.FinalAed : item.AedAmount;
                var divisor = 1 + (item.ContingencyPercent / 100);
                var persistedAmount = divisor == 0 ? amount : amount / divisor;
                SaveSpendItemRow(item, persistedAmount, persistedAmount);
            }
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
                value.Vendor = NormalizeBudgetLineVendors(value.PetId, value.Vendor);
                AmountValidation.ValidateBudgetLineAmount(value.PetId, value.BudgetLineId, value.Cost);
                return Ok(Db.Query("EXEC dbo.sp_SaveBudgetLine @Id,@Pet,@Vendor,@Justification,@Cost,@Currency,@Gl,@PetRef,@CamId,@CamStatus,@CamComments,@LpoRequest,@LpoStatus,@LpoComments,@User,@CamCreatedDate,@CamApprovedDate,@LpoIssueDate", P("@Id", value.BudgetLineId), P("@Pet", value.PetId), P("@Vendor", value.Vendor), P("@Justification", value.Justification), P("@Cost", value.Cost), P("@Currency", value.Currency), P("@Gl", value.GlNumber), P("@PetRef", value.PetReference), P("@CamId", value.CamId), P("@CamStatus", value.CamStatus), P("@CamComments", value.CamComments), P("@LpoRequest", value.LpoRequest), P("@LpoStatus", lpoStatus), P("@LpoComments", value.LpoComments), P("@User", User.Identity.Name), P("@CamCreatedDate", value.CamCreatedDate), P("@CamApprovedDate", value.CamApprovedDate), P("@LpoIssueDate", value.LpoIssueDate)).FirstOrDefault());
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

        [ApiAuthorize("Master"), HttpPut, Route("budgets/{budgetSourceId:int}")]
        public IHttpActionResult UpdateBudget(int budgetSourceId, dynamic value) { Db.Execute("EXEC dbo.sp_UpdateBudget @Id,@Description,@Budget,@Utilization,@Available,@User", P("@Id", budgetSourceId), P("@Description", (string)value.description), P("@Budget", (decimal)value.budget), P("@Utilization", (decimal)value.utilization), P("@Available", (decimal)value.availableBudget), P("@User", User.Identity.Name)); return Ok(); }

        [ApiAuthorize("Requestor", "Master"), HttpPost, Route("attachments/{entityType}/{entityId:int}")]
        public async Task<IHttpActionResult> UploadAttachment(string entityType, int entityId)
        {
            if (!Request.Content.IsMimeMultipartContent()) return Content(HttpStatusCode.UnsupportedMediaType, "Use multipart/form-data.");
            var root = HttpContext.Current.Server.MapPath("~/App_Data/Attachments"); Directory.CreateDirectory(root);
            var provider = await Request.Content.ReadAsMultipartAsync(new MultipartFormDataStreamProvider(root));
            foreach (var file in provider.FileData)
            {
                var original = file.Headers.ContentDisposition.FileName.Trim('"');
                Db.Execute("EXEC dbo.sp_InsertAttachment @type,@id,@original,@stored,@content,@size,@user", P("@type", entityType), P("@id", entityId), P("@original", Path.GetFileName(original)), P("@stored", Path.GetFileName(file.LocalFileName)), P("@content", file.Headers.ContentType == null ? "application/octet-stream" : file.Headers.ContentType.MediaType), P("@size", new FileInfo(file.LocalFileName).Length), P("@user", User.Identity.Name));
            }
            return Ok();
        }

        [HttpGet, Route("attachments/{attachmentId:long}")]
        public IHttpActionResult DownloadAttachment(long attachmentId)
        {
            var row = Db.Query("SELECT OriginalName,StoredName,ContentType FROM dbo.Attachments WHERE AttachmentId=@AttachmentId", P("@AttachmentId", attachmentId)).FirstOrDefault();
            if (row == null) return NotFound();
            var root = HttpContext.Current.Server.MapPath("~/App_Data/Attachments");
            var path = Path.Combine(root, Convert.ToString(row["StoredName"]));
            if (!File.Exists(path)) return NotFound();
            var response = Request.CreateResponse(HttpStatusCode.OK);
            response.Content = new StreamContent(File.OpenRead(path));
            response.Content.Headers.ContentType = new MediaTypeHeaderValue(Convert.ToString(row["ContentType"] ?? "application/octet-stream"));
            response.Content.Headers.ContentDisposition = new ContentDispositionHeaderValue("attachment") { FileName = Convert.ToString(row["OriginalName"]) };
            return ResponseMessage(response);
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
            var department = DepartmentOptions.FirstOrDefault(option => string.Equals(option, value.Department, StringComparison.OrdinalIgnoreCase));
            if (department == null) throw new ArgumentException("Department is required.");
            var unitType = UnitTypeOptions.FirstOrDefault(option => string.Equals(option, value.UnitType, StringComparison.OrdinalIgnoreCase));
            if (unitType == null) throw new ArgumentException("Unit Type is required.");
            var costType = CostTypeOptions.FirstOrDefault(option => string.Equals(option, value.CostType, StringComparison.OrdinalIgnoreCase));
            if (costType == null) throw new ArgumentException("Cost Type is required.");
            if (!value.YearlyRecurrence.HasValue || value.YearlyRecurrence.Value < 1 || value.YearlyRecurrence.Value > 5) throw new ArgumentException("Yearly Recurrence is required.");
            value.Department = department;
            value.UnitType = unitType;
            value.CostType = costType;
        }

        private static string NormalizeBudgetLineVendors(int petId, string vendor)
        {
            var selected = (vendor ?? "").Trim();
            if (selected.Length == 0) throw new ArgumentException("Vendor Name is required.");
            var allowed = AllowedPetVendors(petId);
            if (allowed.Count == 0) throw new ArgumentException("Selected PET does not have an approved Vendor Name.");
            var match = allowed.FirstOrDefault(item => string.Equals(item, selected, StringComparison.OrdinalIgnoreCase));
            if (match == null) throw new ArgumentException("Vendor Name must be selected from SpendItems for the selected PET.");
            return match;
        }

        private static List<string> AllowedPetVendors(int petId)
        {
            var values = new List<string>();
            var rows = Db.Query("SELECT Vendor FROM dbo.SpendItems WHERE PetId=@PetId", P("@PetId", petId));
            foreach (var row in rows)
            {
                foreach (var vendor in SplitVendorNames(Convert.ToString(row["Vendor"])))
                {
                    if (!values.Any(item => string.Equals(item, vendor, StringComparison.OrdinalIgnoreCase))) values.Add(vendor);
                }
            }
            return values;
        }

        private static List<string> SplitVendorNames(string vendor)
        {
            var values = new List<string>();
            var value = (vendor ?? "").Trim();
            Action<string> addVendor = part =>
            {
                var item = (part ?? "").Trim();
                if (item.Length > 0 && !values.Any(existing => string.Equals(existing, item, StringComparison.OrdinalIgnoreCase))) values.Add(item);
            };
            addVendor(value);
            if (value.Contains(",")) foreach (var part in value.Split(',')) addVendor(part);
            return values;
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
