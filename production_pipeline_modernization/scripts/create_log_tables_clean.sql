-- =============================================
-- Advanced Pipeline Logging System
-- =============================================

-- 1. Pipeline Execution Log (Main pipeline runs)
CREATE TABLE PipelineExecutionLog (
    ExecutionID INT IDENTITY(1,1) PRIMARY KEY,
    PipelineRunID NVARCHAR(100) NOT NULL,           -- ADF Pipeline Run ID
    PipelineName NVARCHAR(100) NOT NULL,            -- Name of the pipeline
    TriggerType NVARCHAR(50),                       -- Manual, Scheduled, Event-based
    TriggerName NVARCHAR(100),                      -- Name of the trigger
    SourceFileName NVARCHAR(255),                   -- Input file name
    SourceFileSize BIGINT,                          -- File size in bytes
    StartTime DATETIME2 NOT NULL,                   -- Pipeline start time
    EndTime DATETIME2,                              -- Pipeline end time
    DurationSeconds INT,                            -- Calculated duration
    Status NVARCHAR(50) NOT NULL,                   -- Running, Succeeded, Failed, Cancelled
    RecordsProcessed INT DEFAULT 0,                 -- Total records processed
    ErrorMessage NVARCHAR(MAX),                     -- Error details if failed
    CreatedBy NVARCHAR(100) DEFAULT 'System',       -- User or system that triggered
    CreatedDate DATETIME2 DEFAULT GETDATE()
);

-- 2. Pipeline Activity Log (Individual steps)
CREATE TABLE PipelineActivityLog (
    ActivityLogID INT IDENTITY(1,1) PRIMARY KEY,
    ExecutionID INT NOT NULL,                       -- FK to PipelineExecutionLog
    ActivityRunID NVARCHAR(100),                    -- ADF Activity Run ID
    ActivityName NVARCHAR(100) NOT NULL,            -- Name of the activity/step
    ActivityType NVARCHAR(50) NOT NULL,             -- Validation, Copy, DataFlow, etc.
    StartTime DATETIME2 NOT NULL,                   -- Activity start time
    EndTime DATETIME2,                              -- Activity end time
    DurationSeconds INT,                            -- Calculated duration
    Status NVARCHAR(50) NOT NULL,                   -- Running, Succeeded, Failed, Skipped
    InputParameters NVARCHAR(MAX),                  -- JSON of input parameters
    OutputParameters NVARCHAR(MAX),                 -- JSON of output/results
    RecordsRead INT DEFAULT 0,                      -- Records read in this step
    RecordsWritten INT DEFAULT 0,                   -- Records written in this step
    ErrorCode NVARCHAR(50),                         -- Error code if failed
    ErrorMessage NVARCHAR(MAX),                     -- Detailed error message
    RetryCount INT DEFAULT 0,                       -- Number of retries
    CONSTRAINT FK_ActivityLog_ExecutionLog
        FOREIGN KEY (ExecutionID)
        REFERENCES PipelineExecutionLog(ExecutionID)
);

-- 3. Pipeline Error Log (Detailed error tracking)
CREATE TABLE PipelineErrorLog (
    ErrorLogID INT IDENTITY(1,1) PRIMARY KEY,
    ExecutionID INT,                                -- FK to PipelineExecutionLog
    ActivityLogID INT,                              -- FK to PipelineActivityLog
    ErrorTime DATETIME2 NOT NULL DEFAULT GETDATE(),
    ErrorLevel NVARCHAR(20) NOT NULL,               -- Critical, Error, Warning, Info
    ErrorCode NVARCHAR(50),                         -- Error code
    ErrorMessage NVARCHAR(MAX) NOT NULL,            -- Error message
    ErrorDetails NVARCHAR(MAX),                     -- Stack trace or additional details
    SourceComponent NVARCHAR(100),                  -- Component that raised the error
    CONSTRAINT FK_ErrorLog_ExecutionLog
        FOREIGN KEY (ExecutionID)
        REFERENCES PipelineExecutionLog(ExecutionID),
    CONSTRAINT FK_ErrorLog_ActivityLog
        FOREIGN KEY (ActivityLogID)
        REFERENCES PipelineActivityLog(ActivityLogID)
);

-- 4. Data Quality Metrics (Optional - for validation tracking)
CREATE TABLE DataQualityMetrics (
    MetricID INT IDENTITY(1,1) PRIMARY KEY,
    ExecutionID INT NOT NULL,                       -- FK to PipelineExecutionLog
    TableName NVARCHAR(100) NOT NULL,               -- Employees or Payroll
    MetricName NVARCHAR(100) NOT NULL,              -- Row count, Null values, etc.
    MetricValue NVARCHAR(255),                      -- The actual metric value
    ThresholdValue NVARCHAR(255),                   -- Expected/threshold value
    Status NVARCHAR(20),                            -- Pass, Fail, Warning
    CheckedTime DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT FK_Metrics_ExecutionLog
        FOREIGN KEY (ExecutionID)
        REFERENCES PipelineExecutionLog(ExecutionID)
);

-- =============================================
-- Indexes for Performance
-- =============================================

-- Index on PipelineExecutionLog
CREATE INDEX IX_PipelineExecution_RunID ON PipelineExecutionLog(PipelineRunID);
CREATE INDEX IX_PipelineExecution_Status ON PipelineExecutionLog(Status);
CREATE INDEX IX_PipelineExecution_StartTime ON PipelineExecutionLog(StartTime DESC);
CREATE INDEX IX_PipelineExecution_FileName ON PipelineExecutionLog(SourceFileName);

-- Index on PipelineActivityLog
CREATE INDEX IX_ActivityLog_ExecutionID ON PipelineActivityLog(ExecutionID);
CREATE INDEX IX_ActivityLog_ActivityName ON PipelineActivityLog(ActivityName);
CREATE INDEX IX_ActivityLog_Status ON PipelineActivityLog(Status);
CREATE INDEX IX_ActivityLog_StartTime ON PipelineActivityLog(StartTime DESC);

-- Index on PipelineErrorLog
CREATE INDEX IX_ErrorLog_ExecutionID ON PipelineErrorLog(ExecutionID);
CREATE INDEX IX_ErrorLog_ErrorLevel ON PipelineErrorLog(ErrorLevel);
CREATE INDEX IX_ErrorLog_ErrorTime ON PipelineErrorLog(ErrorTime DESC);

-- =============================================
-- Useful Views for Monitoring
-- =============================================

-- View: Current Running Pipelines
CREATE VIEW vw_RunningPipelines AS
SELECT
    ExecutionID,
    PipelineRunID,
    PipelineName,
    SourceFileName,
    StartTime,
    DATEDIFF(SECOND, StartTime, GETDATE()) AS RunningDurationSeconds,
    RecordsProcessed
FROM PipelineExecutionLog
WHERE Status = 'Running';
GO

-- View: Failed Pipeline Executions with Error Details
CREATE VIEW vw_FailedPipelines AS
SELECT
    pel.ExecutionID,
    pel.PipelineRunID,
    pel.PipelineName,
    pel.SourceFileName,
    pel.StartTime,
    pel.EndTime,
    pel.DurationSeconds,
    pel.ErrorMessage AS PipelineError,
    pal.ActivityName AS FailedActivity,
    pal.ErrorMessage AS ActivityError
FROM PipelineExecutionLog pel
LEFT JOIN PipelineActivityLog pal
    ON pel.ExecutionID = pal.ExecutionID
    AND pal.Status = 'Failed'
WHERE pel.Status = 'Failed';
GO

-- View: Pipeline Performance Summary
CREATE VIEW vw_PipelinePerformance AS
SELECT
    PipelineName,
    COUNT(*) AS TotalRuns,
    SUM(CASE WHEN Status = 'Succeeded' THEN 1 ELSE 0 END) AS SuccessfulRuns,
    SUM(CASE WHEN Status = 'Failed' THEN 1 ELSE 0 END) AS FailedRuns,
    AVG(DurationSeconds) AS AvgDurationSeconds,
    MIN(DurationSeconds) AS MinDurationSeconds,
    MAX(DurationSeconds) AS MaxDurationSeconds,
    SUM(RecordsProcessed) AS TotalRecordsProcessed
FROM PipelineExecutionLog
WHERE Status IN ('Succeeded', 'Failed')
GROUP BY PipelineName;
GO

-- View: Activity Performance by Type
CREATE VIEW vw_ActivityPerformance AS
SELECT
    ActivityName,
    ActivityType,
    COUNT(*) AS TotalExecutions,
    SUM(CASE WHEN Status = 'Succeeded' THEN 1 ELSE 0 END) AS SuccessfulExecutions,
    SUM(CASE WHEN Status = 'Failed' THEN 1 ELSE 0 END) AS FailedExecutions,
    AVG(DurationSeconds) AS AvgDurationSeconds,
    SUM(RecordsRead) AS TotalRecordsRead,
    SUM(RecordsWritten) AS TotalRecordsWritten
FROM PipelineActivityLog
WHERE Status IN ('Succeeded', 'Failed')
GROUP BY ActivityName, ActivityType;
GO

-- =============================================
-- Stored Procedures for Easy Logging
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

    INSERT INTO PipelineExecutionLog (
        PipelineRunID, PipelineName, TriggerType, TriggerName,
        SourceFileName, SourceFileSize, StartTime, Status, CreatedBy
    )
    VALUES (
        @PipelineRunID, @PipelineName, @TriggerType, @TriggerName,
        @SourceFileName, @SourceFileSize, GETDATE(), 'Running', @CreatedBy
    );

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
    SET
        EndTime = GETDATE(),
        DurationSeconds = DATEDIFF(SECOND, StartTime, GETDATE()),
        Status = @Status,
        RecordsProcessed = @RecordsProcessed,
        ErrorMessage = @ErrorMessage
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

    -- If status is Running, insert new record
    IF @Status = 'Running'
    BEGIN
        INSERT INTO PipelineActivityLog (
            ExecutionID, ActivityRunID, ActivityName, ActivityType,
            StartTime, Status, InputParameters
        )
        VALUES (
            @ExecutionID, @ActivityRunID, @ActivityName, @ActivityType,
            GETDATE(), @Status, @InputParameters
        );

        SET @ActivityLogID = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        -- Update existing record with end status
        UPDATE PipelineActivityLog
        SET
            EndTime = GETDATE(),
            DurationSeconds = DATEDIFF(SECOND, StartTime, GETDATE()),
            Status = @Status,
            OutputParameters = @OutputParameters,
            RecordsRead = @RecordsRead,
            RecordsWritten = @RecordsWritten,
            ErrorCode = @ErrorCode,
            ErrorMessage = @ErrorMessage
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

    INSERT INTO PipelineErrorLog (
        ExecutionID, ActivityLogID, ErrorLevel, ErrorCode,
        ErrorMessage, ErrorDetails, SourceComponent
    )
    VALUES (
        @ExecutionID, @ActivityLogID, @ErrorLevel, @ErrorCode,
        @ErrorMessage, @ErrorDetails, @SourceComponent
    );
END;
GO

-- =============================================
-- Logging system created successfully
-- =============================================
PRINT 'Pipeline logging system created successfully!';
PRINT 'Tables: PipelineExecutionLog, PipelineActivityLog, PipelineErrorLog, DataQualityMetrics';
PRINT 'Views: vw_RunningPipelines, vw_FailedPipelines, vw_PipelinePerformance, vw_ActivityPerformance';
PRINT 'Stored Procedures: sp_StartPipelineExecution, sp_EndPipelineExecution, sp_LogActivity, sp_LogError';
