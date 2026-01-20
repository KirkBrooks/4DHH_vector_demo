//%attributes = {"invisible":false,"preemptive":"capable"}
//  LOG_Test_Volume
//  Test high-volume logging performance
//
//  $1 : Integer - number of entries to send (default 500)
//  $2 : Text - channel name (default "volume_test")
//
//  Returns: Object with timing results

#DECLARE($count : Integer; $channel : Text)->$result : Object

If ($count=0)
	$count:=500
End if

If ($channel="")
	$channel:="volume_test"
End if

$result:=New object

var $startTime : Integer
var $endTime : Integer
var $i : Integer

$startTime:=Milliseconds

For ($i; 1; $count)
	LOG_Entry($channel; "info"; "Test message "+String($i); New object("index"; $i; "batch"; "volume_test"))
End for

$endTime:=Milliseconds

var $elapsed : Integer
$elapsed:=$endTime-$startTime

$result.count:=$count
$result.elapsedMs:=$elapsed
$result.entriesPerSecond:=Round(($count/$elapsed)*1000; 0)
$result.channel:=$channel
$result.message:="Sent "+String($count)+" entries in "+String($elapsed)+"ms ("+String($result.entriesPerSecond)+"/sec)"

//  Note: entries are queued, not yet flushed to server
//  Call LOG_Entry with "flush" command or wait for auto-flush
