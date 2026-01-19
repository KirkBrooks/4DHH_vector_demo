//  LOG_Paths
//  Single source of truth for all logserver paths
//  Usage: var $paths : cs.LOG_Paths := cs.LOG_Paths.new()

property serverFolder; projectFolder; logsFolder : 4D.Folder
property serverFile : 4D.File


Class constructor
	
	//  Get the Project folder directly, then escape sandbox
	//  fk database folder returns the Project folder path
	var $projectFolder : 4D.Folder
	$projectFolder:=Folder(Folder(fk database folder).platformPath; fk platform path).folder("Project")
	
	//  Server folder is inside Project
	This.serverFolder:=$projectFolder.folder("logserver")
	
	//  Store project folder for reference
	This.projectFolder:=$projectFolder
	
	//  Logs output folder (Data/Logs is sibling to Project folder)
	This.logsFolder:=$projectFolder.parent.folder("Data/Logs")
	
Function get serverFile : 4D.File
	return This.serverFolder.file("server.ts")
	
Function get configFile : 4D.File
	return This.serverFolder.file("config.json")
	
Function get bunFile->$file : 4D.File
	//  Priority: 1) bundled in logserver/bin, 2) system locations
	var $locations : Collection:=[]
	$locations.push(This.serverFolder.file("bin/bun"))
	$locations.push(This.serverFolder.file("/opt/homebrew/bin/bun"))
	$locations.push(This.serverFolder.file("/usr/local/bin/bun"))
	var $name : Text:=Folder(fk user preferences folder).name
	$locations.push(This.serverFolder.folder($name).file(".bun/bin/bun"))
	
	For each ($file; $locations)
		If ($file.exists)
			return $file
		End if 
	End for each 
	
	return Null
	
Function get uiFolder : 4D.Folder
	return This.serverFolder.folder("ui")
	
Function get queriesFolder : 4D.Folder
	return This.serverFolder.folder("queries")
	
Function get port : Integer
	var $config : Object
	
	If (This.configFile.exists)
		$config:=JSON Parse(This.configFile.getText())
		If ($config.port#Null)
			return Num($config.port)
		End if 
	End if 
	
	return 3333  // default
	
Function ensureLogsFolder
	//  Create logs folder if it doesn't exist
	If (Not(This.logsFolder.exists))
		This.logsFolder.create()
	End if 
	