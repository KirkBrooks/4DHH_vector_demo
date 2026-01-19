//%attributes = {"invisible":true,"preemptive":"capable"}
//  LOG__Server_OnTerminate
//  Handler for when log server process ends
//  $1 : Object with .exitCode, .signalName (if killed by signal)

#DECLARE($event : Object)
//  Clean up Storage reference
Use (Storage)
	Storage.logServer:=Null
End use 

//  Log the termination
If ($event#Null)
	var $msg : Text
	If ($event.exitCode=0)
		$msg:="Log server exited normally"
	Else 
		$msg:="Log server exited with code: "+String($event.exitCode)
		If ($event.signalName#Null)
			$msg:=$msg+" (signal: "+$event.signalName+")"
		End if 
	End if 
	//  Could log this somewhere
End if 
