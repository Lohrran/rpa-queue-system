USE [DATABASE_NAME]

GO

IF EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = 'SymKey_[KEY_NAME]')
	DROP SYMMETRIC KEY SymKey_[KEYNAME]

IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'Cer_[CERTIFICATE_NAME]')
	DROP CERTIFICATE Cer_[CERTIFICATE_NAME]

IF EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE symmetric_key_id = 101)
    DROP MASTER KEY

GO

--considerar el cambio de la palabra PA$$W0RD por la que COS accesos crea conveniente
CREATE MASTER KEY 
	ENCRYPTION BY PASSWORD = 'PA$$W0RD'	
 
CREATE CERTIFICATE Cer_[CERTIFICATE_NAME]
   WITH SUBJECT = '[CERTIFICATE_DESCRIPTION]',
   EXPIRY_DATE = '20290101';
 
CREATE SYMMETRIC KEY SymKey_[KEYNAME]
	WITH IDENTITY_VALUE = '[KEYNAME]KeyEncrypt',
    ALGORITHM = AES_256,
	KEY_SOURCE = 'PA$$W0RD'
    ENCRYPTION BY CERTIFICATE Cer_[CERTIFICATE_NAME];
	
GO

USE [master]

GO

if not exists (select sid from master.dbo.syslogins where loginname = N'DOMAIN\RXXP0X')
	CREATE LOGIN [BCPDOM\RXXP0X] FROM WINDOWS WITH DEFAULT_DATABASE=[DATABASE_NAME]

GO

USE [DATABASE_NAME]

GO

IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = N'DOMAIN\RXXP0X')
    CREATE USER [DOMAIN\RXXP0X] FOR LOGIN [DOMAIN\RXXP0X]
GO	
	ALTER USER [DOMAIN\RXXP0X] WITH DEFAULT_SCHEMA=[dbo]
GO


ALTER ROLE [db_datareader] ADD MEMBER [DOMAIN\RXXP0X]
ALTER ROLE [db_datawriter] ADD MEMBER [DOMAIN\RXXP0X]

GO

GRANT REFERENCES ON SYMMETRIC KEY::[SymKey_[KEYNAME]] TO [DOMAIN\RXXP0X]
GRANT CONTROL ON CERTIFICATE::[Cer_[CERTIFICATE_NAME]] TO [DOMAIN\RXXP0X]

GO



------------------------------------------------------------------------------------------------------------------------------------------------------------

---------- TABLES ----------
GRANT SELECT, UPDATE, INSERT, DELETE ON WorkQueueInfo					TO [DOMAIN\RXXP0X];
GRANT SELECT, UPDATE, INSERT, DELETE ON WorkQueue						TO [DOMAIN\RXXP0X];
GRANT SELECT, UPDATE, INSERT, DELETE ON WorkQueueTask					TO [DOMAIN\RXXP0X];
GRANT SELECT, UPDATE, INSERT, DELETE ON WorkQueueItemTask				TO [DOMAIN\RXXP0X];

GRANT SELECT, UPDATE, INSERT, DELETE ON WorkQueueEnvironmentLocker		TO [DOMAIN\RXXP0X];
GRANT SELECT, UPDATE, INSERT, DELETE ON WorkQueueExecution				TO [DOMAIN\RXXP0X];
GRANT SELECT, UPDATE, INSERT, DELETE ON WorkQueueResource				TO [DOMAIN\RXXP0X];

---------- TABLES ----------
GO
------------------------------------------------------------------------------------------------------------------------------------------------------------

---------- STORED PROCEDURES ----------
GRANT EXECUTE ON sp_add_item_task		 							TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_clean_up_queue		 							TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_count_item_pending		 						TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_count_item_pending_by_resource_name		 		TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_create_item_attempt		 	 					TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_fill_item_empty_row		 						TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_get_completed_items		 						TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_get_item_attempt		 						TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_get_item_data		 							TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_get_item_log_values		 						TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_get_item_priority		 						TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_get_item_status		 							TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_get_item_task		 	 						TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_get_max_attempt		 							TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_get_next_item		 							TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_get_next_item_filter_by_task		 			TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_get_report_data		 							TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_get_state_items_by_task		 					TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_get_terminated_items		 					TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_get_volumetry		 							TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_load_to_queue 									TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_load_to_queue_with_validation	 	 			TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_mark_item_completed		 						TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_mark_item_exception		 						TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_remove_item_task		 						TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_replace_item_task		 						TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_set_data		 								TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_unlock_item		 								TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_update_item_defer_date		 					TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_update_item_priority		 					TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_update_item_status		 						TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_work_queue_balance								TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_display_business_queue_data		 				TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_display_item_business_data		 				TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_display_technical_item_data		 				TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_display_technical_queue_data		 			TO [DOMAIN\RXXP0X];


GRANT EXECUTE ON sp_add_new_execution						TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_add_execution_resource					TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_clean_up_resources						TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_get_execution_resources					TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_get_resource_state						TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_exist_execution_terminated				TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_get_execution_code						TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_get_execution_dates						TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_get_execution_status					TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_get_resource_status						TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_mark_execution_completed				TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_mark_execution_exception				TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_mark_resource_completed					TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_mark_resource_exception					TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_update_execution_status					TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_update_resource_status					TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_wait_resources_update_status			TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_create_execution_attempt				TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_clean_environment_locks					TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_get_environment_lock					TO [DOMAIN\RXXP0X];
GRANT EXECUTE ON sp_release_environment_lock				TO [DOMAIN\RXXP0X];
---------- STORED PROCEDURES ----------

------------------------------------------------------------------------------------------------------------------------------------------------------------
