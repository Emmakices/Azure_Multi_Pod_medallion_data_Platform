-- =============================================
-- Step 2: Create Indexes and Views
-- =============================================

-- Create Indexes
CREATE INDEX IX_PipelineExecution_RunID ON PipelineExecutionLog(PipelineRunID);
CREATE INDEX IX_PipelineExecution_Status ON PipelineExecutionLog(Status);
CREATE INDEX IX_PipelineExecution_StartTime ON PipelineExecutionLog(StartTime DESC);
CREATE INDEX IX_PipelineExecution_FileName ON PipelineExecutionLog(SourceFileName);

CREATE INDEX IX_ActivityLog_ExecutionID ON PipelineActivityLog(ExecutionID);
CREATE INDEX IX_ActivityLog_ActivityName ON PipelineActivityLog(ActivityName);
CREATE INDEX IX_ActivityLog_Status ON PipelineActivityLog(Status);
CREATE INDEX IX_ActivityLog_StartTime ON PipelineActivityLog(StartTime DESC);

CREATE INDEX IX_ErrorLog_ExecutionID ON PipelineErrorLog(ExecutionID);
CREATE INDEX IX_ErrorLog_ErrorLevel ON PipelineErrorLog(ErrorLevel);
CREATE INDEX IX_ErrorLog_ErrorTime ON PipelineErrorLog(ErrorTime DESC);

PRINT 'Indexes created successfully';
GO

-- Create Monitoring Views
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
LEFT JOIN PipelineActivityLog pal ON pel.ExecutionID = pal.ExecutionID AND pal.Status = 'Failed'
WHERE pel.Status = 'Failed';
GO

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

PRINT 'Views created successfully';
