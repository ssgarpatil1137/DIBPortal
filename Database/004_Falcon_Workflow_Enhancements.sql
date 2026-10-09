USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
IF COL_LENGTH('dbo.Projects','RequiresPet') IS NULL
 ALTER TABLE dbo.Projects ADD RequiresPet bit NOT NULL CONSTRAINT DF_Projects_RequiresPet DEFAULT 1, SkipReview bit NOT NULL CONSTRAINT DF_Projects_SkipReview DEFAULT 0;
GO
ALTER TABLE dbo.Projects ALTER COLUMN BudgetType nvarchar(10) NULL;
ALTER TABLE dbo.Projects ALTER COLUMN BudgetSourceId int NULL;
GO
CREATE OR ALTER PROCEDURE dbo.sp_SaveProject
 @ProjectId int=NULL,@IsJira bit,@JiraKey nvarchar(50)=NULL,@Name nvarchar(500),@Type nvarchar(100)=NULL,
 @Lead nvarchar(200),@Executive nvarchar(200),@Sme nvarchar(200)=NULL,@Size nvarchar(50)=NULL,@Manager nvarchar(200)=NULL,
 @BudgetType nvarchar(10)=NULL,@BudgetSource int=NULL,@RequiresPet bit=1,@SkipReview bit=0,@User nvarchar(254)
AS
BEGIN
 SET NOCOUNT ON;
 IF @RequiresPet=1 AND NOT EXISTS(SELECT 1 FROM dbo.BudgetSources WHERE BudgetSourceId=@BudgetSource AND BudgetType=@BudgetType)
  THROW 50001,'Budget source does not match CAPEX/OPEX selection.',1;
 IF @RequiresPet=0 BEGIN SET @BudgetType=NULL; SET @BudgetSource=NULL; SET @SkipReview=0; END;
 IF @ProjectId IS NULL
 BEGIN
  INSERT dbo.Projects(IsJira,JiraKey,ProjectName,ProjectType,AccountableExecLead,AccountableExec,SmeLead,ProjectSize,ProjectManager,RequestorEmail,BudgetType,BudgetSourceId,RequiresPet,SkipReview,Status)
  VALUES(@IsJira,NULLIF(@JiraKey,''),@Name,@Type,@Lead,@Executive,@Sme,@Size,@Manager,@User,@BudgetType,@BudgetSource,@RequiresPet,@SkipReview,CASE WHEN @RequiresPet=0 THEN 'Registered' ELSE 'Active' END);
  SET @ProjectId=SCOPE_IDENTITY();
 END
 ELSE
  UPDATE dbo.Projects SET IsJira=@IsJira,JiraKey=NULLIF(@JiraKey,''),ProjectName=@Name,ProjectType=@Type,AccountableExecLead=@Lead,AccountableExec=@Executive,SmeLead=@Sme,ProjectSize=@Size,ProjectManager=@Manager,BudgetType=@BudgetType,BudgetSourceId=@BudgetSource,RequiresPet=@RequiresPet,SkipReview=@SkipReview,Status=CASE WHEN @RequiresPet=0 THEN 'Registered' ELSE Status END,UpdatedUtc=SYSUTCDATETIME()
  WHERE ProjectId=@ProjectId AND (RequestorEmail=@User OR EXISTS(SELECT 1 FROM dbo.Users u JOIN dbo.UserRoles ur ON ur.UserId=u.UserId JOIN dbo.Roles r ON r.RoleId=ur.RoleId WHERE u.Email=@User AND r.Name='Master'));
 SELECT ProjectId,ProjectCode FROM dbo.Projects WHERE ProjectId=@ProjectId;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_SavePet @PetId int=NULL,@ProjectId int,@Code nvarchar(50),@Amount decimal(19,2),@Currency char(3),@User nvarchar(254)
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @SkipReview bit,@RequiresPet bit,@InitialStatus nvarchar(50);
 SELECT @SkipReview=SkipReview,@RequiresPet=RequiresPet FROM dbo.Projects WHERE ProjectId=@ProjectId;
 IF ISNULL(@RequiresPet,0)=0 THROW 50008,'This project does not require PET registration.',1;
 SET @InitialStatus=CASE WHEN @SkipReview=1 THEN 'Pending Approval' ELSE 'Pending Review' END;
 IF @PetId IS NULL
 BEGIN
  INSERT dbo.PETRequests(ProjectId,Code,RequestedAmount,Currency,Status,CreatedBy) VALUES(@ProjectId,@Code,@Amount,@Currency,@InitialStatus,@User);
  SET @PetId=SCOPE_IDENTITY();
  INSERT dbo.WorkflowHistory(PetId,ToStatus,ActionBy,Comments) VALUES(@PetId,@InitialStatus,@User,CASE WHEN @SkipReview=1 THEN 'Reviewer skipped during project registration.' ELSE NULL END);
 END
 ELSE UPDATE dbo.PETRequests SET Code=@Code,RequestedAmount=@Amount,Currency=@Currency,UpdatedUtc=SYSUTCDATETIME() WHERE PetId=@PetId AND Status IN('Draft','Pending Review','Pending Approval');
 UPDATE dbo.Projects SET Status=CASE WHEN @SkipReview=1 THEN 'PET Approval' ELSE 'PET Review' END,UpdatedUtc=SYSUTCDATETIME() WHERE ProjectId=@ProjectId;
 SELECT PetId,Status FROM dbo.PETRequests WHERE PetId=@PetId;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_SaveSpendItem
 @Id int=NULL,@Pet int,@Head nvarchar(200)=NULL,@Topic nvarchar(300)=NULL,@Vendor nvarchar(300),@CostType nvarchar(100)=NULL,
 @UnitType nvarchar(50)=NULL,@Units decimal(19,4),@UnitPrice decimal(19,2),@Currency char(3),@Foreign decimal(19,2),
 @Aed decimal(19,2),@Contingency decimal(9,4),@Gl nvarchar(50)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 IF NOT EXISTS(SELECT 1 FROM dbo.PETRequests pet JOIN dbo.Projects p ON p.ProjectId=pet.ProjectId WHERE pet.PetId=@Pet AND (pet.Status IN('Draft','Pending Review') OR (pet.Status='Pending Approval' AND p.SkipReview=1))) THROW 50007,'Spend items cannot be changed after review or final approval.',1;
 IF @Id IS NULL BEGIN INSERT dbo.SpendItems(PetId,Head,Topic,Vendor,CostType,UnitType,Units,UnitPrice,Currency,ForeignAmount,AedAmount,ContingencyPercent,GlNumber) VALUES(@Pet,@Head,@Topic,@Vendor,@CostType,@UnitType,@Units,@UnitPrice,@Currency,@Foreign,@Aed,@Contingency,@Gl); SET @Id=SCOPE_IDENTITY(); END
 ELSE UPDATE dbo.SpendItems SET Head=@Head,Topic=@Topic,Vendor=@Vendor,CostType=@CostType,UnitType=@UnitType,Units=@Units,UnitPrice=@UnitPrice,Currency=@Currency,ForeignAmount=@Foreign,AedAmount=@Aed,ContingencyPercent=@Contingency,GlNumber=@Gl WHERE SpendItemId=@Id AND PetId=@Pet;
 UPDATE dbo.PETRequests SET RequestedAmount=(SELECT ISNULL(SUM(FinalAedAmount),0) FROM dbo.SpendItems WHERE PetId=@Pet),UpdatedUtc=SYSUTCDATETIME() WHERE PetId=@Pet;
 SELECT SpendItemId,(SELECT RequestedAmount FROM dbo.PETRequests WHERE PetId=@Pet) FinalRequestAedAmount FROM dbo.SpendItems WHERE SpendItemId=@Id;
END;
GO
CREATE OR ALTER VIEW dbo.vw_ProjectPortfolio AS
SELECT p.ProjectId,p.ProjectCode,p.JiraKey,p.ProjectName,p.ProjectType,p.AccountableExecLead,p.AccountableExec,p.SmeLead,p.ProjectSize,p.ProjectManager,p.RequestorEmail,COALESCE(u.DisplayName,p.RequestorEmail) RequestorName,p.BudgetType,p.BudgetSourceId,p.RequiresPet,p.SkipReview,p.Status,p.CreatedUtc,
 b.ExternalId BudgetSource,b.Budget,b.Utilization,b.AvailableBudget,
 (SELECT COUNT(*) FROM dbo.PETRequests x WHERE x.ProjectId=p.ProjectId) PetCount,
 (SELECT COUNT(*) FROM dbo.PETRequests x WHERE x.ProjectId=p.ProjectId AND x.Status='Approved') ApprovedPetCount,
 (SELECT COUNT(*) FROM dbo.SpendItems s JOIN dbo.PETRequests pet ON pet.PetId=s.PetId WHERE pet.ProjectId=p.ProjectId) SpendRequestCount,
 (SELECT COUNT(*) FROM dbo.BudgetLines bl JOIN dbo.PETRequests pet ON pet.PetId=bl.PetId WHERE pet.ProjectId=p.ProjectId) BudgetLineCount,
 (SELECT COUNT(*) FROM dbo.Invoices i JOIN dbo.BudgetLines bl ON bl.BudgetLineId=i.BudgetLineId JOIN dbo.PETRequests pet ON pet.PetId=bl.PetId WHERE pet.ProjectId=p.ProjectId) InvoiceCount,
 (SELECT ISNULL(SUM(x.InvoiceAmount),0) FROM dbo.Invoices x JOIN dbo.BudgetLines bl ON bl.BudgetLineId=x.BudgetLineId JOIN dbo.PETRequests pet ON pet.PetId=bl.PetId WHERE pet.ProjectId=p.ProjectId) InvoicedAmount
FROM dbo.Projects p LEFT JOIN dbo.Users u ON u.Email=p.RequestorEmail LEFT JOIN dbo.BudgetSources b ON b.BudgetSourceId=p.BudgetSourceId;
GO
CREATE VIEW dbo.vw_CapexProjectUtilization AS
SELECT b.BudgetSourceId,b.ExternalId BudgetSource,b.Description BudgetDescription,p.ProjectId,p.ProjectCode,p.ProjectName,pet.PetId,pet.Code PetCode,pet.RequestedAmount ApprovedAmount,pet.ApprovedUtc
FROM dbo.BudgetSources b JOIN dbo.Projects p ON p.BudgetSourceId=b.BudgetSourceId JOIN dbo.PETRequests pet ON pet.ProjectId=p.ProjectId AND pet.Status='Approved'
WHERE b.BudgetType='CAPEX';
GO
