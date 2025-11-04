-- =============================================
-- Step 1: Create Main Logging Tables
-- =============================================

-- 1. Pipeline Execution Log
CREATE TABLE PipelineExecutionLog (
    ExecutionID INT IDENTITY(1,1) PRIMARY KEY,
    PipelineRunID NVARCHAR(100) NOT NULL,
    PipelineName NVARCHAR(100) NOT NULL,
    TriggerType NVARCHAR(50),
    TriggerName NVARCHAR(100),
    SourceFileName NVARCHAR(255),
    SourceFileSize BIGINT,
    StartTime DATETIME2 NOT NULL,
    EndTime DATETIME2,
    DurationSeconds INT,
    Status NVARCHAR(50) NOT NULL,
    RecordsProcessed INT DEFAULT 0,
    ErrorMessage NVARCHAR(MAX),
    CreatedBy NVARCHAR(100) DEFAULT 'System',
    CreatedDate DATETIME2 DEFAULT GETDATE()
);

-- 2. Pipeline Activity Log
CREATE TABLE PipelineActivityLog (
    ActivityLogID INT IDENTITY(1,1) PRIMARY KEY,
    ExecutionID INT NOT NULL,
    ActivityRunID NVARCHAR(100),
    ActivityName NVARCHAR(100) NOT NULL,
    ActivityType NVARCHAR(50) NOT NULL,
    StartTime DATETIME2 NOT NULL,
    EndTime DATETIME2,
    DurationSeconds INT,
    Status NVARCHAR(50) NOT NULL,
    InputParameters NVARCHAR(MAX),
    OutputParameters NVARCHAR(MAX),
    RecordsRead INT DEFAULT 0,
    RecordsWritten INT DEFAULT 0,
    ErrorCode NVARCHAR(50),
    ErrorMessage NVARCHAR(MAX),
    RetryCount INT DEFAULT 0,
    CONSTRAINT FK_ActivityLog_ExecutionLog FOREIGN KEY (ExecutionID) REFERENCES PipelineExecutionLog(ExecutionID)
);

-- 3. Pipeline Error Log
CREATE TABLE PipelineErrorLog (
    ErrorLogID INT IDENTITY(1,1) PRIMARY KEY,
    ExecutionID INT,
    ActivityLogID INT,
    ErrorTime DATETIME2 NOT NULL DEFAULT GETDATE(),
    ErrorLevel NVARCHAR(20) NOT NULL,
    ErrorCode NVARCHAR(50),
    ErrorMessage NVARCHAR(MAX) NOT NULL,
    ErrorDetails NVARCHAR(MAX),
    SourceComponent NVARCHAR(100),
    CONSTRAINT FK_ErrorLog_ExecutionLog FOREIGN KEY (ExecutionID) REFERENCES PipelineExecutionLog(ExecutionID),
    CONSTRAINT FK_ErrorLog_ActivityLog FOREIGN KEY (ActivityLogID) REFERENCES PipelineActivityLog(ActivityLogID)
);

-- 4. Data Quality Metrics
CREATE TABLE DataQualityMetrics (
    MetricID INT IDENTITY(1,1) PRIMARY KEY,
    ExecutionID INT NOT NULL,
    TableName NVARCHAR(100) NOT NULL,
    MetricName NVARCHAR(100) NOT NULL,
    MetricValue NVARCHAR(255),
    ThresholdValue NVARCHAR(255),
    Status NVARCHAR(20),
    CheckedTime DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT FK_Metrics_ExecutionLog FOREIGN KEY (ExecutionID) REFERENCES PipelineExecutionLog(ExecutionID)
);

PRINT 'Tables created successfully';
