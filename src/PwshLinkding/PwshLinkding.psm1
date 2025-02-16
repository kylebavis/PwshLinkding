# UPDATE ME: This is just example code. Replace this file's contents with your module code.

function New-LinkdingAuthHeader {
	<#
	.SYNOPSIS
	Generates an authentication header object for the Linkding API.
	.PARAMETER ApiKey
	The API key to use for authentication.
	.EXAMPLE
	$authHeader = New-LinkdingAuthHeader -ApiKey "your-api-key"
	#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[string] $ApiKey
	)

	$authHeader = @{
		Authorization = "Token $($ApiKey)"
	}

	Write-Output $authHeader
}

function Get-LinkdingBookmark {
	<#
	.SYNOPSIS
	Retrieves bookmark(s) from the Linkding API.
	.PARAMETER LinkdingUrl
	The URL of the Linkding instance to connect to.
	.PARAMETER ApiKey
	The API key to use for authentication.
	.PARAMETER Query
	String to pass to Linkding's search. This uses the same logic/syntax as the web UI
	.PARAMETER Limit
	Maximum number of bookmarks to return in each batch. Default is 100.
	.PARAMETER Archived
	Switch to include only archived bookmarks.
	.EXAMPLE
	Get-LinkdingBookmark -LinkdingUrl "https://linkding.example.com" -ApiKey "your-api-key" -Query "#example" -Limit 20
	#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[string] $LinkdingUrl,
		[Parameter(Mandatory = $true)]
		[string] $ApiKey,
		[Parameter(Mandatory = $false)]
		[string] $Query,
		[Parameter(Mandatory = $false)]
		[int] $Limit = 100,
		[Parameter()]
		[switch] $Archived
	)

	$uri = "$LinkdingUrl/api/bookmarks/"
	if ($Archived) {
		$uri += "archived/"
	}
	$uri += "?limit=$Limit"
	if ($Query) {
		$encodedQuery =  [System.Uri]::EscapeDataString($Query)
		$uri += "&q=$($encodedQuery)"
	}
	$initialResult = Invoke-RestMethod -Uri $uri -Headers (New-LinkdingAuthHeader -ApiKey $ApiKey)
	# if the result is paginated, we need to fetch all pages.
	$result = $initialResult.results
	while ($initialResult.next) {
		$initialResult = Invoke-RestMethod -Uri $initialResult.next -Headers (New-LinkdingAuthHeader -ApiKey $ApiKey)
		$result += $initialResult.results
	}

	Write-Output $result

}