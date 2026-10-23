using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;

namespace DFM.Web.Infrastructure
{
    public static class VendorMaintenance
    {
        public static void EnsureVendors(params string[] vendorValues)
        {
            var vendors = VendorNames(vendorValues).ToList();
            if (vendors.Count == 0) return;
            if (!VendorTableAvailable()) return;

            foreach (var vendor in vendors)
            {
                Db.Execute(@"IF NOT EXISTS(SELECT 1 FROM dbo.Vendors WHERE UPPER(LTRIM(RTRIM(Name)))=UPPER(@Name))
                    INSERT dbo.Vendors(Name,IsActive) VALUES(@Name,1)", P("@Name", vendor));
            }
        }

        public static void EnsureVendors<T>(IEnumerable<T> items, Func<T, string> vendorSelector)
        {
            if (items == null || vendorSelector == null) return;
            EnsureVendors(items.Select(vendorSelector).ToArray());
        }

        private static IEnumerable<string> VendorNames(IEnumerable<string> vendorValues)
        {
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var value in vendorValues ?? Enumerable.Empty<string>())
            {
                foreach (var part in (value ?? "").Split(','))
                {
                    var vendor = part.Trim();
                    if (vendor.Length == 0 || !seen.Add(vendor)) continue;
                    yield return vendor;
                }
            }
        }

        private static bool VendorTableAvailable()
        {
            var row = Db.Query("SELECT CASE WHEN OBJECT_ID('dbo.Vendors','U') IS NULL THEN 0 ELSE 1 END HasTable").FirstOrDefault();
            return row != null && Convert.ToInt32(row["HasTable"]) == 1;
        }

        private static SqlParameter P(string name, object value) { return new SqlParameter(name, Db.Value(value)); }
    }
}