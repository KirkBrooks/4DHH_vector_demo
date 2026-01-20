//%attributes = {"invisible":true,"preemptive":"capable"}
//  LOG__Flush_Queue
//  Internal: Sends queued log entries to the server as a batch
//  Called from LOG_Worker - do not call directly

//  Check if there's anything to flush
If (LOG_queue=Null) || (LOG_queue.length=0)
	return 
End if 

//  Get server URL
var $paths : cs.LOG_Paths
$paths:=cs.LOG_Paths.new()
var $url : Text:="http://localhost:"+String($paths.port)+"/log/batch"

//  Build request
var $request : 4D.HTTPRequest
var $options : Object
$options:={method: "POST"; headers: New object("Content-Type"; "application/json"); timeout: 5}
$options.body:=JSON Stringify(LOG_queue)
$options.onResponse:=Formula(LOG__HTTP_Response($1))
$options.onError:=Formula(LOG__HTTP_Error($1))

//  clear the queue
LOG_queue:=[]
LOG_lastFlush:=Milliseconds

$request:=4D.HTTPRequest.new($url; $options)
