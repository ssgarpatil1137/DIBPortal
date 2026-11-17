using System;
using System.Data.SqlClient;
using System.Linq;
using System.Web.Http;
using DFM.Web.Infrastructure;
using DFM.Web.Models;

namespace DFM.Web.Controllers
{
    // Self-service delegation: a Reviewer/Approver names one active backup who can act on their assigned PET decisions.
    [ApiAuthorize, RoutePrefix("api/delegation")]
    public class DelegationController : ApiController
    {
        private const string SharedWorkflowRoleSql = @"EXISTS(SELECT 1 FROM dbo.UserRoles mine JOIN dbo.Roles mr ON mr.RoleId=mine.RoleId
            JOIN dbo.UserRoles theirs ON theirs.RoleId=mine.RoleId
            WHERE mine.UserId=@Me AND theirs.UserId={0} AND mr.Name IN ('Reviewer','Approver'))";

        [HttpGet, Route("")]
        public IHttpActionResult Get()
        {
            try
            {
                var me = CurrentUserId();
                if (!me.HasValue) return Unauthorized();
                var current = Db.Query(@"SELECT TOP 1 d.DelegationId,d.DelegateUserId,g.Email DelegateEmail,g.DisplayName DelegateName,d.StartDate,d.EndDate,d.CreatedUtc,d.CreatedBy,d.UpdatedUtc,d.UpdatedBy,
                    CASE WHEN g.IsActive=0 OR g.PortalAccess=0 THEN 'Delegate inactive'
                         WHEN d.StartDate>CAST(GETDATE() AS date) THEN 'Scheduled'
                         WHEN d.EndDate IS NOT NULL AND d.EndDate<CAST(GETDATE() AS date) THEN 'Expired'
                         ELSE 'Active' END Status
                    FROM dbo.UserDelegations d JOIN dbo.Users g ON g.UserId=d.DelegateUserId
                    WHERE d.DelegatorUserId=@Me AND d.RevokedUtc IS NULL", P("@Me", me.Value)).FirstOrDefault();
                return Ok(new { eligible = IsEligible(), delegation = current, received = ReceivedDelegations(User.Identity.Name) });
            }
            catch (SqlException ex) { return BadRequest(ex.Message); }
        }

        [HttpGet, Route("candidates")]
        public IHttpActionResult Candidates()
        {
            if (!IsEligible()) return Ok(new object[0]);
            try
            {
                var me = CurrentUserId();
                if (!me.HasValue) return Unauthorized();
                return Ok(Db.Query(@"SELECT u.UserId,u.DisplayName,u.Email FROM dbo.Users u
                    WHERE u.UserId<>@Me AND u.IsActive=1 AND u.PortalAccess=1 AND " + string.Format(SharedWorkflowRoleSql, "u.UserId") + @"
                    ORDER BY u.DisplayName,u.Email", P("@Me", me.Value)));
            }
            catch (SqlException ex) { return BadRequest(ex.Message); }
        }

        [HttpPost, Route("")]
        public IHttpActionResult Save(DelegationRequest value)
        {
            if (!IsEligible()) return Content(System.Net.HttpStatusCode.Forbidden, "Delegation is available to Reviewers and Approvers only.");
            if (value == null || value.DelegateUserId <= 0) return BadRequest("Select a delegate.");
            try
            {
                var me = CurrentUserId();
                if (!me.HasValue) return Unauthorized();
                var saved = Db.Query(@"SET XACT_ABORT ON; BEGIN TRAN;
                    DECLARE @Today date=CAST(GETDATE() AS date),@Existing int,@OldDelegate int,@OldStart date,@OldEnd date,@DelegateEmail nvarchar(254),@OldDelegateEmail nvarchar(254);
                    SELECT @Existing=DelegationId,@OldDelegate=DelegateUserId,@OldStart=StartDate,@OldEnd=EndDate
                      FROM dbo.UserDelegations WITH(UPDLOCK,HOLDLOCK) WHERE DelegatorUserId=@Me AND RevokedUtc IS NULL;
                    IF @Delegate=@Me THROW 50080,'You cannot delegate to yourself.',1;
                    SELECT @DelegateEmail=Email FROM dbo.Users WHERE UserId=@Delegate AND IsActive=1 AND PortalAccess=1;
                    IF @DelegateEmail IS NULL THROW 50081,'Select an active user as your delegate.',1;
                    IF NOT " + string.Format(SharedWorkflowRoleSql, "@Delegate") + @" THROW 50082,'The delegate must hold the Reviewer or Approver role you are delegating.',1;
                    SET @Start=ISNULL(@Start,@Today);
                    IF @Start<@Today AND (@Existing IS NULL OR @Start<>@OldStart) THROW 50083,'Start date cannot be in the past.',1;
                    IF @End IS NOT NULL AND @End<@Start THROW 50084,'End date cannot be before the start date.',1;
                    IF @End IS NOT NULL AND @End<@Today THROW 50085,'End date cannot be in the past.',1;
                    IF @Existing IS NULL
                    BEGIN
                        INSERT dbo.UserDelegations(DelegatorUserId,DelegateUserId,StartDate,EndDate,CreatedBy,UpdatedBy) VALUES(@Me,@Delegate,@Start,@End,@Actor,@Actor);
                        SET @Existing=CONVERT(int,SCOPE_IDENTITY());
                        INSERT dbo.AuditLog(EntityType,EntityId,ActionName,UserEmail,Detail)
                        VALUES('Delegation',@Existing,'DelegationCreated',@Actor,CONCAT('Delegate=',@DelegateEmail,'; Start=',CONVERT(char(10),@Start,23),'; End=',ISNULL(CONVERT(char(10),@End,23),'none')));
                    END
                    ELSE
                    BEGIN
                        SELECT @OldDelegateEmail=Email FROM dbo.Users WHERE UserId=@OldDelegate;
                        UPDATE dbo.UserDelegations SET DelegateUserId=@Delegate,StartDate=@Start,EndDate=@End,UpdatedUtc=SYSUTCDATETIME(),UpdatedBy=@Actor WHERE DelegationId=@Existing;
                        INSERT dbo.AuditLog(EntityType,EntityId,ActionName,UserEmail,Detail)
                        VALUES('Delegation',@Existing,'DelegationUpdated',@Actor,CONCAT('Delegate=',@OldDelegateEmail,' -> ',@DelegateEmail,'; Start=',CONVERT(char(10),@OldStart,23),' -> ',CONVERT(char(10),@Start,23),'; End=',ISNULL(CONVERT(char(10),@OldEnd,23),'none'),' -> ',ISNULL(CONVERT(char(10),@End,23),'none')));
                    END;
                    COMMIT;
                    SELECT @Existing DelegationId;",
                    P("@Me", me.Value), P("@Delegate", value.DelegateUserId), PDate("@Start", value.StartDate), PDate("@End", value.EndDate), P("@Actor", User.Identity.Name)).FirstOrDefault();
                return Ok(saved);
            }
            catch (SqlException ex) { return BadRequest(ex.Number == 2601 || ex.Number == 2627 ? "You already have a delegation. Update or revoke it instead." : ex.Message); }
        }

        [HttpPost, Route("revoke")]
        public IHttpActionResult Revoke()
        {
            try
            {
                var me = CurrentUserId();
                if (!me.HasValue) return Unauthorized();
                Db.Execute(@"SET XACT_ABORT ON; BEGIN TRAN;
                    DECLARE @Id int,@DelegateEmail nvarchar(254);
                    SELECT @Id=d.DelegationId,@DelegateEmail=g.Email FROM dbo.UserDelegations d WITH(UPDLOCK,HOLDLOCK) JOIN dbo.Users g ON g.UserId=d.DelegateUserId
                      WHERE d.DelegatorUserId=@Me AND d.RevokedUtc IS NULL;
                    IF @Id IS NULL THROW 50086,'You have no delegation to revoke.',1;
                    UPDATE dbo.UserDelegations SET RevokedUtc=SYSUTCDATETIME(),RevokedBy=@Actor,UpdatedUtc=SYSUTCDATETIME(),UpdatedBy=@Actor WHERE DelegationId=@Id;
                    INSERT dbo.AuditLog(EntityType,EntityId,ActionName,UserEmail,Detail) VALUES('Delegation',@Id,'DelegationRevoked',@Actor,CONCAT('Delegate=',@DelegateEmail));
                    COMMIT;", P("@Me", me.Value), P("@Actor", User.Identity.Name));
                return Ok();
            }
            catch (SqlException ex) { return BadRequest(ex.Message); }
        }

        // Active delegators of the given user; empty when the delegation migration has not been deployed.
        internal static object ReceivedDelegations(string delegateEmail)
        {
            try
            {
                return Db.Query(@"SELECT DelegatorEmail Email,DelegatorName DisplayName,DelegatorCanReview CanReview,DelegatorCanApprove CanApprove,StartDate,EndDate
                    FROM dbo.vw_ActiveDelegations WHERE DelegateEmail=@Email ORDER BY DelegatorName", P("@Email", delegateEmail));
            }
            catch (SqlException ex) { if (ex.Number == 208) return new object[0]; throw; }
        }

        // Returns the assignee the actor is acting for through an active delegation, or null when the actor
        // is directly assigned (or not covered by any delegation, in which case sp_PetDecision rejects as before).
        internal static string ResolveOnBehalfOf(int petId, string stage, string actor)
        {
            try
            {
                var row = Db.Query(@"DECLARE @ReviewerEmail nvarchar(254),@ApproverEmail nvarchar(254),@Lead nvarchar(200),@Exec nvarchar(200),@ActorName nvarchar(200);
                    SELECT @ReviewerEmail=pet.ReviewerEmail,@ApproverEmail=pet.ApproverEmail,@Lead=p.AccountableExecLead,@Exec=p.AccountableExec
                      FROM dbo.PETRequests pet JOIN dbo.Projects p ON p.ProjectId=pet.ProjectId WHERE pet.PetId=@PetId;
                    SELECT @ActorName=DisplayName FROM dbo.Users WHERE Email=@Actor;
                    IF (@Stage='Review' AND ((@ReviewerEmail IS NOT NULL AND LOWER(@ReviewerEmail)=LOWER(@Actor)) OR (@ReviewerEmail IS NULL AND @ActorName IS NOT NULL AND LTRIM(RTRIM(@ActorName))=LTRIM(RTRIM(ISNULL(@Lead,''))))))
                       OR (@Stage='Approval' AND ((@ApproverEmail IS NOT NULL AND LOWER(@ApproverEmail)=LOWER(@Actor)) OR (@ApproverEmail IS NULL AND @ActorName IS NOT NULL AND LTRIM(RTRIM(@ActorName))=LTRIM(RTRIM(ISNULL(@Exec,''))))))
                        SELECT CAST(NULL AS nvarchar(254)) OnBehalfOf;
                    ELSE
                        SELECT TOP 1 d.DelegatorEmail OnBehalfOf FROM dbo.vw_ActiveDelegations d
                        WHERE LOWER(d.DelegateEmail)=LOWER(@Actor)
                          AND ((@Stage='Review' AND d.DelegatorCanReview=1 AND ((@ReviewerEmail IS NOT NULL AND LOWER(@ReviewerEmail)=LOWER(d.DelegatorEmail)) OR (@ReviewerEmail IS NULL AND d.DelegatorName IS NOT NULL AND LTRIM(RTRIM(d.DelegatorName))=LTRIM(RTRIM(ISNULL(@Lead,''))))))
                            OR (@Stage='Approval' AND d.DelegatorCanApprove=1 AND ((@ApproverEmail IS NOT NULL AND LOWER(@ApproverEmail)=LOWER(d.DelegatorEmail)) OR (@ApproverEmail IS NULL AND d.DelegatorName IS NOT NULL AND LTRIM(RTRIM(d.DelegatorName))=LTRIM(RTRIM(ISNULL(@Exec,'')))))))
                        ORDER BY d.DelegationId;",
                    P("@PetId", petId), P("@Stage", stage), P("@Actor", actor)).FirstOrDefault();
                return row == null ? null : row["OnBehalfOf"] as string;
            }
            catch (SqlException ex) { if (ex.Number == 208) return null; throw; }
        }

        private bool IsEligible() { return User.IsInRole("Reviewer") || User.IsInRole("Approver"); }

        private int? CurrentUserId()
        {
            var row = Db.Query("SELECT UserId FROM dbo.Users WHERE Email=@Email AND IsActive=1 AND PortalAccess=1", P("@Email", User.Identity.Name)).FirstOrDefault();
            return row == null ? (int?)null : Convert.ToInt32(row["UserId"]);
        }

        private static SqlParameter PDate(string name, DateTime? value)
        {
            return new SqlParameter(name, System.Data.SqlDbType.Date) { Value = value.HasValue ? (object)value.Value.Date : DBNull.Value };
        }

        private static SqlParameter P(string name, object value) { return new SqlParameter(name, Db.Value(value)); }
    }
}
