# Check if Nuget is present or not
if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)){
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
}

# Check if PSSQLite is present of not
if (-not (Get-Module -ListAvailable -Name PSSQLite)) {
    Install-Module -Name PSSQLite -Force
}

function Get-Database{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DBPath,
        [Parameter(Mandatory)]
        [string]$Query
    )
    if (-not (Test-Path $dbpath)) { Write-Warning "Database file missing: $dbpath" ; return }
    $tempDbPath = Join-Path $env:TEMP ([IO.Path]::GetFileName($dbpath))
    Copy-Item -Path $dbpath -Destination $tempDbPath -Force
    $results = Invoke-SqliteQuery -DataSource $tempDbPath -Query $query -ErrorAction Stop
    foreach ($row in $results) {
        [PSCustomObject]@{
            User      = $env:UserName
            Browser   = $Browser
            Link      = $row.Link
            Title     = $row.Title
            Timestamp = $row.Visited ? $row.Visited : $row.Added
        }
    }
    Remove-Item $tempDbPath -Force
}


function Get-BrowserData{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("chrome", "edge", "firefox")]
        [string]$Browser,

        [Parameter(Mandatory)]
        [ValidateSet("history", "bookmarks")]
        [string]$Data,

        [string]$Match = ""
    )

    Import-Module PSSQLite -ErrorAction Stop
    $profile = $env:USERPROFILE
    $query   = ""   
    $dbpath  = ""

    if ($Data -eq "history"){
        switch($Browser){
            "chrome"{
                $dbpath = "$profile\AppData\Local\Google\Chrome\User Data\Default\History"
                $query  = "SELECT url AS Link, title AS Title, datetime(last_visit_time/1000000-11644473600, 'unixepoch') AS Visited FROM urls WHERE url LIKE '%$Match%' ORDER BY last_visit_time DESC"
            }
            "edge"{
                $dbpath = "$profile\AppData\Local\Microsoft\Edge\User Data\Default\History"
                $query  = "SELECT url AS Link, title AS Title, datetime(last_visit_time/1000000-11644473600, 'unixepoch') AS Visited FROM urls WHERE url LIKE '%$Match%' ORDER BY last_visit_time DESC"
            }
            "firefox" {
                $profdir = Get-ChildItem "$profile\AppData\Roaming\Mozilla\Firefox\Profiles" -Directory | Where-Object { $_.Name -like "*.default-release*" } | Select-Object -First 1
                if (-not $profdir) { Write-Warning "Firefox profile not found." ; return }
                $dbpath = Join-Path $profdir.FullName "places.sqlite"
                $query = "SELECT url AS Link, title AS Title, datetime(last_visit_date/1000000, 'unixepoch') AS Visited FROM moz_places WHERE url LIKE '%$Match%' ORDER BY last_visit_date DESC"
            }
        }
        
        Get-Database -DBPath $dbpath -Query $query
        
        
    }
    elseif ($Data -eq "bookmarks"){
        if ($Browser -eq "firefox"){
            $profdir = Get-ChildItem "$profile\AppData\Roaming\Mozilla\Firefox\Profiles" -Directory | Where-Object { $_.Name -like "*.default-release*" } | Select-Object -First 1
            if (-not $profdir) { Write-Warning "Firefox profile not found." ; return }
            $dbpath = Join-Path $profdir.FullName "places.sqlite"
            $query = "SELECT p.url AS Link, b.title AS Title, datetime(b.dateAdded/1000000, 'unixepoch') AS Added FROM moz_bookmarks b JOIN moz_places p ON b.fk=p.id WHERE p.url LIKE '%$Match%' ORDER BY b.dateAdded DESC"

            Get-Database -DBPath $dbpath -Query $query

        }
        else{
            switch ($Browser){
                "chrome"{
                    $jsonFilePath = "$profile\AppData\Local\Google\Chrome\User Data\Default\Bookmarks"
                }
                "edge"{
                    $jsonFilePath = "$profile\AppData\Local\Microsoft\Edge\User Data\Default\Bookmarks"

                }
            }

            $jsonText = Get-Content -Path $jsonFilePath -Raw
            $jsonObject = $jsonText | ConvertFrom-Json
            $webkitEpoch = [datetime]::ParseExact(
                "1601-01-01T00:00:00Z",
                "yyyy-MM-ddTHH:mm:ssZ",
                [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::AssumeUniversal
            )
            foreach ($results in $jsonObject.roots.bookmark_bar.children, $jsonObject.roots.other.children, $jsonObject.roots.synced.children){
                foreach ($row in $results) {
                    if ($null -ne $row.date_added -and $row.date_added -ne "0") {
                        $micro = [int64]$row.date_added
                        $ticks = $micro * 10
                        $dateUtc = $webkitEpoch.AddTicks($ticks)
                        $dateLocal = $dateUtc.ToLocalTime()
                    } 
                    [PSCustomObject]@{
                                User      = $env:UserName
                                Browser   = $Browser
                                InfoType  = $row.type
                                Link      = $row.url
                                Title     = $row.name
                                Timestamp = $dateLocal
                    }
                }
            }
        }

    }

}
