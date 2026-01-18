//%attributes = {"preemptive":"capable"}
/* Purpose: 
 ------------------
Import_data ()
 Created by: Kirk Brooks as Designer, Created: 01/16/26, 13:43:40
*/


var $path : Text
var $n_workers : Integer

$n_workers:=6

CONFIRM("Start the Product data import?")
If (ok=1)
	//  this file has the Product data in it
	$path:="4DworkDisk:4D_Happy_Hour:Vector Demo:4DHH_vector_demo:import files:meta_Electronics.jsonl"
	//Import_dispatcher($path; "Import_Product"; $n_workers)
End if 




CONFIRM("Start the Rating Data Import")
If (ok=1)
	TRUNCATE TABLE([Rating])
	TRUNCATE TABLE([RatingImage])
	//  this file has the Reviews data in it
	$path:="4DworkDisk:4D_Happy_Hour:Vector Demo:4DHH_vector_demo:import files:Electronics.jsonl"
	//Import_dispatcher($path; "Import_Rating"; $n_workers)
End if 
