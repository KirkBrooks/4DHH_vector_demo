//%attributes = {"invisible":false,"preemptive":"capable"}
//  LOG_Server_Stop
//  Gracefully stops the log server
//  Call this from On Exit or On Server Shutdown database method
//  
//  Returns: Object with status info
//    .success : Boolean
//    .message : Text

#DECLARE->$result : Object
$result:=New object("success"; False; "message"; "")

//  Stop the LOG_Worker first (flush remaining entries)
CALL WORKER("LOG_Worker"; "LOG_Worker"; "stop")
DELAY PROCESS(Current process; 10)  // Give it time to flush

//  Check if running
If (Storage.logServer=Null)
	$result.message:="Log server not running"
	$result.success:=True
	return
End if

var $worker : 4D.SystemWorker
$worker:=Storage.logServer.worker

If ($worker#Null)
	//  terminate() sends SIGTERM which triggers graceful shutdown
	//  The server will flush all queues before exiting
	$worker.terminate()
	
	//  Wait briefly for clean shutdown (max 2 seconds)
	var $timeout : Integer
	$timeout:=0
	While (($worker.terminated=False) && ($timeout<20))
		DELAY PROCESS(Current process; 6)  // 100ms
		$timeout:=$timeout+1
	End while 
	
	If ($worker.terminated)
		$result.message:="Log server stopped gracefully"
	Else 
		//  Force kill if needed
		$worker.terminate()  // force
		$result.message:="Log server force terminated"
	End if 
End if 

//  Clear from Storage
Use (Storage)
	Storage.logServer:=Null
End use 

$result.success:=True
return 
