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
property Thermometer : Integer

property importer : cs.Import_large_JSONL  //  the class for importing large JSONL files
property parameters : Object  //  shared object
property table_metrics : Object
property time_series : Collection
property time_series_LB : Collection

Class constructor
	var $params : Object:={}
	$params.ok_to_run:=False  //  set to true when running
	$params.path:=""
	$params.fileName:=""
	$params.fileSize:=0
	$params.bytes_read:=0
	$params.method:=""
	$params.worker_queue:=[0; 0; 0; 0; 0; 0; 0; 0]
	$params.chunkSize:=32000
	$params.worker_limit_index:=3  //  default is 4 workers
	$params.worker_queue_limit:=30  // max number of jobs to allow in queue
	This.parameters:=OB Copy($params; ck shared)
	
	This.method_name:=""
	This.chunkSize:=$params.chunkSize
	This.ruler_queue_limit:=$params.worker_queue_limit
	This.ruler_n_workers:=$params.worker_limit_index+1  //  number workers
	This.truncate_tables:=False
	This.time_series:=[]
	OBJECT SET ENABLED(*; "btn_cancel_import"; False)
	
	//mark:  --- form events
Function handle_event($formEvent : Object)->$handled : Boolean
	$formEvent:=$formEvent || FORM Event
	$handled:=True
	
	Case of 
		: ($formEvent.code=On Load)
			SET TIMER(60*2)
			
		: ($formEvent.code=On Timer)
			This.handle_On_Timer()
			
		: ($formEvent.objectName="ruler_@")
			This.handle_ruler($formEvent)
			
		: ($formEvent.objectName="chunkSize") && ($formEvent.code=On Data Change)
			This._set_parameter("chunkSize"; Form.chunkSize)
			
		: ($formEvent.objectName="method_name") && ($formEvent.code=On Data Change)
			This.handle_method_name($formEvent)
			
		: ($formEvent.objectName="table_names") && ($formEvent.code=On Data Change)
			This.handle_table_names($formEvent)
			
		: ($formEvent.objectName="btn_file")
			This.handle_btn_file($formEvent)
			
		: ($formEvent.objectName="btn_import")
			This.handle_btn_import($formEvent)
			
		: ($formEvent.objectName="btn_cancel_import")
			This._set_parameter("ok_to_run"; False)
			This._kill_workers()
			This._set_parameter("worker_queue"; New shared collection(0; 0; 0; 0; 0; 0; 0; 0))
			Console_log("xxx  Import canceled:  "+This.parameters.fileName)
			
		: ($formEvent.objectName="btn_console") && ($formEvent.code=On Clicked)
			Console_log_show
			
		Else 
			$handled:=False
	End case 
	
	//mark:  --- functions
Function get_worker_queue_count : Integer
	return This.parameters.worker_queue.sum()
	
Function handle_On_Timer()
	
	If (This.get_worker_queue_count()=0)
		return 
	End if 
	
	// update the thermometer and metrics
	This.Thermometer:=Round(This.parameters.bytes_read/This.parameters.fileSize*100; 0)
	
	//  update current record counts for the tables
	var $table : Text
	var $delta; $recs_now; $sum_delta : Integer
	
	For each ($table; This.tables)
		$recs_now:=Formula from string("Records in table(["+$table+"])").call()
		$delta:=$recs_now-This.table_metrics[$table].recs_created  //  how many created since we last checked?
		$sum_delta+=$delta  //  running count of the deltas for this intervale
		This.table_metrics[$table].recs_created+=$delta
	End for each 
	
	// update time series
	This.time_series.push({\
		n: This.time_series.length+1; \
		recs: $delta; \
		workers: This.ruler_n_workers; \
		limit: This.ruler_queue_limit; \
		chunk: This.chunkSize})
	
	//  display the last 10 lines
	This.time_series_LB:=This.time_series.slice(This.time_series.length-10)
	
	OBJECT SET VALUE("worker_jobs"; JSON Stringify(This.parameters.worker_queue))
	
	//  update the web area
	This._update_web_area()
	// check if we're done
	This._check_if_done()
	
Function handle_btn_import($formEvent : Object)
	If ($formEvent.code#On Clicked)
		return 
	End if 
	
	If (Not(This._ok_to_run()))
		var $msg : Text:="Verify you have this information :\n"
		$msg+="   - the import file is .jsonl \n"
		$msg+="   - you entered the 4D method to handle the import data \n"
		$msg+="   - you entered the Table Name(s) where records will be created \n\n"
		ALERT($msg)
		return 
	End if 
	
	OBJECT SET ENABLED(*; "btn_import"; False)
	OBJECT SET ENABLED(*; "btn_cancel_import"; True)
	
	This._truncate_tables()
	This._set_parameter("ok_to_run"; True)
	// The dispatcher needs to run in its own Worker so this process can do things like update 
	// the metrics and web area
	This.time_series:=[]
	
	CALL WORKER("Import_dispatcher"; "Import_dispatcher"; This.parameters)
	
Function handle_table_names($formEvent : Object)
	// this object is enterable when app is compiled
	This.tables:=Split string(OBJECT Get value("table_names"); ","; sk ignore empty strings+sk trim spaces)  // filter out duplicates
	OBJECT SET VALUE("table_names"; This.tables.join(", "))
	This._setup_table_metrics()
	
Function handle_method_name($formEvent : Object)
	// is this a valid method? Can only test interpreted
	If (Is compiled mode)
		This._set_parameter("method"; Form.method_name)
		OBJECT SET ENTERABLE(*; "table_names"; True)
		return 
	End if 
	
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
	
	// set up table_metrics
	This._setup_table_metrics()
	
Function _setup_table_metrics
	var $table : Text
	This.table_metrics:={}
	
	For each ($table; This.tables)
		var $obj:={}
		$obj.start_recs:=Formula from string("Records in table(["+$table+"])").call()
		$obj.recs_created:=0
		This.table_metrics[$table]:=$obj
	End for each 
	
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
		
		// update the parameters
		This._set_parameter("fileSize"; This.file.size)
		This._set_parameter("path"; This.file.platformPath)
		This._set_parameter("name"; This.file.fullName)
	End if 
	
Function handle_ruler($formEvent : Object)
	Case of 
		: ($formEvent.code#On Data Change)
			return 
		: ($formEvent.objectName="ruler_n_workers")
			This._set_parameter("worker_limit_index"; This.ruler_n_workers-1)  // -1 because the saved value is the collection index
			
		: ($formEvent.objectName="ruler_queue_limit")
			This._set_parameter("ruler_queue_limit"; This.ruler_queue_limit)
			
	End case 
	
	//mark:  --- privates
Function _ok_to_run->$ok : Boolean
	// return true if there is a valid file and method
	$ok:=(This.parameters.path#"") && (This.parameters.method#"") && (This.tables#Null)
	
Function _check_if_done
	// we are done when there are no more jobs in any of the queues
	If (This.get_worker_queue_count()=0)
		This._set_parameter("ok_to_run"; False)
		This._kill_workers()
	End if 
	
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
			$f:=Formula from string("TRUNCATE TABLE(["+$table+"])")
			$f.call()
		End for each 
	End if 
	
Function _update_web_area()
	WA EXECUTE JAVASCRIPT FUNCTION(*; "webArea"; "Update_time_series"; *; This.time_series)
	
Function _kill_workers
	var $i : Integer
	For ($i; 0; 7)
		KILL WORKER("Importer_"+String($i))
	End for 
	