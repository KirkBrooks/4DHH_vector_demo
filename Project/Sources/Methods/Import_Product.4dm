//%attributes = {"preemptive":"capable"}
/*  Import_Product method
 Created by: Claude, Created: 01/16/26
 ------------------
Processes a chunk of JSONL data for the Product table.
Called by Import_large_JSONL class via CALL WORKER.

Each line in the chunk is a JSON object with Product data from meta_Electronics.jsonl
*/

#DECLARE($chunk : Text; $fileName : Text)
Console_log("Processing: "+$fileName+"; "+Current process name)

var $lines : Collection
var $line : Text
var $obj : Object
var $product : cs.ProductEntity
var $description : Collection
var $count : Integer


// Split the chunk into individual JSONL lines
$lines:=Split string($chunk; "\n"; sk ignore empty strings)

For each ($line; $lines)
	// Skip empty lines
	If (Length(Trim($line))>0)
		// Parse the JSON line
		$obj:=JSON Parse($line)
		
		If ($obj#Null)
			// Create new Product entity
			$product:=ds.Product.new()
			
			// Map fields from JSON to Product table
			$product.main_category:=$obj.main_category
			$product.title:=$obj.title
			$product.average_rating:=$obj.average_rating
			$product.price:=$obj.price
			$product.store:=$obj.store
			$product.parent_asin:=$obj.parent_asin
			$product.bought_together:=$obj.bought_together
			
			// Handle features - it's an array, join to text
			If ($obj.features#Null) && ($obj.features.length>0)
				$product.features:=$obj.features.join("\n")
			End if 
			
			// Handle description - it's an array, join to text
			If ($obj.description#Null) && ($obj.description.length>0)
				$product.description:=$obj.description.join("\n")
			End if 
			
			// Handle categories - it's an array, join to text
			If ($obj.categories#Null) && ($obj.categories.length>0)
				$product.categories:=$obj.categories.join(" > ")
			End if 
			
			// Handle images - store as JSON object
			If ($obj.images#Null)
				$product.images:=$obj.images
			End if 
			
			// Handle videos - store as JSON object
			If ($obj.videos#Null)
				$product.videos:=$obj.videos
			End if 
			
			// Handle details - store as JSON object
			If ($obj.details#Null)
				$product.details:=$obj.details
			End if 
			
			// Save the entity
			$product.save()
			
			$count+=1
		End if 
	End if 
End for each 

Console_log(Current process name+"; "+String($count)+" records created. ")
