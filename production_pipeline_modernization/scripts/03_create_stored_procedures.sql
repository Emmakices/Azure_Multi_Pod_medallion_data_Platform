-- =============================================
-- Step 3: Create Stored Procedures
-- =============================================

-- SP: Start Pipeline Execution
CREATE PROCEDURE sp_StartPipelineExecution
    @PipelineRunID NVARCHAR(100),
    @PipelineName NVARCHAR(100),
    @SourceFileName NVARCHAR(255) = NULL,
    @SourceFileSize BIGINT = NULL,
    @TriggerType NVARCHAR(50) = 'Manual',
    @TriggerName NVARCHAR(100) = NULL,
    @CreatedBy NVARCHAR(100) = 'System',
    @ExecutionID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO PipelineExecutionLog (PipelineRunID, PipelineName, TriggerType, TriggerName, SourceFileName, SourceFileSize, StartTime, Status, CreatedBy)
    VALUES (@PipelineRunID, @PipelineName, @TriggerType, @TriggerName, @SourceFileName, @SourceFileSize, GETDATE(), 'Running', @CreatedBy);
    SET @ExecutionID = SCOPE_IDENTITY();
    SELECT @ExecutionID AS ExecutionID;
END;
GO

-- SP: End Pipeline Execution
CREATE PROCEDURE sp_EndPipelineExecution
    @ExecutionID INT,
    @Status NVARCHAR(50),
    @RecordsProcessed INT = 0,
    @ErrorMessage NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE PipelineExecutionLog
    SET EndTime = GETDATE(), DurationSeconds = DATEDIFF(SECOND, StartTime, GETDATE()), Status = @Status, RecordsProcessed = @RecordsProcessed, ErrorMessage = @ErrorMessage
    WHERE ExecutionID = @ExecutionID;
END;
GO

-- SP: Log Activity
CREATE PROCEDURE sp_LogActivity
    @ExecutionID INT,
    @ActivityRunID NVARCHAR(100) = NULL,
    @ActivityName NVARCHAR(100),
    @ActivityType NVARCHAR(50),
    @Status NVARCHAR(50) = 'Running',
    @InputParameters NVARCHAR(MAX) = NULL,
    @OutputParameters NVARCHAR(MAX) = NULL,
    @RecordsRead INT = 0,
    @RecordsWritten INT = 0,
    @ErrorCode NVARCHAR(50) = NULL,
    @ErrorMessage NVARCHAR(MAX) = NULL,
    @ActivityLogID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF @Status = 'Running'
    BEGIN
        INSERT INTO PipelineActivityLog (ExecutionID, ActivityRunID, ActivityName, ActivityType, StartTime, Status, InputParameters)
        VALUES (@ExecutionID, @ActivityRunID, @ActivityName, @ActivityType, GETDATE(), @Status, @InputParameters);
        SET @ActivityLogID = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE PipelineActivityLog
        SET EndTime = GETDATE(), DurationSeconds = DATEDIFF(SECOND, StartTime, GETDATE()), Status = @Status, OutputParameters = @OutputParameters, RecordsRead = @RecordsRead, RecordsWritten = @RecordsWritten, ErrorCode = @ErrorCode, ErrorMessage = @ErrorMessage
        WHERE ActivityLogID = @ActivityLogID;
    END
    SELECT @ActivityLogID AS ActivityLogID;
END;
GO

-- SP: Log Error
CREATE PROCEDURE sp_LogError
    @ExecutionID INT = NULL,
    @ActivityLogID INT = NULL,
    @ErrorLevel NVARCHAR(20) = 'Error',
    @ErrorCode NVARCHAR(50) = NULL,
    @ErrorMessage NVARCHAR(MAX),
    @ErrorDetails NVARCHAR(MAX) = NULL,
    @SourceComponent NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO PipelineErrorLog (ExecutionID, ActivityLogID, ErrorLevel, ErrorCode, ErrorMessage, ErrorDetails, SourceComponent)
    VALUES (@ExecutionID, @ActivityLogID, @ErrorLevel, @ErrorCode, @ErrorMessage, @ErrorDetails, @SourceComponent);
END;
GO

PRINT 'Stored procedures created successfully';
PRINT 'Logging system setup complete!';
