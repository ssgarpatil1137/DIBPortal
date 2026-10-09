USE DFM;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ReplicateDatabaseObjects
 @TargetDatabase sysname,
 @PreviewOnly bit = 1,
 @StopOnError bit = 1
AS
BEGIN
 SET NOCOUNT ON;

 IF DB_ID(@TargetDatabase) IS NULL THROW 50100,'Target database was not found on this SQL Server instance.',1;
 IF DB_ID(@TargetDatabase)=DB_ID() THROW 50101,'Target database must be different from the source database.',1;

 CREATE TABLE #ReplicateScripts(
  ScriptId int IDENTITY(1,1) NOT NULL PRIMARY KEY,
  StepOrder int NOT NULL,
  ObjectType nvarchar(60) NOT NULL,
  SchemaName sysname NULL,
  ObjectName sysname NULL,
  CommandText nvarchar(max) NOT NULL
 );

 CREATE TABLE #Results(
  ScriptId int NOT NULL,
  StepOrder int NOT NULL,
  ObjectType nvarchar(60) NOT NULL,
  SchemaName sysname NULL,
  ObjectName sysname NULL,
  Succeeded bit NOT NULL,
  ErrorMessage nvarchar(max) NULL
 );

 INSERT #ReplicateScripts(StepOrder,ObjectType,SchemaName,ObjectName,CommandText)
 SELECT 10,N'SCHEMA',s.name,s.name,
        CONCAT(N'IF SCHEMA_ID(N''',REPLACE(s.name,'''',''''''),N''') IS NULL EXEC(N''CREATE SCHEMA ',QUOTENAME(s.name),N''');')
 FROM sys.schemas s
 WHERE s.name NOT IN(N'dbo',N'guest',N'INFORMATION_SCHEMA',N'sys')
   AND s.schema_id < 16384;

 INSERT #ReplicateScripts(StepOrder,ObjectType,SchemaName,ObjectName,CommandText)
 SELECT 20,N'TABLE',s.name,t.name,
        CONCAT(N'IF OBJECT_ID(N''',REPLACE(QUOTENAME(s.name)+N'.'+QUOTENAME(t.name),'''',''''''),N''', N''U'') IS NULL CREATE TABLE ',QUOTENAME(s.name),N'.',QUOTENAME(t.name),N'(',CHAR(13),
        STUFF((
          SELECT CONCAT(N',',CHAR(13),N' ',QUOTENAME(c.name),N' ',
            CASE WHEN cc.object_id IS NOT NULL THEN CONCAT(N'AS ',cc.definition,CASE WHEN cc.is_persisted=1 THEN N' PERSISTED' ELSE N'' END)
                 ELSE CONCAT(
                   CASE WHEN ty.is_user_defined=1 THEN QUOTENAME(SCHEMA_NAME(ty.schema_id))+N'.'+QUOTENAME(ty.name)
                        WHEN ty.name IN(N'varchar',N'char',N'varbinary',N'binary') THEN CONCAT(ty.name,N'(',CASE WHEN c.max_length=-1 THEN N'max' ELSE CONVERT(nvarchar(20),c.max_length) END,N')')
                        WHEN ty.name IN(N'nvarchar',N'nchar') THEN CONCAT(ty.name,N'(',CASE WHEN c.max_length=-1 THEN N'max' ELSE CONVERT(nvarchar(20),c.max_length/2) END,N')')
                        WHEN ty.name IN(N'decimal',N'numeric') THEN CONCAT(ty.name,N'(',CONVERT(nvarchar(20),c.precision),N',',CONVERT(nvarchar(20),c.scale),N')')
                        WHEN ty.name IN(N'datetime2',N'datetimeoffset',N'time') THEN CONCAT(ty.name,N'(',CONVERT(nvarchar(20),c.scale),N')')
                        WHEN ty.name=N'float' AND c.precision<>53 THEN CONCAT(ty.name,N'(',CONVERT(nvarchar(20),c.precision),N')')
                        ELSE ty.name END,
                   CASE WHEN ic.object_id IS NOT NULL THEN CONCAT(N' IDENTITY(',CONVERT(nvarchar(40),ic.seed_value),N',',CONVERT(nvarchar(40),ic.increment_value),N')') ELSE N'' END,
                   CASE WHEN c.collation_name IS NOT NULL AND ty.name IN(N'varchar',N'char',N'nvarchar',N'nchar',N'text',N'ntext') THEN CONCAT(N' COLLATE ',c.collation_name) ELSE N'' END,
                   CASE WHEN c.is_rowguidcol=1 THEN N' ROWGUIDCOL' ELSE N'' END,
                   CASE WHEN c.is_nullable=1 THEN N' NULL' ELSE N' NOT NULL' END)
            END)
          FROM sys.columns c
          JOIN sys.types ty ON ty.user_type_id=c.user_type_id
          LEFT JOIN sys.computed_columns cc ON cc.object_id=c.object_id AND cc.column_id=c.column_id
          LEFT JOIN sys.identity_columns ic ON ic.object_id=c.object_id AND ic.column_id=c.column_id
          WHERE c.object_id=t.object_id
          ORDER BY c.column_id
          FOR XML PATH(N''),TYPE).value(N'.',N'nvarchar(max)'),1,3,N''),CHAR(13),N');')
 FROM sys.tables t
 JOIN sys.schemas s ON s.schema_id=t.schema_id
 WHERE t.is_ms_shipped=0;

 INSERT #ReplicateScripts(StepOrder,ObjectType,SchemaName,ObjectName,CommandText)
 SELECT CASE WHEN o.type IN(N'FN',N'IF',N'TF') THEN 30 WHEN o.type=N'V' THEN 90 WHEN o.type=N'P' THEN 100 ELSE 110 END,
        o.type_desc,s.name,o.name,
        CASE WHEN UPPER(LEFT(LTRIM(m.definition),15))=N'CREATE OR ALTER' THEN m.definition
             WHEN UPPER(LEFT(LTRIM(m.definition),6))=N'CREATE' THEN STUFF(m.definition,CHARINDEX(N'CREATE',UPPER(m.definition)),6,N'CREATE OR ALTER')
             WHEN UPPER(LEFT(LTRIM(m.definition),5))=N'ALTER' THEN STUFF(m.definition,CHARINDEX(N'ALTER',UPPER(m.definition)),5,N'CREATE OR ALTER')
             ELSE m.definition END
 FROM sys.objects o
 JOIN sys.schemas s ON s.schema_id=o.schema_id
 JOIN sys.sql_modules m ON m.object_id=o.object_id
 WHERE o.is_ms_shipped=0
   AND o.type IN(N'FN',N'IF',N'TF',N'V',N'P',N'TR')
   AND m.definition IS NOT NULL;

 INSERT #ReplicateScripts(StepOrder,ObjectType,SchemaName,ObjectName,CommandText)
 SELECT 40,kc.type_desc,s.name,kc.name,
        CONCAT(N'IF OBJECT_ID(N''',REPLACE(QUOTENAME(s.name)+N'.'+QUOTENAME(kc.name),'''',''''''),N''', N''',kc.type,N''') IS NULL ALTER TABLE ',QUOTENAME(s.name),N'.',QUOTENAME(t.name),N' ADD CONSTRAINT ',QUOTENAME(kc.name),N' ',
               CASE WHEN kc.type=N'PK' THEN N'PRIMARY KEY ' ELSE N'UNIQUE ' END,
               CASE WHEN i.type=1 THEN N'CLUSTERED ' ELSE N'NONCLUSTERED ' END,N'(',
               STUFF((SELECT CONCAT(N', ',QUOTENAME(c.name),CASE WHEN ic.is_descending_key=1 THEN N' DESC' ELSE N' ASC' END)
                      FROM sys.index_columns ic
                      JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id
                      WHERE ic.object_id=kc.parent_object_id AND ic.index_id=kc.unique_index_id AND ic.key_ordinal>0
                      ORDER BY ic.key_ordinal
                      FOR XML PATH(N''),TYPE).value(N'.',N'nvarchar(max)'),1,2,N''),N');')
 FROM sys.key_constraints kc
 JOIN sys.tables t ON t.object_id=kc.parent_object_id
 JOIN sys.schemas s ON s.schema_id=t.schema_id
 JOIN sys.indexes i ON i.object_id=kc.parent_object_id AND i.index_id=kc.unique_index_id
 WHERE t.is_ms_shipped=0;

 INSERT #ReplicateScripts(StepOrder,ObjectType,SchemaName,ObjectName,CommandText)
 SELECT 50,N'DEFAULT_CONSTRAINT',s.name,dc.name,
        CONCAT(N'IF OBJECT_ID(N''',REPLACE(QUOTENAME(s.name)+N'.'+QUOTENAME(dc.name),'''',''''''),N''', N''D'') IS NULL ALTER TABLE ',QUOTENAME(s.name),N'.',QUOTENAME(t.name),N' ADD CONSTRAINT ',QUOTENAME(dc.name),N' DEFAULT ',dc.definition,N' FOR ',QUOTENAME(c.name),N';')
 FROM sys.default_constraints dc
 JOIN sys.tables t ON t.object_id=dc.parent_object_id
 JOIN sys.schemas s ON s.schema_id=t.schema_id
 JOIN sys.columns c ON c.object_id=dc.parent_object_id AND c.column_id=dc.parent_column_id
 WHERE t.is_ms_shipped=0;

 INSERT #ReplicateScripts(StepOrder,ObjectType,SchemaName,ObjectName,CommandText)
 SELECT 60,N'CHECK_CONSTRAINT',s.name,cc.name,
        CONCAT(N'IF OBJECT_ID(N''',REPLACE(QUOTENAME(s.name)+N'.'+QUOTENAME(cc.name),'''',''''''),N''', N''C'') IS NULL BEGIN ALTER TABLE ',QUOTENAME(s.name),N'.',QUOTENAME(t.name),N' WITH CHECK ADD CONSTRAINT ',QUOTENAME(cc.name),N' CHECK ',cc.definition,N'; ALTER TABLE ',QUOTENAME(s.name),N'.',QUOTENAME(t.name),N' CHECK CONSTRAINT ',QUOTENAME(cc.name),N'; END;')
 FROM sys.check_constraints cc
 JOIN sys.tables t ON t.object_id=cc.parent_object_id
 JOIN sys.schemas s ON s.schema_id=t.schema_id
 WHERE t.is_ms_shipped=0;

 INSERT #ReplicateScripts(StepOrder,ObjectType,SchemaName,ObjectName,CommandText)
 SELECT 70,N'FOREIGN_KEY',ps.name,fk.name,
        CONCAT(N'IF OBJECT_ID(N''',REPLACE(QUOTENAME(ps.name)+N'.'+QUOTENAME(fk.name),'''',''''''),N''', N''F'') IS NULL BEGIN ALTER TABLE ',QUOTENAME(ps.name),N'.',QUOTENAME(pt.name),N' WITH CHECK ADD CONSTRAINT ',QUOTENAME(fk.name),N' FOREIGN KEY(',
               STUFF((SELECT CONCAT(N', ',QUOTENAME(pc.name))
                      FROM sys.foreign_key_columns fkc
                      JOIN sys.columns pc ON pc.object_id=fkc.parent_object_id AND pc.column_id=fkc.parent_column_id
                      WHERE fkc.constraint_object_id=fk.object_id
                      ORDER BY fkc.constraint_column_id
                      FOR XML PATH(N''),TYPE).value(N'.',N'nvarchar(max)'),1,2,N''),
               N') REFERENCES ',QUOTENAME(rs.name),N'.',QUOTENAME(rt.name),N'(',
               STUFF((SELECT CONCAT(N', ',QUOTENAME(rc.name))
                      FROM sys.foreign_key_columns fkc
                      JOIN sys.columns rc ON rc.object_id=fkc.referenced_object_id AND rc.column_id=fkc.referenced_column_id
                      WHERE fkc.constraint_object_id=fk.object_id
                      ORDER BY fkc.constraint_column_id
                      FOR XML PATH(N''),TYPE).value(N'.',N'nvarchar(max)'),1,2,N''),N')',
               CASE WHEN fk.delete_referential_action_desc<>N'NO_ACTION' THEN CONCAT(N' ON DELETE ',REPLACE(fk.delete_referential_action_desc,N'_',N' ')) ELSE N'' END,
               CASE WHEN fk.update_referential_action_desc<>N'NO_ACTION' THEN CONCAT(N' ON UPDATE ',REPLACE(fk.update_referential_action_desc,N'_',N' ')) ELSE N'' END,
               N'; ALTER TABLE ',QUOTENAME(ps.name),N'.',QUOTENAME(pt.name),N' CHECK CONSTRAINT ',QUOTENAME(fk.name),N'; END;')
 FROM sys.foreign_keys fk
 JOIN sys.tables pt ON pt.object_id=fk.parent_object_id
 JOIN sys.schemas ps ON ps.schema_id=pt.schema_id
 JOIN sys.tables rt ON rt.object_id=fk.referenced_object_id
 JOIN sys.schemas rs ON rs.schema_id=rt.schema_id
 WHERE pt.is_ms_shipped=0;

 INSERT #ReplicateScripts(StepOrder,ObjectType,SchemaName,ObjectName,CommandText)
 SELECT 80,N'INDEX',s.name,i.name,
        CONCAT(N'IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N''',REPLACE(QUOTENAME(s.name)+N'.'+QUOTENAME(t.name),'''',''''''),N''', N''U'') AND name=N''',REPLACE(i.name,'''',''''''),N''') CREATE ',
               CASE WHEN i.is_unique=1 THEN N'UNIQUE ' ELSE N'' END,CASE WHEN i.type=1 THEN N'CLUSTERED ' ELSE N'NONCLUSTERED ' END,N'INDEX ',QUOTENAME(i.name),N' ON ',QUOTENAME(s.name),N'.',QUOTENAME(t.name),N'(',
               STUFF((SELECT CONCAT(N', ',QUOTENAME(c.name),CASE WHEN ic.is_descending_key=1 THEN N' DESC' ELSE N' ASC' END)
                      FROM sys.index_columns ic
                      JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id
                      WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0
                      ORDER BY ic.key_ordinal
                      FOR XML PATH(N''),TYPE).value(N'.',N'nvarchar(max)'),1,2,N''),N')',
               CASE WHEN EXISTS(SELECT 1 FROM sys.index_columns ixi WHERE ixi.object_id=i.object_id AND ixi.index_id=i.index_id AND ixi.is_included_column=1)
                    THEN CONCAT(N' INCLUDE (',STUFF((SELECT CONCAT(N', ',QUOTENAME(c.name))
                                                    FROM sys.index_columns ic
                                                    JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id
                                                    WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.is_included_column=1
                                                    ORDER BY ic.index_column_id
                                                    FOR XML PATH(N''),TYPE).value(N'.',N'nvarchar(max)'),1,2,N''),N')')
                    ELSE N'' END,
               CASE WHEN i.has_filter=1 THEN CONCAT(N' WHERE ',i.filter_definition) ELSE N'' END,N';')
 FROM sys.indexes i
 JOIN sys.tables t ON t.object_id=i.object_id
 JOIN sys.schemas s ON s.schema_id=t.schema_id
 WHERE t.is_ms_shipped=0
   AND i.name IS NOT NULL
   AND i.type IN(1,2)
   AND i.is_primary_key=0
   AND i.is_unique_constraint=0
   AND i.is_hypothetical=0;

 IF @PreviewOnly=1
 BEGIN
       SELECT CAST(1 AS bit) PreviewOnly,
                             N'Preview only. Re-run with @PreviewOnly = 0 to create objects in the target database.' StatusMessage,
                             ScriptId,StepOrder,ObjectType,SchemaName,ObjectName,CommandText
  FROM #ReplicateScripts
  ORDER BY StepOrder,ScriptId;
  RETURN;
 END;

 DECLARE @ScriptId int,@StepOrder int,@ObjectType nvarchar(60),@SchemaName sysname,@ObjectName sysname,@CommandText nvarchar(max),@TargetCommand nvarchar(max);
 SET @TargetCommand=CONCAT(N'USE ',QUOTENAME(@TargetDatabase),N'; EXEC sys.sp_executesql @InnerCommand;');

 DECLARE ReplicateCursor CURSOR LOCAL FAST_FORWARD FOR
 SELECT ScriptId,StepOrder,ObjectType,SchemaName,ObjectName,CommandText
 FROM #ReplicateScripts
 ORDER BY StepOrder,ScriptId;

 OPEN ReplicateCursor;
 FETCH NEXT FROM ReplicateCursor INTO @ScriptId,@StepOrder,@ObjectType,@SchemaName,@ObjectName,@CommandText;
 WHILE @@FETCH_STATUS=0
 BEGIN
  BEGIN TRY
   EXEC sys.sp_executesql @TargetCommand,N'@InnerCommand nvarchar(max)',@InnerCommand=@CommandText;
   INSERT #Results VALUES(@ScriptId,@StepOrder,@ObjectType,@SchemaName,@ObjectName,1,NULL);
  END TRY
  BEGIN CATCH
   INSERT #Results VALUES(@ScriptId,@StepOrder,@ObjectType,@SchemaName,@ObjectName,0,ERROR_MESSAGE());
   IF @StopOnError=1
   BEGIN
    CLOSE ReplicateCursor;
    DEALLOCATE ReplicateCursor;
    SELECT ScriptId,StepOrder,ObjectType,SchemaName,ObjectName,Succeeded,ErrorMessage FROM #Results ORDER BY ScriptId;
    THROW;
   END;
  END CATCH;
  FETCH NEXT FROM ReplicateCursor INTO @ScriptId,@StepOrder,@ObjectType,@SchemaName,@ObjectName,@CommandText;
 END;
 CLOSE ReplicateCursor;
 DEALLOCATE ReplicateCursor;

 SELECT ScriptId,StepOrder,ObjectType,SchemaName,ObjectName,Succeeded,ErrorMessage
 FROM #Results
 ORDER BY ScriptId;
END;
GO