using System;
using System.Data.SqlClient;
using System.Linq;

namespace DFM.Web.Infrastructure
{
    // OPEX Contracts are regular dbo.Projects rows identified by ProjectType = 'OPEX Contract'.
    // Their PETs bypass review/approval and are finalized immediately against the project's OPEX source.
    public static class OpexContract
    {
        public const string ProjectTypeName = "OPEX Contract";
        private const string AutoApprovalComment = "Auto-approved: OPEX Contract does not require review or approval.";

        public static bool IsProjectType(string projectType)
        {
            return string.Equals((projectType ?? "").Trim(), ProjectTypeName, StringComparison.OrdinalIgnoreCase);
        }

        public static bool IsProject(int projectId)
        {
            var row = Db.Query("SELECT ProjectType FROM dbo.Projects WHERE ProjectId=@ProjectId", P("@ProjectId", projectId)).FirstOrDefault();
            return row != null && IsProjectType(Convert.ToString(row["ProjectType"]));
        }

        public static bool IsPet(int petId)
        {
            var row = Db.Query("SELECT p.ProjectType FROM dbo.PETRequests pet JOIN dbo.Projects p ON p.ProjectId=pet.ProjectId WHERE pet.PetId=@PetId", P("@PetId", petId)).FirstOrDefault();
            return row != null && IsProjectType(Convert.ToString(row["ProjectType"]));
        }

        public static void FinalizePet(int petId, bool isNewPet, string user)
        {
            try { ApprovePet(petId, user); }
            catch
            {
                if (isNewPet) DiscardPet(petId);
                throw;
            }
        }

        private static void ApprovePet(int petId, string user)
        {
            Db.Execute(@"SET XACT_ABORT ON; BEGIN TRAN;
DECLARE @Old nvarchar(50),@Amount decimal(19,2),@ProjectId int,@BudgetSource int,@Budget decimal(19,2),@Used decimal(19,2),@NonProjectUsed decimal(19,2)=0;
SELECT @Old=pet.Status,@Amount=pet.RequestedAmount,@ProjectId=pet.ProjectId,@BudgetSource=p.BudgetSourceId
FROM dbo.PETRequests pet WITH(UPDLOCK) JOIN dbo.Projects p ON p.ProjectId=pet.ProjectId
WHERE pet.PetId=@PetId AND LTRIM(RTRIM(ISNULL(p.ProjectType,'')))=@OpexType;
IF @ProjectId IS NULL THROW 50060,'PET is not linked to an OPEX Contract.',1;
IF @Old IN('Draft','Pending Review','Pending Approval','Sent Back')
BEGIN
 IF @BudgetSource IS NULL OR NOT EXISTS(SELECT 1 FROM dbo.BudgetSources WHERE BudgetSourceId=@BudgetSource AND BudgetType='OPEX')
  THROW 50061,'Select an OPEX budget source for this OPEX Contract before adding PET.',1;
 SELECT @Budget=Budget FROM dbo.BudgetSources WITH(UPDLOCK) WHERE BudgetSourceId=@BudgetSource;
 SELECT @Used=ISNULL(SUM(x.RequestedAmount),0) FROM dbo.PETRequests x JOIN dbo.Projects xp ON xp.ProjectId=x.ProjectId WHERE xp.BudgetSourceId=@BudgetSource AND x.Status='Approved';
 IF OBJECT_ID('dbo.vw_NonProjectOpexUtilization','V') IS NOT NULL
  SELECT @NonProjectUsed=ISNULL(SUM(AmountApprovedAed),0) FROM dbo.vw_NonProjectOpexUtilization WHERE BudgetSourceId=@BudgetSource;
 IF ISNULL(@Budget,0)-ISNULL(@Used,0)-ISNULL(@NonProjectUsed,0) < @Amount THROW 50004,'Insufficient remaining OPEX budget for this OPEX Contract PET.',1;
 UPDATE dbo.BudgetSources SET Utilization=Utilization+@Amount,AvailableBudget=AvailableBudget-@Amount,NetBalance=NetBalance-@Amount,UpdatedUtc=SYSUTCDATETIME() WHERE BudgetSourceId=@BudgetSource;
 UPDATE dbo.PETRequests SET Status='Approved',ReviewRequired=0,ApprovalComments=@Comment,ApprovedUtc=SYSUTCDATETIME(),UpdatedUtc=SYSUTCDATETIME() WHERE PetId=@PetId;
 UPDATE dbo.WorkflowHistory SET ToStatus='Approved',Comments=@Comment
  WHERE WorkflowHistoryId=(SELECT MAX(WorkflowHistoryId) FROM dbo.WorkflowHistory WHERE PetId=@PetId) AND ToStatus IN('Pending Review','Pending Approval');
 IF @@ROWCOUNT=0 INSERT dbo.WorkflowHistory(PetId,FromStatus,ToStatus,ActionBy,Comments) VALUES(@PetId,@Old,'Approved',@User,@Comment);
 UPDATE dbo.Projects SET Status='Approved',UpdatedUtc=SYSUTCDATETIME() WHERE ProjectId=@ProjectId;
END;
COMMIT;",
                P("@PetId", petId), P("@OpexType", ProjectTypeName), P("@Comment", AutoApprovalComment), P("@User", user));
        }

        private static void DiscardPet(int petId)
        {
            try
            {
                Db.Execute(@"SET XACT_ABORT ON; BEGIN TRAN;
DECLARE @ProjectId int=(SELECT ProjectId FROM dbo.PETRequests WHERE PetId=@PetId AND Status<>'Approved');
IF @ProjectId IS NOT NULL
BEGIN
 DELETE FROM dbo.Attachments WHERE EntityType='PET' AND EntityId=@PetId;
 DELETE FROM dbo.SpendItems WHERE PetId=@PetId;
 DELETE FROM dbo.WorkflowHistory WHERE PetId=@PetId;
 DELETE FROM dbo.PETRequests WHERE PetId=@PetId;
 UPDATE dbo.Projects SET Status=CASE WHEN EXISTS(SELECT 1 FROM dbo.PETRequests WHERE ProjectId=@ProjectId AND Status='Approved') THEN 'Approved' ELSE 'Active' END,UpdatedUtc=SYSUTCDATETIME() WHERE ProjectId=@ProjectId;
END;
COMMIT;", P("@PetId", petId));
            }
            catch (SqlException) { }
        }

        private static SqlParameter P(string name, object value) { return new SqlParameter(name, Db.Value(value)); }
    }
}
