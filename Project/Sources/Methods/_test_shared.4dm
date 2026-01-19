//%attributes = {}


var $class : cs.testClass
$class:=cs.testClass.new()

var $n : Integer:=Formula from string("Records in table([Product])").call()

$projectRoot:=Folder(Folder(fk database folder; *).platformPath; fk platform path)
