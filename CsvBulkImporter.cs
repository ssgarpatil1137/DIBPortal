using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Globalization;
using System.Linq;
using System.Text;
using DFM.Web.Models;

namespace DFM.Web.Infrastructure
{
    public static class CsvBulkImporter
    {
        public static int Import(string kind, int parentId, string csv, string user)
        {
            return ImportRows(kind, parentId, Parse(csv), user, "CSV");
        }

        public static int ImportRows(string kind, int parentId, List<List<string>> rows, string user, string sourceName)
        {
            if (rows.Count < 2) throw new ArgumentException("The " + sourceName + " has no data rows.");
            rows = TableFromHeader(rows, RequiredColumns(kind), sourceName);
            var headers = HeaderMap(rows[0]);
            if (kind.Equals("pet", StringComparison.OrdinalIgnoreCase)) return ImportPets(parentId, rows, headers, user);
            if (kind.Equals("budget", StringComparison.OrdinalIgnoreCase)) return ImportBudgetLines(parentId, rows, headers, user);
            if (kind.Equals("invoice", StringComparison.OrdinalIgnoreCase)) return ImportInvoices(parentId, rows, headers, user);
            throw new ArgumentException("Unknown import kind.");
        }

        private static int ImportPets(int projectId, List<List<string>> rows, Dictionary<string, int> headers, string user)
        {
            return ImportPetRows(projectId, PetRows(rows.Skip(1), headers, true), user);
        }

        public static List<PetUploadRowRequest> PreviewPetRows(List<List<string>> rows, string sourceName)
        {
            rows = TableFromHeader(rows, RequiredColumns("pet"), sourceName);
            return PetRows(rows.Skip(1), HeaderMap(rows[0]), false);
        }

        public static int ImportPetRows(int projectId, IEnumerable<PetUploadRowRequest> rows, string user)
        {
            var uploadRows = (rows ?? Enumerable.Empty<PetUploadRowRequest>()).Where(row => row != null).Select(row => CalculatePetRow(row, true)).ToList();
            if (uploadRows.Count == 0) throw new ArgumentException("Add at least one PET row before saving.");
            var imported = 0;
            foreach (var group in uploadRows.GroupBy(row => row.PetReference, StringComparer.OrdinalIgnoreCase))
            {
                var existing = Db.Query("SELECT PetId FROM dbo.PETRequests WHERE ProjectId=@project AND Code=@code AND Status IN ('Draft','Pending Review','Pending Approval','Sent Back')", P("@project", projectId), P("@code", group.Key));
                var uploadedTotal = group.Sum(row => row.FinalAed); var petId = 0; var firstRow = group.First();
                if (existing.Count > 0)
                {
                    petId = Convert.ToInt32(existing[0]["PetId"]);
                    var existingSpend = Db.Query("SELECT ISNULL(SUM(FinalAedAmount),0) Amount FROM dbo.SpendItems WHERE PetId=@pet", P("@pet", petId)).FirstOrDefault();
                    uploadedTotal += existingSpend == null ? 0 : Convert.ToDecimal(existingSpend["Amount"], CultureInfo.InvariantCulture);
                }
                AmountValidation.ValidatePetRequestAmount(projectId, petId == 0 ? (int?)null : petId, uploadedTotal);
                var result = Db.Query("EXEC dbo.sp_SavePet @PetId,@project,@code,@amount,@currency,@user", P("@PetId", petId == 0 ? (object)null : petId), P("@project", projectId), P("@code", group.Key), P("@amount", uploadedTotal), P("@currency", firstRow.Currency), P("@user", user));
                if (petId == 0) petId = Convert.ToInt32(result[0]["PetId"]);
                foreach (var item in group)
                {
                    var divisor = 1 + (item.ContingencyPercent / 100);
                    var persistedAmount = divisor == 0 ? item.FinalAed : item.FinalAed / divisor;
                    try
                    {
                        Db.Query("EXEC dbo.sp_SaveSpendItem NULL,@pet,@head,@topic,@vendor,@costType,@unitType,@units,@unitPrice,@currency,@foreign,@aed,@contingency,@gl,@department,@description,@yearlyRecurrence", P("@pet", petId), P("@head", item.Head), P("@topic", item.Topic), P("@vendor", item.Vendor), P("@costType", item.CostType), P("@unitType", item.UnitType), P("@units", item.Units), P("@unitPrice", item.UnitPrice), P("@currency", item.Currency), P("@foreign", persistedAmount), P("@aed", persistedAmount), P("@contingency", item.ContingencyPercent), P("@gl", item.GlNumber), P("@department", item.Department), P("@description", item.Description), P("@yearlyRecurrence", item.YearlyRecurrence)); imported++;
                    }
                    catch (SqlException ex)
                    {
                        if (!ProcedureParameterError(ex)) throw;
                        Db.Query("EXEC dbo.sp_SaveSpendItem NULL,@pet,@head,@topic,@vendor,@costType,@unitType,@units,@unitPrice,@currency,@foreign,@aed,@contingency,@gl", P("@pet", petId), P("@head", item.Head), P("@topic", item.Topic), P("@vendor", item.Vendor), P("@costType", item.CostType), P("@unitType", item.UnitType), P("@units", item.Units), P("@unitPrice", item.UnitPrice), P("@currency", item.Currency), P("@foreign", persistedAmount), P("@aed", persistedAmount), P("@contingency", item.ContingencyPercent), P("@gl", item.GlNumber)); imported++;
                    }
                }
            }
            return imported;
        }

        private static List<PetUploadRowRequest> PetRows(IEnumerable<List<string>> rows, Dictionary<string, int> headers, bool strict)
        {
            Require(headers, "vendor", "unitprice");
            return rows.Where(row => !Empty(row)).Select(row => CalculatePetRow(new PetUploadRowRequest { ProjectId = GetAny(row, headers, "", "projectid"), PetReference = GetAny(row, headers, "", "petreference", "id"), Department = Get(row, headers, "department"), Currency = GetAny(row, headers, "AED", "currency", "basecy"), Head = GetAny(row, headers, "", "head", "exphead"), Topic = Get(row, headers, "topic"), Vendor = Get(row, headers, "vendor"), Description = Get(row, headers, "description"), CostType = Get(row, headers, "costtype"), UnitType = Get(row, headers, "unittype"), Units = Decimal(row, headers, "units", 1), UnitPrice = Decimal(row, headers, "unitprice"), ForeignAmount = DecimalAny(row, headers, 0, "fcyamount", "amtfcy"), ExchangeRate = DecimalAny(row, headers, 0, "exchangerate", "conversionrate", "fxrate", "aedrate"), AedAmount = DecimalAny(row, headers, 0, "aedamount", "amtlcy"), ContingencyPercent = DecimalAny(row, headers, 0, "contingency", "cont"), FinalAed = DecimalAny(row, headers, 0, "finalaed", "finalamtlcy"), YearlyRecurrence = IntNullable(row, headers, "yearlyrecurrence"), GlNumber = Get(row, headers, "glnumber") }, strict)).ToList();
        }

        private static PetUploadRowRequest CalculatePetRow(PetUploadRowRequest row, bool strict)
        {
            if (strict && string.IsNullOrWhiteSpace(row.PetReference)) throw new ArgumentException("PET reference is required for every PET row.");
            if (strict && string.IsNullOrWhiteSpace(row.Vendor)) throw new ArgumentException("Vendor is required for every PET row.");
            if (strict && row.UnitPrice <= 0) throw new ArgumentException("Unit Price is required for every PET row.");
            row.Currency = string.IsNullOrWhiteSpace(row.Currency) ? "AED" : row.Currency.Trim().ToUpperInvariant();
            row.Units = row.Units == 0 ? 1 : row.Units;
            if (string.Equals(row.Currency, "AED", StringComparison.OrdinalIgnoreCase))
            {
                row.ExchangeRate = 1;
                row.AedAmount = row.UnitPrice;
                row.ForeignAmount = row.UnitPrice;
            }
            else
            {
                row.ForeignAmount = row.UnitPrice;
                if (row.AedAmount == 0) row.AedAmount = row.ForeignAmount;
            }
            row.FinalAed = row.Units * (string.Equals(row.Currency, "AED", StringComparison.OrdinalIgnoreCase) ? row.AedAmount : row.ForeignAmount);
            return row;
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

        public static List<List<string>> Parse(string text)
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
        private static string[] RequiredColumns(string kind) { return kind.Equals("pet", StringComparison.OrdinalIgnoreCase) ? new[] { "vendor", "unitprice" } : kind.Equals("budget", StringComparison.OrdinalIgnoreCase) ? new[] { "vendor", "cost", "currency" } : kind.Equals("invoice", StringComparison.OrdinalIgnoreCase) ? new[] { "vendorname", "invoicenumber", "invoiceamount" } : new string[0]; }
        private static List<List<string>> TableFromHeader(List<List<string>> rows, string[] required, string sourceName)
        {
            for (var index = 0; index < rows.Count; index++)
            {
                var headers = HeaderMap(rows[index]);
                if (required.All(headers.ContainsKey)) return rows.Skip(index).ToList();
            }
            throw new ArgumentException("Missing upload columns in " + sourceName + ": " + string.Join(", ", required));
        }
        private static Dictionary<string, int> HeaderMap(List<string> row) { var headers = new Dictionary<string, int>(); row.Select((name, index) => new { name = Normalize(name), index }).Where(item => !string.IsNullOrWhiteSpace(item.name)).ToList().ForEach(item => { if (!headers.ContainsKey(item.name)) headers.Add(item.name, item.index); }); return headers; }
        private static string Get(List<string> row, Dictionary<string, int> headers, string name, string fallback = "") { int index; return headers.TryGetValue(name, out index) && index < row.Count && !string.IsNullOrWhiteSpace(row[index]) ? row[index].Trim() : fallback; }
        private static string GetAny(List<string> row, Dictionary<string, int> headers, string fallback, params string[] names) { foreach (var name in names) { var value = Get(row, headers, name); if (!string.IsNullOrWhiteSpace(value)) return value; } return fallback; }
        private static decimal Decimal(List<string> row, Dictionary<string, int> headers, string name, decimal fallback = 0) { decimal value; return decimal.TryParse(Get(row, headers, name).Replace(",", ""), NumberStyles.Number, CultureInfo.InvariantCulture, out value) ? value : fallback; }
        private static decimal DecimalAny(List<string> row, Dictionary<string, int> headers, decimal fallback, params string[] names) { foreach (var name in names) { var value = Decimal(row, headers, name, decimal.MinValue); if (value != decimal.MinValue) return value; } return fallback; }
        private static bool Has(List<string> row, Dictionary<string, int> headers, string name) { int index; return headers.TryGetValue(name, out index) && index < row.Count && !string.IsNullOrWhiteSpace(row[index]); }
        private static bool HasAny(List<string> row, Dictionary<string, int> headers, params string[] names) { return names.Any(name => Has(row, headers, name)); }
        private static int Int(List<string> row, Dictionary<string, int> headers, string name, int fallback) { int value; return int.TryParse(Get(row, headers, name), out value) ? value : fallback; }
        private static int? IntNullable(List<string> row, Dictionary<string, int> headers, string name) { int value; return int.TryParse(Get(row, headers, name), out value) ? (int?)value : null; }
        private static bool Empty(List<string> row) { return row.All(string.IsNullOrWhiteSpace); }
        private static void Require(Dictionary<string, int> headers, params string[] names) { var missing = names.Where(name => !headers.ContainsKey(name)).ToArray(); if (missing.Length > 0) throw new ArgumentException("Missing upload columns: " + string.Join(", ", missing)); }
        private static bool ProcedureParameterError(SqlException ex) { return ex.Errors.Cast<SqlError>().Any(error => error.Number == 8144 || error.Number == 201 || error.Number == 207); }
        private static SqlParameter P(string name, object value) { return new SqlParameter(name, Db.Value(value)); }

    }
}
