using System;
using System.Data.SqlClient;
using System.Linq;
using System.Net;
using System.Web.Http;
using DFM.Web.Infrastructure;
using DFM.Web.Models;

namespace DFM.Web.Controllers
{
    [RoutePrefix("api/auth")]
    public class AuthController : ApiController
    {
        [AllowAnonymous, HttpPost, Route("login")]
        public IHttpActionResult Login(LoginRequest request)
        {
            var email = NormalizeEmail(request == null ? null : request.Email);
            if (string.IsNullOrWhiteSpace(email)) return BadRequest("Email is required.");
            var users = Db.Query("SELECT UserId,Email,DisplayName,PasswordSalt,PasswordHash,RequiresPasswordSetup FROM Users WHERE Email=@email AND IsActive=1", new SqlParameter("@email", email));
            if (users.Count == 0) return Unauthorized();
            var user = users[0];
            if (Convert.ToBoolean(user["RequiresPasswordSetup"])) return Ok(new AuthResult { Email = Convert.ToString(user["Email"]), DisplayName = Convert.ToString(user["DisplayName"]), RequiresPasswordSetup = true });
            if (user["PasswordHash"] == null || !PasswordSecurity.Verify(request.Password ?? "", (byte[])user["PasswordSalt"], (byte[])user["PasswordHash"])) return Unauthorized();
            return Ok(CreateSession(Convert.ToInt32(user["UserId"]), Convert.ToString(user["Email"]), Convert.ToString(user["DisplayName"])));
        }

        [ApiAuthorize, HttpGet, Route("session")]
        public IHttpActionResult Session()
        {
            var users = Db.Query("SELECT UserId,Email,DisplayName FROM Users WHERE Email=@email AND IsActive=1", new SqlParameter("@email", User.Identity.Name));
            if (users.Count == 0) return Unauthorized();
            var user = users[0];
            var roles = Db.Query("SELECT r.Name FROM UserRoles ur JOIN Roles r ON r.RoleId=ur.RoleId WHERE ur.UserId=@user", new SqlParameter("@user", user["UserId"])).Select(row => Convert.ToString(row["Name"])).ToArray();
            return Ok(new AuthResult { Email = Convert.ToString(user["Email"]), DisplayName = Convert.ToString(user["DisplayName"]), Roles = roles });
        }

        [AllowAnonymous, HttpGet, Route("security-questions")]
        public IHttpActionResult Questions() { return Ok(Db.Query("SELECT SecurityQuestionId,Question FROM SecurityQuestions WHERE IsActive=1 ORDER BY SecurityQuestionId")); }

        [AllowAnonymous, HttpPost, Route("first-time-setup")]
        public IHttpActionResult FirstTimeSetup(PasswordSetupRequest request)
        {
            if (!ValidPassword(request == null ? null : request.Password)) return BadRequest("Password must be at least 10 characters and contain upper, lower, number and symbol.");
            var email = NormalizeEmail(request == null ? null : request.Email);
            if (string.IsNullOrWhiteSpace(email)) return BadRequest("Email is required.");
            var users = Db.Query("SELECT UserId,RequiresPasswordSetup FROM Users WHERE Email=@email AND IsActive=1", new SqlParameter("@email", email));
            if (users.Count == 0 || !Convert.ToBoolean(users[0]["RequiresPasswordSetup"])) return Content(HttpStatusCode.Conflict, "First-time setup is unavailable.");
            request.Email = email;
            SavePassword(Convert.ToInt32(users[0]["UserId"]), request);
            return Ok();
        }

        [AllowAnonymous, HttpPost, Route("reset/challenge")]
        public IHttpActionResult ResetChallenge(ResetChallengeRequest request)
        {
            var email = NormalizeEmail(request == null ? null : request.Email);
            if (request == null || string.IsNullOrWhiteSpace(email)) return BadRequest("Email is required.");
            var rows = Db.Query("SELECT u.UserId,u.SecurityAnswerSalt,u.SecurityAnswerHash FROM Users u WHERE u.Email=@email AND u.SecurityQuestionId=@question AND u.IsActive=1", new SqlParameter("@email", email), new SqlParameter("@question", request.SecurityQuestionId));
            if (rows.Count == 0 || rows[0]["SecurityAnswerHash"] == null || !PasswordSecurity.Verify((request.SecurityAnswer ?? "").Trim().ToUpperInvariant(), (byte[])rows[0]["SecurityAnswerSalt"], (byte[])rows[0]["SecurityAnswerHash"])) return Unauthorized();
            var token = PasswordSecurity.Token();
            Db.Execute("INSERT PasswordResetTokens(UserId,TokenHash,ExpiresUtc) VALUES(@user,HASHBYTES('SHA2_256',@token),DATEADD(MINUTE,15,GETUTCDATE()))", new SqlParameter("@user", rows[0]["UserId"]), new SqlParameter("@token", token));
            return Ok(new { resetToken = token });
        }

        [AllowAnonymous, HttpPost, Route("reset/complete")]
        public IHttpActionResult ResetComplete(PasswordSetupRequest request)
        {
            if (!ValidPassword(request == null ? null : request.Password)) return BadRequest("Password does not meet policy.");
            var email = NormalizeEmail(request == null ? null : request.Email);
            if (string.IsNullOrWhiteSpace(email)) return BadRequest("Email is required.");
            var rows = Db.Query("SELECT TOP 1 t.ResetTokenId,t.UserId FROM PasswordResetTokens t JOIN Users u ON u.UserId=t.UserId WHERE u.Email=@email AND t.TokenHash=HASHBYTES('SHA2_256',@token) AND t.UsedUtc IS NULL AND t.ExpiresUtc>GETUTCDATE()", new SqlParameter("@email", email), new SqlParameter("@token", request.ResetToken));
            if (rows.Count == 0) return Unauthorized();
            SavePassword(Convert.ToInt32(rows[0]["UserId"]), request);
            Db.Execute("UPDATE PasswordResetTokens SET UsedUtc=GETUTCDATE() WHERE ResetTokenId=@id", new SqlParameter("@id", rows[0]["ResetTokenId"]));
            return Ok();
        }

        private static AuthResult CreateSession(int userId, string email, string displayName)
        {
            var token = PasswordSecurity.Token();
            Db.Execute("DELETE UserSessions WHERE UserId=@user; INSERT UserSessions(UserId,TokenHash,ExpiresUtc) VALUES(@user,HASHBYTES('SHA2_256',@token),DATEADD(HOUR,8,GETUTCDATE()))", new SqlParameter("@user", userId), new SqlParameter("@token", token));
            var roles = Db.Query("SELECT r.Name FROM UserRoles ur JOIN Roles r ON r.RoleId=ur.RoleId WHERE ur.UserId=@user", new SqlParameter("@user", userId)).Select(row => Convert.ToString(row["Name"])).ToArray();
            return new AuthResult { Token = token, Email = email, DisplayName = displayName, Roles = roles };
        }

        private static string NormalizeEmail(string email)
        {
            return (email ?? "").Trim().TrimEnd(';', ',').Trim().ToLowerInvariant();
        }

        private static void SavePassword(int userId, PasswordSetupRequest request)
        {
            byte[] salt, hash, answerSalt, answerHash;
            PasswordSecurity.CreateHash(request.Password, out salt, out hash);
            PasswordSecurity.CreateHash((request.SecurityAnswer ?? "").Trim().ToUpperInvariant(), out answerSalt, out answerHash);
            Db.Execute("UPDATE Users SET PasswordSalt=@salt,PasswordHash=@hash,SecurityQuestionId=@question,SecurityAnswerSalt=@answerSalt,SecurityAnswerHash=@answerHash,RequiresPasswordSetup=0,UpdatedUtc=GETUTCDATE() WHERE UserId=@user", new SqlParameter("@salt", salt), new SqlParameter("@hash", hash), new SqlParameter("@question", request.SecurityQuestionId), new SqlParameter("@answerSalt", answerSalt), new SqlParameter("@answerHash", answerHash), new SqlParameter("@user", userId));
        }

        private static bool ValidPassword(string value) { return !string.IsNullOrEmpty(value) && value.Length >= 10 && value.Any(char.IsUpper) && value.Any(char.IsLower) && value.Any(char.IsDigit) && value.Any(ch => !char.IsLetterOrDigit(ch)); }
    }
}
