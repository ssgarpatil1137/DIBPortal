using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
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
            return Ok(new {
                project = sets[0].FirstOrDefault(),
                pets = sets[1],
                spendItems = sets[2],
                budgetLines = sets[3],
                invoices = sets[4],
                attachments = sets[5]
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
                if (value.ProjectId.HasValue)
                {
                    var existing = Db.Query("SELECT RequiresPet,SkipReview FROM dbo.Projects WHERE ProjectId=@ProjectId", P("@ProjectId", value.ProjectId)).FirstOrDefault();
                    if (existing != null && existing["RequiresPet"] != null) requiresPet = Convert.ToBoolean(existing["RequiresPet"]);
                    if (existing != null && existing["SkipReview"] != null) skipReview = Convert.ToBoolean(existing["SkipReview"]);
                }
                var rows = Db.Query("EXEC dbo.sp_SaveProject @ProjectId,@IsJira,@JiraKey,@Name,@Type,@Lead,@Executive,@Sme,@Size,@Manager,@BudgetType,@BudgetSource,@RequiresPet,@SkipReview,@User", P("@ProjectId", value.ProjectId), P("@IsJira", value.IsJira), P("@JiraKey", value.JiraKey), P("@Name", value.ProjectName), P("@Type", value.ProjectType), P("@Lead", value.AccountableExecLead), P("@Executive", value.AccountableExec), P("@Sme", value.SmeLead), P("@Size", value.ProjectSize), P("@Manager", value.ProjectManager), P("@BudgetType", value.BudgetType), P("@BudgetSource", value.BudgetSourceId), P("@RequiresPet", requiresPet), P("@SkipReview", skipReview), P("@User", User.Identity.Name));
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
                        Db.Execute("UPDATE dbo.PETRequests SET VendorName=@VendorName,UpdatedUtc=SYSUTCDATETIME() WHERE PetId=@PetId AND Status='Approved'", P("@VendorName", value.VendorName), P("@PetId", value.PetId));
                        return Ok(new { PetId = value.PetId, Status = "Approved" });
                    }
                }
                if (value.RequestedAmount <= 0) return BadRequest("A positive PET amount is required.");
                return Ok(Db.Query("EXEC dbo.sp_SavePet @PetId,@ProjectId,@Code,@Amount,@Currency,@User,@VendorName", P("@PetId", value.PetId), P("@ProjectId", value.ProjectId), P("@Code", value.Code), P("@Amount", value.RequestedAmount), P("@Currency", value.Currency), P("@User", User.Identity.Name), P("@VendorName", value.VendorName)).FirstOrDefault());
            }
            catch (SqlException ex) { return BadRequest(ex.Message); }
            catch (Exception ex) { return BadRequest(ex.Message); }
        }

        [ApiAuthorize("Requestor", "Master"), HttpPost, Route("spend-items")]
        public IHttpActionResult SaveSpendItem(SpendItemRequest value)
        {
            if (value == null || string.IsNullOrWhiteSpace(value.Vendor)) return BadRequest("Vendor is required.");
            var foreignAmount = value.ForeignAmount == 0 ? value.Units * value.UnitPrice : value.ForeignAmount;
            var aedAmount = value.AedAmount == 0 ? foreignAmount : value.AedAmount;
            try { return Ok(Db.Query("EXEC dbo.sp_SaveSpendItem @Id,@Pet,@Head,@Topic,@Vendor,@CostType,@UnitType,@Units,@UnitPrice,@Currency,@Foreign,@Aed,@Contingency,@Gl", P("@Id", value.SpendItemId), P("@Pet", value.PetId), P("@Head", value.Head), P("@Topic", value.Topic), P("@Vendor", value.Vendor), P("@CostType", value.CostType), P("@UnitType", value.UnitType), P("@Units", value.Units), P("@UnitPrice", value.UnitPrice), P("@Currency", value.Currency), P("@Foreign", foreignAmount), P("@Aed", aedAmount), P("@Contingency", value.ContingencyPercent), P("@Gl", value.GlNumber)).FirstOrDefault()); }
            catch (SqlException ex) { return BadRequest(ex.Message); }
        }

        [ApiAuthorize("Reviewer"), HttpPost, Route("pets/{petId:int}/review")]
        public IHttpActionResult Review(int petId, DecisionRequest value) { try { Db.Execute("EXEC dbo.sp_PetDecision @PetId,@Stage,@Approve,@Comments,@User", P("@PetId", petId), P("@Stage", "Review"), P("@Approve", value.Approve), P("@Comments", value.Comments), P("@User", User.Identity.Name)); return Ok(); } catch (SqlException ex) { return BadRequest(ex.Message); } }

        [ApiAuthorize("Approver"), HttpPost, Route("pets/{petId:int}/approve")]
        public IHttpActionResult Approve(int petId, DecisionRequest value) { try { Db.Execute("EXEC dbo.sp_PetDecision @PetId,@Stage,@Approve,@Comments,@User,@BudgetSourceId", P("@PetId", petId), P("@Stage", "Approval"), P("@Approve", value.Approve), P("@Comments", value.Comments), P("@User", User.Identity.Name), P("@BudgetSourceId", value.BudgetSourceId)); return Ok(); } catch (SqlException ex) { return BadRequest(ex.Message); } }

        [ApiAuthorize("Requestor", "Master"), HttpPost, Route("budget-lines")]
        public IHttpActionResult SaveBudgetLine(BudgetLineRequest value)
        {
            try
            {
                object lpoStatus = null;
                if (value.BudgetLineId.HasValue)
                {
                    var existing = Db.Query("SELECT LpoStatus FROM dbo.BudgetLines WHERE BudgetLineId=@Id", P("@Id", value.BudgetLineId)).FirstOrDefault();
                    if (existing != null) lpoStatus = existing["LpoStatus"];
                }
                return Ok(Db.Query("EXEC dbo.sp_SaveBudgetLine @Id,@Pet,@Vendor,@Justification,@Cost,@Currency,@Gl,@PetRef,@CamId,@CamStatus,@CamComments,@LpoRequest,@LpoStatus,@LpoComments,@User,@CamCreatedDate,@CamApprovedDate,@LpoIssueDate", P("@Id", value.BudgetLineId), P("@Pet", value.PetId), P("@Vendor", value.Vendor), P("@Justification", value.Justification), P("@Cost", value.Cost), P("@Currency", value.Currency), P("@Gl", value.GlNumber), P("@PetRef", value.PetReference), P("@CamId", value.CamId), P("@CamStatus", value.CamStatus), P("@CamComments", value.CamComments), P("@LpoRequest", value.LpoRequest), P("@LpoStatus", lpoStatus), P("@LpoComments", value.LpoComments), P("@User", User.Identity.Name), P("@CamCreatedDate", value.CamCreatedDate), P("@CamApprovedDate", value.CamApprovedDate), P("@LpoIssueDate", value.LpoIssueDate)).FirstOrDefault());
            }
            catch (SqlException ex) { return BadRequest(ex.Message); }
            catch (Exception ex) { return BadRequest(ex.Message); }
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

        [ApiAuthorize("Requestor", "Master"), HttpPost, Route("bulk/{kind}/{parentId:int}")]
        public async Task<IHttpActionResult> Bulk(string kind, int parentId)
        {
            if (!new[] { "pet", "budget", "invoice" }.Contains(kind, StringComparer.OrdinalIgnoreCase)) return BadRequest("Unknown template type.");
            try
            {
                var csv = await Request.Content.ReadAsStringAsync();
                var imported = CsvBulkImporter.Import(kind, parentId, csv, User.Identity.Name);
                return Ok(new { imported = imported });
            }
            catch (SqlException ex) { return BadRequest(ex.Message); }
            catch (Exception ex) { return BadRequest(ex.Message); }
        }

        private static SqlParameter P(string name, object value) { return new SqlParameter(name, Db.Value(value)); }
    }
}
