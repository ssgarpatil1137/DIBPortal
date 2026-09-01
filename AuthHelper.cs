using System;
using System.Configuration;
using System.Web;

namespace DFM_BPM.App_Code.Helpers
{
    /// <summary>
    /// Authentication helper.
    /// Dev mode: identity comes from Session["DevUser"] or AppSettings["DevUser"] -- no IIS auth required.
    /// UAT/Prod: identity comes from IIS Windows Authentication.
    /// Roles are stored in dbo.AppUsers / dbo.UserRoleAssignments and auto-provisioned as Requestor.
    /// </summary>
    public static class AuthHelper
    {
        // -- Environment flags -----------------------------------------------

        public static bool IsDev
        {
            get
            {
                string env = ConfigurationManager.AppSettings["AppEnvironment"];
                return string.IsNullOrEmpty(env) || string.Equals(env, "Dev", StringComparison.OrdinalIgnoreCase);
            }
        }

        public static bool IsUAT
        {
            get
            {
                return string.Equals(ConfigurationManager.AppSettings["AppEnvironment"] ?? "", "UAT", StringComparison.OrdinalIgnoreCase);
            }
        }

        public static bool IsProd
        {
            get
            {
                return string.Equals(ConfigurationManager.AppSettings["AppEnvironment"] ?? "", "Prod", StringComparison.OrdinalIgnoreCase);
            }
        }

        // -- Identity ---------------------------------------------------------

        /// <summary>Returns DOMAIN\user (UAT/Prod) or dev username (Dev).</summary>
        public static string CurrentUser
        {
            get
            {
                if (IsDev)
                {
                    // Dev mode: prefer session override, fall back to config default
                    if (HttpContext.Current != null && HttpContext.Current.Session != null)
                    {
                        string sessionUser = HttpContext.Current.Session["DevUser"] as string;
                        if (!string.IsNullOrEmpty(sessionUser)) return sessionUser;
                    }
                    string cfgUser = ConfigurationManager.AppSettings["DevUser"];
                    return !string.IsNullOrEmpty(cfgUser) ? cfgUser : "devadmin";
                }

                // UAT / Prod: Windows identity from IIS
                if (HttpContext.Current == null) return "system";
                if (HttpContext.Current.User == null) return "anonymous";
                var identity = HttpContext.Current.User.Identity;
                if (identity == null || !identity.IsAuthenticated) return "anonymous";
                string name = identity.Name != null ? identity.Name : "anonymous";
                return name;
            }
        }

        /// <summary>Short name without domain (used as DB key).</summary>
        public static string CurrentUserShort
        {
            get
            {
                string u = CurrentUser;
                int bs = u.LastIndexOf('\\');
                return bs >= 0 ? u.Substring(bs + 1) : u;
            }
        }

        public static string CurrentFullName
        {
            get
            {
                if (HttpContext.Current == null || HttpContext.Current.Session == null) return CurrentUserShort;
                return (HttpContext.Current.Session["FullName"] as string) ?? CurrentUserShort;
            }
        }

        public static string CurrentRole
        {
            get
            {
                if (HttpContext.Current == null || HttpContext.Current.Session == null) return "";
                // In Dev mode, session role override takes highest priority
                if (IsDev)
                {
                    string devRole = HttpContext.Current.Session["DevRoleOverride"] as string;
                    if (!string.IsNullOrEmpty(devRole)) return devRole;
                }
                return (HttpContext.Current.Session["Role"] as string) ?? "";
            }
        }

        public static bool IsAdmin
        {
            get { return string.Equals(CurrentRole, "Admin", StringComparison.OrdinalIgnoreCase); }
        }

        public static bool IsRequestor
        {
            get { return HasRoleAssignment("Requestor"); }
        }

        public static bool IsReviewer
        {
            get { return HasRoleAssignment("Reviewer"); }
        }

        public static bool IsApprover
        {
            get { return HasRoleAssignment("Approver"); }
        }

        private static bool HasRoleAssignment(string roleType)
        {
            if (HttpContext.Current == null || HttpContext.Current.Session == null) return false;

            // In Dev mode, if role override is set, use it (Admin gets all roles)
            if (IsDev)
            {
                string devRole = HttpContext.Current.Session["DevRoleOverride"] as string;
                if (!string.IsNullOrEmpty(devRole))
                {
                    if (string.Equals(devRole, "Admin", StringComparison.OrdinalIgnoreCase)) return true;
                    return string.Equals(devRole, roleType, StringComparison.OrdinalIgnoreCase);
                }
            }

            string key = "RoleAssign_" + roleType;
            object cached = HttpContext.Current.Session[key];
            if (cached != null) return (bool)cached;
            int cnt = Convert.ToInt32(DAL.Db.Scalar(
                "SELECT COUNT(*) FROM dbo.UserRoleAssignments WHERE Username=@u AND RoleType=@r",
                DAL.Db.P("@u", CurrentUserShort), DAL.Db.P("@r", roleType)));
            bool result = cnt > 0;
            HttpContext.Current.Session[key] = result;
            return result;
        }

        /// <summary>
        /// Called once per session to load/provision the user in DB.
        /// In Dev mode uses DevUser from session/config; in UAT/Prod uses Windows identity.
        /// Creates a Requestor record if not already present.
        /// </summary>
        public static void EnsureWindowsUser()
        {
            if (HttpContext.Current == null || HttpContext.Current.Session == null) return;
            if ((HttpContext.Current.Session["_winUserLoaded"] as string) == "1") return;

            string shortUser = CurrentUserShort;
            var row = DAL.Db.QueryRow(
                "SELECT u.FullName, r.RoleName, u.IsEnabled FROM dbo.AppUsers u " +
                "INNER JOIN dbo.UserRoles r ON r.RoleID = u.RoleID WHERE u.Username=@u",
                DAL.Db.P("@u", shortUser));

            if (row == null)
            {
                // Auto-provision: add user with Requestor role
                int roleId = Convert.ToInt32(DAL.Db.Scalar(
                    "SELECT TOP 1 RoleID FROM dbo.UserRoles WHERE RoleName='Requestor'"));
                if (roleId == 0)
                {
                    DAL.Db.Exec("IF NOT EXISTS(SELECT 1 FROM dbo.UserRoles WHERE RoleName='Requestor') " +
                                "INSERT INTO dbo.UserRoles(RoleName,Description) VALUES('Requestor','Default role')");
                    roleId = Convert.ToInt32(DAL.Db.Scalar(
                        "SELECT TOP 1 RoleID FROM dbo.UserRoles WHERE RoleName='Requestor'"));
                }
                DAL.Db.Exec(
                    "IF NOT EXISTS(SELECT 1 FROM dbo.AppUsers WHERE Username=@u) " +
                    "INSERT INTO dbo.AppUsers(Username,FullName,Email,Department,RoleID,IsEnabled,CreatedBy) " +
                    "VALUES(@u,@n,'','',@r,1,'system')",
                    DAL.Db.P("@u", shortUser),
                    DAL.Db.P("@n", shortUser),
                    DAL.Db.P("@r", roleId));
                DAL.Db.Exec(
                    "IF NOT EXISTS(SELECT 1 FROM dbo.UserRoleAssignments WHERE Username=@u AND RoleType='Requestor') " +
                    "INSERT INTO dbo.UserRoleAssignments(Username,RoleType,CreatedBy) VALUES(@u,'Requestor','system')",
                    DAL.Db.P("@u", shortUser));

                HttpContext.Current.Session["FullName"] = shortUser;
                HttpContext.Current.Session["Role"] = "Requestor";
            }
            else
            {
                HttpContext.Current.Session["FullName"] = row["FullName"].ToString();
                HttpContext.Current.Session["Role"] = row["RoleName"].ToString();
                DAL.Db.Exec("UPDATE dbo.AppUsers SET LastLoginDate=GETDATE() WHERE Username=@u",
                    DAL.Db.P("@u", shortUser));
            }

            HttpContext.Current.Session["_winUserLoaded"] = "1";
        }

        // -- Dev mode user/role switching ------------------------------------

        /// <summary>Switch the active dev user. Clears cached session state so next request re-provisions.</summary>
        public static void SwitchDevUser(string username)
        {
            if (!IsDev || HttpContext.Current == null || HttpContext.Current.Session == null) return;
            HttpContext.Current.Session["DevUser"] = username;
            HttpContext.Current.Session["_winUserLoaded"] = null;
            HttpContext.Current.Session["FullName"] = null;
            HttpContext.Current.Session["Role"] = null;
            ClearRoleCache();
            EnsureWindowsUser();
        }

        /// <summary>Override the active dev role. Pass empty string to use DB role.</summary>
        public static void SwitchDevRole(string role)
        {
            if (!IsDev || HttpContext.Current == null || HttpContext.Current.Session == null) return;
            HttpContext.Current.Session["DevRoleOverride"] = string.IsNullOrEmpty(role) ? null : (object)role;
            ClearRoleCache();
        }

        private static void ClearRoleCache()
        {
            if (HttpContext.Current == null || HttpContext.Current.Session == null) return;
            foreach (string roleType in new[] { "Requestor", "Reviewer", "Approver", "Admin" })
                HttpContext.Current.Session["RoleAssign_" + roleType] = null;
        }

        // -- Sign-out / access -----------------------------------------------

        public static void SignOut()
        {
            if (HttpContext.Current != null && HttpContext.Current.Session != null)
                HttpContext.Current.Session.Abandon();
        }

        public static bool CanAccessPage(string pageName)
        {
            if (IsAdmin) return true;
            int roleId = Convert.ToInt32(DAL.Db.Scalar(
                "SELECT RoleID FROM dbo.AppUsers WHERE Username=@u",
                DAL.Db.P("@u", CurrentUserShort)));
            int cnt = Convert.ToInt32(DAL.Db.Scalar(@"
                SELECT COUNT(*) FROM dbo.PageAccess a
                INNER JOIN dbo.PageRegistry p ON p.PageID = a.PageID
                WHERE a.RoleID=@r AND p.PageName=@n AND a.CanView=1",
                DAL.Db.P("@r", roleId), DAL.Db.P("@n", pageName)));
            return cnt > 0;
        }
    }
}