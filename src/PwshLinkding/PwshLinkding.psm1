# UPDATE ME: This is just example code. Replace this file's contents with your module code.

function Get-LinkdingAuthHeader {
	<#
	.SYNOPSIS
	Generates an authentication header object for the Linkding API.
	.PARAMETER ApiKey
	The API key to use for authentication.
	.EXAMPLE
	$authHeader = Get-LinkdingAuthHeader -ApiKey "your-api-key"
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
		[Parameter(Mandatory = $false, ParameterSetName = "Query")]
		[string] $Query,
		[Parameter(Mandatory = $false, ParameterSetName = "Query")]
		[int] $Limit = 100,
		[Parameter(ParameterSetName = "Query")]
		[switch] $Archived,
		[Parameter(Mandatory = $true, ParameterSetName = "Id")]
		[int] $Id,
		[Parameter(Mandatory = $true, ParameterSetName = "URL")]
		[string] $URL
	)

	$uri = "$LinkdingUrl/api/bookmarks/"
	switch ($PSCmdlet.ParameterSetName) {
		"Query" {
			if ($Archived) {
				$uri += "archived/"
			}
			$uri += "?limit=$Limit"
			if ($Query) {
				$encodedQuery = [System.Uri]::EscapeDataString($Query)
				$uri += "&q=$($encodedQuery)"
			}
		}
		"Id" {
			$uri += "$($Id)/"
		}
		"URL" {
			$url = [System.Uri]::EscapeDataString($URL)
			$uri += "check/?url=$URL"
		}
	}

	Write-Verbose "Calling $uri"
	$initialResult = Invoke-RestMethod -Uri $uri -Headers (Get-LinkdingAuthHeader -ApiKey $ApiKey)
	# if the result is paginated, we need to fetch all pages.
	switch ($PSCmdlet.ParameterSetName) {
		"Query" {
			$result = $initialResult.results
			while ($initialResult.next) {
				$initialResult = Invoke-RestMethod -Uri $initialResult.next -Headers (Get-LinkdingAuthHeader -ApiKey $ApiKey)
				$result += $initialResult.results
			}
		}
		"Id" {
			$result = $initialResult
		}
		"URL" {
			$result = $initialResult.bookmark
		}
	}

	Write-Output $result

}

function New-LinkdingBookmark {
	<#
	.SYNOPSIS
	Creates a new bookmark
	.PARAMETER LinkdingUrl
	The URL of the Linkding instance to connect to.
	.PARAMETER ApiKey
	The API key to use for authentication.
	.PARAMETER URL
	The URL of the bookmark. This is mandatory
	.PARAMETER Title
	The title of the bookmark. This is optional. Linkding will try to scrape this if not provided.
	.PARAMETER Description
	The description of the bookmark. This is optional. Linkding will try to scrape this if not provided.
	.PARAMETER Tags
	Tags to add to the bookmark. This is optional. Supply an array of strings.
	.PARAMETER Archived
	Mark the bookmark as archived. This defaults to false.
	.PARAMETER Shared
	Mark the bookmark as shared. This defaults to false.
	.PARAMETER Unread
	Mark the bookmark as unread. This defaults to false.
	.PARAMETER Notes
	Notes to add to the bookmark. This is optional.
	.PARAMETER Force
	Do not check to see if the URL has already been bookmarked. This will overwrite any existing bookmark for the URL
	.EXAMPLE
	New-LinkdingBookmark -LinkdingUrl "https://linkding.example.com" -ApiKey "your-api
	#>
	[CmdletBinding(SupportsShouldProcess)]
	Param (
		[Parameter(Mandatory = $true)]
		[string] $LinkdingUrl,
		[Parameter(Mandatory = $true)]
		[string] $ApiKey,
		[Parameter(Mandatory = $true)]
		[string] $URL,
		[Parameter(Mandatory = $false)]
		[string] $Title,
		[Parameter(Mandatory = $false)]
		[string] $Description,
		[Parameter(Mandatory = $false)]
		[string[]] $Tags,
		[Parameter(Mandatory = $false)]
		[bool] $Archived=$false,
		[Parameter(Mandatory = $false)]
		[bool] $Shared=$false,
		[Parameter(Mandatory = $false)]
		[bool] $Unread=$false,
		[Parameter(Mandatory = $false)]
		[string] $Notes,
		[Parameter()][switch] $Force
	)

	$authHeader = Get-LinkdingAuthHeader -ApiKey $ApiKey
	$uri = "$LinkdingUrl/api/bookmarks/"
	$payload = @{
		url = $URL
		is_archived = $Archived
		unread = $Unread
		shared = $Shared
	}
	if ($Title) {$payload.title = $Title}
	if ($Description) {$payload.description = $Description}
	if ($Tags) {$payload.tag_names = $Tags}
	if ($Notes) {$payload.notes = $Notes}
	$body = $payload | ConvertTo-Json

	if (-not $Force) {
		$existing = Get-LinkdingBookmark -LinkdingUrl $LinkdingUrl -ApiKey $ApiKey -URL $URL
		if ($existing) {
			Write-Warning "Bookmark already exists for $URL. Use -Force to overwrite."
			return
		}
	}

	if ($PSCmdlet.ShouldProcess($URL, "Create bookmark")) {
		Write-Verbose "Request payload: $body"
		Invoke-RestMethod -Uri $uri -Method Post -Headers $authHeader -Body $body -ContentType "application/json"
	}
}

function Remove-Linkdingbookmark {
	<#
	.SYNOPSIS
	Removes a bookmark from Linkding
	.PARAMETER LinkdingUrl
	The URL of the Linkding instance to connect to. This is mandatory unless you are piping in a bookmark object
	.PARAMETER ApiKey
	The API key to use for authentication. This is mandatory unless you are piping in a bookmark object
	.PARAMETER Id
	The ID of the bookmark to remove.
	.PARAMETER URL
	The URL of the bookmark to remove.
	.EXAMPLE
	Remove-Linkdingbookmark -LinkdingUrl "https://linkding.example.com" -ApiKey "your-api-key" -Id 123
	.
	#>
	[CmdletBinding(SupportsShouldProcess)]
	Param (
		[Parameter(Mandatory = $true, ParameterSetName = "Id")]
		$Id,
		[Parameter(Mandatory = $true)]
		[string] $LinkdingUrl,
		[Parameter(Mandatory = $true, ParameterSetName = "URL")]
		[string] $URL,
		[Parameter(Mandatory = $true)]
		[string] $ApiKey
	)

	if ($url) {
		$bookmark = Get-LinkdingBookmark -LinkdingUrl $LinkdingUrl -ApiKey $ApiKey -URL $URL
		if (-not $bookmark) {
			Write-Warning "No bookmark found for $URL"
			return
		}
		$id = $bookmark.id
	}

	$uri = "$LinkdingUrl/api/bookmarks/$Id/"
	if ($PSCmdlet.ShouldProcess($Id, "Delete bookmark")) {
		Invoke-RestMethod -Uri $uri -Method Delete -Headers (Get-LinkdingAuthHeader -ApiKey $ApiKey)
	}
}

function Set-LinkdingBookmark {
	<#
	.SYNOPSIS
	Archives or unarchives a bookmark in Linkding.
	.PARAMETER LinkdingUrl
	The URL of the Linkding instance to connect to.
	.PARAMETER ApiKey
	The API key to use for authentication.
	.PARAMETER Id
	The ID of the bookmark to modify.
	.PARAMETER URL
	The URL of the bookmark to modify.
	.PARAMETER Archive
	Switch to archive the bookmark. If not specified, the bookmark will be unarchived.
	.EXAMPLE
	Set-LinkdingBookmark -LinkdingUrl "https://linkding.example.com" -ApiKey "your-api-key" -Id 123 -Archived $true
	#>
	[CmdletBinding(SupportsShouldProcess)]
	Param (
		[Parameter(Mandatory = $true, ParameterSetName = "Id")]
		[int] $Id,
		[Parameter(Mandatory = $true)]
		[string] $LinkdingUrl,
		[Parameter(Mandatory = $true, ParameterSetName = "URL")]
		[string] $URL,
		[Parameter(Mandatory = $true)]
		[string] $ApiKey,
		[Parameter(Mandatory = $true)]
		[bool] $Archived
	)

	if ($URL) {
		$bookmark = Get-LinkdingBookmark -LinkdingUrl $LinkdingUrl -ApiKey $ApiKey -URL $URL
		if (-not $bookmark) {
			Write-Warning "No bookmark found for $URL"
			return
		}
		$Id = $bookmark.id
	}

	$action = if ($Archived) { "archive" } else { "unarchive" }
	$uri = "$LinkdingUrl/api/bookmarks/$Id/$action/"

	if ($PSCmdlet.ShouldProcess($Id, "$action bookmark")) {
		Invoke-RestMethod -Uri $uri -Method Post -Headers (Get-LinkdingAuthHeader -ApiKey $ApiKey)
	}
}