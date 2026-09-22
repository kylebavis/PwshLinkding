BeforeAll {
	Import-Module "$PSScriptRoot\PwshLinkding.psd1" -Force
	$script:common = @{ LinkdingUrl = 'https://ld.test'; ApiKey = 'key' }
}

Describe 'Get-LinkdingBookmark' {
	BeforeEach {
		Mock -ModuleName PwshLinkding Invoke-RestMethod {
			if ($Uri -like '*offset=1*') { return [pscustomobject]@{ next = $null; results = @(@{ id = 2 }) } }
			[pscustomobject]@{ next = 'https://ld.test/api/bookmarks/?limit=1&offset=1'; results = @(@{ id = 1 }) }
		}
	}

	It 'Follows pagination' {
		$result = Get-LinkdingBookmark @common -Limit 1
		$result.id | Should -Be @(1, 2)
	}

	It 'Adds filter parameters to the query' {
		$date = [datetime]::new(2025, 1, 2, 3, 4, 5, [DateTimeKind]::Utc)
		Get-LinkdingBookmark @common -Query '#a b' -ModifiedSince $date -AddedSince $date -BundleId 7 -Offset 5 | Out-Null
		Should -Invoke -ModuleName PwshLinkding Invoke-RestMethod -ParameterFilter {
			$Uri -eq 'https://ld.test/api/bookmarks/?limit=100&offset=5&q=%23a%20b&modified_since=2025-01-02T03%3A04%3A05Z&added_since=2025-01-02T03%3A04%3A05Z&bundle=7'
		}
	}

	It 'Uses the archived endpoint' {
		Get-LinkdingBookmark @common -Archived | Out-Null
		Should -Invoke -ModuleName PwshLinkding Invoke-RestMethod -ParameterFilter { $Uri -like 'https://ld.test/api/bookmarks/archived/?limit=100' }
	}
}

Describe 'Get-LinkdingBookmarkCheck' {
	It 'Returns the full check response' {
		Mock -ModuleName PwshLinkding Invoke-RestMethod { [pscustomobject]@{ bookmark = $null; metadata = @{ title = 't' }; auto_tags = @('x') } }
		$result = Get-LinkdingBookmarkCheck @common -URL 'https://example.com'
		$result.auto_tags | Should -Be @('x')
		Should -Invoke -ModuleName PwshLinkding Invoke-RestMethod -ParameterFilter { $Uri -eq 'https://ld.test/api/bookmarks/check/?url=https%3A%2F%2Fexample.com' }
	}
}

Describe 'New-LinkdingBookmark' {
	It 'Adds disable_scraping' {
		Mock -ModuleName PwshLinkding Invoke-RestMethod { }
		New-LinkdingBookmark @common -URL 'https://example.com' -DisableScraping -Force
		Should -Invoke -ModuleName PwshLinkding Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' -and $Uri -eq 'https://ld.test/api/bookmarks/?disable_scraping' }
	}
}

Describe 'Set-LinkdingBookmark' {
	BeforeEach {
		Mock -ModuleName PwshLinkding Invoke-RestMethod { }
	}

	It 'Patches only the supplied fields' {
		Set-LinkdingBookmark @common -Id 3 -Title 'New' -Tags @()
		Should -Invoke -ModuleName PwshLinkding Invoke-RestMethod -Times 1 -Exactly
		Should -Invoke -ModuleName PwshLinkding Invoke-RestMethod -ParameterFilter {
			$b = $Body | ConvertFrom-Json
			$Method -eq 'Patch' -and $Uri -eq 'https://ld.test/api/bookmarks/3/' -and
			$b.title -eq 'New' -and @($b.tag_names).Count -eq 0 -and $null -eq $b.PSObject.Properties['description']
		}
	}

	It 'Archives without patching' {
		Set-LinkdingBookmark @common -Id 3 -Archived $true
		Should -Invoke -ModuleName PwshLinkding Invoke-RestMethod -Times 1 -Exactly
		Should -Invoke -ModuleName PwshLinkding Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' -and $Uri -eq 'https://ld.test/api/bookmarks/3/archive/' }
	}

	It 'Unarchives' {
		Set-LinkdingBookmark @common -Id 3 -Archived $false
		Should -Invoke -ModuleName PwshLinkding Invoke-RestMethod -ParameterFilter { $Uri -eq 'https://ld.test/api/bookmarks/3/unarchive/' }
	}
}

Describe 'Bookmark assets' {
	BeforeEach {
		Mock -ModuleName PwshLinkding Invoke-RestMethod { [pscustomobject]@{ next = $null; results = @(@{ id = 1 }) } }
	}

	It 'Lists assets' {
		(Get-LinkdingBookmarkAsset @common -BookmarkId 4).id | Should -Be 1
		Should -Invoke -ModuleName PwshLinkding Invoke-RestMethod -ParameterFilter { $Uri -eq 'https://ld.test/api/bookmarks/4/assets/' }
	}

	It 'Gets a single asset' {
		Get-LinkdingBookmarkAsset @common -BookmarkId 4 -Id 9 | Out-Null
		Should -Invoke -ModuleName PwshLinkding Invoke-RestMethod -ParameterFilter { $Uri -eq 'https://ld.test/api/bookmarks/4/assets/9/' }
	}

	It 'Deletes an asset' {
		Remove-LinkdingBookmarkAsset @common -BookmarkId 4 -Id 9
		Should -Invoke -ModuleName PwshLinkding Invoke-RestMethod -ParameterFilter { $Method -eq 'Delete' -and $Uri -eq 'https://ld.test/api/bookmarks/4/assets/9/' }
	}

	It 'Downloads an asset' {
		Mock -ModuleName PwshLinkding Invoke-WebRequest { Set-Content -LiteralPath $OutFile -Value 'x' }
		$path = Join-Path $TestDrive 'asset.bin'
		(Save-LinkdingBookmarkAsset @common -BookmarkId 4 -Id 9 -Path $path).FullName | Should -Be $path
		Should -Invoke -ModuleName PwshLinkding Invoke-WebRequest -ParameterFilter { $Uri -eq 'https://ld.test/api/bookmarks/4/assets/9/download/' }
	}
}

Describe 'Tags' {
	BeforeEach {
		Mock -ModuleName PwshLinkding Invoke-RestMethod { [pscustomobject]@{ next = $null; results = @(@{ id = 1 }) } }
	}

	It 'Lists tags' {
		Get-LinkdingTag @common | Out-Null
		Should -Invoke -ModuleName PwshLinkding Invoke-RestMethod -ParameterFilter { $Uri -eq 'https://ld.test/api/tags/?limit=100' }
	}

	It 'Creates a tag' {
		New-LinkdingTag @common -Name 'foo'
		Should -Invoke -ModuleName PwshLinkding Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' -and ($Body | ConvertFrom-Json).name -eq 'foo' }
	}

	It 'Deletes a tag' {
		Remove-LinkdingTag @common -Id 2
		Should -Invoke -ModuleName PwshLinkding Invoke-RestMethod -ParameterFilter { $Method -eq 'Delete' -and $Uri -eq 'https://ld.test/api/tags/2/' }
	}
}

Describe 'Bundles' {
	BeforeEach {
		Mock -ModuleName PwshLinkding Invoke-RestMethod { [pscustomobject]@{ next = $null; results = @(@{ id = 1 }) } }
	}

	It 'Gets a bundle' {
		Get-LinkdingBundle @common -Id 2 | Out-Null
		Should -Invoke -ModuleName PwshLinkding Invoke-RestMethod -ParameterFilter { $Uri -eq 'https://ld.test/api/bundles/2/' }
	}

	It 'Creates a bundle with space-separated tags' {
		New-LinkdingBundle @common -Name 'b' -AnyTags 'a', 'b'
		Should -Invoke -ModuleName PwshLinkding Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' -and ($Body | ConvertFrom-Json).any_tags -eq 'a b' }
	}

	It 'Patches a bundle' {
		Set-LinkdingBundle @common -Id 2 -Order 0
		Should -Invoke -ModuleName PwshLinkding Invoke-RestMethod -ParameterFilter { $Method -eq 'Patch' -and ($Body | ConvertFrom-Json).order -eq 0 }
	}

	It 'Deletes a bundle' {
		Remove-LinkdingBundle @common -Id 2
		Should -Invoke -ModuleName PwshLinkding Invoke-RestMethod -ParameterFilter { $Method -eq 'Delete' -and $Uri -eq 'https://ld.test/api/bundles/2/' }
	}
}

Describe 'Get-LinkdingUserProfile' {
	It 'Calls the profile endpoint' {
		Mock -ModuleName PwshLinkding Invoke-RestMethod { }
		Get-LinkdingUserProfile @common
		Should -Invoke -ModuleName PwshLinkding Invoke-RestMethod -ParameterFilter { $Uri -eq 'https://ld.test/api/user/profile/' }
	}
}
