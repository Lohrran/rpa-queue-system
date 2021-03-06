USE [DATABASE_NAME]
GO
/****** Object:  StoredProcedure [dbo].[sp_add_item_task]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_Encrypt]
(
	@Texto VARCHAR(MAX),
	@Resultado VARBINARY(MAX) OUTPUT
)
AS
BEGIN

	OPEN SYMMETRIC KEY SymKey_[KEYNAME]
	DECRYPTION BY CERTIFICATE Cer_[CERTIFICATE_NAME]; 

	SET @Resultado = EncryptByKey( KEY_GUID('SymKey_[KEYNAME]'), @Texto )
END
GO

CREATE PROCEDURE [dbo].[sp_add_item_task]
	@id INT,
	@new_task VARCHAR (100)
AS
BEGIN
	DECLARE @task INT
	
	IF LTRIM (RTRIM (@new_task)) <> '' BEGIN
		IF @new_task NOT IN (SELECT task_name FROM WorkQueueTask) BEGIN
			INSERT INTO WorkQueueTask VALUES (@new_task)
		END

		SET @task = (SELECT task_id FROM WorkQueueTask WHERE task_name = @new_task)
		IF (SELECT COUNT (*) FROM WorkQueueItemTask WHERE item_id = @id and task_id = @task) = 0   BEGIN
			INSERT INTO WorkQueueItemTask VALUES (@id, @task,  CONVERT(VARCHAR, GETDATE(), 20))
		END
	END
END
GO
/****** Object:  StoredProcedure [dbo].[sp_clean_up_queue]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_clean_up_queue]
	@machine_name VARCHAR (50)
AS
BEGIN
	-- CLEAN UP LOCKED ITEMS
	UPDATE WorkQueue
	SET item_state = 'Pending',
	item_worked_time = '',
	item_exception_reason = 'Item was cleaned up because unexpected exception'
	WHERE item_state = 'Locked'
	AND item_resource_name = @machine_name
END
GO
/****** Object:  StoredProcedure [dbo].[sp_count_item_pending]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_count_item_pending]
    @queue_name VARCHAR (50),
	@count INT OUTPUT
AS
BEGIN
	SET @count = (
		SELECT COUNT (item_id) AS pending_items
		FROM WorkQueue
		WHERE item_queue_name = @queue_name
		AND item_state = 'Pending'
)
END
GO
/****** Object:  StoredProcedure [dbo].[sp_count_item_pending_by_resource_name]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_count_item_pending_by_resource_name]
    @queue_name VARCHAR (50),
	@machine_name VARCHAR (50),
	@count INT OUTPUT
AS
BEGIN
	SET @count = (
		SELECT COUNT (item_id) AS pending_items
		FROM WorkQueue
		WHERE item_queue_name = @queue_name
		AND item_state = 'Pending'
		AND item_resource_name = @machine_name
)
END
GO
/****** Object:  StoredProcedure [dbo].[sp_create_item_attempt]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_create_item_attempt]
       @id INT,
	   @attempt INT OUTPUT,
	   @new_id VARCHAR (MAX) OUTPUT
AS
BEGIN

	DECLARE @pos INT
	DECLARE @len INT
	DECLARE @value VARCHAR(MAX)
	DECLARE @item_tasks VARCHAR(MAX)

	DECLARE @get_id table (id_temp INT) --TABLE VAR TO GET INSERTED ID

	BEGIN TRANSACTION [CREATEITEMATTEMPT]
		BEGIN TRY
			-- CREATE ATTEMPT
			INSERT INTO WorkQueue
			(
				item_state,
				item_key,
				item_status,
				item_priority,
				item_attempt,
				item_defer_date,
				item_worked_time,
				item_start_date,
				item_end_date,
				item_exception_reason,
				item_queue_name,
				item_data,
				item_resource_name
			)OUTPUT inserted.item_id INTO @get_id
			SELECT 'Pending', w.item_key, w.item_status, w.item_priority, w.item_attempt + 1, w.item_defer_date,'', w.item_start_date, 
					'', '', w.item_queue_name, w.item_data, w.item_resource_name
			FROM WorkQueue w
				JOIN WorkQueueInfo i
				ON w.item_queue_name = i.queue_name
			WHERE w.item_id = @id AND item_attempt < i.max_attempt AND w.item_state = 'Terminated'

			-- GET NEW ITEM ID
			SET @new_id = (SELECT * FROM @get_id)

			
			IF (@new_id IS NOT NULL)BEGIN
				-- ADD TASK
				INSERT INTO WorkQueueItemTask (item_id, task_id)
					SELECT @new_id AS 'new_id', task_id FROM WorkQueueItemTask
				WHERE item_id = @id
	
				-- GET ATTEMPT
				SET @attempt =
				(
					SELECT item_attempt FROM WorkQueue
					WHERE item_id = @new_id
				)
			END
			COMMIT TRANSACTION [CREATEITEMATTEMPT]
		END TRY
		BEGIN CATCH
			DECLARE @error_message VARCHAR (MAX) 
			DECLARE @error_severity INT
			DECLARE @error_state INT

			SELECT 
				@error_message  = ERROR_MESSAGE() + ' ' + ERROR_LINE(),
				@error_severity = ERROR_SEVERITY(),
				@error_state  = ERROR_STATE()

			RAISERROR(@error_message, @error_severity, @error_state)

			ROLLBACK TRANSACTION [CREATEITEMATTEMPT]
		END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[sp_display_business_queue_data]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_display_business_queue_data]
	@queue_name VARCHAR(50)
AS
BEGIN
	-- LOCAL VARIABLES
	DECLARE @columns NVARCHAR(MAX)
	DECLARE @query NVARCHAR(MAX)

	OPEN SYMMETRIC KEY SymKey_[KEYNAME]
	DECRYPTION BY CERTIFICATE Cer_[CERTIFICATE_NAME]; 

	SET @columns =
	(
		SELECT DISTINCT 
			',CAST(DecryptByKey(item_data) AS XML).value(''(/Data/row/' + A.cf.value('local-name(.)','nvarchar(max)') + ')[1]'',''nvarchar(max)'') AS ' /* Column Values */
			+  A.cf.value('local-name(.)','nvarchar(max)')-- Column Name
		FROM WorkQueue
		CROSS APPLY (
			SELECT CAST(
				DecryptByKey(item_data) AS XML
			) AS realxml
		) s -- Convert VARCHAR to XML
		CROSS APPLY s.realxml.nodes('/Data/row/*') AS A(cf)  
		WHERE item_queue_name = @queue_name
		FOR XML PATH('')
	);

	SET @columns = Stuff(@columns, 1, 1, '')

	SET @query =
	'SELECT item_id, '
	+ @columns +
	' FROM WorkQueue WHERE item_queue_name = ' + '''' + @queue_name + ''''

	EXEC(@query)
END
GO
/****** Object:  StoredProcedure [dbo].[sp_display_item_business_data]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_display_item_business_data]
	@id INT
AS
BEGIN
	-- LOCAL VARIABLES
	DECLARE @columns NVARCHAR(MAX)
	DECLARE @query NVARCHAR(MAX)

	OPEN SYMMETRIC KEY SymKey_[KEYNAME]
	DECRYPTION BY CERTIFICATE Cer_[CERTIFICATE_NAME]; 

	SET @columns =
	(
		SELECT DISTINCT 
			',CAST(DecryptByKey(item_data) AS XML).value(''(/Data/row/' + A.cf.value('local-name(.)','nvarchar(max)') + ')[1]'',''nvarchar(max)'') AS ' /* Column Values */
			+  A.cf.value('local-name(.)','nvarchar(max)')-- Column Name
		FROM WorkQueue
		CROSS APPLY (
			SELECT CAST(
				DecryptByKey(item_data) AS XML
			) AS realxml
		) s -- Convert VARCHAR to XML
		CROSS APPLY s.realxml.nodes('/Data/row/*') AS A(cf)  
		WHERE item_id = @id
		FOR XML PATH('')
	);

	SET @columns = Stuff(@columns, 1, 1, '')

	SET @query =
	'SELECT item_id, '
	+ @columns +
	' FROM WorkQueue WHERE item_id = ' + CONVERT(VARCHAR (MAX), @id)

	EXEC(@query)
END
GO
/****** Object:  StoredProcedure [dbo].[sp_display_technical_item_data]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_display_technical_item_data]
	@id INT
AS
BEGIN
 	
	-- DISPLAY TAGS WITH TECHNICAL QUEUE
	SELECT
		w.item_id,
		w.item_state,
		w.item_key,
		w.item_status,
		w.item_priority,

		STUFF ((
			SELECT ';' + t.task_name
			FROM WorkQueueTask t
			JOIN WorkQueueItemTask i
				ON i.task_id = t.task_id AND i.item_id = w.item_id
			FOR XML PATH('')), 1, 1, ''
		) AS 'item_task',

		w.item_attempt,
		w.item_defer_date,
		w.item_worked_time,
		w.item_start_date,
		w.item_end_date,
		w.item_exception_reason,
		w.item_queue_name,
		w.item_data,
		w.item_resource_name
	FROM WorkQueue w
	WHERE w.item_id = @id
END
GO
/****** Object:  StoredProcedure [dbo].[sp_display_technical_queue_data]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_display_technical_queue_data]
	@queue_name VARCHAR (50)
AS
BEGIN
 	
	-- DISPLAY TAGS WITH TECHNICAL QUEUE
	SELECT
		w.item_id,
		w.item_state,
		w.item_key,
		w.item_status,
		w.item_priority,

		STUFF ((
			SELECT '; ' + t.task_name
			FROM WorkQueueTask t
			JOIN WorkQueueItemTask i
				ON i.task_id = t.task_id AND i.item_id = w.item_id
			FOR XML PATH('')), 1, 1, ''
		) AS 'item_task',

		w.item_attempt,
		w.item_defer_date,
		w.item_worked_time,
		w.item_start_date,
		w.item_end_date,
		w.item_exception_reason,
		w.item_queue_name,
		w.item_data,
		w.item_resource_name
	FROM WorkQueue w
	WHERE w.item_queue_name = @queue_name
END
GO
/****** Object:  StoredProcedure [dbo].[sp_fill_item_empty_row]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_fill_item_empty_row]
	@queue_name VARCHAR (100),
	@state VARCHAR (100),
	@column_name VARCHAR (100),
	@row_value VARCHAR (MAX)
AS
BEGIN
	DECLARE @xml XML

	OPEN SYMMETRIC KEY SymKey_[KEYNAME]
	DECRYPTION BY CERTIFICATE Cer_[CERTIFICATE_NAME]; 

	CREATE TABLE #temp_xml_table (id int, xml_values XML)

	INSERT INTO #temp_xml_table (id, xml_values)
		SELECT 
			item_id, 
			CAST (DecryptByKey(item_data) AS XML)
		FROM WorkQueue
	WHERE item_state = @state 
	AND item_queue_name = @queue_name

	UPDATE #temp_xml_table
	SET xml_values.modify('replace value of (/Data/row/*[local-name() = sql:variable("@column_name")]/text())[1] with sql:variable("@row_value")')


	UPDATE WorkQueue
		SET item_data = EncryptByKey( KEY_GUID('SymKey_[KEYNAME]'), '<?xml version="1.0" encoding="iso-8859-1"?>' + CAST (t.xml_values AS VARCHAR (MAX)))
	FROM WorkQueue w
	JOIN
	(
		SELECT * FROM #temp_xml_table
	) t ON t.id = w.item_id
	WHERE DecryptByKey(CAST (item_data AS VARCHAR (MAX))) 
	LIKE '%<' + @column_name + '>NULL</' + @column_name + '>%' OR item_data LIKE '%<' + @column_name + '></' + @column_name + '>%'

	DROP TABLE #temp_xml_table
END
GO
/****** Object:  StoredProcedure [dbo].[sp_get_completed_items]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_get_completed_items]
    @queue_name VARCHAR (50),
	@start_date VARCHAR (30),
	@end_date VARCHAR (30)
AS
BEGIN
		SELECT 
		w.item_state,  
		w.item_status, 
		STUFF ((
			SELECT ';' + t.task_name
			FROM WorkQueueTask t
			JOIN WorkQueueItemTask i
				ON i.task_id = t.task_id AND i.item_id = w.item_id
			FOR XML PATH('')), 1, 1, ''
		) AS 'item_task', 
		w.item_attempt,
		w.item_worked_time,
		w.item_start_date, w.item_end_date,
		w.item_exception_reason,
		w.item_resource_name 
		FROM WorkQueue w
		WHERE w.item_state = 'Completed' 
		AND w.item_queue_name =  @queue_name 
		AND w.item_start_date BETWEEN  @start_date  AND  @end_date 
END
GO
/****** Object:  StoredProcedure [dbo].[sp_get_item_attempt]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_get_item_attempt]
	@id INT,
	@attempt INT OUTPUT
AS
BEGIN
	SET @attempt = (
		SELECT item_attempt FROM WorkQueue WHERE item_id = @id
	)
END
GO
/****** Object:  StoredProcedure [dbo].[sp_get_item_data]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_get_item_data]
	@queue_name VARCHAR(50),
	@id INT,
	@columns_name VARCHAR (MAX),
	@row_values VARCHAR (MAX) OUTPUT
AS
BEGIN
	DECLARE @pos INT
	DECLARE @len INT
	DECLARE @value varchar(MAX)

	SET @pos = 0
	SET @len = 0

	OPEN SYMMETRIC KEY SymKey_[KEYNAME]
	DECRYPTION BY CERTIFICATE Cer_[CERTIFICATE_NAME];


	-- VALIDATE LAST CHARACTER FROM STRING IS DIVIDER IF NOT CONCAT DIVIDER
	IF RIGHT(@columns_name, 1) NOT IN (';') BEGIN
		SET @columns_name = @columns_name + ';'
	END


	WHILE CHARINDEX(';', @columns_name, @pos + 1) > 0
	BEGIN
		set @len = CHARINDEX(';', @columns_name, @pos + 1) - @pos
		set @value = SUBSTRING(@columns_name, @pos, @len)

		SET @row_values = CONCAT(
			@row_values,
			(
				SELECT CAST(DecryptByKey(item_data) AS XML).value('(/Data/row/*[local-name() = sql:variable("@value")]/text())[1]','nvarchar(max)') AS queue_value 
				FROM WorkQueue
				WHERE item_id = @id
			),
			';'
		)
		set @pos = CHARINDEX(';', @columns_name, @pos + @len) +1
	END

	SET @row_values = SUBSTRING(@row_values, 1, (LEN(@row_values) - 1))
END
GO
/****** Object:  StoredProcedure [dbo].[sp_get_item_log_values]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_get_item_log_values]
	@id INT
AS
BEGIN
	-- GET VALUES TO LOG
		SELECT
		w.item_key,
		w.item_state, 
		 STUFF ((
			SELECT '; ' + t.task_name
			FROM WorkQueueTask t
			JOIN WorkQueueItemTask i
				ON i.task_id = t.task_id AND i.item_id = w.item_id
			FOR XML PATH('')), 1, 1, ''
		) AS 'item_task', 
		w.item_status, 
		w.item_start_date, 
		w.item_end_date, 
		w.item_queue_name, 
		w.item_exception_reason 
	FROM WorkQueue w
	WHERE w.item_id = @id
END
GO
/****** Object:  StoredProcedure [dbo].[sp_get_item_priority]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_get_item_priority]
	@id INT,
	@priority INT OUTPUT
AS
BEGIN
	-- GET ITEM PRIORITY
	SET @priority = (SELECT item_priority FROM WorkQueue WHERE item_id = @id)
END
GO
/****** Object:  StoredProcedure [dbo].[sp_get_item_status]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_get_item_status]
	@id INT,
	@status VARCHAR (100) OUTPUT
AS
BEGIN
	-- GET ITEM STATUS
	SET @status = (SELECT item_status FROM WorkQueue WHERE item_id = @id)
END
GO
/****** Object:  StoredProcedure [dbo].[sp_get_item_task]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_get_item_task]
	@id INT,
	@task VARCHAR (MAX) OUTPUT
AS
BEGIN
	-- GET ITEM TASK
	SET @task = (
		SELECT
			STUFF ((
				SELECT ';' + t.task_name
				FROM WorkQueueTask t
				JOIN WorkQueueItemTask i
					ON i.task_id = t.task_id AND i.item_id = w.item_id
				FOR XML PATH('')), 1, 1, ''
			) AS 'item_task'
			FROM WorkQueue w
		WHERE w.item_id = @id
	)
END
GO

/****** Object:  StoredProcedure [dbo].[sp_get_max_attempt]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_get_max_attempt]
       @queue_name VARCHAR (50),
	   @max_attempt INT OUTPUT
AS
BEGIN
	SET @max_attempt = (
		SELECT max_attempt FROM WorkQueueInfo
		WHERE queue_name = @queue_name
		)
END
GO
/****** Object:  StoredProcedure [dbo].[sp_get_next_item]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_get_next_item]
	@queue_name VARCHAR(50),
	@machine_name VARCHAR (50),

	@id VARCHAR (MAX) OUTPUT,
	@key VARCHAR (50) OUTPUT,
	@task VARCHAR (MAX) OUTPUT
AS
BEGIN
	-- GET NEWST PENDING ITEM
	SET @id = (
		SELECT TOP 1 item_id FROM WorkQueue
			WHERE item_state = 'Pending'
			AND item_queue_name = @queue_name
			AND item_resource_name = @machine_name
			AND item_priority in (
				SELECT MAX (item_priority) FROM WorkQueue 
				WHERE item_state = 'Pending' 
				AND item_queue_name = @queue_name
			) 
			AND (item_defer_date <= CONVERT(VARCHAR, GETDATE(), 20) OR item_defer_date = '')
			ORDER BY item_id ASC
	)

	-- UPDATE ITEM STATE
	UPDATE WorkQueue 
	SET item_state = 'Locked', 
	item_worked_time = CONVERT(VARCHAR, GETDATE(), 20),
	item_resource_name = @machine_name
	WHERE item_id = @id

	-- GET LOCKED ITEM KEY
	SET @key = (SELECT item_key FROM WorkQueue
	WHERE item_state = 'Locked'
	AND item_queue_name = @queue_name
	AND item_resource_name = @machine_name
	AND item_id = @id)

	-- GET LOCKED ITEM TASK
	SET @task = (
		SELECT
			STUFF ((
				SELECT ';' + t.task_name
				FROM WorkQueueTask t
				JOIN WorkQueueItemTask i
					ON i.task_id = t.task_id AND i.item_id = w.item_id
				FOR XML PATH('')), 1, 1, ''
			) AS 'item_task'
			FROM WorkQueue w
		WHERE w.item_id = @id
	)
END
GO
/****** Object:  StoredProcedure [dbo].[sp_get_next_item_filter_by_task]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--DROP PROCEDURE sp_get_next_item_filter_by_task
------------------------------------------------------------------------------------------------------------------------------------------------------------

---------- GET NEXT ITEM FILTER BY TASK ----------
CREATE PROCEDURE [dbo].[sp_get_next_item_filter_by_task]
	@queue_name VARCHAR (50),
	@machine_name VARCHAR (50),
	@input_task VARCHAR (MAX),

	@id VARCHAR (MAX) OUTPUT,
	@key VARCHAR (50) OUTPUT,
	@task VARCHAR (MAX) OUTPUT
AS
BEGIN
	DECLARE @today_date VARCHAR(MAX)
	
	DECLARE @pos INT
	DECLARE @len INT
	DECLARE @value varchar(MAX)

	SET @pos = 0
	SET @len = 0

	SET @today_date = CONVERT(VARCHAR(MAX), GETDATE(), 20) 

	-- CREATE TABLE TO FILTER TASKS
	IF OBJECT_ID ('tempdb..#ontasks') IS NOT NULL DROP TABLE #ontasks

	CREATE TABLE #ontasks (task_name VARCHAR (100))

	-- VALIDATE LAST CHARACTER FROM STRING IS DIVIDER IF NOT CONCAT DIVIDER
	IF RIGHT(@input_task, 1) NOT IN (';') BEGIN
		SET @input_task = @input_task + ';'
	END

	WHILE CHARINDEX(';', @input_task, @pos + 1) > 0
	BEGIN
		SET @len = CHARINDEX(';', @input_task, @pos + 1) - @pos
		SET @value = SUBSTRING(@input_task, @pos, @len)
		
		EXEC ('INSERT INTO #ontasks VALUES (''' + @value + ''')')

		SET @pos = CHARINDEX(';', @input_task, @pos + @len) +1
	END

	-- GET NEWST PENDING ITEM
	SET @id = (
			SELECT TOP 1 wq.item_id
			FROM (
				SELECT TOP 1 w.item_id, 
					COUNT (t.task_name) AS encounter, 
					MAX(w.item_priority) priority_max
				FROM WorkQueue w
					JOIN WorkQueueItemTask i 
					ON i.item_id = w.item_id
					JOIN WorkQueueTask t
					ON t.task_id = i.task_id

				WHERE w.item_queue_name = @queue_name 
				AND w.item_resource_name = @machine_name
				AND w.item_state = 'Pending'	
				AND t.task_name IN (SELECT task_name FROM #ontasks)
				AND ((SELECT CONVERT(DATETIME, w.item_defer_date)) < (SELECT CONVERT(DATETIME,@today_date,20)) OR w.item_defer_date = '')
			
				GROUP BY w.item_id
				ORDER BY COUNT (t.task_name) DESC, MAX(w.item_priority) DESC

			) AS wq
	)

	DROP TABLE #ontasks

	-- UPDATE ITEM STATE
	UPDATE WorkQueue 
	SET item_state = 'Locked', 
	item_worked_time = CONVERT(VARCHAR, GETDATE(), 20),
	item_resource_name = @machine_name
	WHERE item_id = @id

	-- GET LOCKED ITEM KEY
	SET @key = (SELECT item_key FROM WorkQueue
	WHERE item_state = 'Locked'
	AND item_queue_name = @queue_name
	AND item_resource_name = @machine_name
	AND item_id = @id)

	-- GET LOCKED ITEM TASK
	SET @task = (
		SELECT
			STUFF ((
				SELECT ';' + t.task_name
				FROM WorkQueueTask t
				JOIN WorkQueueItemTask i
					ON i.task_id = t.task_id AND i.item_id = w.item_id
				FOR XML PATH('')), 1, 1, ''
			) AS 'item_task'
			FROM WorkQueue w
		WHERE w.item_id = @id
	)

END
GO
/****** Object:  StoredProcedure [dbo].[sp_get_report_data]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_get_report_data]
	@queue_name VARCHAR (50),
	@start_date VARCHAR (50),
	@end_date VARCHAR (50)
AS
BEGIN
	-- LOCAL VARIABLES
	DECLARE @columns NVARCHAR(MAX)
	DECLARE @query NVARCHAR(MAX)

	OPEN SYMMETRIC KEY SymKey_[KEYNAME]
	DECRYPTION BY CERTIFICATE Cer_[CERTIFICATE_NAME]; 

	SET @columns =
	(
		SELECT DISTINCT 
			',CAST(DecryptByKey(item_data) AS XML).value(''(/Data/row/' + A.cf.value('local-name(.)','nvarchar(max)') + ')[1]'',''nvarchar(max)'') AS ' /* Column Values */
			+  A.cf.value('local-name(.)','nvarchar(max)')-- Column Name
		FROM WorkQueue
		CROSS APPLY (
			SELECT CAST(
				DecryptByKey(item_data) AS XML
			) AS realxml
		) s -- Convert VARCHAR to XML
		CROSS APPLY s.realxml.nodes('/Data/row/*') AS A(cf)  
		WHERE item_queue_name = @queue_name
		FOR XML PATH('')
	);

	SET @columns = Stuff(@columns, 1, 1, '')

	SET @query =
	'SELECT w.item_id, ' +
	' w.item_state, ' + 
	' w.item_key, ' +
	' w.item_status, ' +
	' STUFF ((
			SELECT ''; '' + t.task_name
			FROM WorkQueueTask t
			JOIN WorkQueueItemTask i
				ON i.task_id = t.task_id AND i.item_id = w.item_id
			FOR XML PATH('''')), 1, 1, ''''
		) AS ''item_task'', ' +
	@columns +
	', w.item_attempt, ' + 
	' w.item_worked_time,' +
	' w.item_start_date, w.item_end_date,' +
	' w.item_exception_reason,' + 
	' w.item_resource_name' +
	' FROM WorkQueue w WHERE item_queue_name = ' + '''' + @queue_name + '''' +
	' AND CAST (w.item_start_date AS DATETIME) >= ' + 'CAST (''' + @start_date + '''AS DATETIME)'+
	' AND CAST (w.item_end_date AS DATETIME) <= ' + 'CAST (''' + @end_date + '''AS DATETIME)'

	EXEC (@query)
END
GO
/****** Object:  StoredProcedure [dbo].[sp_get_state_items_by_task]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_get_state_items_by_task]
    @queue_name VARCHAR (50),
	@start_date VARCHAR (30),
	@end_date VARCHAR (30),
	@state VARCHAR (30),
	@tasks VARCHAR (MAX)
AS
BEGIN	
	DECLARE @pos INT
	DECLARE @len INT
	DECLARE @value VARCHAR(MAX)
	
	DECLARE @local_tasks VARCHAR(MAX)
	DECLARE @query NVARCHAR (MAX)

	SET @pos = 0
	SET @len = 0


	-- VALIDATE LAST CHARACTER FROM STRING IS DIVIDER IF NOT CONCAT DIVIDER
	IF RIGHT(@tasks, 1) NOT IN (';') BEGIN
		SET @tasks = @tasks + ';'
	END

	WHILE CHARINDEX(';', @tasks, @pos + 1) > 0
	BEGIN
		SET @len = CHARINDEX(';', @tasks, @pos + 1) - @pos
		SET @value = SUBSTRING(@tasks, @pos, @len)
		
		SET @local_tasks =(SELECT(CONCAT(@local_tasks, '''', @value, '''', ','))) --'''' + @value + '''' + ','

		SET @pos = CHARINDEX(';', @tasks, @pos + @len) +1
	END

	IF RIGHT(@local_tasks, 1) IN (',') BEGIN
		SET @local_tasks = (SELECT SUBSTRING (@local_tasks, 1, (LEN(@local_tasks) - 1)))
	END

	SET @query = 
	'SELECT ' + 
	' w.item_id,' +
	' w.item_state,' +  
	' w.item_status,' + 
	' STUFF ((
		SELECT '';'' + t.task_name
		FROM WorkQueueTask t
		JOIN WorkQueueItemTask i
			ON i.task_id = t.task_id AND i.item_id = w.item_id
		FOR XML PATH('''')), 1, 1, ''''
	) AS ''item_task'', ' +
	' w.item_attempt,' +
	' w.item_worked_time,' +
	' w.item_start_date, w.item_end_date,' +
	' w.item_exception_reason,' +
	' w.item_resource_name ' +
	' FROM WorkQueue w ' +
	' JOIN WorkQueueItemTask i ' +
		' ON i.item_id = w.item_id ' +
		' JOIN WorkQueueTask t ' +
		' ON t.task_id = i.task_id ' +
	' WHERE w.item_state =' + '''' + @state + '''' +
	' AND w.item_queue_name =' + '''' + @queue_name + '''' +
	' AND t.task_name IN (' + @local_tasks + ')'
		
	EXEC (@query)
END
GO
/****** Object:  StoredProcedure [dbo].[sp_get_terminated_items]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_get_terminated_items]
    @queue_name VARCHAR (50),
	@start_date VARCHAR (30),
	@end_date VARCHAR (30)
AS
BEGIN
	SELECT 
	w.item_state,  
	w.item_status, 
	STUFF ((
		SELECT ';' + t.task_name
		FROM WorkQueueTask t
		JOIN WorkQueueItemTask i
			ON i.task_id = t.task_id AND i.item_id = w.item_id
		FOR XML PATH('')), 1, 1, ''
	) AS 'item_task', 
	w.item_attempt,
	w.item_worked_time,
	w.item_start_date, w.item_end_date,
	w.item_exception_reason,
	w.item_resource_name 
	FROM WorkQueue w
	WHERE w.item_state = 'Terminated' 
	AND w.item_queue_name =  @queue_name 
	AND w.item_start_date BETWEEN  @start_date  AND  @end_date 
END
GO
/****** Object:  StoredProcedure [dbo].[sp_get_volumetry]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[sp_get_volumetry]
	@queue_name VARCHAR (50),
	@start_date VARCHAR (20),
	@end_date VARCHAR (20)
AS
BEGIN
	SELECT	
		SUM(CASE WHEN item_state <> 'Pending' AND item_state <> 'Locked' THEN 1 END) AS items_worked,
		SUM(CASE WHEN item_state = 'Completed' THEN 1 END) AS items_completed,
		SUM(CASE WHEN item_state = 'Terminated' THEN 1 END) AS items_terminated,
		CONVERT (VARCHAR (10), '0'+ CONVERT (VARCHAR, ( SUM (DATEPART (SECOND, [item_worked_time]) + 60 * DATEPART (MINUTE, [item_worked_time]) + 3600 * DATEPART (HOUR, [item_worked_time] ))
				/ COUNT (item_queue_name)/3600)) + ':' +
			RIGHT('0'+ CONVERT (VARCHAR, (SUM (DATEPART (SECOND, [item_worked_time]) + 60 * DATEPART (MINUTE, [item_worked_time]) + 3600 *	DATEPART (HOUR, [item_worked_time] )) 
					/ COUNT (item_queue_name) % 3600) / 60), 2)	+ ':' +
			RIGHT(CONVERT (VARCHAR, (SUM (DATEPART (SECOND, [item_worked_time]) + 60 * DATEPART (MINUTE, [item_worked_time]) + 3600 * DATEPART (HOUR, [item_worked_time] )) 
				/ COUNT (item_queue_name) % 60), 2), 108)
		) AS item_average_worked_time
	FROM WorkQueue
	WHERE item_queue_name = @queue_name AND
	CAST (item_start_date AS DATETIME) >= CAST (@start_date AS DATETIME) AND 
	CAST (item_start_date AS DATETIME) <=  CAST (@end_date AS DATETIME)
END
GO
/****** Object:  StoredProcedure [dbo].[sp_load_to_queue]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_load_to_queue]
	@queue_name VARCHAR(50),
	@machine_name VARCHAR(100),
	@row VARCHAR (MAX),
	@task VARCHAR (100),
	@status VARCHAR (50),
	@id INT OUTPUT
AS
BEGIN
	-- LOCAL VARIABLES 
	
	DECLARE @key_column_name VARCHAR (MAX)
	DECLARE @query NVARCHAR (MAX)
	DECLARE @xml_data XML
	DECLARE @xml_string VARCHAR (MAX)
	DECLARE @encrypted_data VARBINARY (MAX)

	DECLARE @start_date VARCHAR (50)

	DECLARE @value VARCHAR(MAX)
	DECLARE @table VARCHAR (MAX)
	DECLARE @columns VARCHAR (MAX)
	DECLARE @pos INT
	DECLARE @len INT


	DECLARE @get_id table (id_temp INT) --TABLE VAR TO GET INSERTED ID

	-- CREATE TEMPORARY TABLE
	SET @columns = (SELECT queue_columns FROM WorkQueueInfo WHERE queue_name = @queue_name) + ','

	-- VALIDATE IF LAST CO
	IF RIGHT(@row, 1) IN (',') BEGIN
		SET @row = SUBSTRING(@row, 1, (LEN(@row) - 1))
	END

	SET @pos = 0
	SET @len = 0

	BEGIN TRANSACTION [LOADTOQUEUE]
		BEGIN TRY
			WHILE CHARINDEX(',', @columns, @pos + 1)>0
			BEGIN
				set @len = CHARINDEX(',', @columns, @pos + 1) - @pos
				set @value = SUBSTRING(@columns, @pos, @len)

				SET @table = CONCAT(@table, @value, ' VARCHAR(MAX), ') -- CONCACT COLUMNS

				set @pos = CHARINDEX(',', @columns, @pos + @len) +1
			END

			SET @table = SUBSTRING(@table, 1, (LEN(@table) - 1))

			EXEC ('CREATE TABLE ##temp_table( '+ @table + ' );')


			SET @columns = SUBSTRING(@columns, 1, (LEN(@columns) - 1))


			-- INSERT INTO TEMPORARY TABLE
			EXEC ('INSERT INTO ##temp_table (' + @columns +  ') VALUES (' + @row + ')')


			-- GET VALUE FROM BUSINESS QUEUE ITEM KEY
			SET @key_column_name = (SELECT queue_key_name FROM WorkQueueInfo WHERE queue_name = @queue_name)
			SET @query = 'SELECT @row = ' + @key_column_name + ' FROM ##temp_table'

			EXEC sp_executesql @query, N'@row VARCHAR(MAX) OUTPUT', @value  OUTPUT

			-- TRANSFORM TO XML

			SET @xml_data = (SELECT * FROM ##temp_table FOR XML PATH ('row'), ROOT('Data'))

			SET @xml_string =  CAST (@xml_data AS VARCHAR (MAX))
				SET @xml_string = '<?xml version="1.0" encoding="iso-8859-1"?>' + @xml_string

			EXEC sp_Encrypt @xml_string, @Resultado = @encrypted_data OUTPUT

			DROP TABLE ##temp_table

			-- SET START DATE
			SET @start_date = CONVERT(VARCHAR, GETDATE(), 20) -- EXAMPLE: 2006-12-30 00:38:54

			-- CREATE EMPTY ROW
			INSERT INTO WorkQueue(
				item_state,
				item_key,
				item_status,
				item_priority,
				item_attempt,
				item_defer_date,
				item_worked_time,
				item_start_date,
				item_end_date,
				item_exception_reason,
				item_queue_name,
				item_data,
				item_resource_name
			)OUTPUT inserted.item_id INTO @get_id
			VALUES(	
				'Pending',
				@value,
				@status,
				0,
				0,
				'',
				'',
				@start_date,
				'',
				'',
				@queue_name,
				@encrypted_data,
				@machine_name
			)
			

			SET @id = (SELECT * FROM @get_id)

			SET @pos = 0
			SET @len = 0
			SET @value = ''

			-- VALIDATE IF LAST CO
			IF RIGHT(@task, 1) NOT IN (';') BEGIN
				SET @task = @task + ';'
			END

			WHILE CHARINDEX(';', @task, @pos + 1)>0
				BEGIN
					SET @len = CHARINDEX(';', @task, @pos + 1) - @pos
					SET @value = SUBSTRING(@task, @pos, @len)

					SET @value = LTRIM (@value)
					SET @value = RTRIM (@value)

					EXEC sp_add_item_task @id, @value

					SET @pos = CHARINDEX(';', @task, @pos + @len) +1
				END

			COMMIT TRANSACTION [LOADTOQUEUE]

		END TRY

		BEGIN CATCH		
			DECLARE @error_message VARCHAR (MAX) 
			DECLARE @error_severity INT
			DECLARE @error_state INT

			SELECT 
				@error_message  = ERROR_MESSAGE() + ' ' + ERROR_LINE(),
				@error_severity = ERROR_SEVERITY(),
				@error_state  = ERROR_STATE()

			RAISERROR(@error_message, @error_severity, @error_state)

			ROLLBACK TRANSACTION [LOADTOQUEUE]
		END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[sp_load_to_queue_with_validation]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_load_to_queue_with_validation]
	@queue_name VARCHAR(50),
	@machine_name VARCHAR(100),
	@row VARCHAR (MAX),
	@task VARCHAR (100),
	@status VARCHAR (50),
	@save_item VARCHAR (5),
	@query NVARCHAR(MAX),
	@exception_reason VARCHAR(MAX) OUTPUT
AS
BEGIN
	-- LOCAL VARIABLES 
	DECLARE @id INT

	DECLARE @value VARCHAR(MAX)
	DECLARE @table VARCHAR (MAX)
	DECLARE @columns VARCHAR (MAX)
	DECLARE @pos INT
	DECLARE @len INT

	-- RESET
	SET @exception_reason = ''

	-- CREATE TEMPORARY TABLE
	SET @columns = (SELECT queue_columns FROM WorkQueueInfo WHERE queue_name = @queue_name) + ','

	-- VALIDATE IF LAST CO
	IF RIGHT(@row, 1) IN (',') BEGIN
		SET @row = SUBSTRING(@row, 1, (LEN(@row) - 1))
	END

	SET @pos = 0
	SET @len = 0

	BEGIN TRANSACTION [LOADTOQUEUEWITHVALIDATION]
		BEGIN TRY
			WHILE CHARINDEX(',', @columns, @pos + 1)>0
			BEGIN
				set @len = CHARINDEX(',', @columns, @pos + 1) - @pos
				set @value = SUBSTRING(@columns, @pos, @len)

				SET @table = CONCAT(@table, @value, ' VARCHAR(MAX), ') -- CONCACT COLUMNS

				set @pos = CHARINDEX(',', @columns, @pos + @len) +1
			END

			SET @table = SUBSTRING(@table, 1, (LEN(@table) - 1))

			EXEC ('CREATE TABLE ##table( '+ @table + ' );')


			SET @columns = SUBSTRING(@columns, 1, (LEN(@columns) - 1))
			

			-- INSERT INTO TEMPORARY TABLE
			EXEC ('INSERT INTO ##table (' + @columns +  ') VALUES (' + @row + ')')

			-- BUSINESS VALIDATION
			EXEC sp_executesql @query, N'@exception_reason VARCHAR(MAX) OUTPUT', @exception_reason OUTPUT

			DROP TABLE ##table

			IF (RTRIM(LTRIM(@exception_reason)) = '') BEGIN
				EXEC sp_load_to_queue @queue_name, @machine_name, @row, @task, @status, @id = @id OUTPUT
			END

			ELSE IF (@exception_reason <> '' AND (SELECT UPPER (@save_item)) = 'TRUE') BEGIN
				
				EXEC sp_load_to_queue @queue_name, @machine_name, @row, @task, @status, @id = @id OUTPUT
				
				-- LOCK ITEM
				UPDATE WorkQueue SET item_state = 'Locked' WHERE item_id = @id

				EXEC sp_mark_item_exception @id, @exception_reason
			END

			COMMIT TRANSACTION [LOADTOQUEUEWITHVALIDATION]

		END TRY

		BEGIN CATCH		
			DECLARE @error_message VARCHAR (MAX) 
			DECLARE @error_severity INT
			DECLARE @error_state INT

			SELECT 
				@error_message  = ERROR_MESSAGE() + ' ' + ERROR_LINE(),
				@error_severity = ERROR_SEVERITY(),
				@error_state  = ERROR_STATE()

			RAISERROR(@error_message, @error_severity, @error_state)

			ROLLBACK TRANSACTION [LOADTOQUEUEWITHVALIDATION]
		END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[sp_mark_item_completed]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_mark_item_completed]
	@id INT
AS
BEGIN
	-- LOCAL VARIABLES
	DECLARE @end_date VARCHAR (50)
	DECLARE @time_stamp INT
	DECLARE @worked_time VARCHAR (30)

	-- SET END DATE
	SET @end_date = CONVERT(VARCHAR, GETDATE(), 20) -- Example: 2006-12-30 00:38:54 


	-- SET TIME STAMP IN SECONDS
	SET @time_stamp = (
		SELECT DATEDIFF(SECOND, item_worked_time, GETDATE()) 
		FROM WorkQueue
		WHERE item_id = @id
	)

	SET @worked_time = (
		SELECT RIGHT('0' + CAST(@time_stamp / 3600 AS VARCHAR),2) + ':' +
		RIGHT('0' + CAST((@time_stamp / 60) % 60 AS VARCHAR),2) + ':' +
		RIGHT('0' + CAST(@time_stamp % 60 AS VARCHAR),2)
	)


	-- MARK ITEM AS COMPLETED
	UPDATE WorkQueue
	SET item_state = 'Completed', 
		item_worked_time = @worked_time,
		item_end_date = @end_date
	WHERE item_id = @id
END
GO
/****** Object:  StoredProcedure [dbo].[sp_mark_item_exception]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_mark_item_exception]
    @id INT,
	@exception_reason VARCHAR (MAX)
AS
BEGIN
	-- LOCAL VARIABLES
	DECLARE @end_date VARCHAR (50)
	DECLARE @time_stamp INT
	DECLARE @worked_time VARCHAR (30)

	-- SET END DATE
	SET @end_date = CONVERT(VARCHAR, GETDATE(), 20) --2006-12-30 00:38:54

	
	-- SET TIME STAMP IN SECONDS
	BEGIN TRY
		SET @time_stamp = (
			SELECT DATEDIFF(SECOND, item_worked_time, GETDATE()) 
			FROM WorkQueue
			WHERE item_id = @id
		)
	END TRY
	BEGIN CATCH
		SET @time_stamp = 0
	END CATCH

	SET @worked_time = (
		SELECT RIGHT('0' + CAST(@time_stamp / 3600 AS VARCHAR),2) + ':' +
		RIGHT('0' + CAST((@time_stamp / 60) % 60 AS VARCHAR),2) + ':' +
		RIGHT('0' + CAST(@time_stamp % 60 AS VARCHAR),2)
	)

	-- MARK ITEM AS EXCEPTION
	UPDATE WorkQueue
	SET item_state = 'Terminated', 
		item_worked_time = @worked_time,
		item_end_date = @end_date, 
		item_exception_reason = @exception_reason
	WHERE item_id = @id AND item_state = 'Locked'
END
GO
/****** Object:  StoredProcedure [dbo].[sp_remove_item_task]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_remove_item_task]
	@id INT,
	@task_name VARCHAR (100)
AS
BEGIN
	DECLARE @num_tag INT
	
	BEGIN TRANSACTION [REMOVEITEMTASK]
		IF LTRIM(RTRIM(@task_name)) <> '' BEGIN
			SET @num_tag = (SELECT task_id FROM WorkQueueTask WHERE task_name = @task_name)
			DELETE FROM WorkQueueItemTask WHERE item_id = @id AND task_id = @num_tag
		END
	COMMIT TRANSACTION [REMOVEITEMTASK]

END
GO
/****** Object:  StoredProcedure [dbo].[sp_replace_item_task]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_replace_item_task]
	@id INT,
	@old_task VARCHAR (100),
	@new_task VARCHAR (100)
AS
BEGIN

	IF LTRIM (RTRIM(@old_task)) <> '' BEGIN
		IF LTRIM (RTRIM (@new_task)) <> '' BEGIN
			EXEC sp_remove_item_task @id, @old_task
			EXEC sp_add_item_task @id, @new_task
		END
	END

END
GO
/****** Object:  StoredProcedure [dbo].[sp_set_data]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_set_data]
	@id INT,
	@column VARCHAR (MAX),
	@value VARCHAR(MAX)
AS
BEGIN
	BEGIN TRANSACTION [SETDATA]
		BEGIN TRY
			DECLARE @xml_vble XML
			
			OPEN SYMMETRIC KEY SymKey_[KEYNAME]
			DECRYPTION BY CERTIFICATE Cer_[CERTIFICATE_NAME]; 

			SET @xml_vble = CAST ((SELECT CONVERT (VARCHAR (MAX), DecryptByKey(item_data)) FROM WorkQueue WHERE item_id = @id) AS XML)

				IF LTRIM (RTRIM(@value)) <> '' BEGIN
				SET @xml_vble.modify('replace value of (/Data/row/*[local-name() = sql:variable("@column")]/text())[1] with sql:variable("@value")')
			END

			UPDATE WorkQueue
				SET item_data = EncryptByKey( KEY_GUID('SymKey_[KEYNAME]'), '<?xml version="1.0" encoding="iso-8859-1"?>' + CAST (@xml_vble AS VARCHAR(MAX)))
			WHERE item_id = @id

			COMMIT TRANSACTION [SETDATA]

		END TRY
		BEGIN CATCH		
			DECLARE @error_message VARCHAR (MAX) 
			DECLARE @error_severity INT
			DECLARE @error_state INT

			SELECT 
				@error_message  = ERROR_MESSAGE() + ' ' + ERROR_LINE(),
				@error_severity = ERROR_SEVERITY(),
				@error_state  = ERROR_STATE()

			RAISERROR(@error_message, @error_severity, @error_state)

			ROLLBACK TRANSACTION [SETDATA]
		END CATCH

END
GO
/****** Object:  StoredProcedure [dbo].[sp_unlock_item]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_unlock_item]
	@id INT
AS
BEGIN
	-- UPDATE ITEM STATE
	UPDATE WorkQueue 
	SET item_state = 'Pending',
	item_worked_time = ''
	WHERE item_id = @id
END
GO
/****** Object:  StoredProcedure [dbo].[sp_update_item_defer_date]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_update_item_defer_date]
	@id INT,
	@defer_date VARCHAR (200)
AS
BEGIN
	-- UPDATE ITEM DEFER DATE
	UPDATE WorkQueue 
	SET item_defer_date = @defer_date
	WHERE item_id = @id
END
GO
/****** Object:  StoredProcedure [dbo].[sp_update_item_priority]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_update_item_priority]
	@id INT,
	@priority INT
AS
BEGIN
	-- UPDATE ITEM PRIORITY
	UPDATE WorkQueue 
	SET item_priority = @priority
	WHERE item_id = @id
END
GO
/****** Object:  StoredProcedure [dbo].[sp_update_item_status]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_update_item_status]
	@id INT,
	@status VARCHAR (100)
AS
BEGIN
	-- UPDATE ITEM STATE
	UPDATE WorkQueue 
	SET item_status = @status
	WHERE item_id = @id
END
GO
/****** Object:  StoredProcedure [dbo].[sp_work_queue_balance]    Script Date: 27/11/2020 01:35:42 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_work_queue_balance]

	@machines VARCHAR (MAX),
	@queue_name VARCHAR (50)
AS
BEGIN

	-- LOCAL VARIABLES
	DECLARE @pos INT				
	DECLARE @len INT
	DECLARE @count INT
	DECLARE @amount INT

	DECLARE @machine_name VARCHAR (50)

	SET @amount = (
		SELECT LEN(@machines) - LEN(REPLACE(@machines,',','')) 
		AS Amount
	)

	-- DIVIDE EQUALLY ITEMS TO WORK
	UPDATE WorkQueue
	SET item_resource_name = work.machine_id
	FROM (
		SELECT item_id, NTILE(@amount) OVER (ORDER BY item_id) AS machine_id
		FROM WorkQueue
		WHERE item_queue_name = @queue_name
		AND item_state = 'Pending'
	) work
	JOIN WorkQueue w ON
	w.item_id = work.item_id


	SET @pos = 0
	SET @len = 0
	SET @count = 0

	-- ASSIGN MACHINES TO ITEMS TO WORK
	WHILE CHARINDEX(',', @machines, @pos + 1) > 0
	BEGIN
		SET @len = CHARINDEX(',', @machines, @pos + 1) - @pos
		SET @machine_name = SUBSTRING(@machines, @pos, @len)
    
		SET @count = @count + 1

		--UPDATE ITEMS TO WORK
		UPDATE WorkQueue
		SET item_resource_name = @machine_name
		WHERE item_resource_name = CAST(@count AS VARCHAR (3))
		AND item_queue_name = @queue_name

		SET @pos = CHARINDEX(',', @machines, @pos + @len) + 1
	END
END
GO

USE RPA_CONREC

GO

CREATE PROCEDURE [dbo].[sp_add_new_execution]
	@project_code VARCHAR (10),
	@queue_name VARCHAR (50),
	@status VARCHAR(50),
	@execution_id INT OUTPUT
AS
BEGIN

	DECLARE @start_date VARCHAR (30) = CONVERT(VARCHAR, GETDATE(), 20) 
	DECLARE @get_id table (id_temp INT) --TABLE VAR TO GET INSERTED ID

	SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
	BEGIN TRANSACTION [CREATEEXECUTION]
		BEGIN TRY
			IF @queue_name NOT IN (
				SELECT execution_queue_name FROM WorkQueueExecution 
					WHERE execution_queue_name = @queue_name AND (execution_state = 'Locked' OR execution_state = 'Pending')
					) 
				BEGIN
					INSERT INTO WorkQueueExecution (execution_state, execution_code, execution_status, execution_queue_name, execution_worked_time,execution_start_date, 
						execution_end_date, execution_exception_reason)OUTPUT inserted.execution_id INTO @get_id
							VALUES 
							(
								'Locked', 
								@project_code + CONVERT (VARCHAR (50), FORMAT (CONVERT (DATETIME, @start_date), 'yyyyMMddHHmm')),
								@status,
								@queue_name,
								'',
								@start_date,
								'',
								''
							)
					SET @execution_id = (SELECT * FROM @get_id)
				END
			ELSE
				BEGIN
					SET @execution_id = (
						SELECT TOP 1 execution_id FROM WorkQueueExecution 
						WHERE execution_queue_name = @queue_name AND (execution_state = 'Locked' OR execution_state = 'Pending')
					)
					UPDATE WorkQueueExecution
						SET execution_state = 'Locked'
					WHERE execution_id = @execution_id 
				END
			COMMIT TRANSACTION [CREATEEXECUTION]
		END TRY
		
		BEGIN CATCH		
			DECLARE @error_message VARCHAR (MAX) 
			DECLARE @error_severity INT
			DECLARE @error_state INT

			SELECT 
				@error_message  = ERROR_MESSAGE() + ' ' + ERROR_LINE(),
				@error_severity = ERROR_SEVERITY(),
				@error_state  = ERROR_STATE()

			RAISERROR(@error_message, @error_severity, @error_state)

			ROLLBACK TRANSACTION [CREATEEXECUTION]
		END CATCH
END

GO

CREATE PROCEDURE [dbo].[sp_add_execution_resource]
	@execution_id INT,
	@resource_status VARCHAR (50), 
	@resource_id INT OUTPUT
AS
BEGIN

	DECLARE @start_date VARCHAR (30) = CONVERT(VARCHAR, GETDATE(), 20)
	DECLARE @get_id table (id_temp INT) --TABLE VAR TO GET INSERTED ID

	BEGIN TRANSACTION [ADDRESOURCE]
		BEGIN TRY
			-- CHECK ALREADY EXIST LOCKED ITEM
			IF (SELECT COUNT(resource_id) AS co FROM WorkQueueResource 
					WHERE execution_id = @execution_id AND resource_name = (SELECT HOST_NAME() AS resource_name) 
						AND resource_state = 'Locked') <= 0
			BEGIN
				INSERT INTO WorkQueueResource(execution_id, resource_name, resource_user, resource_state, resource_status, 
					resource_worked_time, resource_start_date, resource_end_date, resource_exception_reason, resource_last_update)
					OUTPUT inserted.resource_id INTO @get_id
						VALUES
						(
							@execution_id,
							(SELECT HOST_NAME() AS resource_name),
							(SELECT RIGHT(SYSTEM_USER, CHARINDEX('\', SYSTEM_USER) - 1) AS resource_user),
							'Locked',
							@resource_status,
							'',
							@start_date,
							'',
							'',
							@start_date
						)
					SET @resource_id = (SELECT * FROM @get_id)
			END

			ELSE BEGIN
				SET @resource_id = (
						SELECT TOP 1 resource_id 
							FROM WorkQueueResource
						WHERE execution_id = @execution_id AND resource_name = (SELECT HOST_NAME() AS resource_name) 
						AND resource_state = 'Locked'
				)
			END

			COMMIT TRANSACTION [ADDRESOURCE]
		END TRY
		
		BEGIN CATCH		
			DECLARE @error_message VARCHAR (MAX) 
			DECLARE @error_severity INT
			DECLARE @error_state INT

			SELECT 
				@error_message  = ERROR_MESSAGE() + ' ' + ERROR_LINE(),
				@error_severity = ERROR_SEVERITY(),
				@error_state  = ERROR_STATE()

			RAISERROR(@error_message, @error_severity, @error_state)

			ROLLBACK TRANSACTION [ADDRESOURCE]
		END CATCH
END
GO

CREATE PROCEDURE [dbo].[sp_clean_up_resources]

AS
BEGIN
	UPDATE WorkQueueResource
		SET resource_state = 'Terminated',

		resource_worked_time = 	RIGHT('0' + CAST(rr.diff / 3600 AS VARCHAR),2) + ':' + 
								RIGHT('0' + CAST((rr.diff / 60) % 60 AS VARCHAR),2) + ':' + 
								RIGHT('0' + CAST(rr.diff % 60 AS VARCHAR),2),

		resource_end_date = CONVERT(VARCHAR, GETDATE(), 20),
		resource_exception_reason = 'Resource had an unexpected exception'
	FROM WorkQueueResource r 
	JOIN
	(
		SELECT resource_id, DATEDIFF(SECOND, resource_start_date, GETDATE()) AS diff 
		FROM WorkQueueResource
	)rr ON rr.resource_id = r.resource_id

	WHERE r.resource_name = (SELECT HOST_NAME() AS resource_name)
	AND (r.resource_state = 'Locked' OR r.resource_state = 'Pending')
END

GO

CREATE PROCEDURE [dbo].[sp_get_execution_resources]
	@execution_id INT,
	@count_resources INT OUTPUT,
	@resources VARCHAR(MAX) OUTPUT,
	@resources_id VARCHAR(MAX) OUTPUT
AS
BEGIN
	SET @count_resources = (
		SELECT COUNT (resource_id) 
			FROM WorkQueueResource
		WHERE execution_id = @execution_id 
	)

	SET @resources = (
		SELECT STUFF ((
			SELECT ';' + resource_name
				FROM WorkQueueResource 
			WHERE execution_id = @execution_id
			ORDER BY resource_id ASC
			FOR XML PATH('')), 1, 1, ''
		)AS resource_name
	)

	SET @resources_id = (
		SELECT STUFF ((
			SELECT ';' + CAST (resource_id AS VARCHAR(MAX))
				FROM WorkQueueResource 
			WHERE execution_id = @execution_id
			ORDER BY resource_id ASC
			FOR XML PATH('')), 1, 1, ''
		)AS resource_name
	)

END

GO

CREATE PROCEDURE [dbo].[sp_get_resource_state]
	@id INT,
	@state VARCHAR (10) OUTPUT
AS
BEGIN
	SET @state = (
		SELECT resource_state FROM WorkQueueResource
		WHERE resource_id = @id
	)
	
END
GO

CREATE PROCEDURE [dbo].[sp_exist_execution_terminated]
	@execution_code VARCHAR (30),
	@count INT
AS
BEGIN
	SET @count = (
		SELECT COUNT(execution_code) AS terminateds FROM WorkQueueExecution
		WHERE execution_code = @execution_code
		AND execution_state = 'Terminated'
	)
END
GO

CREATE PROCEDURE [dbo].[sp_get_execution_code]
	@id INT,
	@execution_code VARCHAR (30) OUTPUT
AS
BEGIN
	SET @execution_code = (
		SELECT execution_code FROM WorkQueueExecution
		WHERE execution_id = @id
	)
END
GO

CREATE PROCEDURE [dbo].[sp_get_execution_dates]
	@id INT,
	@start_date VARCHAR(30) OUTPUT,
	@end_date VARCHAR(30) OUTPUT
AS
BEGIN
	SET @start_date = (
		SELECT execution_start_date FROM WorkQueueExecution
		WHERE execution_id = @id
	)

	SET @end_date = (
		SELECT execution_end_date FROM WorkQueueExecution
		WHERE execution_id = @id
	)
END
GO

CREATE PROCEDURE [dbo].[sp_get_execution_status]
	@execution_id INT,
	@status VARCHAR (50) OUTPUT
AS
BEGIN

	SET @status = (
		SELECT execution_status FROM WorkQueueExecution
		WHERE execution_id = @execution_id
	)

END
GO

CREATE PROCEDURE [dbo].[sp_get_resource_status]
	@id INT,
	@status VARCHAR(MAX) OUTPUT
AS
BEGIN
	
	SET @status = (
		SELECT resource_status FROM WorkQueueResource
		WHERE resource_id = @id
	)
END
GO

CREATE PROCEDURE [dbo].[sp_mark_execution_completed]
	@id INT
AS
BEGIN
	-- LOCAL VARIABLES
	DECLARE @end_date VARCHAR (50)
	DECLARE @time_stamp INT
	DECLARE @worked_time VARCHAR (30)

	-- SET END DATE
	SET @end_date = CONVERT(VARCHAR, GETDATE(), 20) -- Example: 2006-12-30 00:38:54 

	-- SET TIME STAMP IN SECONDS
	SET @time_stamp = (
		SELECT DATEDIFF(SECOND, resource_start_date, GETDATE()) 
		FROM WorkQueueResource
		WHERE resource_id = @id
	)

	SET @worked_time = (
		SELECT RIGHT('0' + CAST(@time_stamp / 3600 AS VARCHAR),2) + ':' +
		RIGHT('0' + CAST((@time_stamp / 60) % 60 AS VARCHAR),2) + ':' +
		RIGHT('0' + CAST(@time_stamp % 60 AS VARCHAR),2)
	)

	-- MARK EXECUTION AS COMPLETED
	UPDATE WorkQueueExecution
	SET execution_state = 'Completed', 
		execution_worked_time = @worked_time,
		execution_end_date = @end_date
	WHERE execution_id = @id
END
GO

CREATE PROCEDURE [dbo].[sp_mark_execution_exception]
    @id INT
AS
BEGIN
	-- LOCAL VARIABLES
	DECLARE @exception_reason VARCHAR (MAX)
	DECLARE @end_date VARCHAR (50) = CONVERT(VARCHAR, GETDATE(), 20) --2006-12-30 00:38:54
	DECLARE @time_stamp INT
	DECLARE @worked_time VARCHAR (30)
	
	-- GET LAST RESOURCE EXCEPTION
	SET @exception_reason = (
		SELECT TOP 1 resource_exception_reason FROM WorkQueueResource
		WHERE execution_id = @id AND resource_state = 'Terminated'
		ORDER BY resource_end_date DESC
	)

	-- SET TIME STAMP IN SECONDS
	SET @time_stamp = (
		SELECT DATEDIFF(SECOND, resource_start_date, GETDATE()) 
		FROM WorkQueueResource
		WHERE resource_id = @id
	)

	SET @worked_time = (
		SELECT RIGHT('0' + CAST(@time_stamp / 3600 AS VARCHAR),2) + ':' +
		RIGHT('0' + CAST((@time_stamp / 60) % 60 AS VARCHAR),2) + ':' +
		RIGHT('0' + CAST(@time_stamp % 60 AS VARCHAR),2)
	)


	-- MARK EXECUTION AS EXCEPTION
	UPDATE WorkQueueExecution
	SET execution_state = 'Terminated', 
		execution_worked_time = @worked_time,
		execution_end_date = @end_date, 
		execution_exception_reason = @exception_reason
	WHERE execution_id = @id


END

GO

CREATE PROCEDURE [dbo].[sp_mark_resource_completed]
	@id INT
AS
BEGIN
	-- LOCAL VARIABLES
	DECLARE @end_date VARCHAR (50)
	DECLARE @time_stamp INT
	DECLARE @worked_time VARCHAR (30)

	-- SET END DATE
	SET @end_date = CONVERT(VARCHAR, GETDATE(), 20) -- Example: 2006-12-30 00:38:54 

	-- SET TIME STAMP IN SECONDS
	SET @time_stamp = (
		SELECT DATEDIFF(SECOND, resource_start_date, GETDATE()) 
		FROM WorkQueueResource
		WHERE resource_id = @id
	)

	SET @worked_time = (
		SELECT RIGHT('0' + CAST(@time_stamp / 3600 AS VARCHAR),2) + ':' +
		RIGHT('0' + CAST((@time_stamp / 60) % 60 AS VARCHAR),2) + ':' +
		RIGHT('0' + CAST(@time_stamp % 60 AS VARCHAR),2)
	)

	-- MARK ITEM AS COMPLETED
	UPDATE WorkQueueResource
	SET resource_state = 'Completed', 
		resource_worked_time = @worked_time,
		resource_last_update = @end_date,
		resource_end_date = @end_date
	WHERE resource_id = @id
END

GO

CREATE PROCEDURE [dbo].[sp_mark_resource_exception]
	@id INT,
	@exception_reason VARCHAR (MAX)
AS
BEGIN
	-- LOCAL VARIABLES
	DECLARE @end_date VARCHAR (50)
	DECLARE @time_stamp INT
	DECLARE @worked_time VARCHAR (30)

	-- SET END DATE
	SET @end_date = CONVERT(VARCHAR, GETDATE(), 20) -- Example: 2006-12-30 00:38:54 

	-- SET TIME STAMP IN SECONDS
	SET @time_stamp = (
		SELECT DATEDIFF(SECOND, resource_start_date, GETDATE()) 
		FROM WorkQueueResource
		WHERE resource_id = @id
	)

	SET @worked_time = (
		SELECT RIGHT('0' + CAST(@time_stamp / 3600 AS VARCHAR),2) + ':' +
		RIGHT('0' + CAST((@time_stamp / 60) % 60 AS VARCHAR),2) + ':' +
		RIGHT('0' + CAST(@time_stamp % 60 AS VARCHAR),2)
	)

	-- MARK ITEM AS TERMINATED
	UPDATE WorkQueueResource
	SET resource_state = 'Terminated', 
		resource_worked_time = @worked_time,
		resource_last_update = @end_date,
		resource_end_date = @end_date,
		resource_exception_reason = @exception_reason
	WHERE resource_id = @id
END


GO

CREATE PROCEDURE [dbo].[sp_update_execution_status]
	@execution_id INT,
	@status VARCHAR (50)
AS
BEGIN
	UPDATE WorkQueueExecution
		SET execution_status = @status
	WHERE execution_id = @execution_id
END

GO

CREATE PROCEDURE [dbo].[sp_update_resource_status]
	@id INT,
	@status VARCHAR (100)
AS
BEGIN
	
	DECLARE @last_update_date VARCHAR (30) = CONVERT(VARCHAR, GETDATE(), 20)

	-- UPDATE RESOURCE STATUS
	UPDATE WorkQueueResource 
	SET resource_status = @status,
	resource_last_update = @last_update_date
	WHERE resource_id = @id
END

GO

CREATE PROCEDURE [dbo].[sp_wait_resources_update_status]
	@execution_id INT,
	@next_status VARCHAR(50),
	@finished VARCHAR(10) OUTPUT
AS
BEGIN
	DECLARE @reptived INT = 0
	DECLARE @resources_availables INT = 0

	SET @finished = 'False'

	WHILE @reptived <= 1000 BEGIN
		SET @resources_availables = (
			SELECT COUNT(resource_id) AS resources
			FROM WorkQueueResource
			WHERE execution_id = @execution_id
				AND resource_status <> @next_status
				AND resource_state <> 'Terminated' AND resource_state <> 'Completed'
		)

		IF (@resources_availables = 0) BEGIN
			SET @finished = 'True'
			BREAK
		END

		WAITFOR DELAY '00:00:01'

		SET @reptived += 1
	END
END

GO

CREATE PROCEDURE [dbo].[sp_create_execution_attempt]
       @id INT,
	   @new_id VARCHAR (MAX) OUTPUT
AS
BEGIN
	DECLARE @get_id table (id_temp INT) --TABLE VAR TO GET INSERTED ID

	BEGIN TRANSACTION [CREATEEXECUTIONATTEMPT]
		BEGIN TRY
		SELECT * FROM WorkQueueExecution
			-- CREATE ATTEMPT
			INSERT INTO WorkQueueExecution
			(
				execution_state,
				execution_code,
				execution_status,
				execution_queue_name,
				execution_worked_time,
				execution_start_date,
				execution_end_date,
				execution_exception_reason
			)OUTPUT inserted.execution_id INTO @get_id
			SELECT 'Pending', w.execution_code, w.execution_status,
					w.execution_queue_name ,'', w.execution_start_date, 
					'', ''
			FROM WorkQueueExecution w
			WHERE w.execution_id = @id AND w.execution_state = 'Terminated'

			-- GET NEW ITEM ID
			SET @new_id = (SELECT * FROM @get_id)

			COMMIT TRANSACTION [CREATEEXECUTIONATTEMPT]
		END TRY
		BEGIN CATCH
			DECLARE @error_message VARCHAR (MAX) 
			DECLARE @error_severity INT
			DECLARE @error_state INT

			SELECT 
				@error_message  = ERROR_MESSAGE() + ' ' + ERROR_LINE(),
				@error_severity = ERROR_SEVERITY(),
				@error_state  = ERROR_STATE()

			RAISERROR(@error_message, @error_severity, @error_state)

			ROLLBACK TRANSACTION [CREATEEXECUTIONATTEMPT]
		END CATCH
END


GO