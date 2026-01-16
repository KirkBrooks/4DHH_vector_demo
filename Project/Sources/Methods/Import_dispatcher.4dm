//%attributes = {"preemptive":"capable"}
/* Purpose: 
 ------------------
Import_dispatcher ()
 Created by: Kirk Brooks as Designer, Created: 01/16/26, 13:42:02
*/

#DECLARE($importFile : Text; $method : Text)

var $importer : cs.Import_large_JSONL
var $workers : Collection:=["importer_1"; "importer_2"; "importer_3"; "importer_4"; "importer_5"]

$importer:=cs.Import_large_JSONL.new($importFile; $method; $workers)
$importer.import_file()
