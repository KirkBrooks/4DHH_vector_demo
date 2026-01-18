/*  Import_large_JSONL class
 Created by: Kirk Brooks as Designer, Created: 01/16/26, 09:34:13
 ------------------
For managing importing a large JSONL file.

Use SET CHANNEL for file I/O operations because
other 4D file operations load the entire file into memory. Since
4D has a 2 gb limit on variable size files larger than that present
a problem. 

This class will open the document and parse the contents in chunks. 
The chunks will be returned as a collection of json objects.

$path:    system path to the JSONL file to import
$method:  method to run in a worker
$workers: names of workers to call with file chunks

*/

property parameters : Object
property next_worker_index : Integer:=0

Class constructor($parameters : Object)
	This.parameters:=$parameters  //  shared object
	
Function get worker_limit_index : Integer
	return This.parameters.worker_limit_index
	
Function get path : Text
	return This.parameters.path
	
Function get fileName : Text
	return This.parameters.fileName
	
Function get chunkSize : Integer
	return This.parameters.chunkSize
	
Function get method : Text
	return This.parameters.method
	
Function get ok_to_run : Boolean
	return This.parameters.ok_to_run
	
Function get delay_ticks : Integer
	return This.parameters.delay_ticks
	
Function import_file()
/*  Read a chunck of data and pass it to a worker for processing
The chunks will be passed to workers seqeuentially
*/
	var $text; $lastChar : Text
	var $importedSize : Real
	var $i : Integer
	var $threshold; $delay : Integer
	
	Console_log("Beginning import of: "+This.fileName)
	
	var $ms:=Milliseconds
	SET CHANNEL(10; This.path)
	
	Repeat 
		RECEIVE PACKET($text; This.chunkSize)
		
		If (Length($text)>2)  //  file ends in \n or maybe \r\n
			// read until we are sure we have a complete object in the chunk
			RECEIVE PACKET($lastChar; "}"+Char(10)+"{")  // read till next }\n{ 
			
			$text+=$lastChar+"}"  //Delimiter string is not returned in receiveVar!  So we have to add a } to $text
			
			If ($importedSize=0)  // this is the first chunk
				$importedSize+=(Length($text)+1)  //  for \n
				This._assign_chunk($text)
			Else 
/*
Only the first chuck will have a leading {
All subsequent ones won't so we need to add it as well 
*/
				$importedSize+=(Length($text)+2)  //  for  { and \n
				This._assign_chunk("{"+$text)
				// I'm avoiding $text:="{"+$text because re-writing $text is minimally slower
			End if 
			
			$importedSize+=Length($text)  // keep track of how many bytes read
			This._msg($importedSize)
			
			This._pause()
			
		End if 
		
	Until ($text="") || (Not(This.ok_to_run))
	
	SET CHANNEL(11)  //  close the file
	
	Console_log("Finished importing : "+This.fileName+" in "+String(This.elapsedSeconds)+" seconds")
	
Function _pause()
	
	If (This.worker_queue.sum()>This.worker_queue_limit)
		Console_log(" -- import pause:  "+JSON Stringify(This.worker_queue))
		DELAY PROCESS(Current process; This.delay_ticks)
	End if 
	
Function _assign_chunk($chunk : Text)
	//  assigns this chunk to the next worker 
	var $next_index : Integer:=This.next_worker_index+1
	
	If ($next_index>This.worker_limit_index)  // over limit
		$next_index:=0  // start back at the bottom
	End if 
	
	var $workerName:="Importer_"+String($next_index)
	
	This.next_worker_index:=$next_index
	// increment the queue counter
	Use (This.parameters.worker_queue)
		This.parameters.worker_queue[$next_index]+=1
	End use 
	
	CALL WORKER($workerName; This.method; $chunk; This.fileName; This.parameters.worker_queue)
	
Function _msg($size : Real)
	Console_log(This.fileName+"; Data Read: "+String($size/1048576; "########0.00")+" mbs;  "+String(Round($size/This.fileSize*100; 3); "###0.000")+" % \r")
	