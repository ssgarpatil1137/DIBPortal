using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Globalization;
using System.Linq;
using System.Text;

namespace DFM.Web.Infrastructure
{
    public static class CsvBulkImporter
    {
        public static int Import(string kind, int parentId, string csv, string user)
        {
            var rows = Parse(csv);
            if (rows.Count < 2) throw new ArgumentException("The CSV has no data rows.");
            var headers = rows[0].Select((name, index) => new { name = Normalize(name), index }).ToDictionary(item => item.name, item => item.index);
            if (kind.Equals("pet", StringComparison.OrdinalIgnoreCase)) return ImportPets(parentId, rows, headers, user);
            if (kind.Equals("budget", StringComparison.OrdinalIgnoreCase)) return ImportBudgetLines(parentId, rows, headers, user);
            if (kind.Equals("invoice", StringComparison.OrdinalIgnoreCase)) return ImportInvoices(parentId, rows, headers, user);
            throw new ArgumentException("Unknown CSV import kind.");
        }

        private static int ImportPets(int projectId, List<List<string>> rows, Dictionary<string, int> headers, string user)
        {
            Require(headers, "petreference", "vendor", "unitprice");
            var pets = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase); var imported = 0;
            for (var index = 1; index < rows.Count; index++)
            {
                var row = rows[index]; if (Empty(row)) continue; var reference = Get(row, headers, "petreference"); int petId;
                var units = Decimal(row, headers, "units", 1); var unitPrice = Decimal(row, headers, "unitprice"); var foreign = Decimal(row, headers, "fcyamount", units * unitPrice); var aed = Decimal(row, headers, "aedamount", foreign); var contingency = Decimal(row, headers, "contingency");
                var finalAmount = aed * (1 + contingency / 100);
                var amountValidated = false;
                if (string.IsNullOrWhiteSpace(reference)) throw new ArgumentException("PET reference is required for every PET import row.");
                if (!pets.TryGetValue(reference, out petId))
                {
                    var existing = Db.Query("SELECT PetId FROM dbo.PETRequests WHERE ProjectId=@project AND Code=@code AND Status IN ('Draft','Pending Review','Pending Approval')", P("@project", projectId), P("@code", reference));
                    if (existing.Count > 0)
                    {
                        petId = Convert.ToInt32(existing[0]["PetId"]);
                        AmountValidation.ValidateSpendItemAmount(petId, null, finalAmount);
                    }
                    else
                    {
                        AmountValidation.ValidatePetRequestAmount(projectId, null, finalAmount);
                        var result = Db.Query("EXEC dbo.sp_SavePet NULL,@project,@code,@amount,@currency,@user", P("@project", projectId), P("@code", reference), P("@amount", finalAmount), P("@currency", Get(row, headers, "currency", "AED")), P("@user", user));
                        petId = Convert.ToInt32(result[0]["PetId"]);
                    }
                    amountValidated = true;
                    pets[reference] = petId;
                }
                if (!amountValidated) AmountValidation.ValidateSpendItemAmount(petId, null, finalAmount);
                Db.Query("EXEC dbo.sp_SaveSpendItem NULL,@pet,@head,@topic,@vendor,@costType,@unitType,@units,@unitPrice,@currency,@foreign,@aed,@contingency,@gl", P("@pet", petId), P("@head", Get(row, headers, "head")), P("@topic", Get(row, headers, "topic")), P("@vendor", Get(row, headers, "vendor")), P("@costType", Get(row, headers, "costtype")), P("@unitType", Get(row, headers, "unittype")), P("@units", units), P("@unitPrice", unitPrice), P("@currency", Get(row, headers, "currency", "AED")), P("@foreign", foreign), P("@aed", aed), P("@contingency", contingency), P("@gl", Get(row, headers, "glnumber"))); imported++;
            }
            return imported;
        }

        private static int ImportBudgetLines(int petId, List<List<string>> rows, Dictionary<string, int> headers, string user)
        {
            Require(headers, "vendor", "cost", "currency"); var imported = 0;
            for (var index = 1; index < rows.Count; index++)
            {
                var row = rows[index]; if (Empty(row)) continue;
                var cost = Decimal(row, headers, "cost");
                AmountValidation.ValidateBudgetLineAmount(petId, null, cost);
                Db.Query("EXEC dbo.sp_SaveBudgetLine NULL,@pet,@vendor,@justification,@cost,@currency,@gl,@petRef,@camId,@camStatus,@camComments,@lpoRequest,@lpoStatus,@lpoComments,@user", P("@pet", petId), P("@vendor", Get(row, headers, "vendor")), P("@justification", Get(row, headers, "justification")), P("@cost", cost), P("@currency", Get(row, headers, "currency", "AED")), P("@gl", Get(row, headers, "gl")), P("@petRef", Get(row, headers, "petreference")), P("@camId", Get(row, headers, "camid")), P("@camStatus", Get(row, headers, "camstatus")), P("@camComments", Get(row, headers, "camcomments")), P("@lpoRequest", Get(row, headers, "lporequest")), P("@lpoStatus", Get(row, headers, "lpostatus")), P("@lpoComments", Get(row, headers, "lpocomments")), P("@user", user)); imported++;
            }
            return imported;
        }

        private static int ImportInvoices(int defaultBudgetLineId, List<List<string>> rows, Dictionary<string, int> headers, string user)
        {
            Require(headers, "vendorname", "invoicenumber", "invoiceamount"); var imported = 0;
            for (var index = 1; index < rows.Count; index++)
            {
                var row = rows[index]; if (Empty(row)) continue; var lineId = Int(row, headers, "budgetlineid", defaultBudgetLineId); DateTime paymentDate; object date = DateTime.TryParse(Get(row, headers, "paymentdate"), CultureInfo.InvariantCulture, DateTimeStyles.None, out paymentDate) ? (object)paymentDate : null;
                Db.Query("EXEC dbo.sp_SaveInvoice NULL,@line,@vendor,@justification,@gl,@number,@amount,@status,@paymentDate,@user", P("@line", lineId), P("@vendor", Get(row, headers, "vendorname")), P("@justification", Get(row, headers, "justification")), P("@gl", Get(row, headers, "glnumber")), P("@number", Get(row, headers, "invoicenumber")), P("@amount", Decimal(row, headers, "invoiceamount")), P("@status", Get(row, headers, "invoicestatus", "Raised")), P("@paymentDate", date), P("@user", user)); imported++;
            }
            return imported;
        }

        private static List<List<string>> Parse(string text)
        {
            var result = new List<List<string>>(); var row = new List<string>(); var field = new StringBuilder(); var quoted = false; text = text ?? "";
            for (var index = 0; index < text.Length; index++)
            {
                var character = text[index];
                if (character == '"') { if (quoted && index + 1 < text.Length && text[index + 1] == '"') { field.Append('"'); index++; } else quoted = !quoted; }
                else if (character == ',' && !quoted) { row.Add(field.ToString()); field.Length = 0; }
                else if ((character == '\r' || character == '\n') && !quoted) { if (character == '\r' && index + 1 < text.Length && text[index + 1] == '\n') index++; row.Add(field.ToString()); field.Length = 0; result.Add(row); row = new List<string>(); }
                else field.Append(character);
            }
            if (field.Length > 0 || row.Count > 0) { row.Add(field.ToString()); result.Add(row); } return result;
        }

        private static string Normalize(string value) { return new string((value ?? "").Where(char.IsLetterOrDigit).Select(char.ToLowerInvariant).ToArray()); }
        private static string Get(List<string> row, Dictionary<string, int> headers, string name, string fallback = "") { int index; return headers.TryGetValue(name, out index) && index < row.Count && !string.IsNullOrWhiteSpace(row[index]) ? row[index].Trim() : fallback; }
        private static decimal Decimal(List<string> row, Dictionary<string, int> headers, string name, decimal fallback = 0) { decimal value; return decimal.TryParse(Get(row, headers, name).Replace(",", ""), NumberStyles.Number, CultureInfo.InvariantCulture, out value) ? value : fallback; }
        private static int Int(List<string> row, Dictionary<string, int> headers, string name, int fallback) { int value; return int.TryParse(Get(row, headers, name), out value) ? value : fallback; }
        private static bool Empty(List<string> row) { return row.All(string.IsNullOrWhiteSpace); }
        private static void Require(Dictionary<string, int> headers, params string[] names) { var missing = names.Where(name => !headers.ContainsKey(name)).ToArray(); if (missing.Length > 0) throw new ArgumentException("Missing CSV columns: " + string.Join(", ", missing)); }
        private static SqlParameter P(string name, object value) { return new SqlParameter(name, Db.Value(value)); }
    }
}
