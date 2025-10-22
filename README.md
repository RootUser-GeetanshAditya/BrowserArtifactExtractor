# Browser Artifact Extractor
A PowerShell script for extracting browser history and bookmarks from Chrome, Edge, and Firefox browsers on Windows systems. Designed as a red teaming and forensic tool to gather user browsing activity data from common browsers.
This tool is only a Proof-of-concept (POC) for Red Teamers. It can be combined with some other techniques to make it completely undetectable for evading the Blue Teamers.

## Features
- Supports Chrome, Edge and Firefox
- Extracts both browsing history and bookmarks
- Uses SQLite queries for history and Firefox bookmarks
- Parses JSON bookmark files for Chrome and Edge
- Filters URLs and bookmarks by optional matching patterns
- Handles locked SQLite databases by copying to a temporary location
- Outputs structured PowerShell objects for easy further processing

## Requirements
- Windows operating system (tested on Windows 10/11)
- PowerShell 5.1 or later
- Internet connection for initial module installation (NuGet, PSSQLite)

## Installation
The script automatically installs required components when run:
- NuGet package provider (minimum version 2.8.5.201)
- PSSQLite PowerShell module for running SQLite queries

```powershell
# Import or dot-source the script
.\BrowserArtifactExtractor.ps1

# Get browsing history entries matching "login" from Chrome
Get-BrowserData -Browser chrome -Data history -Match "login"

# Get all bookmarks from Firefox
Get-BrowserData -Browser firefox -Data bookmarks

# Get Edge history without filter
Get-BrowserData -Browser edge -Data history
```
