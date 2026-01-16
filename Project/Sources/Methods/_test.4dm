//%attributes = {"preemptive":"capable"}

var $path : Text:="4DworkDisk:4D_Happy_Hour:Vector Demo:Electronics.jsonl"
var $text; $lastChar : Text
var $chunkSize : Real
var $totalSize : Real
var $ms : Integer

$file:=File($path; fk platform path)





SET CHANNEL(10; $path)  //  opens channel to the document without reading it

$newDoc:=Create document("4DworkDisk:4D_Happy_Hour:Vector Demo:Electronics_copy.jsonl")

$chunkSize:=20000  //  number of chars to read

var $chunks:=[]  // for this test

var $i:=0
$ms:=Milliseconds

Repeat 
	RECEIVE PACKET($text; $chunkSize)
	
	If (Length($text)>2)  //  file ends in \n or maybe \r\n
		
		// read until we are sure we have a complete object in the chunk
		RECEIVE PACKET($lastChar; "}"+Char(10)+"{")
/* read till next }\n{ 
		
this string is not returned in receiveVar!
So we have to add a } to $text
*/
		$text+=$lastChar+"}"
		
/*
This also means only the first chuck will have a leading {
All subsequent ones won't so we need to add it as well 
*/
		If ($totalSize>0)
			SEND PACKET($newDoc; "{"+$text)
			$totalSize+=(Length($text)+2)  //  for  { and \n
		Else 
			SEND PACKET($newDoc; $text)
			$totalSize+=(Length($text)+1)  //  for \n
		End if 
		
		
		MESSAGE("Total size: "+String($totalSize/1048576; "########0.00")+" mbs\r")
	End if 
	$i+=1
	
Until (Length($text)<=2) || ($i>100)

$ms:=Milliseconds-$ms

SET CHANNEL(11)  //  close the file
CLOSE DOCUMENT($newDoc)

ALERT("Elapsed time: "+String($ms/1000)+" seconds")

ALERT("file size  = "+String($file.size)+"\n$totalSize = "+String($totalSize)+"\ndiff = "+String($totalSize-$file.size))

//$text:=$chunks.join("\n")
//SET TEXT TO PASTEBOARD($text)
