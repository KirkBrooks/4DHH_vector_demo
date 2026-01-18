/*  Import_dialog_controller class
 Created by: Kirk Brooks as Designer, Created: 01/17/26, 16:00:34
 ------------------
 The form controller for "Import_file_dlog"

*/

property file : 4D.File  // the JSONL file to be imported
property tables : Collection  // table names that will be written to 
property ruler_n_workers; ruler_queue_limit : Integer  //  ruler objects
property chunkSize : Integer
property method_name : Text
property truncate_tables : Boolean

property importer : cs.Import_large_JSONL  //  the class for importing large JSONL files
property parameters : Object  //  shared object



Class constructor
	var $params : Object:={}
	$params.ok_to_run:=False  //  set to true when run
	$params.path:=""
	$params.fileName:=""
	$params.fileSize:=0
	$params.method:=""
	$params.worker_queue:=[0; 0; 0; 0; 0; 0; 0]
	$params.chunkSize:=32000
	$params.worker_limit_index:=3  //  default is 4 workers
	$params.worker_queue_limit:=30  // max number of jobs to allow in queue
	This.parameters:=OB Copy($params; ck shared)
	
	This.method_name:=""
	This.chunkSize:=$params.chunkSize
	This.ruler_queue_limit:=$params.worker_queue_limit
	This.ruler_n_workers:=$params.worker_limit_index+1  //  number workers
	This.truncate_tables:=False
	
	//mark:  --- form events
Function handle_event($formEvent : Object)->$handled : Boolean
	$formEvent:=$formEvent || FORM Event
	$handled:=True
	
	Case of 
		: ($formEvent.objectName="ruler_@")
			This.handle_ruler($formEvent)
			
		: ($formEvent.objectName="chunkSize") && ($formEvent.code=On Data Change)
			This._set_parameter("chunkSize"; Form.chunkSize)
			
		: ($formEvent.objectName="method_name") && ($formEvent.code=On Data Change)
			This.handle_method_name($formEvent)
			
		: ($formEvent.objectName="btn_file")
			This.handle_btn_file($formEvent)
			
		: ($formEvent.objectName="btn_import")
			This.handle_btn_import($formEvent)
			
		Else 
			$handled:=False
	End case 
	
	//mark:  --- functions
Function handle_btn_import($formEvent : Object)
	If ($formEvent.code#On Clicked)
		return 
	End if 
	
	OBJECT SET ENABLED(*; "btn_import"; False)
	
	This._truncate_tables()
	Import_dispatcher(This.parameters)
	
Function handle_method_name($formEvent : Object)
	// is this a valid method?
	ARRAY TEXT($aMethods; 0)
	METHOD GET NAMES($aMethods; This.method_name)
	
	If (Size of array($aMethods)=0)
		ALERT("'"+This.method_name+"' is not a method.")
		return 
	End if 
	
	This._set_parameter("method"; Form.method_name)
	
	// extract the tables and dataclasses created in this method
	var $tables : Collection:=[]
	var $code : Text
	METHOD GET CODE(This.method_name; $code)
	
	ARRAY LONGINT($pos; 0)
	ARRAY LONGINT($len; 0)
	var $pattern : Text
	var $start : Integer
	
	//  classic code
	//  [^\]]+ rather than \w+ in case your table names ever contain spaces or special characters
	$pattern:="CREATE RECORD\\s*\\(\\[([^\\]]+)\\]\\)"
	$start:=1
	While (Match regex($pattern; $code; $start; $pos; $len))
		$tables.push(Substring($code; $pos{1}; $len{1}))
		$start:=$pos{0}+$len{0}
	End while 
	
	//  ORDA code
	//   \w+ assumes standard identifier naming
	$pattern:="ds\\.(\\w+)\\.new\\(\\)"
	$start:=1
	While (Match regex($pattern; $code; $start; $pos; $len))
		$tables.push(Substring($code; $pos{1}; $len{1}))
		$start:=$pos{0}+$len{0}
	End while 
	
	This.tables:=$tables.distinct()  // filter out duplicates
	OBJECT SET VALUE("table_names"; This.tables.join(", "))
	
Function handle_btn_file($formEvent : Object)
	If ($formEvent.code#On Clicked)
		return 
	End if 
	
	// choose a file for importing
	var $docName; $docType; $message; $defaultPath : Text
	var $options : Integer
	ARRAY TEXT($aDocs; 0)
	
	$options:=Allow alias files+Use sheet window
	$defaultPath:=""
	$docType:=".jsonl"
	$message:="Select JSONL document to import :"
	
	If (Select document($defaultPath; $docType; $message; $options; $aDocs)#"")
		This.file:=File($aDocs{1}; fk platform path)
		OBJECT SET VISIBLE(*; "btn_file"; False)
	End if 
	
Function handle_ruler($formEvent : Object)
	Case of 
		: ($formEvent.code#On Data Change)
			return 
		: ($formEvent.objectName="ruler_n_workers")
			This._set_parameter("worker_limit_index"; Form.worker_limit_index-1)  // -1 because the saved value is the collection index
			
		: ($formEvent.objectName="ruler_queue_limit")
			This._set_parameter("ruler_queue_limit"; Form.ruler_queue_limit)
			
	End case 
	
	
	
	//mark:  --- privates
Function _set_parameter($key : Text; $value)
	//  sets a value in the shared parameters object
	Use (This.parameters)
		This.parameters[$key]:=$value
	End use 
	
Function _truncate_tables
	var $f : 4D.Function
	var $table : Text
	
	If (This.truncate_tables)
		For each ($table; This.tables)
			$f:=Formula from string("TRUCATE TABLE(["+$table+"])")
			$f.call()
		End for each 
	End if 
	