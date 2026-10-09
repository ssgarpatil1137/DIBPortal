USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
CREATE OR ALTER PROCEDURE dbo.sp_SaveBudgetLine
 @Id int=NULL,@Pet int,@Vendor nvarchar(300),@Justification nvarchar(1000)=NULL,@Cost decimal(19,2),@Currency char(3),@Gl nvarchar(50)=NULL,@PetRef nvarchar(100)=NULL,@CamId nvarchar(100)=NULL,@CamStatus nvarchar(50)=NULL,@CamComments nvarchar(1000)=NULL,@LpoRequest nvarchar(100)=NULL,@LpoStatus nvarchar(50)=NULL,@LpoComments nvarchar(1000)=NULL,@User nvarchar(254),@CamCreatedDate date=NULL,@CamApprovedDate date=NULL,@LpoIssueDate date=NULL
AS
BEGIN
 SET NOCOUNT ON;
 IF @Id IS NULL AND NOT EXISTS(SELECT 1 FROM dbo.PETRequests WHERE PetId=@Pet AND Status='Approved') THROW 50016,'Budget Lines can be added only after the selected PET is approved.',1;
 IF @Id IS NULL BEGIN INSERT dbo.BudgetLines(PetId,Vendor,Justification,Cost,Currency,GlNumber,PetReference,CamId,CamStatus,CamCreatedDate,CamApprovedDate,CamComments,LpoRequest,LpoStatus,LpoIssueDate,LpoComments,CreatedBy) VALUES(@Pet,@Vendor,@Justification,@Cost,@Currency,@Gl,@PetRef,@CamId,@CamStatus,@CamCreatedDate,@CamApprovedDate,@CamComments,@LpoRequest,@LpoStatus,@LpoIssueDate,@LpoComments,@User); SET @Id=SCOPE_IDENTITY(); END ELSE UPDATE dbo.BudgetLines SET Vendor=@Vendor,Justification=@Justification,Cost=@Cost,Currency=@Currency,GlNumber=@Gl,PetReference=@PetRef,CamId=@CamId,CamStatus=@CamStatus,CamCreatedDate=@CamCreatedDate,CamApprovedDate=@CamApprovedDate,CamComments=@CamComments,LpoRequest=@LpoRequest,LpoStatus=@LpoStatus,LpoIssueDate=@LpoIssueDate,LpoComments=@LpoComments,UpdatedUtc=SYSUTCDATETIME() WHERE BudgetLineId=@Id;
 SELECT BudgetLineId FROM dbo.BudgetLines WHERE BudgetLineId=@Id;
END;
GO