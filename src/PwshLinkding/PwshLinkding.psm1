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

function Invoke-LinkdingPagedRequest {
	<#
	.SYNOPSIS
	Calls a paginated Linkding API endpoint and returns the results from all pages.
	.PARAMETER Uri
	The URI of the first page.
	.PARAMETER ApiKey
	The API key to use for authentication.
	#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[string] $Uri,
		[Parameter(Mandatory = $true)]
		[string] $ApiKey
	)

	$headers = Get-LinkdingAuthHeader -ApiKey $ApiKey
	$next = $Uri
	while ($next) {
		Write-Verbose "Calling $next"
		$page = Invoke-RestMethod -Uri $next -Headers $headers
		Write-Output $page.results
		$next = $page.next
	}
}

function ConvertTo-LinkdingDate {
	<#
	.SYNOPSIS
	Formats a date as an ISO 8601 UTC string for use in Linkding API query parameters.
	#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[datetime] $Date
	)

	$Date.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ", [System.Globalization.CultureInfo]::InvariantCulture)
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
	.PARAMETER Offset
	Index from which to start returning results.
	.PARAMETER ModifiedSince
	Only return bookmarks modified after this date.
	.PARAMETER AddedSince
	Only return bookmarks added after this date.
	.PARAMETER BundleId
	Only return bookmarks matched by the bundle with this ID.
	.PARAMETER Archived
	Switch to include only archived bookmarks.
	.PARAMETER Id
	The ID of the bookmark to retrieve.
	.PARAMETER URL
	The URL of the bookmark to retrieve.
	.EXAMPLE
	Get-LinkdingBookmark -LinkdingUrl "https://linkding.example.com" -ApiKey "your-api-key" -Query "#example" -Limit 20
	.EXAMPLE
	Get-LinkdingBookmark -LinkdingUrl "https://linkding.example.com" -ApiKey "your-api-key" -ModifiedSince (Get-Date).AddDays(-7)
	#>
	[CmdletBinding(DefaultParameterSetName = "Query")]
	Param (
		[Parameter(Mandatory = $true)]
		[string] $LinkdingUrl,
		[Parameter(Mandatory = $true)]
		[string] $ApiKey,
		[Parameter(Mandatory = $false, ParameterSetName = "Query")]
		[string] $Query,
		[Parameter(Mandatory = $false, ParameterSetName = "Query")]
		[int] $Limit = 100,
		[Parameter(Mandatory = $false, ParameterSetName = "Query")]
		[int] $Offset,
		[Parameter(Mandatory = $false, ParameterSetName = "Query")]
		[datetime] $ModifiedSince,
		[Parameter(Mandatory = $false, ParameterSetName = "Query")]
		[datetime] $AddedSince,
		[Parameter(Mandatory = $false, ParameterSetName = "Query")]
		[int] $BundleId,
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
			if ($Offset) {
				$uri += "&offset=$Offset"
			}
			if ($Query) {
				$uri += "&q=$([System.Uri]::EscapeDataString($Query))"
			}
			if ($PSBoundParameters.ContainsKey('ModifiedSince')) {
				$uri += "&modified_since=$([System.Uri]::EscapeDataString((ConvertTo-LinkdingDate $ModifiedSince)))"
			}
			if ($PSBoundParameters.ContainsKey('AddedSince')) {
				$uri += "&added_since=$([System.Uri]::EscapeDataString((ConvertTo-LinkdingDate $AddedSince)))"
			}
			if ($PSBoundParameters.ContainsKey('BundleId')) {
				$uri += "&bundle=$BundleId"
			}
			Invoke-LinkdingPagedRequest -Uri $uri -ApiKey $ApiKey
		}
		"Id" {
			$uri += "$($Id)/"
			Write-Verbose "Calling $uri"
			Invoke-RestMethod -Uri $uri -Headers (Get-LinkdingAuthHeader -ApiKey $ApiKey)
		}
		"URL" {
			$check = Get-LinkdingBookmarkCheck -LinkdingUrl $LinkdingUrl -ApiKey $ApiKey -URL $URL
			Write-Output $check.bookmark
		}
	}
}

function Get-LinkdingBookmarkCheck {
	<#
	.SYNOPSIS
	Checks whether a URL is bookmarked, and returns scraped metadata and auto tags for it.
	.DESCRIPTION
	Returns an object with the properties bookmark (null if the URL is not bookmarked), metadata, and auto_tags.
	.PARAMETER LinkdingUrl
	The URL of the Linkding instance to connect to.
	.PARAMETER ApiKey
	The API key to use for authentication.
	.PARAMETER URL
	The URL to check.
	.EXAMPLE
	Get-LinkdingBookmarkCheck -LinkdingUrl "https://linkding.example.com" -ApiKey "your-api-key" -URL "https://example.com"
	#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[string] $LinkdingUrl,
		[Parameter(Mandatory = $true)]
		[string] $ApiKey,
		[Parameter(Mandatory = $true)]
		[string] $URL
	)

	$uri = "$LinkdingUrl/api/bookmarks/check/?url=$([System.Uri]::EscapeDataString($URL))"
	Write-Verbose "Calling $uri"
	Invoke-RestMethod -Uri $uri -Headers (Get-LinkdingAuthHeader -ApiKey $ApiKey)
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
	.PARAMETER DisableScraping
	Do not scrape the title and description from the website.
	.PARAMETER Force
	Do not check to see if the URL has already been bookmarked. This will overwrite any existing bookmark for the URL
	.EXAMPLE
	New-LinkdingBookmark -LinkdingUrl "https://linkding.example.com" -ApiKey "your-api-key" -URL "https://example.com" -Tags "example"
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
		[Parameter()][switch] $DisableScraping,
		[Parameter()][switch] $Force
	)

	$authHeader = Get-LinkdingAuthHeader -ApiKey $ApiKey
	$uri = "$LinkdingUrl/api/bookmarks/"
	if ($DisableScraping) {
		$uri += "?disable_scraping"
	}
	$payload = @{
		url = $URL
		is_archived = $Archived
		unread = $Unread
		shared = $Shared
	}
	if ($Title) {$payload.title = $Title}
	if ($Description) {$payload.description = $Description}
	if ($Tags) {$payload.tag_names = @($Tags)}
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

function Remove-LinkdingBookmark {
	<#
	.SYNOPSIS
	Removes a bookmark from Linkding
	.PARAMETER LinkdingUrl
	The URL of the Linkding instance to connect to.
	.PARAMETER ApiKey
	The API key to use for authentication.
	.PARAMETER Id
	The ID of the bookmark to remove.
	.PARAMETER URL
	The URL of the bookmark to remove.
	.EXAMPLE
	Remove-LinkdingBookmark -LinkdingUrl "https://linkding.example.com" -ApiKey "your-api-key" -Id 123
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
		[string] $ApiKey
	)

	if ($URL) {
		$bookmark = Get-LinkdingBookmark -LinkdingUrl $LinkdingUrl -ApiKey $ApiKey -URL $URL
		if (-not $bookmark) {
			Write-Warning "No bookmark found for $URL"
			return
		}
		$Id = $bookmark.id
	}

	$uri = "$LinkdingUrl/api/bookmarks/$Id/"
	if ($PSCmdlet.ShouldProcess($Id, "Delete bookmark")) {
		Invoke-RestMethod -Uri $uri -Method Delete -Headers (Get-LinkdingAuthHeader -ApiKey $ApiKey)
	}
}

function Set-LinkdingBookmark {
	<#
	.SYNOPSIS
	Updates a bookmark in Linkding.
	.DESCRIPTION
	Only the supplied fields are modified. Archiving and unarchiving use the dedicated archive endpoints.
	.PARAMETER LinkdingUrl
	The URL of the Linkding instance to connect to.
	.PARAMETER ApiKey
	The API key to use for authentication.
	.PARAMETER Id
	The ID of the bookmark to modify.
	.PARAMETER URL
	The URL of the bookmark to modify.
	.PARAMETER NewURL
	A new URL for the bookmark.
	.PARAMETER Title
	The new title of the bookmark.
	.PARAMETER Description
	The new description of the bookmark.
	.PARAMETER Notes
	The new notes of the bookmark.
	.PARAMETER Tags
	The tags of the bookmark. This replaces the existing tags. Supply an empty array to remove all tags.
	.PARAMETER Unread
	Mark the bookmark as read or unread.
	.PARAMETER Shared
	Mark the bookmark as shared or not shared.
	.PARAMETER Archived
	Archive ($true) or unarchive ($false) the bookmark.
	.EXAMPLE
	Set-LinkdingBookmark -LinkdingUrl "https://linkding.example.com" -ApiKey "your-api-key" -Id 123 -Archived $true
	.EXAMPLE
	Set-LinkdingBookmark -LinkdingUrl "https://linkding.example.com" -ApiKey "your-api-key" -URL "https://example.com" -Title "Example" -Tags "tag1","tag2"
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
		[Parameter(Mandatory = $false)]
		[string] $NewURL,
		[Parameter(Mandatory = $false)]
		[string] $Title,
		[Parameter(Mandatory = $false)]
		[string] $Description,
		[Parameter(Mandatory = $false)]
		[string] $Notes,
		[Parameter(Mandatory = $false)]
		[AllowEmptyCollection()]
		[string[]] $Tags,
		[Parameter(Mandatory = $false)]
		[bool] $Unread,
		[Parameter(Mandatory = $false)]
		[bool] $Shared,
		[Parameter(Mandatory = $false)]
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

	$authHeader = Get-LinkdingAuthHeader -ApiKey $ApiKey
	$payload = @{}
	if ($PSBoundParameters.ContainsKey('NewURL')) {$payload.url = $NewURL}
	if ($PSBoundParameters.ContainsKey('Title')) {$payload.title = $Title}
	if ($PSBoundParameters.ContainsKey('Description')) {$payload.description = $Description}
	if ($PSBoundParameters.ContainsKey('Notes')) {$payload.notes = $Notes}
	if ($PSBoundParameters.ContainsKey('Tags')) {$payload.tag_names = @($Tags)}
	if ($PSBoundParameters.ContainsKey('Unread')) {$payload.unread = $Unread}
	if ($PSBoundParameters.ContainsKey('Shared')) {$payload.shared = $Shared}

	if ($payload.Count -gt 0) {
		$body = ConvertTo-Json -InputObject $payload
		if ($PSCmdlet.ShouldProcess($Id, "Update bookmark")) {
			Write-Verbose "Request payload: $body"
			Invoke-RestMethod -Uri "$LinkdingUrl/api/bookmarks/$Id/" -Method Patch -Headers $authHeader -Body $body -ContentType "application/json"
		}
	}

	if ($PSBoundParameters.ContainsKey('Archived')) {
		$action = if ($Archived) { "archive" } else { "unarchive" }
		if ($PSCmdlet.ShouldProcess($Id, "$action bookmark")) {
			Invoke-RestMethod -Uri "$LinkdingUrl/api/bookmarks/$Id/$action/" -Method Post -Headers $authHeader
		}
	}
}

function Get-LinkdingBookmarkAsset {
	<#
	.SYNOPSIS
	Retrieves the asset(s) of a bookmark.
	.PARAMETER LinkdingUrl
	The URL of the Linkding instance to connect to.
	.PARAMETER ApiKey
	The API key to use for authentication.
	.PARAMETER BookmarkId
	The ID of the bookmark.
	.PARAMETER Id
	The ID of a single asset to retrieve. If omitted, all assets of the bookmark are returned.
	.EXAMPLE
	Get-LinkdingBookmarkAsset -LinkdingUrl "https://linkding.example.com" -ApiKey "your-api-key" -BookmarkId 123
	#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[string] $LinkdingUrl,
		[Parameter(Mandatory = $true)]
		[string] $ApiKey,
		[Parameter(Mandatory = $true)]
		[int] $BookmarkId,
		[Parameter(Mandatory = $false)]
		[int] $Id
	)

	$uri = "$LinkdingUrl/api/bookmarks/$BookmarkId/assets/"
	if ($PSBoundParameters.ContainsKey('Id')) {
		$uri += "$Id/"
		Write-Verbose "Calling $uri"
		Invoke-RestMethod -Uri $uri -Headers (Get-LinkdingAuthHeader -ApiKey $ApiKey)
	}
	else {
		Invoke-LinkdingPagedRequest -Uri $uri -ApiKey $ApiKey
	}
}

function Save-LinkdingBookmarkAsset {
	<#
	.SYNOPSIS
	Downloads a bookmark asset to a file.
	.PARAMETER LinkdingUrl
	The URL of the Linkding instance to connect to.
	.PARAMETER ApiKey
	The API key to use for authentication.
	.PARAMETER BookmarkId
	The ID of the bookmark.
	.PARAMETER Id
	The ID of the asset to download.
	.PARAMETER Path
	The file path to save the asset to.
	.EXAMPLE
	Save-LinkdingBookmarkAsset -LinkdingUrl "https://linkding.example.com" -ApiKey "your-api-key" -BookmarkId 123 -Id 1 -Path ./snapshot.html.gz
	#>
	[CmdletBinding(SupportsShouldProcess)]
	Param (
		[Parameter(Mandatory = $true)]
		[string] $LinkdingUrl,
		[Parameter(Mandatory = $true)]
		[string] $ApiKey,
		[Parameter(Mandatory = $true)]
		[int] $BookmarkId,
		[Parameter(Mandatory = $true)]
		[int] $Id,
		[Parameter(Mandatory = $true)]
		[string] $Path
	)

	$uri = "$LinkdingUrl/api/bookmarks/$BookmarkId/assets/$Id/download/"
	$outFile = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($Path)
	if ($PSCmdlet.ShouldProcess($outFile, "Download asset $Id")) {
		Invoke-WebRequest -Uri $uri -Headers (Get-LinkdingAuthHeader -ApiKey $ApiKey) -OutFile $outFile -UseBasicParsing
		Get-Item -LiteralPath $outFile
	}
}

function Add-LinkdingBookmarkAsset {
	<#
	.SYNOPSIS
	Uploads a file as an asset of a bookmark.
	.PARAMETER LinkdingUrl
	The URL of the Linkding instance to connect to.
	.PARAMETER ApiKey
	The API key to use for authentication.
	.PARAMETER BookmarkId
	The ID of the bookmark.
	.PARAMETER Path
	The path of the file to upload.
	.EXAMPLE
	Add-LinkdingBookmarkAsset -LinkdingUrl "https://linkding.example.com" -ApiKey "your-api-key" -BookmarkId 123 -Path ./example.pdf
	#>
	[CmdletBinding(SupportsShouldProcess)]
	Param (
		[Parameter(Mandatory = $true)]
		[string] $LinkdingUrl,
		[Parameter(Mandatory = $true)]
		[string] $ApiKey,
		[Parameter(Mandatory = $true)]
		[int] $BookmarkId,
		[Parameter(Mandatory = $true)]
		[string] $Path
	)

	$file = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
	$uri = "$LinkdingUrl/api/bookmarks/$BookmarkId/assets/upload/"
	if (-not $PSCmdlet.ShouldProcess($file, "Upload asset to bookmark $BookmarkId")) {
		return
	}

	# Invoke-RestMethod -Form is not available in Windows PowerShell, so build the multipart request manually.
	Add-Type -AssemblyName System.Net.Http
	$client = New-Object System.Net.Http.HttpClient
	$content = New-Object System.Net.Http.MultipartFormDataContent
	$stream = [System.IO.File]::OpenRead($file)
	try {
		$client.DefaultRequestHeaders.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Token", $ApiKey)
		$fileContent = New-Object System.Net.Http.StreamContent($stream)
		$fileContent.Headers.ContentType = New-Object System.Net.Http.Headers.MediaTypeHeaderValue("application/octet-stream")
		$content.Add($fileContent, "file", [System.IO.Path]::GetFileName($file))
		$response = $client.PostAsync($uri, $content).GetAwaiter().GetResult()
		$responseBody = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
		if (-not $response.IsSuccessStatusCode) {
			throw "Asset upload failed with status $([int]$response.StatusCode): $responseBody"
		}
		$responseBody | ConvertFrom-Json
	}
	finally {
		$stream.Dispose()
		$content.Dispose()
		$client.Dispose()
	}
}

function Remove-LinkdingBookmarkAsset {
	<#
	.SYNOPSIS
	Deletes an asset of a bookmark.
	.PARAMETER LinkdingUrl
	The URL of the Linkding instance to connect to.
	.PARAMETER ApiKey
	The API key to use for authentication.
	.PARAMETER BookmarkId
	The ID of the bookmark.
	.PARAMETER Id
	The ID of the asset to delete.
	.EXAMPLE
	Remove-LinkdingBookmarkAsset -LinkdingUrl "https://linkding.example.com" -ApiKey "your-api-key" -BookmarkId 123 -Id 1
	#>
	[CmdletBinding(SupportsShouldProcess)]
	Param (
		[Parameter(Mandatory = $true)]
		[string] $LinkdingUrl,
		[Parameter(Mandatory = $true)]
		[string] $ApiKey,
		[Parameter(Mandatory = $true)]
		[int] $BookmarkId,
		[Parameter(Mandatory = $true)]
		[int] $Id
	)

	$uri = "$LinkdingUrl/api/bookmarks/$BookmarkId/assets/$Id/"
	if ($PSCmdlet.ShouldProcess($Id, "Delete asset")) {
		Invoke-RestMethod -Uri $uri -Method Delete -Headers (Get-LinkdingAuthHeader -ApiKey $ApiKey)
	}
}

function Get-LinkdingTag {
	<#
	.SYNOPSIS
	Retrieves tag(s) from Linkding.
	.PARAMETER LinkdingUrl
	The URL of the Linkding instance to connect to.
	.PARAMETER ApiKey
	The API key to use for authentication.
	.PARAMETER Id
	The ID of a single tag to retrieve. If omitted, all tags are returned.
	.PARAMETER Limit
	Maximum number of tags to return in each batch. Default is 100.
	.EXAMPLE
	Get-LinkdingTag -LinkdingUrl "https://linkding.example.com" -ApiKey "your-api-key"
	#>
	[CmdletBinding(DefaultParameterSetName = "List")]
	Param (
		[Parameter(Mandatory = $true)]
		[string] $LinkdingUrl,
		[Parameter(Mandatory = $true)]
		[string] $ApiKey,
		[Parameter(Mandatory = $true, ParameterSetName = "Id")]
		[int] $Id,
		[Parameter(Mandatory = $false, ParameterSetName = "List")]
		[int] $Limit = 100
	)

	if ($PSCmdlet.ParameterSetName -eq "Id") {
		$uri = "$LinkdingUrl/api/tags/$Id/"
		Write-Verbose "Calling $uri"
		Invoke-RestMethod -Uri $uri -Headers (Get-LinkdingAuthHeader -ApiKey $ApiKey)
	}
	else {
		Invoke-LinkdingPagedRequest -Uri "$LinkdingUrl/api/tags/?limit=$Limit" -ApiKey $ApiKey
	}
}

function New-LinkdingTag {
	<#
	.SYNOPSIS
	Creates a new tag.
	.PARAMETER LinkdingUrl
	The URL of the Linkding instance to connect to.
	.PARAMETER ApiKey
	The API key to use for authentication.
	.PARAMETER Name
	The name of the tag.
	.EXAMPLE
	New-LinkdingTag -LinkdingUrl "https://linkding.example.com" -ApiKey "your-api-key" -Name "example"
	#>
	[CmdletBinding(SupportsShouldProcess)]
	Param (
		[Parameter(Mandatory = $true)]
		[string] $LinkdingUrl,
		[Parameter(Mandatory = $true)]
		[string] $ApiKey,
		[Parameter(Mandatory = $true)]
		[string] $Name
	)

	$body = @{ name = $Name } | ConvertTo-Json
	if ($PSCmdlet.ShouldProcess($Name, "Create tag")) {
		Invoke-RestMethod -Uri "$LinkdingUrl/api/tags/" -Method Post -Headers (Get-LinkdingAuthHeader -ApiKey $ApiKey) -Body $body -ContentType "application/json"
	}
}

function Remove-LinkdingTag {
	<#
	.SYNOPSIS
	Deletes a tag.
	.PARAMETER LinkdingUrl
	The URL of the Linkding instance to connect to.
	.PARAMETER ApiKey
	The API key to use for authentication.
	.PARAMETER Id
	The ID of the tag to delete.
	.EXAMPLE
	Remove-LinkdingTag -LinkdingUrl "https://linkding.example.com" -ApiKey "your-api-key" -Id 5
	#>
	[CmdletBinding(SupportsShouldProcess)]
	Param (
		[Parameter(Mandatory = $true)]
		[string] $LinkdingUrl,
		[Parameter(Mandatory = $true)]
		[string] $ApiKey,
		[Parameter(Mandatory = $true)]
		[int] $Id
	)

	if ($PSCmdlet.ShouldProcess($Id, "Delete tag")) {
		Invoke-RestMethod -Uri "$LinkdingUrl/api/tags/$Id/" -Method Delete -Headers (Get-LinkdingAuthHeader -ApiKey $ApiKey)
	}
}

function Get-LinkdingBundle {
	<#
	.SYNOPSIS
	Retrieves bundle(s) from Linkding.
	.PARAMETER LinkdingUrl
	The URL of the Linkding instance to connect to.
	.PARAMETER ApiKey
	The API key to use for authentication.
	.PARAMETER Id
	The ID of a single bundle to retrieve. If omitted, all bundles are returned.
	.PARAMETER Limit
	Maximum number of bundles to return in each batch. Default is 100.
	.EXAMPLE
	Get-LinkdingBundle -LinkdingUrl "https://linkding.example.com" -ApiKey "your-api-key"
	#>
	[CmdletBinding(DefaultParameterSetName = "List")]
	Param (
		[Parameter(Mandatory = $true)]
		[string] $LinkdingUrl,
		[Parameter(Mandatory = $true)]
		[string] $ApiKey,
		[Parameter(Mandatory = $true, ParameterSetName = "Id")]
		[int] $Id,
		[Parameter(Mandatory = $false, ParameterSetName = "List")]
		[int] $Limit = 100
	)

	if ($PSCmdlet.ParameterSetName -eq "Id") {
		$uri = "$LinkdingUrl/api/bundles/$Id/"
		Write-Verbose "Calling $uri"
		Invoke-RestMethod -Uri $uri -Headers (Get-LinkdingAuthHeader -ApiKey $ApiKey)
	}
	else {
		Invoke-LinkdingPagedRequest -Uri "$LinkdingUrl/api/bundles/?limit=$Limit" -ApiKey $ApiKey
	}
}

function New-LinkdingBundle {
	<#
	.SYNOPSIS
	Creates a new bundle.
	.PARAMETER LinkdingUrl
	The URL of the Linkding instance to connect to.
	.PARAMETER ApiKey
	The API key to use for authentication.
	.PARAMETER Name
	The name of the bundle.
	.PARAMETER Search
	Search terms to match bookmarks.
	.PARAMETER AnyTags
	Bookmarks with any of these tags are matched.
	.PARAMETER AllTags
	Bookmarks with all of these tags are matched.
	.PARAMETER ExcludedTags
	Bookmarks with any of these tags are excluded.
	.PARAMETER Order
	Position of the bundle. If omitted, the bundle is placed last.
	.EXAMPLE
	New-LinkdingBundle -LinkdingUrl "https://linkding.example.com" -ApiKey "your-api-key" -Name "Work" -AnyTags "work","productivity"
	#>
	[CmdletBinding(SupportsShouldProcess)]
	Param (
		[Parameter(Mandatory = $true)]
		[string] $LinkdingUrl,
		[Parameter(Mandatory = $true)]
		[string] $ApiKey,
		[Parameter(Mandatory = $true)]
		[string] $Name,
		[Parameter(Mandatory = $false)]
		[string] $Search,
		[Parameter(Mandatory = $false)]
		[string[]] $AnyTags,
		[Parameter(Mandatory = $false)]
		[string[]] $AllTags,
		[Parameter(Mandatory = $false)]
		[string[]] $ExcludedTags,
		[Parameter(Mandatory = $false)]
		[int] $Order
	)

	$payload = @{ name = $Name }
	if ($Search) {$payload.search = $Search}
	if ($AnyTags) {$payload.any_tags = $AnyTags -join " "}
	if ($AllTags) {$payload.all_tags = $AllTags -join " "}
	if ($ExcludedTags) {$payload.excluded_tags = $ExcludedTags -join " "}
	if ($PSBoundParameters.ContainsKey('Order')) {$payload.order = $Order}
	$body = $payload | ConvertTo-Json

	if ($PSCmdlet.ShouldProcess($Name, "Create bundle")) {
		Write-Verbose "Request payload: $body"
		Invoke-RestMethod -Uri "$LinkdingUrl/api/bundles/" -Method Post -Headers (Get-LinkdingAuthHeader -ApiKey $ApiKey) -Body $body -ContentType "application/json"
	}
}

function Set-LinkdingBundle {
	<#
	.SYNOPSIS
	Updates a bundle. Only the supplied fields are modified.
	.PARAMETER LinkdingUrl
	The URL of the Linkding instance to connect to.
	.PARAMETER ApiKey
	The API key to use for authentication.
	.PARAMETER Id
	The ID of the bundle to update.
	.PARAMETER Name
	The name of the bundle.
	.PARAMETER Search
	Search terms to match bookmarks.
	.PARAMETER AnyTags
	Bookmarks with any of these tags are matched.
	.PARAMETER AllTags
	Bookmarks with all of these tags are matched.
	.PARAMETER ExcludedTags
	Bookmarks with any of these tags are excluded.
	.PARAMETER Order
	Position of the bundle.
	.EXAMPLE
	Set-LinkdingBundle -LinkdingUrl "https://linkding.example.com" -ApiKey "your-api-key" -Id 1 -Order 0
	#>
	[CmdletBinding(SupportsShouldProcess)]
	Param (
		[Parameter(Mandatory = $true)]
		[string] $LinkdingUrl,
		[Parameter(Mandatory = $true)]
		[string] $ApiKey,
		[Parameter(Mandatory = $true)]
		[int] $Id,
		[Parameter(Mandatory = $false)]
		[string] $Name,
		[Parameter(Mandatory = $false)]
		[string] $Search,
		[Parameter(Mandatory = $false)]
		[AllowEmptyCollection()]
		[string[]] $AnyTags,
		[Parameter(Mandatory = $false)]
		[AllowEmptyCollection()]
		[string[]] $AllTags,
		[Parameter(Mandatory = $false)]
		[AllowEmptyCollection()]
		[string[]] $ExcludedTags,
		[Parameter(Mandatory = $false)]
		[int] $Order
	)

	$payload = @{}
	if ($PSBoundParameters.ContainsKey('Name')) {$payload.name = $Name}
	if ($PSBoundParameters.ContainsKey('Search')) {$payload.search = $Search}
	if ($PSBoundParameters.ContainsKey('AnyTags')) {$payload.any_tags = $AnyTags -join " "}
	if ($PSBoundParameters.ContainsKey('AllTags')) {$payload.all_tags = $AllTags -join " "}
	if ($PSBoundParameters.ContainsKey('ExcludedTags')) {$payload.excluded_tags = $ExcludedTags -join " "}
	if ($PSBoundParameters.ContainsKey('Order')) {$payload.order = $Order}
	if ($payload.Count -eq 0) {
		Write-Warning "No fields to update were supplied."
		return
	}
	$body = $payload | ConvertTo-Json

	if ($PSCmdlet.ShouldProcess($Id, "Update bundle")) {
		Write-Verbose "Request payload: $body"
		Invoke-RestMethod -Uri "$LinkdingUrl/api/bundles/$Id/" -Method Patch -Headers (Get-LinkdingAuthHeader -ApiKey $ApiKey) -Body $body -ContentType "application/json"
	}
}

function Remove-LinkdingBundle {
	<#
	.SYNOPSIS
	Deletes a bundle.
	.PARAMETER LinkdingUrl
	The URL of the Linkding instance to connect to.
	.PARAMETER ApiKey
	The API key to use for authentication.
	.PARAMETER Id
	The ID of the bundle to delete.
	.EXAMPLE
	Remove-LinkdingBundle -LinkdingUrl "https://linkding.example.com" -ApiKey "your-api-key" -Id 1
	#>
	[CmdletBinding(SupportsShouldProcess)]
	Param (
		[Parameter(Mandatory = $true)]
		[string] $LinkdingUrl,
		[Parameter(Mandatory = $true)]
		[string] $ApiKey,
		[Parameter(Mandatory = $true)]
		[int] $Id
	)

	if ($PSCmdlet.ShouldProcess($Id, "Delete bundle")) {
		Invoke-RestMethod -Uri "$LinkdingUrl/api/bundles/$Id/" -Method Delete -Headers (Get-LinkdingAuthHeader -ApiKey $ApiKey)
	}
}

function Get-LinkdingUserProfile {
	<#
	.SYNOPSIS
	Retrieves the preferences of the user the API key belongs to.
	.PARAMETER LinkdingUrl
	The URL of the Linkding instance to connect to.
	.PARAMETER ApiKey
	The API key to use for authentication.
	.EXAMPLE
	Get-LinkdingUserProfile -LinkdingUrl "https://linkding.example.com" -ApiKey "your-api-key"
	#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[string] $LinkdingUrl,
		[Parameter(Mandatory = $true)]
		[string] $ApiKey
	)

	Invoke-RestMethod -Uri "$LinkdingUrl/api/user/profile/" -Headers (Get-LinkdingAuthHeader -ApiKey $ApiKey)
}
