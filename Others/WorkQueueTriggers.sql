USE [RPA_CONREC]
GO

/****** Object:  Trigger [dbo].[workqueueview_trigger]    Script Date: 12/01/2021 05:35:50 p.m. ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TRIGGER [dbo].[workqueueview_trigger]
ON [dbo].[WorkQueue]
AFTER INSERT, DELETE, UPDATE
AS
BEGIN
	SET NOCOUNT ON;

	-- UPDATE LAST TIME QUEUE WAS INTERACTED
	UPDATE WorkQueueView
	SET 
		queue_last_updated = CONVERT(VARCHAR, GETDATE(), 20)
	FROM WorkQueueView v
	JOIN
	(
		SELECT
			q.item_queue_name,
			q.item_id
		FROM WorkQueue q
		INNER JOIN 
		(
			inserted 
				FULL
			OUTER JOIN 
			deleted ON 
				inserted.item_id = deleted.item_id
		) ON q.item_id = COALESCE(inserted.item_id, deleted.item_id)
	)w ON w.item_queue_name = v.queue_name

	-- UPDATE ITEMS COUNT
	UPDATE WorkQueueView
	SET 
		queue_pending_items =		CASE WHEN w.pending IS NOT NULL THEN w.pending ELSE 0 END,
		queue_worked_items =		CASE WHEN w.worked IS NOT NULL THEN w.worked ELSE 0 END,
		queue_completed_items =		CASE WHEN w.completed IS NOT NULL THEN w.completed ELSE 0 END,
		queue_system_exception =	CASE WHEN w.system_exception IS NOT NULL THEN w.system_exception ELSE 0 END,
		queue_business_exception =	CASE WHEN w.business_exception IS NOT NULL THEN w.business_exception ELSE 0 END,
		queue_terminated_items =	CASE WHEN w.terminated IS NOT NULL THEN w.terminated ELSE 0 END
	FROM WorkQueueView v
	JOIN
	(
		SELECT 
			item_queue_name, 
			SUM(CASE WHEN item_state = 'Pending' THEN 1 END) AS pending,
			SUM(CASE WHEN item_state <> 'Pending' AND item_state <> 'Locked' THEN 1 END) AS worked,
			SUM(CASE WHEN item_state = 'Completed' THEN 1 END) AS completed,
			SUM(CASE WHEN item_state = 'Terminated' AND item_exception_reason NOT LIKE '%BUSINESS%' THEN 1 END) AS system_exception,
			SUM(CASE WHEN item_state = 'Terminated' AND item_exception_reason LIKE '%BUSINESS%' THEN 1 END) AS business_exception,
			SUM(CASE WHEN item_state = 'Terminated' THEN 1 END) AS terminated
		FROM WorkQueue 
		GROUP BY item_queue_name
	)w ON w.item_queue_name = v.queue_name


	-- UPDATE ITEM AND QUEUE TIME
	UPDATE WorkQueueView
	SET 
		queue_total_worked_time = w.worked_time,
		item_average_work_time = w.item_average_worked_time
	FROM WorkQueueView v
	JOIN
	(
		SELECT 
			item_queue_name,
			CONVERT (VARCHAR (10), CONVERT (VARCHAR, ( SUM (DATEPART (SECOND, [item_worked_time]) + 60 * DATEPART (MINUTE, [item_worked_time]) + 3600 * DATEPART (HOUR, [item_worked_time] ))
				 /3600)) + ':' +
				RIGHT('0'+ CONVERT (VARCHAR, (SUM (DATEPART (SECOND, [item_worked_time]) + 60 * DATEPART (MINUTE, [item_worked_time]) + 3600 *	DATEPART (HOUR, [item_worked_time] )) 
						 % 3600) / 60), 2)	+ ':' +
				RIGHT(CONVERT (VARCHAR, (SUM (DATEPART (SECOND, [item_worked_time]) + 60 * DATEPART (MINUTE, [item_worked_time]) + 3600 * DATEPART (HOUR, [item_worked_time] )) 
					 % 60), 2), 108)
			)  AS worked_time,

			CONVERT (VARCHAR (10), '0'+ CONVERT (VARCHAR, ( SUM (DATEPART (SECOND, [item_worked_time]) + 60 * DATEPART (MINUTE, [item_worked_time]) + 3600 * DATEPART (HOUR, [item_worked_time] ))
				 / COUNT (item_queue_name)/3600)) + ':' +
				RIGHT('0'+ CONVERT (VARCHAR, (SUM (DATEPART (SECOND, [item_worked_time]) + 60 * DATEPART (MINUTE, [item_worked_time]) + 3600 *	DATEPART (HOUR, [item_worked_time] )) 
						/ COUNT (item_queue_name) % 3600) / 60), 2)	+ ':' +
				RIGHT(CONVERT (VARCHAR, (SUM (DATEPART (SECOND, [item_worked_time]) + 60 * DATEPART (MINUTE, [item_worked_time]) + 3600 * DATEPART (HOUR, [item_worked_time] )) 
					/ COUNT (item_queue_name) % 60), 2), 108)
			) AS item_average_worked_time
		FROM WorkQueue 
		WHERE item_state <> 'Pending' AND item_state <> 'Locked'
		GROUP BY item_queue_name
	)w ON w.item_queue_name = v.queue_name
END
GO

ALTER TABLE [dbo].[WorkQueue] DISABLE TRIGGER [workqueueview_trigger]
GO



CREATE TRIGGER [dbo].[workqueuedailyview_trigger]
ON [dbo].[WorkQueue]
AFTER INSERT, DELETE, UPDATE
AS
BEGIN
	SET NOCOUNT ON;

	-- INSERT NEW DAYS	
	BEGIN TRANSACTION [INSERTNEWDAYS]
		BEGIN TRY
			INSERT INTO WorkQueueDailyView (queue_name, queue_date)
				SELECT DISTINCT item_queue_name, CAST (item_start_date AS DATE) AS item_start_day_date FROM WorkQueue
					EXCEPT SELECT queue_name, queue_date FROM WorkQueueDailyView
				
			COMMIT TRANSACTION [INSERTNEWDAYS]
		END TRY
		BEGIN CATCH 
				RAISERROR (21,-1,-1, 'workqueuedailyview_trigger'); 
				ROLLBACK TRANSACTION [INSERTNEWDAYS]
		END CATCH
	
	BEGIN TRANSACTION [UPDATEVOLUMETRY]
		BEGIN TRY
			-- GET WORKED ITEMS
			UPDATE WorkQueueDailyView
			SET 
				queue_pending_items =		CASE WHEN w.pending IS NOT NULL THEN w.pending ELSE 0 END,
				queue_worked_items =		CASE WHEN w.worked IS NOT NULL THEN w.worked ELSE 0 END,
				queue_completed_items =		CASE WHEN w.completed IS NOT NULL THEN w.completed ELSE 0 END,
				queue_system_exception =	CASE WHEN w.system_exception IS NOT NULL THEN w.system_exception ELSE 0 END,
				queue_business_exception =	CASE WHEN w.business_exception IS NOT NULL THEN w.business_exception ELSE 0 END,
				queue_terminated_items =	CASE WHEN w.terminated IS NOT NULL THEN w.terminated ELSE 0 END
			FROM WorkQueueDailyView v
			JOIN
			(
				SELECT 
					CAST (item_start_date AS DATE) AS item_start_day_date, 
					SUM(CASE WHEN item_state = 'Pending' THEN 1 END) AS pending,
					SUM(CASE WHEN item_state <> 'Pending' AND item_state <> 'Locked' THEN 1 END) AS worked,
					SUM(CASE WHEN item_state = 'Completed' THEN 1 END) AS completed,
					SUM(CASE WHEN item_state = 'Terminated' AND item_exception_reason NOT LIKE '%BUSINESS%' THEN 1 END) AS system_exception,
					SUM(CASE WHEN item_state = 'Terminated' AND item_exception_reason LIKE '%BUSINESS%' THEN 1 END) AS business_exception,
					SUM(CASE WHEN item_state = 'Terminated' THEN 1 END) AS terminated
				FROM WorkQueue 
				GROUP BY CAST (item_start_date AS DATE)
			)w ON w.item_start_day_date = v.queue_date


			-- UPDATE ITEM AND QUEUE TIME
			UPDATE WorkQueueDailyView
			SET 
				queue_total_worked_time = w.worked_time,
				item_average_work_time = w.item_average_worked_time
			FROM WorkQueueDailyView v
			JOIN
			(
				SELECT 
					CAST (item_start_date AS DATE) AS item_start_day_date,
					CONVERT (VARCHAR (10), CONVERT (VARCHAR, ( SUM (DATEPART (SECOND, [item_worked_time]) + 60 * DATEPART (MINUTE, [item_worked_time]) + 3600 * DATEPART (HOUR, [item_worked_time] ))
							/3600)) + ':' +
						RIGHT('0'+ CONVERT (VARCHAR, (SUM (DATEPART (SECOND, [item_worked_time]) + 60 * DATEPART (MINUTE, [item_worked_time]) + 3600 *	DATEPART (HOUR, [item_worked_time] )) 
									% 3600) / 60), 2)	+ ':' +
						RIGHT(CONVERT (VARCHAR, (SUM (DATEPART (SECOND, [item_worked_time]) + 60 * DATEPART (MINUTE, [item_worked_time]) + 3600 * DATEPART (HOUR, [item_worked_time] )) 
								% 60), 2), 108)
					) AS worked_time,

					CONVERT (VARCHAR (10), '0'+ CONVERT (VARCHAR, ( SUM (DATEPART (SECOND, [item_worked_time]) + 60 * DATEPART (MINUTE, [item_worked_time]) + 3600 * DATEPART (HOUR, [item_worked_time] ))
							/ COUNT (item_queue_name)/3600)) + ':' +
						RIGHT('0'+ CONVERT (VARCHAR, (SUM (DATEPART (SECOND, [item_worked_time]) + 60 * DATEPART (MINUTE, [item_worked_time]) + 3600 *	DATEPART (HOUR, [item_worked_time] )) 
								/ COUNT (item_queue_name) % 3600) / 60), 2)	+ ':' +
						RIGHT(CONVERT (VARCHAR, (SUM (DATEPART (SECOND, [item_worked_time]) + 60 * DATEPART (MINUTE, [item_worked_time]) + 3600 * DATEPART (HOUR, [item_worked_time] )) 
							/ COUNT (item_queue_name) % 60), 2), 108)
					) AS item_average_worked_time
				FROM WorkQueue 
				WHERE item_state <> 'Pending' AND item_state <> 'Locked'
				GROUP BY CAST (item_start_date AS DATE)
			)w ON w.item_start_day_date = v.queue_date
			
			COMMIT TRANSACTION [UPDATEVOLUMETRY]

		END TRY
		BEGIN CATCH 
				ROLLBACK TRANSACTION [UPDATEVOLUMETRY]
				RAISERROR (22,-1,-1, 'workqueuedailyview_trigger');  
		END CATCH


	BEGIN TRANSACTION [DELETEEMPTYDAYS]
		BEGIN TRY
			DELETE FROM WorkQueueDailyView
				WHERE queue_pending_items = 0 AND queue_worked_items = 0 AND 
						queue_completed_items = 0 AND queue_system_exception = 0 AND
							queue_business_exception = 0 AND queue_terminated_items = 0
			COMMIT TRANSACTION [DELETEEMPTYDAYS]
		END TRY
		BEGIN CATCH 
				RAISERROR (23,-1,-1, 'workqueuedailyview_trigger'); 
				ROLLBACK TRANSACTION [DELETEEMPTYDAYS]
		END CATCH
		
END
GO

ALTER TABLE [dbo].[WorkQueue] DISABLE TRIGGER [workqueuedailyview_trigger]
GO


