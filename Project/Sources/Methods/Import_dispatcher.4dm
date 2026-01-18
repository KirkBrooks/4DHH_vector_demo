//%attributes = {"preemptive":"capable"}
/* Purpose: 
 ------------------
Import_dispatcher ()
 Created by: Kirk Brooks as Designer, Created: 01/16/26, 13:42:02
*/

#DECLARE($parameters : Object)
var $importer : cs.Import_large_JSONL

$importer:=cs.Import_large_JSONL.new($parameters)
$importer.import_file()
