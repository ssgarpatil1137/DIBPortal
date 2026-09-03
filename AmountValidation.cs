using System;
using System.Data.SqlClient;
using System.Linq;

namespace DFM.Web.Infrastructure
{
    public static class AmountValidation
    {
        public static void ValidatePetRequestAmount(int projectId, int? petId, decimal requestedAmount)
        {
            if (requestedAmount <= 0) throw new ArgumentException("A positive PET amount is required.");

            var project = Db.Query(@"SELECT b.Budget FROM dbo.Projects p LEFT JOIN dbo.BudgetSources b ON b.BudgetSourceId=p.BudgetSourceId WHERE p.ProjectId=@ProjectId", P("@ProjectId", projectId)).FirstOrDefault();
            if (project == null) throw new ArgumentException("Project was not found.");

            var projectBudget = ToDecimal(project["Budget"]);
            if (projectBudget > 0 && requestedAmount > projectBudget)
                throw new ArgumentException("PET Request amount exceeds the Project Budget. Project Budget: " + Money(projectBudget) + "; entered amount: " + Money(requestedAmount) + ".");

            if (!petId.HasValue) return;
            var budgetLineTotal = ScalarDecimal("SELECT ISNULL(SUM(Cost),0) Amount FROM dbo.BudgetLines WHERE PetId=@PetId", P("@PetId", petId.Value));
            if (budgetLineTotal > requestedAmount)
                throw new ArgumentException("PET Request amount is below the existing Budget Line total for this PET Reference. Existing Budget Lines total: " + Money(budgetLineTotal) + "; entered PET amount: " + Money(requestedAmount) + ".");
        }

        public static void ValidateSpendItemAmount(int petId, int? spendItemId, decimal finalItemAmount)
        {
            var pet = Db.Query(@"SELECT pet.ProjectId FROM dbo.PETRequests pet WHERE pet.PetId=@PetId", P("@PetId", petId)).FirstOrDefault();
            if (pet == null) throw new ArgumentException("PET request was not found.");

            var existingSpendTotal = ScalarDecimal("SELECT ISNULL(SUM(FinalAedAmount),0) Amount FROM dbo.SpendItems WHERE PetId=@PetId AND (@SpendItemId IS NULL OR SpendItemId<>@SpendItemId)", P("@PetId", petId), P("@SpendItemId", spendItemId));
            ValidatePetRequestAmount(Convert.ToInt32(pet["ProjectId"]), petId, existingSpendTotal + finalItemAmount);
        }

        public static void ValidateBudgetLineAmount(int petId, int? budgetLineId, decimal cost)
        {
            if (cost <= 0) throw new ArgumentException("A positive Budget Line amount is required.");

            var pet = Db.Query("SELECT Code,RequestedAmount FROM dbo.PETRequests WHERE PetId=@PetId", P("@PetId", petId)).FirstOrDefault();
            if (pet == null) throw new ArgumentException("PET request was not found.");

            var requestedAmount = ToDecimal(pet["RequestedAmount"]);
            var existingBudgetLines = ScalarDecimal("SELECT ISNULL(SUM(Cost),0) Amount FROM dbo.BudgetLines WHERE PetId=@PetId AND (@BudgetLineId IS NULL OR BudgetLineId<>@BudgetLineId)", P("@PetId", petId), P("@BudgetLineId", budgetLineId));
            var available = requestedAmount - existingBudgetLines;
            if (cost > available)
                throw new ArgumentException("Budget Line amount exceeds the available balance for PET Reference " + Convert.ToString(pet["Code"]) + ". Available balance: " + Money(Math.Max(available, 0)) + "; entered amount: " + Money(cost) + ".");
        }

        private static decimal ScalarDecimal(string sql, params SqlParameter[] parameters)
        {
            var row = Db.Query(sql, parameters).FirstOrDefault();
            return row == null ? 0 : ToDecimal(row["Amount"]);
        }

        private static decimal ToDecimal(object value)
        {
            return value == null || value == DBNull.Value ? 0 : Convert.ToDecimal(value);
        }

        private static string Money(decimal amount)
        {
            return "AED " + amount.ToString("N2");
        }

        private static SqlParameter P(string name, object value) { return new SqlParameter(name, Db.Value(value)); }
    }
}