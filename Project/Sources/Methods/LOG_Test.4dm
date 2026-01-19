//%attributes = {"invisible":false,"preemptive":"capable"}
//  LOG_Test
//  Test method to verify log server is working
//  Run this after starting the database to test the logging system

var $result : Object

//  Check if server is running
If (Storage.logServer=Null)
	ALERT("Log server not running. Call LOG_Server_Start first.")
	return 
End if 

ALERT("Log server running on port "+String(Storage.logServer.port)+"\n\nSending test entries...")

//  Send some test entries
LOG_Entry("test_kb"; "info"; "Test message 1 - info level")
LOG_Entry("test_kb"; "debug"; "Test message 2 - debug level")
LOG_Entry("test_kb"; "warn"; "Test message 3 - warning level")
LOG_Entry("test_kb"; "error"; "Test message 4 - error level")

//  Test with data object
LOG_Entry("test"; "info"; "Test with data"; New object(\
"userId"; 12345; \
"action"; "login"; \
"timestamp"; Current time(*)))

//  Test different channel
LOG_Entry("app"; "info"; "Application event"; New object("version"; "1.0.0"))

ALERT("Test entries sent!\n\nCheck:\n• Browser: http://localhost:"+String(Storage.logServer.port)+"\n• Files in Data/Logs/")
