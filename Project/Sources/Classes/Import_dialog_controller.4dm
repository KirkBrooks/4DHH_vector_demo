/*  Import_dialog_controller class
 Created by: Kirk Brooks as Designer, Created: 01/17/26, 16:00:34
 ------------------
 The form controller for "Import_file_dlog"

*/

property file : 4D.File  // the JSONL file to be imported
property tables : Collection  // table names that will be written to 

property importer : cs.Import_large_JSONL  //  the class for importing large JSONL files
property parameters : Object  //  shared object


Class constructor
	var $params : Object
	$params.path:=""
	$params.fileName:=""
	$params.fileSize:=0
	$params.chunkSize:=32000
	$params.method:=""
	$params.worker_queue:=[0; 0; 0; 0; 0; 0; 0]
	$params.worker_limit_index:=3  //  default is 4 workers
	$params.ok_to_run:=False  //  set to true when run
	$params.delay_ticks:=60*3  //  3 seconds
	
	
	
	This.parameters:=OB Copy($params; ck shared)
	