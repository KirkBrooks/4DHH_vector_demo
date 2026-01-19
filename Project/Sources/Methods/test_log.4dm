//%attributes = {}


// LOG_Server_Stop()
$result:=LOG_Server_Start()


If (Storage.logServer=Null)
	ALERT("logServer is null - never started")
Else 
	var $worker : 4D.SystemWorker
	$worker:=Storage.logServer.worker
	ALERT("terminated: "+String($worker.terminated)+"\nexit code: "+String($worker.exitCode))
End if 

