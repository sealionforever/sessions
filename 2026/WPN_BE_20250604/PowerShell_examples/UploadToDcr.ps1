# ENTER YOUR PARAMETERS
$MonitorToken = ""	# Your bearer token to the Az Monitor environment
$DCE_LogsIngestionEndpoint = ""		# The Logs Ingestion API url of the data collection endpoint you're using
$DCR_ImmutableId = ""	# The immutable id of the data collection rule you're using
$Tables = @()	<# A list of objects which should look like this:
					@{
						stream = "Custom-Applications_CL"	# this is the stream name that is defined in the data collection rule
						logs = $Applications				# this is the list of custom objects you're trying to upload to the law (make sure this is the same as defined in the dcr!)
					}
#>

foreach ($t in $Tables) {
	# Parameters
	$Uri = "$DCE_LogsIngestionEndpoint/dataCollectionRules/$DCR_ImmutableId/streams/$($t.stream)" + "?api-version=2023-01-01"
	$BatchSize = 500
	
	# Create headers
	$Headers = @{ "Authorization" = $MonitorToken; "Content-Type"  = "application/json" }
	$Pointer = 0
	do {
		# Set range for upload
		$a = $Pointer
		$b = $Pointer + $BatchSize - 1
		if ($b -ge $t.logs.Count) {
			$b =  $t.logs.Count - 1
		}
	
		# Create JSON object
		$JsonContent = $t.logs[$a..$b] | ConvertTo-Json -AsArray
		
		# Attempt posting to Data Collection Endpoint
		Invoke-RestMethod -Uri $Uri -Headers $Headers -Body $JsonContent -Method Post

		Write-Host "Uploaded $($b - $a) items to the data collection rule (index $a to $b)" -ForegroundColor Yellow
	
		# Moving up pointer
		$Pointer += $BatchSize
	} while ($Pointer -lt $t.logs.Count)
}
Write-Host "Done uploading!" -ForegroundColor Green