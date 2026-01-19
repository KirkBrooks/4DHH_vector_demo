//%attributes = {"invisible":true,"preemptive":"capable"}
  //  LOG__Server_OnData
  //  Handler for stdout from log server
  //  $1 : Object with .data (Blob) and .type ("stdout")

var $event : Object
$event:=$1

If ($event#Null) && ($event.data#Null)
	var $text : Text
	$text:=Convert to text($event.data; "UTF-8")
	
	  //  Log to console or handle as needed
	  //  You could write to a dedicated log file or use TRACE
	If (Length($text)>0)
		TRACE  // Opens debugger if in debug mode - remove in production
		  // Or write to a separate startup log
	End if 
End if 
