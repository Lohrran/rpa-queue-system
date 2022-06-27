USE [DATABASE_NAME]
GO

------------------------------------------------------------------------------------------------------------------------------------------------------------

---------- INSERT TABLE DETAIL ----------
IF NOT EXISTS (SELECT queue_name FROM WorkQueueInfo WHERE queue_name = '[ROBOT_NAME]')
		INSERT INTO WorkQueueInfo (queue_name, queue_key_name, max_attempt, queue_columns)
		VALUES('[BOT_NAME]', '[KEY_NAME]', 0, '[COLUMN_NAMES]')
GO
---------- INSERT TABLE DETAIL ----------

------------------------------------------------------------------------------------------------------------------------------------------------------------
