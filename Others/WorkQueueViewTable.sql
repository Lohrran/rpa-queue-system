USE [RPA_CONREC]
GO

/****** Object:  Table [dbo].[WorkQueueView]    Script Date: 12/01/2021 05:33:34 p.m. ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[WorkQueueView](
	[queue_name] [varchar](50) NOT NULL,
	[queue_pending_items] [int] NULL,
	[queue_worked_items] [int] NULL,
	[queue_completed_items] [int] NULL,
	[queue_system_exception] [int] NULL,
	[queue_business_exception] [int] NULL,
	[queue_terminated_items] [int] NULL,
	[item_average_work_time] [varchar](100) NULL,
	[queue_total_worked_time] [varchar](100) NULL,
	[queue_last_updated] [varchar](100) NULL,
PRIMARY KEY CLUSTERED 
(
	[queue_name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO


CREATE TABLE [dbo].[WorkQueueDailyView](
	[queue_name] [varchar](50) NOT NULL,
	[queue_date] [date] NOT NULL,
	[queue_pending_items] [int] NULL,
	[queue_worked_items] [int] NULL,
	[queue_completed_items] [int] NULL,
	[queue_system_exception] [int] NULL,
	[queue_business_exception] [int] NULL,
	[queue_terminated_items] [int] NULL,
	[item_average_work_time] [varchar](100) NULL,
	[queue_total_worked_time] [varchar](100) NULL
) ON [PRIMARY]
GO


