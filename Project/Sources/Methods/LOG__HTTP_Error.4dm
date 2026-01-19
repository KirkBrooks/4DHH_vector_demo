//%attributes = {"invisible":true,"preemptive":"capable"}
  //  LOG__HTTP_Error
  //  Callback for async HTTP error - intentionally minimal
  //  We don't want logging failures to cause problems
  //  $1 : 4D.HTTPRequest object

  //  Could increment an error counter if needed for diagnostics
  //  But generally we stay silent - fire and forget means accepting some loss
  
  //  Uncomment for debugging:
  //  var $req : 4D.HTTPRequest
  //  $req:=$1
  //  TRACE  // will show $req.errors in debugger
