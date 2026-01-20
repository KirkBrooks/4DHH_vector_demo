//%attributes = {"invisible":true,"preemptive":"capable"}
//  LOG_Worker
//  Background worker process that batches log entries
//  Called via CALL WORKER - do not call directly
//
//  $1 : Text - command ("entry", "flush", "stop", "tick")
//  $2 : Object - for "entry": the log entry object

#DECLARE($command : Text; $param : Object)

//  Initialize queue in process variables on first call
var LOG_queue : Collection

If (LOG_queue=Null)
	LOG_queue:=New collection
	var LOG_batchSize:=50
	var LOG_flushIntervalMs:=100
	var LOG_lastFlush:=Milliseconds
	var LOG_running:=True
	
	//  Start the tick loop
	CALL WORKER(Current process name; "LOG_Worker"; "tick")
End if 

Case of 
	: ($command="entry")
		//  Add entry to queue
		If ($param#Null)
			LOG_queue.push($param)
			
			//  Flush immediately if batch size reached
			If (LOG_queue.length>=LOG_batchSize)
				LOG__Flush_Queue
			End if 
		End if 
		
	: ($command="flush")
		//  Force flush
		LOG__Flush_Queue
		
	: ($command="stop")
		//  Final flush and mark as stopped
		LOG__Flush_Queue
		LOG_running:=False
		
	: ($command="tick")
		//  Periodic timer tick - check if we need to flush
		If (LOG_running)
			If (LOG_queue.length>0)
				var $elapsed : Integer
				$elapsed:=Milliseconds-LOG_lastFlush
				If ($elapsed>=LOG_flushIntervalMs)
					LOG__Flush_Queue
				End if 
			End if 
			
			//  Schedule next tick using DELAY PROCESS
			DELAY PROCESS(Current process; LOG_flushIntervalMs/1000*60)
			CALL WORKER(Current process name; "LOG_Worker"; "tick")
		End if 
		
End case 
