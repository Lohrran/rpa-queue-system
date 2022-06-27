USE [DATEBASE_NAME]
GO

CREATE TABLE [dbo].[WorkQueueInfo](
	[queue_name] [varchar](50) NOT NULL,
	[queue_key_name] [varchar](50) NOT NULL,
	[max_attempt] [int] NOT NULL,
	[queue_columns] [varchar](max) NULL,
PRIMARY KEY CLUSTERED 
(
	[queue_name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO


CREATE TABLE [dbo].[WorkQueue](
	[item_id] [int] IDENTITY(1,1) NOT NULL,
	[item_state] [varchar](50) NOT NULL,
	[item_key] [varchar](max) NULL,
	[item_status] [varchar](50) NULL,
	[item_priority] [int] NOT NULL,
	[item_attempt] [int] NOT NULL,
	[item_defer_date] [varchar](30) NULL,
	[item_worked_time] [varchar](30) NULL,
	[item_start_date] [varchar](50) NOT NULL,
	[item_end_date] [varchar](50) NULL,
	[item_exception_reason] [varchar](max) NULL,
	[item_queue_name] [varchar](50) NULL,
	[item_data] [varbinary](max) NULL,
	[item_resource_name] [varchar](100) NULL,
PRIMARY KEY CLUSTERED 
(
	[item_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO


CREATE TABLE [dbo].[WorkQueueTask](
	[task_id] [int] IDENTITY(1,1) NOT NULL,
	[task_name] [varchar](100) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[task_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO


CREATE TABLE [dbo].[WorkQueueItemTask](
	[item_id] [int] NOT NULL,
	[task_id] [int] NOT NULL,
	[time_stamp] [varchar](20) NULL
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[WorkQueueItemTask]  WITH CHECK ADD FOREIGN KEY([item_id])
REFERENCES [dbo].[WorkQueue] ([item_id])
GO

ALTER TABLE [dbo].[WorkQueueItemTask]  WITH CHECK ADD FOREIGN KEY([task_id])
REFERENCES [dbo].[WorkQueueTask] ([task_id])
GO



CREATE TABLE [dbo].[WorkQueueEnvironmentLocker](
	[environment_id] [int] IDENTITY(1,1) NOT NULL,
	[environment_name] [varchar](100) NULL,
	[environment_state] [varchar](20) NOT NULL,
	[resource_name] [varchar](20) NULL,
	[last_updated] [varchar](20) NULL
) ON [PRIMARY]
GO
GO


CREATE TABLE [dbo].[WorkQueueExecution](
	[execution_id] [int] IDENTITY(1,1) NOT NULL,
	[execution_state] [varchar](15) NOT NULL,
	[execution_code] [varchar](50) NOT NULL,
	[execution_status] [varchar](50) NULL,
	[execution_queue_name] [varchar](50) NOT NULL,
	[execution_worked_time] [varchar](30) NULL,
	[execution_start_date] [varchar](30) NOT NULL,
	[execution_end_date] [varchar](30) NULL,
	[execution_exception_reason] [varchar](max) NULL,
PRIMARY KEY CLUSTERED 
(
	[execution_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
GO


CREATE TABLE [dbo].[WorkQueueResource](
	[resource_id] [int] IDENTITY(1,1) NOT NULL,
	[execution_id] [int] NULL,
	[resource_state] [varchar](20) NOT NULL,
	[resource_user] [varchar](20) NOT NULL,
	[resource_name] [varchar](50) NOT NULL,
	[resource_status] [varchar](100) NULL,
	[resource_worked_time] [varchar](30) NULL,
	[resource_start_date] [varchar](30) NOT NULL,
	[resource_end_date] [varchar](30) NULL,
	[resource_exception_reason] [varchar](max) NULL,
	[resource_last_update] [varchar](30) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[resource_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE [dbo].[WorkQueueResource]  WITH CHECK ADD FOREIGN KEY([execution_id])
REFERENCES [dbo].[WorkQueueExecution] ([execution_id])
GO

CREATE TABLE [dbo].[WorkQueueHistoric](
	[item_id] [int] NOT NULL,
	[item_state] [varchar](50) NOT NULL,
	[item_key] [varchar](max) NULL,
	[item_status] [varchar](50) NULL,
	[item_priority] [int] NOT NULL,
	[item_attempt] [int] NOT NULL,
	[item_defer_date] [varchar](30) NULL,
	[item_worked_time] [varchar](30) NOT NULL,
	[item_start_date] [varchar](50) NOT NULL,
	[item_end_date] [varchar](50) NOT NULL,
	[item_exception_reason] [varchar](max) NULL,
	[item_queue_name] [varchar](50) NOT NULL,
	[item_data] [varbinary](max) NULL,
	[item_resource_name] [varchar](100) NULL,
PRIMARY KEY CLUSTERED 
(
	[item_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

CREATE TABLE [dbo].[WorkQueueItemTaskHistoric](
	[item_id] [int] NOT NULL,
	[task_id] [int] NOT NULL,
	[time_stamp] [varchar](20) NULL
) ON [PRIMARY]
GO

GO

