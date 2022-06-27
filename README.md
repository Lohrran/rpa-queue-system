# RPA Queue System
> A simple SQL Server Queue System to RPA projects

## Why?
Longer my Software Engineer career I encounter severals automation projects using different technologies like python, or RPA tools like Automation Anywhere, in those projects the team try to emulate a queue system different to each new automation.
So thinking in that I created a common system that could be use for any RPA project. 

## Introduction
It's a queue system simple to understand and easy to use, it was based on different queue system, but mainly in the Blue Prism Tool, from cross internet.

> The queue system can handle mostly every automation.


## What it Looks Like?

It will have two main tables to keep eye on.

**WorkQueueInfo:** Information of the queue.

| queue_name | queue_key_name  | max_attempt | queue_columns                                          |
| ---------- | --------------- | ----------- | ------------------------------------------------------ |
| QueueName  | document_number | 3           | person_name,document_number,document_type,person_email |
           

**WorkQueue:** Track of each item and its attempt load to the queue. 


| item_id | item_state | item_key | item_status | item_priority | item_attempt | item_defer_date | item_worked_time | item_start_date  | item_end_date | item_exception_reason | item_queue_name | item_data   | item_resource_nam |
| ------- | ---------- | -------- | ----------- | ------------- | ------------ | --------------- | ---------------- | ---------------- | ------------- | --------------------- | --------------- | ----------- | ----------------- |
| 1       | Pending    | 1885550  | Validate    | 0             | 0            |                 |                  | 18/02/2022 21:48 |               |                       | QueueName       | 0x00E6ABB6F | HOSTNAME          |


*item_queue_data* will be encrypt below a example how it look like without encryptation.

```xml
<Data>
	<row>
		<person_name>Some Name</person_name>
		<document_number>1885550</document_number>
		<document_type>DNI</document_type>
		<person_email>somename@gmail.com</person_email>
	</row>
</Data>
```

## How to

#### How to Install Database
1.	Open the follow files (.sql): 
	a.	01 – Create Tables
	b.	02 – Stored Procedures
	c.	03 – Load Data
	d.	04 – Security
	
2.	For each file opened previously replace the follow parameters:
	a.	[DATABASE_NAME]: Replace this for the name of the database where it will be deployed.
	b.	[KEYNAME]: Replace this for the name of the SYMMETRIC  KEY from the database where it will be deploy.
	c.	[CERTIFICATE_NAME]: Replace this for the name of the CERTIFICATE  from the database where it will be deploy.
	d.	RXXP0X: Replace this for the name of the username whom will have the access to the database.
	e.	[BOT_NAME]: Replace this for the name of the robot to be deploy.
	f.	[COLUMN_NAMES]: Replace this for the solution business columns.
	g.	[KEY_NAME]:  Replace this for the column that will be used as the key identificator.
	
3.	Execute the files in the order as ordered: 01, 02, 03, 04.


## Observation

