function Get-OSMachine {
    return @"
SELECT host_platform, host_distribution, host_release, 
host_service_pack_level, host_sku, os_language_version,
host_architecture
FROM sys.dm_os_host_info WITH (NOLOCK); 
"@
}

function Get-SQLVersion {
    return @"
SELECT @@SERVERNAME AS [Server Name], @@VERSION AS [SQL Server and OS Version Info];
"@
}

function Get-CoresNumaNodes {
    return @"
SELECT cpu_count AS [Logical CPU Count], scheduler_count, 
(socket_count * cores_per_socket) AS [Physical Core Count], 
socket_count AS [Socket Count], cores_per_socket, numa_node_count
FROM sys.dm_os_sys_info WITH (NOLOCK);
"@
}
function Get-Parallelism {
    return @"
SELECT name, value, value_in_use, minimum, maximum, [description], is_dynamic, is_advanced
FROM sys.configurations WITH (NOLOCK)
where name in ('cost threshold for parallelism','max degree of parallelism')
ORDER BY name;
"@
}

function Get-ProcessMemory {
    return @"
SELECT physical_memory_in_use_kb/1024 AS [SQL Server Memory Usage (MB)],
memory_utilization_percentage,  
process_physical_memory_low, process_virtual_memory_low
FROM sys.dm_os_process_memory WITH (NOLOCK);
"@
}

function Get-MemoryDetails {
    return @"
    SELECT total_physical_memory_kb/1024 AS [Physical Memory (MB)], 
    available_physical_memory_kb/1024 AS [Available Memory (MB)], 
    total_page_file_kb/1024 AS [Page File Commit Limit (MB)],
    total_page_file_kb/1024 - total_physical_memory_kb/1024 AS [Physical Page File Size (MB)],
    available_page_file_kb/1024 AS [Available Page File (MB)], 
    system_cache_kb/1024 AS [System Cache (MB)],
    system_memory_state_desc AS [System Memory State]
FROM sys.dm_os_sys_memory WITH (NOLOCK);

"@
}

function Get-FileLatency {
    return @"
-- Calculates average latency per read, per write, and per total input/output for each database file  (Query 32) (IO Latency by File)
SELECT DB_NAME(fs.database_id) AS [Database Name], CAST(fs.io_stall_read_ms/(1.0 + fs.num_of_reads) AS NUMERIC(10,1)) AS [avg_read_latency_ms],
CAST(fs.io_stall_write_ms/(1.0 + fs.num_of_writes) AS NUMERIC(10,1)) AS [avg_write_latency_ms],
CAST((fs.io_stall_read_ms + fs.io_stall_write_ms)/(1.0 + fs.num_of_reads + fs.num_of_writes) AS NUMERIC(10,1)) AS [avg_io_latency_ms],
CONVERT(DECIMAL(18,2), mf.size/128.0) AS [File Size (MB)], mf.physical_name, mf.type_desc, fs.io_stall_read_ms, fs.num_of_reads, 
fs.io_stall_write_ms, fs.num_of_writes, fs.io_stall_read_ms + fs.io_stall_write_ms AS [io_stalls], fs.num_of_reads + fs.num_of_writes AS [total_io],
io_stall_queued_read_ms AS [Resource Governor Total Read IO Latency (ms)], io_stall_queued_write_ms AS [Resource Governor Total Write IO Latency (ms)] 
FROM sys.dm_io_virtual_file_stats(null,null) AS fs
INNER JOIN sys.master_files AS mf WITH (NOLOCK)
ON fs.database_id = mf.database_id
AND fs.[file_id] = mf.[file_id]
ORDER BY avg_io_latency_ms DESC;
"@
}

function Get-AutoGrowth {
    return @"
SELECT DB_NAME([database_id]) AS [Database Name], 
[file_id], [name], physical_name, [type_desc], state_desc,
is_percent_growth, growth, 
CONVERT(bigint, growth/128.0) AS [Growth in MB], 
CONVERT(bigint, size/128.0) AS [Total Size in MB], max_size
FROM sys.master_files WITH (NOLOCK)
ORDER BY DB_NAME([database_id]), [file_id];
"@
}

function Get-tempdb {
    return @"
EXEC sys.xp_readerrorlog 0, 1, N'The tempdb database has';
"@
}

function Get-CompatibilityLevel {
    return @"
SELECT db.[name] AS [Database Name], SUSER_SNAME(db.owner_sid) AS [Database Owner],
db.[compatibility_level] AS [DB Compatibility Level], 
db.recovery_model_desc AS [Recovery Model], 
db.log_reuse_wait_desc AS [Log Reuse Wait Description],
ORDER BY db.[name];
"@
}

function Get-AutoCreateStats {
    return @"
SELECT db.[name] AS [Database Name],
db.is_auto_create_stats_on, db.is_auto_update_stats_on, db.is_auto_update_stats_async_on, db.is_auto_shrink_on 
FROM sys.databases AS db WITH (NOLOCK);
"@
}
function Get-StatsUpdates {
    return @"
SELECT SCHEMA_NAME(o.Schema_ID) + N'.' + o.[NAME] AS [Object Name], o.[type_desc] AS [Object Type],
i.[name] AS [Index Name], STATS_DATE(i.[object_id], i.index_id) AS [Statistics Date], 
s.auto_created, s.no_recompute, s.user_created, s.is_incremental, s.is_temporary, 
s.has_persisted_sample, sp.persisted_sample_percent, 
(sp.rows_sampled * 100)/sp.rows AS [Actual Sample Percent], sp.modification_counter,
st.row_count, st.used_page_count
FROM sys.objects AS o WITH (NOLOCK)
INNER JOIN sys.indexes AS i WITH (NOLOCK)
ON o.[object_id] = i.[object_id]
INNER JOIN sys.stats AS s WITH (NOLOCK)
ON i.[object_id] = s.[object_id] 
AND i.index_id = s.stats_id
INNER JOIN sys.dm_db_partition_stats AS st WITH (NOLOCK)
ON o.[object_id] = st.[object_id]
AND i.[index_id] = st.[index_id]
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) AS sp
WHERE o.[type] IN ('U', 'V')
AND st.row_count > 0
ORDER BY STATS_DATE(i.[object_id], i.index_id) DESC;
"@
}

function Get-AutomaticTuningOptions {
    return @"
SELECT [name], desired_state_desc, actual_state_desc, reason_desc
FROM sys.database_automatic_tuning_options WITH (NOLOCK);
"@
}

function Get-RecentFullBackups {
    return @"
    SELECT TOP (30) bs.machine_name, bs.server_name, bs.database_name AS [Database Name], bs.recovery_model,
    CONVERT (BIGINT, bs.backup_size / 1048576 ) AS [Uncompressed Backup Size (MB)],
    CONVERT (BIGINT, bs.compressed_backup_size / 1048576 ) AS [Compressed Backup Size (MB)],
    CONVERT (NUMERIC (20,2), (CONVERT (FLOAT, bs.backup_size) /
    CONVERT (FLOAT, bs.compressed_backup_size))) AS [Compression Ratio], bs.compression_algorithm,
    bs.has_backup_checksums, bs.is_copy_only, bs.encryptor_type,
    DATEDIFF (SECOND, bs.backup_start_date, bs.backup_finish_date) AS [Backup Elapsed Time (sec)],
    bs.backup_finish_date AS [Backup Finish Date], bmf.physical_device_name AS [Backup Location], 
    bmf.physical_block_size,  bs.last_valid_restore_time
    FROM msdb.dbo.backupset AS bs WITH (NOLOCK)
    INNER JOIN msdb.dbo.backupmediafamily AS bmf WITH (NOLOCK)
    ON bs.media_set_id = bmf.media_set_id  
    WHERE bs.database_name = DB_NAME(DB_ID())
    AND bs.[type] = 'D' -- Change to L if you want Log backups
    ORDER BY bs.backup_finish_date DESC;
"@
}

function Get-TopWaits {
    return @"
    WITH [Waits] 
    AS (SELECT wait_type, wait_time_ms/ 1000.0 AS [WaitS],
              (wait_time_ms - signal_wait_time_ms) / 1000.0 AS [ResourceS],
               signal_wait_time_ms / 1000.0 AS [SignalS],
               waiting_tasks_count AS [WaitCount],
               100.0 *  wait_time_ms / SUM (wait_time_ms) OVER() AS [Percentage],
               ROW_NUMBER() OVER(ORDER BY wait_time_ms DESC) AS [RowNum]
        FROM sys.dm_os_wait_stats WITH (NOLOCK)
        WHERE [wait_type] NOT IN (
            N'BROKER_EVENTHANDLER', N'BROKER_RECEIVE_WAITFOR', N'BROKER_TASK_STOP',
            N'BROKER_TO_FLUSH', N'BROKER_TRANSMITTER', N'CHECKPOINT_QUEUE',
            N'CHKPT', N'CLR_AUTO_EVENT', N'CLR_MANUAL_EVENT', N'CLR_SEMAPHORE', N'CXCONSUMER',
            N'DBMIRROR_DBM_EVENT', N'DBMIRROR_EVENTS_QUEUE', N'DBMIRROR_WORKER_QUEUE',
            N'DBMIRRORING_CMD', N'DIRTY_PAGE_POLL', N'DISPATCHER_QUEUE_SEMAPHORE',
            N'EXECSYNC', N'FSAGENT', N'FT_IFTS_SCHEDULER_IDLE_WAIT', N'FT_IFTSHC_MUTEX',
            N'HADR_CLUSAPI_CALL', N'HADR_FILESTREAM_IOMGR_IOCOMPLETION', N'HADR_LOGCAPTURE_WAIT', 
            N'HADR_NOTIFICATION_DEQUEUE', N'HADR_TIMER_TASK', N'HADR_WORK_QUEUE',
            N'KSOURCE_WAKEUP', N'LAZYWRITER_SLEEP', N'LOGMGR_QUEUE', 
            N'MEMORY_ALLOCATION_EXT', N'ONDEMAND_TASK_QUEUE',
            N'PARALLEL_REDO_DRAIN_WORKER', N'PARALLEL_REDO_LOG_CACHE', N'PARALLEL_REDO_TRAN_LIST',
            N'PARALLEL_REDO_WORKER_SYNC', N'PARALLEL_REDO_WORKER_WAIT_WORK',
            N'PREEMPTIVE_HADR_LEASE_MECHANISM', N'PREEMPTIVE_SP_SERVER_DIAGNOSTICS',
            N'PREEMPTIVE_OS_LIBRARYOPS', N'PREEMPTIVE_OS_COMOPS', N'PREEMPTIVE_OS_CRYPTOPS',
            N'PREEMPTIVE_OS_PIPEOPS', N'PREEMPTIVE_OS_AUTHENTICATIONOPS',
            N'PREEMPTIVE_OS_GENERICOPS', N'PREEMPTIVE_OS_VERIFYTRUST',
            N'PREEMPTIVE_OS_DELETESECURITYCONTEXT', N'PREEMPTIVE_OS_REPORTEVENT',
            N'PREEMPTIVE_OS_FILEOPS', N'PREEMPTIVE_OS_DEVICEOPS', N'PREEMPTIVE_OS_QUERYREGISTRY',
            N'PREEMPTIVE_OS_WRITEFILE', N'PREEMPTIVE_OS_WRITEFILEGATHER',
            N'PREEMPTIVE_XE_CALLBACKEXECUTE', N'PREEMPTIVE_XE_DISPATCHER',
            N'PREEMPTIVE_XE_GETTARGETSTATE', N'PREEMPTIVE_XE_SESSIONCOMMIT',
            N'PREEMPTIVE_XE_TARGETINIT', N'PREEMPTIVE_XE_TARGETFINALIZE',
            N'POPULATE_LOCK_ORDINALS',
            N'PWAIT_ALL_COMPONENTS_INITIALIZED', N'PWAIT_DIRECTLOGCONSUMER_GETNEXT',
            N'PWAIT_EXTENSIBILITY_CLEANUP_TASK',
            N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP', N'QDS_ASYNC_QUEUE',
            N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP', N'REQUEST_FOR_DEADLOCK_SEARCH',
            N'RESOURCE_QUEUE', N'SERVER_IDLE_CHECK', N'SLEEP_BPOOL_FLUSH', N'SLEEP_DBSTARTUP',
            N'SLEEP_DCOMSTARTUP', N'SLEEP_MASTERDBREADY', N'SLEEP_MASTERMDREADY',
            N'SLEEP_MASTERUPGRADED', N'SLEEP_MSDBSTARTUP', N'SLEEP_SYSTEMTASK', N'SLEEP_TASK',
            N'SLEEP_TEMPDBSTARTUP', N'SNI_HTTP_ACCEPT', N'SOS_WORK_DISPATCHER',
            N'SP_SERVER_DIAGNOSTICS_SLEEP', N'SOS_WORKER_MIGRATION', N'VDI_CLIENT_OTHER',
            N'SQLTRACE_BUFFER_FLUSH', N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP', N'SQLTRACE_WAIT_ENTRIES',
            N'STARTUP_DEPENDENCY_MANAGER',
            N'WAIT_FOR_RESULTS', N'WAITFOR', N'WAITFOR_TASKSHUTDOWN', N'WAIT_XTP_HOST_WAIT',
            N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG', N'WAIT_XTP_CKPT_CLOSE', N'WAIT_XTP_RECOVERY',
            N'XE_BUFFERMGR_ALLPROCESSED_EVENT', N'XE_DISPATCHER_JOIN',
            N'XE_DISPATCHER_WAIT', N'XE_LIVE_TARGET_TVF', N'XE_TIMER_EVENT')
        AND waiting_tasks_count > 0)
    SELECT
        MAX (W1.wait_type) AS [WaitType],
        CAST (MAX (W1.Percentage) AS DECIMAL (5,2)) AS [Wait Percentage],
        CAST ((MAX (W1.WaitS) / MAX (W1.WaitCount)) AS DECIMAL (16,4)) AS [AvgWait_Sec],
        CAST ((MAX (W1.ResourceS) / MAX (W1.WaitCount)) AS DECIMAL (16,4)) AS [AvgRes_Sec],
        CAST ((MAX (W1.SignalS) / MAX (W1.WaitCount)) AS DECIMAL (16,4)) AS [AvgSig_Sec], 
        CAST (MAX (W1.WaitS) AS DECIMAL (16,2)) AS [Wait_Sec],
        CAST (MAX (W1.ResourceS) AS DECIMAL (16,2)) AS [Resource_Sec],
        CAST (MAX (W1.SignalS) AS DECIMAL (16,2)) AS [Signal_Sec],
        MAX (W1.WaitCount) AS [Wait Count],
        CAST (N'https://www.sqlskills.com/help/waits/' + W1.wait_type AS XML) AS [Help/Info URL]
    FROM Waits AS W1
    INNER JOIN Waits AS W2
    ON W2.RowNum <= W1.RowNum
    GROUP BY W1.RowNum, W1.wait_type
    HAVING SUM (W2.Percentage) - MAX (W1.Percentage) < 99 -- percentage threshold;
"@
}
