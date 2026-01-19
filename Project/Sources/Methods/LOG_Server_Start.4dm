//%attributes = {"invisible":false,"preemptive":"capable"}
//  LOG_Server_Start
//  Starts the log server using System Worker
//  Call this from On Startup database method
//
//  Returns: Object with status info
//    .success : Boolean
//    .message : Text
//    .port : Integer (if successful)

var $result : Object
$result:=New object("success"; False; "message"; "")

//  Check if already running
If (Storage.logServer#Null)
	$result.message:="Log server already running"
	$result.success:=True
	$result.port:=Storage.logServer.port
	return $result
End if 

//  Get paths from centralized path manager
var $paths : cs.LOG_Paths
$paths:=cs.LOG_Paths.new()

//  Check if server script exists
If (Not($paths.serverFile.exists))
	$result.message:="Server script not found: "+$paths.serverFile.path
	return $result
End if 

//  Check for bun executable
var $bunFile : 4D.File
$bunFile:=$paths.bunFile

If ($bunFile=Null)
	$result.message:="Bun not found. Place bun binary in Project/logserver/bin/ or install from https://bun.sh"
	return $result
End if 

//  Get port from config
var $port : Integer
$port:=$paths.port

//  Create System Worker
var $worker : 4D.SystemWorker
var $command : Text

$command:="\""+$bunFile.path+"\" run \""+$paths.serverFile.path+"\""

var $options : Object:={}
$options.currentDirectory:=$paths.serverFolder.path
//  Set up handlers
$options.onData:=Formula(LOG__Server_OnData($1))
$options.onError:=Formula(LOG__Server_OnError($1))
$options.onTerminate:=Formula(LOG__Server_OnTerminate($1))

$worker:=4D.SystemWorker.new($command; $options)


//  Store in Storage for access from other processes
Use (Storage)
	Storage.logServer:=New shared object(\
		"port"; $port; \
		"startTime"; Current date(*); \
		"startTimestamp"; Timestamp)
End use 

$result.success:=True
$result.message:="Log server started on port "+String($port)
$result.port:=$port

return $result
