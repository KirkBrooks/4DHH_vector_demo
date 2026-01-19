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
	
Function get worker_limit_index : Integer  //  max number of workers
	return This.parameters.worker_limit_index
	
Function get worker_queue_limit : Integer  //  max number of jobs in worker queue
	return This.parameters.worker_queue_limit
	
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
	
Function import_file()
/*  Read a chunck of data and pass it to a worker for processing
The chunks will be passed to workers seqeuentially
*/
	var $text_chunk; $lastChar : Text
	var $bytes_read : Real
	var $count : Integer
	var $threshold; $delay : Integer
	var $isFirst : Boolean:=True
	
	Console_log("Beginning import of: "+This.parameters.name)
	
	var $ms:=Milliseconds
	SET CHANNEL(10; This.path)
	
	var $delimiter : Text:="}"+Char(10)+"{"
	
	Repeat 
		RECEIVE PACKET($text_chunk; This.chunkSize)
		
		If (Length($text_chunk)>2)  //  file ends in \n or maybe \r\n
			// read until we are sure we have a complete object in the chunk
			// this is the position of the next $delimiter or the end of the document
			// RECEIVE PACKET will stop reading at the end of the document if it doesn't find a delimiter
			RECEIVE PACKET($lastChar; $delimiter)
			
			$text_chunk+=$lastChar+"}"  //Delimiter string is not returned in receiveVar!  So we have to add a } to $text
			
			If ($isFirst)  // this is the first chunk which will have the leading { char
				$isFirst:=False
				$bytes_read+=(Length($text_chunk)+1)  //  for }
				This._assign_chunk($text_chunk)
			Else 
/*
Only the first chuck will have a leading {
All subsequent ones won't so we need to add it as well 
*/
				$bytes_read+=(Length($text_chunk)+2)  //  for  { and \n
				This._assign_chunk("{"+$text_chunk)
				// I'm avoiding `$text:="{"+$text`  because re-writing $text is minimally slower
			End if 
			
			This._set_parameter("bytes_read"; $bytes_read)
			$count+=1  // number of tasks created
			
		End if 
		
	Until (Length($text_chunk)<2) || (Not(This.ok_to_run))
	
	SET CHANNEL(11)  //  close the file
	
	Console_log("Finished importing : "+This.fileName+" in "+String(This.elapsedSeconds)+" seconds")
	
Function _set_parameter($key : Text; $value)
	//  sets a value in the shared parameters object
	Use (This.parameters)
		This.parameters[$key]:=$value
	End use 
	
Function _assign_chunk($chunk : Text)
	//  assigns this chunk to the next worker that has capacity
	var $this_index : Integer:=This.next_worker_index
	var $ok : Boolean
	var $count : Integer
	
	Repeat 
		$count+=1
		
		If ($this_index>=This.worker_limit_index)  // over or at limit
			$this_index:=0  // start back at the bottom
		End if 
		
		// how many jobs in this queue?
		$ok:=This.parameters.worker_queue[$this_index]<This.worker_queue_limit
		
		If (Not($ok)) && ($count>This.worker_limit_index)
			// we have checked all the workers
			Console_log(">>>>>>>>>>>>>>> Import process delayed for 1 sec <<<")
			DELAY PROCESS(Current process; 60*1)  // pause for 1 secs
			$count:=0
		Else 
			IDLE  // yield back
		End if 
		
	Until ($ok)
	
	var $workerName:="Importer_"+String($this_index)
	// increment the queue counter
	Use (This.parameters.worker_queue)
		This.parameters.worker_queue[$this_index]+=1
	End use 
	
	CALL WORKER($workerName; This.method; $chunk; This.parameters.worker_queue)
	
	This.next_worker_index:=$this_index+1
	
Function _msg($size : Real)
	Console_log(This.fileName+"; Data Read: "+String($size/1048576; "########0.00")+" mbs;  "+String(Round($size/This.fileSize*100; 3); "###0.000")+" % \r")
	