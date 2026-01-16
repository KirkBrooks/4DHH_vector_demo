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

property path : Text  //  system path to the file
property fileName : Text
property chunkSize : Integer  // initial number of chunks to read
property fileSize : Real
property workers : Collection  // names of workers to call
property method : Text  // name of method to run on worker
property nextWorkerIndx : Integer
property elapsedSeconds : Integer  // how long the import took in seconds

Class constructor($path : Text; $method : Text; $workers : Collection)
	var $file : 4D.File:=File($path; fk platform path)
	If ($file.exists=False)
		ALERT("That file does not exist!")
		return 
	End if 
	
	This.fileName:=$file.name
	This.path:=$path
	This.fileSize:=$file.size
	This.chunkSize:=20000
	
	If ($method="")
		ALERT("You must pass a method to run for each imported chunk.")
		return 
	End if 
	This.method:=$method
	
	If ($workers.length=0)
		ALERT("You did not specify any workers to run the import method.")
		return 
	End if 
	This.workers:=$workers
	
Function import_file()
/*  Read a chunck of data and pass it to a worker for processing
The chunks will be passed to workers seqeuentially
*/
	var $text; $lastChar : Text
	var $importedSize : Real
	
	var $ms:=Milliseconds
	SET CHANNEL(10; This.path)
	This._msg(0)
	
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
			
		End if 
		
	Until ($text="")  //  End for 
	
	SET CHANNEL(11)  //  close the file
	This._msg(-1)
	This.elapsedSeconds:=(Milliseconds-$ms)/1000
	
Function _assign_chunk($chunk : Text)
	//  assigns this chunk to the next worker 
	CALL WORKER(This.workers[This.nextWorkerIndx]; This.method; $chunk)
	
	// set the next worker index
	If (This.nextWorkerIndx=This.workers.length)
		This.nextWorkerIndx:=0
	Else 
		This.nextWorkerIndx+=1
	End if 
	
Function _msg($size : Real)
	Console_log(This.fileName+"; Data Read: "+String($size/1048576; "########0.00")+" mbs\r")
	