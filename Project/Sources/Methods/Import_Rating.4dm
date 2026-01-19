//%attributes = {"preemptive":"capable"}
/*  Import_Rating method
 Created by: Claude, Created: 01/16/26
 ------------------
Processes a chunk of JSONL data for the Rating table.
Called by Import_large_JSONL class via CALL WORKER.

Each line in the chunk is a JSON object with Rating data from Electronics.jsonl
Also creates RatingImage records for ratings that have images.
*/

#DECLARE($chunk : Text; $workers : Collection)
Console_log("= = = Processing: "+Current process name)

var $lines : Collection
var $line : Text
var $obj : Object
var $rating : cs.RatingEntity
var $ratingImage : cs.RatingImageEntity
var $product : cs.ProductEntity
var $imageObj : Object
var $timestamp : Integer
var $date : Date
var $time : Time
var $isoTimestamp : Text

// Split the chunk into individual JSONL lines
$lines:=Split string($chunk; "}\n"; sk ignore empty strings+sk trim spaces)

For each ($line; $lines)
	// Parse the JSON line
	$obj:=JSON Parse($line+"}")
	
	If ($obj#Null)
		// Create new Rating entity
		$rating:=ds.Rating.new()
		
		// Map fields from JSON to Rating table
		$rating.rating:=$obj.rating
		$rating.title:=$obj.title
		$rating.text:=$obj.text
		$rating.asin:=$obj.asin
		$rating.parent_asin:=$obj.parent_asin
		$rating.user_id:=$obj.user_id
		$rating.helpful_vote:=$obj.helpful_vote
		$rating.verified_purchase:=$obj.verified_purchase
		$rating.timestamp:=$obj.timestamp
		$rating.save()
		
		// Create RatingImage records for any images
		If ($obj.images#Null) && ($obj.images.length>0)
			For each ($imageObj; $obj.images)
				$ratingImage:=ds.RatingImage.new()
				$ratingImage.FK_Rating:=$rating.PK
				$ratingImage.small_image_url:=$imageObj.small_image_url
				$ratingImage.medium_image_url:=$imageObj.medium_image_url
				$ratingImage.large_image_url:=$imageObj.large_image_url
				$ratingImage.attachment_type:=$imageObj.attachment_type
				$ratingImage.save()
			End for each 
		End if 
		
	End if 
End for each 

var $index : Integer:=Num(Current process name)  //  this is why the name of the worker is important

Use ($workers)
	$workers[$index]-=1  //  decrement this job
End use 

Console_log("* * * Processing Done: "+Current process name)
