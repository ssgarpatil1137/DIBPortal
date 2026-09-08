using System;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Security.Principal;
using System.Web.Http.Controllers;
using System.Web.Http.Filters;
using System.Data.SqlClient;
using DFM.Web.Controllers;

namespace DFM.Web.Infrastructure
{
    [AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = true)]
    public sealed class ApiAuthorizeAttribute : AuthorizationFilterAttribute
    {
        private readonly string[] _roles;
        public ApiAuthorizeAttribute(params string[] roles) { _roles = roles ?? new string[0]; }

        public override void OnAuthorization(HttpActionContext context)
        {
            var header = context.Request.Headers.Authorization;
            var token = header != null && header.Scheme == "Bearer" ? header.Parameter : null;
            var rows = string.IsNullOrWhiteSpace(token) ? null : Db.Query(@"SELECT u.Email, STUFF((SELECT ',' + r.Name FROM UserRoles ur JOIN Roles r ON r.RoleId=ur.RoleId WHERE ur.UserId=u.UserId FOR XML PATH('')),1,1,'') Roles FROM UserSessions s JOIN Users u ON u.UserId=s.UserId WHERE s.TokenHash=HASHBYTES('SHA2_256',@token) AND s.ExpiresUtc>GETUTCDATE() AND u.IsActive=1", new SqlParameter("@token", token));
            if (rows == null || rows.Count == 0) { Deny(context, HttpStatusCode.Unauthorized); return; }
            Db.Execute("UPDATE UserSessions SET ExpiresUtc=DATEADD(MINUTE,@timeout,GETUTCDATE()) WHERE TokenHash=HASHBYTES('SHA2_256',@token)", new SqlParameter("@timeout", AuthController.SessionTimeoutMinutes), new SqlParameter("@token", token));
            var roles = Convert.ToString(rows[0]["Roles"]).Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries);
            if (_roles.Length > 0 && !_roles.Any(required => HasRole(roles, required))) { Deny(context, HttpStatusCode.Forbidden); return; }
            context.RequestContext.Principal = new GenericPrincipal(new GenericIdentity(Convert.ToString(rows[0]["Email"]), "Bearer"), roles);
        }

        private static bool HasRole(string[] roles, string required)
        {
            return roles.Contains(required, StringComparer.OrdinalIgnoreCase) ||
                (required.Equals("Master", StringComparison.OrdinalIgnoreCase) && roles.Contains("Admin", StringComparer.OrdinalIgnoreCase)) ||
                (required.Equals("Admin", StringComparison.OrdinalIgnoreCase) && roles.Contains("Master", StringComparer.OrdinalIgnoreCase));
        }

        private static void Deny(HttpActionContext context, HttpStatusCode status) { context.Response = context.Request.CreateErrorResponse(status, status == HttpStatusCode.Unauthorized ? "Authentication required." : "This role cannot perform the action."); }
    }
}
