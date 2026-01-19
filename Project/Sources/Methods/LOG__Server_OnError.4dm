//%attributes = {"invisible":true,"preemptive":"capable"}
  //  LOG__Server_OnError
  //  Handler for stderr from log server
  //  $1 : Object with .data (Blob) and .type ("stderr")

var $event : Object
$event:=$1

If ($event#Null) && ($event.data#Null)
	var $text : Text
	$text:=Convert to text($event.data; "UTF-8")
	
	If (Length($text)>0)
		  //  Log errors - these are important
		  //  Could write to a file, alert, or just trace
		TRACE  // Shows in debugger
	End if 
End if 
