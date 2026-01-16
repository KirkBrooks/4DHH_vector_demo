//%attributes = {}
/* Purpose: 
 ------------------
Import_data ()
 Created by: Kirk Brooks as Designer, Created: 01/16/26, 13:43:40
*/


var $path : Text

//  this file has the Product data in it
$path:="4DworkDisk:4D_Happy_Hour:Vector Demo:4DHH_vector_demo:import files:meta_Electronics.jsonl"

TRUNCATE TABLE([Product])

Import_dispatcher($path; "Import_Product")
