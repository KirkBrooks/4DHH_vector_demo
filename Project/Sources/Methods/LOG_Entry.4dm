//%attributes = {"invisible":false,"preemptive":"capable"}
//  LOG_Entry
//  Fire-and-forget log entry - truly async
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

var $port : Integer
$port:=Storage.logServer.port

//  Build payload
var $payload : Object
$payload:=New object(\
"channel"; $channel; \
"level"; $level; \
"message"; $message; \
"timestamp"; Timestamp)

If ($data#Null)
	$payload.data:=$data
End if 

//  Fire and forget using 4D.HTTPRequest with empty callback
//  This returns immediately without blocking
var $url : Text
$url:="http://127.0.0.1:"+String($port)+"/log"

var $options : Object
$options:=New object
$options.method:="POST"
$options.body:=JSON Stringify($payload)
$options.headers:=New object("Content-Type"; "application/json")
$options.timeout:=5  //  short timeout since it's localhost

//  The onResponse/onError callbacks make it async
//  We use empty formulas - we don't care about the response
$options.onResponse:=Formula(LOG__HTTP_Response($1))
$options.onError:=Formula(LOG__HTTP_Error($1))

//  This returns immediately - does not block
var $request : 4D.HTTPRequest
$request:=4D.HTTPRequest.new($url; $options)

//  $request goes out of scope but the request continues in background
