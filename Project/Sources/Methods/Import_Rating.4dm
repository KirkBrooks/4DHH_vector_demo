//%attributes = {}
/*  Import_Rating method
 Created by: Claude, Created: 01/16/26
 ------------------
Processes a chunk of JSONL data for the Rating table.
Called by Import_large_JSONL class via CALL WORKER.

Each line in the chunk is a JSON object with Rating data from Electronics.jsonl
Also creates RatingImage records for ratings that have images.
*/

#DECLARE($chunk : Text; $fileName : Text)
Console_log("Processing: "+$fileName+"; "+Current process name)

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
$lines:=Split string($chunk; "\n"; sk ignore empty strings)

For each ($line; $lines)
	// Skip empty lines
	If (Length(Trim($line))>0)
		// Parse the JSON line
		$obj:=JSON Parse($line)
		
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
			
			// Convert timestamp (milliseconds) to ISO 8601 GMT format
			If ($obj.timestamp#Null)
				// Convert milliseconds to seconds for 4D
				$timestamp:=$obj.timestamp/1000
				// Create date/time from Unix timestamp
				$date:=Add to date(!1970-01-01!; 0; 0; $timestamp/86400)
				$time:=Time(Mod($timestamp; 86400))
				// Format as ISO 8601: YYYY-MM-DDTHH:MM:SSZ
				$isoTimestamp:=String($date; ISO date GMT)+String($time; ISO date GMT)
				$rating.timestamp:=$isoTimestamp
			End if 
			
			// Look up the Product by parent_asin and set FK_Product
			If ($obj.parent_asin#Null) && ($obj.parent_asin#"")
				$product:=ds.Product.query("parent_asin = :1"; $obj.parent_asin).first()
				If ($product#Null)
					$rating.FK_Product:=$product.PK
				End if 
			End if 
			
			// Save the Rating entity first to get its PK
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
	End if 
End for each 
