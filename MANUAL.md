# Work Queue System Manual

## Overview
The objective for the system it's to facilitate the automation with software that does not have an integrated work queue.

## Schema
<p align="center">
  <img width="auto" height="auto" src="https://i.ibb.co/jTSfDxX/workqueue-diagram-drawio.png">
</p>



## Database
More information for each table.
### WorkQueueInfo
This table has the base information from the _queues_ that the system use, the date load will be link with the table WorkQueue.

| queue_name | queue_key_name  | max_attempt | queue_columns                                          |
| ---------- | --------------- | ----------- | ------------------------------------------------------ |
| QueueName  | document_number | 3           | person_name,document_number,document_type,person_email |

- **Columns**
    - **queue_name**: The column explain itself.
    - **queue_key_name**: This field must have the column key to the data inserted in the table _WorkQueue_.
    - **max_attempt**: This field is the number of attempts that one item in _WorkQueue_ will retry.
    - **queue_columns**: The column explain itself, but remeber to divide the columns by comma like it can be seem in the explain above.

### WorkQueue
Keep the detailed information for the items load from differents _queues_.

| item_id | item_state | item_key | item_status | item_priority | item_attempt | item_defer_date | item_worked_time | item_start_date  | item_end_date    | item_exception_reason | item_queue_name | item_data   | item_resource_nam |
| ------- | ---------- | -------- | ----------- | ------------- | ------------ | --------------- | ---------------- | ---------------- | ---------------- | --------------------- | --------------- | ----------- | ----------------- |
| 1       | Pending    | 1885550  | Validate    | 0             | 0            |                 |                  | 18/02/2022 21:48 |                  |                       | QueueName       | 0x00E6ABB6F | HOSTNAME          |
| 2       | Completed  | 223586   | Registered  | 0             | 1            |                 | 00:02:00         | 18/02/2022 21:48 | 18/02/2022 22:02 |                       | QueueName       | 0x00E6ABB6F | HOSTNAME                  |

- **Columns**
    - **item_id**: PK.
    - **item_state**: Item state, it can have 4: Pending (Waiting to be work), Locked (Working), Completed (Finished sucessful), Terminated (Finished fail). 
    - **item_key**: Value came from data loaded.
    - **item_status**: It will be define by the user, _and can also be use to control the flow of the automation_.
    - **item_priority**:  Priority to work the item (Low > High).
    - **item_attempt**: How many attempts the item had.
    - **item_defer_date**: Here the user can specify when the item should be work.
    - **item_worked_time**: Time between the state Locked and Completed/Terminated.
    - **item_start_date**: Time it was loaded in the table.
    - **item_end_date**: Time of the last state (Completed/Terminated).
    - **item_exception_reason**: Detail of exception (Error Type | Line | Class/Function | Reason).
    - **item_queue_name**: Explain itself.
    - **item_resource_name**: Hostname that worked the item.


### WorkQueueExecution
Keep the detailed information for the executions for each projects that work with the work queue system.

- **Columns**
    - **execution_id**: PK.
    - **execution_state**: Execution state, it can have 4: Pending (Waiting to be work), Locked (Working), Completed (Finished sucessful), Terminated (Finished fail). 
    - **execution_code**: Value to specify execution.
    - **execution_status**: It will be define by the user, _and can also be use to control the flow of the automation_.
    - **execution_queue_name**: Queue name for the execution.
    - **execution_defer_date**: Here the user can specify when the item should be work.
    - **execution_worked_time**: Time between the state Locked and Completed/Terminated.
    - **execution_start_date**: Time it was loaded in the table.
    - **execution_end_date**: Time of the last state (Completed/Terminated).
    - **execution_exception_reason**: The exception that made the automation stopped.

### WorkQueueResource
Keep the detailed iformation about the hostnames that work in the automation.

- **Columns**
    - **resource_id**: PK.
    - **execution_id:** FK, id from WorkQueueExecution.
    - **resource_state**: Hostname state, it can have 4: Pending (Waiting to be work), Locked (Working), Completed (Finished sucessful), Terminated (Finished fail). 
    - **resource_user**: Username.
    - **resource_name**: Hostname value.
    - **resource_status**: It will be define by the user, _and can also be use to control the flow of the automation_.
    - **resource_worked_time**: How much time the robot worked in the execution linked.
    - **resource_start_date**:Time it was loaded in the table.
    - **resource_end_date**: Time of the last state (Completed/Terminated).

### WorkQueueItemTask and WorkQueueTask
These two table work as a tag system for the queue.

### WorkQueueView and WorkQueueDailyView
These two table work as resumen from the WorkQueue table.


> **Important Note**: WorkQueueExecution and WorkQueueResource do not need to be use to work with this system.

## Stored Procedures
The scripts are self explanatory.

- **WorkQueueInfo** / **WorkQueue** / **WorkQueueItemTask** / **WorkQueueTask**
	 - sp_add_item_task		 							
	 - sp_clean_up_queue		 							
	 - sp_count_item_pending		 						
	 - sp_count_item_pending_by_resource_name		 		
	 - sp_create_item_attempt		 	 					
	 - sp_fill_item_empty_row		 						
	 - sp_get_completed_items		 						
	 - sp_get_item_attempt		 						
	 - sp_get_item_data		 							
	 - sp_get_item_log_values		 						
	 - sp_get_item_priority		 						
	 - sp_get_item_status		 							
	 - sp_get_item_task		 	 						
	 - sp_get_max_attempt		 							
	 - sp_get_next_item		 							
	 - sp_get_next_item_filter_by_task		 			
	 - sp_get_report_data		 							
	 - sp_get_state_items_by_task		 					
	 - sp_get_terminated_items		 					
	 - sp_get_volumetry		 							
	 - sp_load_to_queue 									
	 - sp_load_to_queue_with_validation	 	 			
	 - sp_mark_item_completed		 						
	 - sp_mark_item_exception		 						
	 - sp_remove_item_task		 						
	 - sp_replace_item_task		 						
	 - sp_set_data		 								
	 - sp_unlock_item		 								
	 - sp_update_item_defer_date		 					
	 - sp_update_item_priority		 					
	 - sp_update_item_status		 						
	 - sp_work_queue_balance								
	 - sp_display_business_queue_data		 				
	 - sp_display_item_business_data		 				
	 - sp_display_technical_item_data		 				
	 - sp_display_technical_queue_data		 			

- **WorkQueueExecution** / **WorkQueueResource**
	- sp_add_new_execution
	- sp_add_execution_resource					
	- sp_clean_up_resources						
	- sp_get_execution_resources					
	- sp_get_resource_state						
	- sp_exist_execution_terminated				
	- sp_get_execution_code						
	- sp_get_execution_dates						
	- sp_get_execution_status					
	- sp_get_resource_status						
	- sp_mark_execution_completed				
	- sp_mark_execution_exception				
	- sp_mark_resource_completed					
	- sp_mark_resource_exception					
	- sp_update_execution_status					
	- sp_update_resource_status					
	- sp_wait_resources_update_status			
	- sp_create_execution_attempt				