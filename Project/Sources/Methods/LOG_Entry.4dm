//%attributes = {"preemptive":"capable"}
//  LOG_Entry
//  Fire-and-forget log entry - batched for high performance
//
//  $1 : Text - channel name
//  $2 : Text - level (debug, info, warn, error) - optional, defaults to "info"
//  $3 : Text - message
//  $4 : Object - additional data (optional)
//
//  Example:
//    LOG_Entry("myapp"; "info"; "User logged in"; New object("userId"; 123))
//    LOG_Entry("errors"; "error"; "Database connection failed")

#DECLARE($channel : Text; $level : Text; $message : Text; $data : Object)

//  Defaults
If ($level="")
	$level:="info"
End if

//  Validate level
If (New collection("debug"; "info"; "warn"; "error").indexOf($level)<0)
	$level:="info"
End if

//  Check if server is running
If (Storage.logServer=Null)
	//  Server not running - silently fail (fire and forget)
	return
End if

//  Build entry object
var $entry : Object
$entry:=New object(\
"channel"; $channel; \
"level"; $level; \
"message"; $message; \
"timestamp"; Timestamp)

If ($data#Null)
	$entry.data:=$data
End if

//  Send to worker for batching
//  CALL WORKER is non-blocking - returns immediately
CALL WORKER("LOG_Worker"; "LOG_Worker"; "entry"; $entry)
