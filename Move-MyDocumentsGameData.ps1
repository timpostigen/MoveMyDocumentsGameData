<#
.Description
Moves game data folders from My Documents into AppData and symlinks them back.

.Parameter WhatIf
When specified with -Verbose, only prints out the projected moves.

.Parameter Fix
Not currently implemented. Intended to ensure symlinks are created properly and file attributes are set.

.Example
<repo>\Move-MyDocumentsGameData.ps1 -Verbose 

.Notes
Validated for PowerShell Core 7 via WinTerm
#>

[CmdletBinding()]
Param(
    [switch] $Fix,
    [switch] $WhatIf
)

function Get-RunAsAdministrator {
    [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")
}

function Test-RunAsAdministrator {
    if (-not (Get-RunAsAdministrator)) { throw "Must run as Administrator for symlinking to work properly." }
}

if(-not $WhatIf) { Test-RunAsAdministrator }

$myDocuments = [Environment]::GetFolderPath('MyDocuments')

$gameDirs = ConvertFrom-Yaml (Get-Content -raw (Join-Path $PSScriptRoot 'Move-MyDocumentsGameData.yaml'))

$gameDirMappings = @()
$intermediateDirMappings = @()


# TODO: we want creator/title flat in appdata
# so we want to symlink ?????
function generateGameDirPaths([hashtable] $GameDirs, $PathPrefix) {
    foreach ($gameDir in $GameDirs.GetEnumerator()) {
        $documentsFolder = Join-Path $myDocuments $PathPrefix $gameDir.Key
    
        $value = $gameDir.Value
        $valueTypeName = $value.GetType().Name
        
        # wierd type from ConvertFrom-Yaml
        if ($valueTypeName -eq 'List`1') {
            $valueDir = Join-Path @value
        }
        elseif ($valueTypeName -eq 'String') {

            $valueDir = Split-Path $documentsFolder -Leaf

            if ($value -ne '') { $valueDir = Join-Path $value $valueDir }
        }
        elseif ($valueTypeName -eq 'HashTable') {
            $valueDir = $gameDir.Key
            $newPathPrefix = $gameDir.Key

            if ($PathPrefix -ne '') { $newPathPrefix = Join-Path $PathPrefix $gameDir.Key }
            
            $script:intermediateDirMappings += , @($documentsFolder, (Join-Path $env:AppData $PathPrefix $valueDir))

            generateGameDirPaths $value $newPathPrefix
            continue
        }
    
        $script:gameDirMappings += , @($documentsFolder, (Join-Path $env:AppData $valueDir)) # (Join-Path $env:AppData $valueDir))
    }
}

generateGameDirPaths $gameDirs ''

foreach ($mappingList in $intermediateDirMappings, $gameDirMappings) {
    foreach ($mapping in $mappingList) {
        $documentsFolder = $mapping[0]
        $appDataGameDir = $mapping[1]

        Write-Verbose "$documentsFolder > $appDataGameDir"
        if ($WhatIf) { continue }

        if ($Fix) {
                Write-Error "-Fix behavior not defined yet"
                throw [System.NotImplementedException]
                $symLink = Get-Item $documentsFolder
            
                $symLink.Attributes
                continue
            }
        
        # Use Get-Item here instead of Test-Path because Get-Item fails for links/reparse points
        if (Get-Item $documentsFolder -ErrorAction SilentlyContinue) {
            Write-Verbose "moving $documentsFolder to $appDataGameDir"
            throw "$documentsFolder"
            
            New-Item -ItemType Directory -Force -Path $appDataGameDir
                
            Move-Item "$documentsFolder/*" $appDataGameDir -Force
            
            Remove-Item $documentsFolder
            
            $symLink = New-Item -ItemType SymbolicLink -Path $documentsFolder -Target $appDataGameDir
            
            $symLink.Attributes = $symLink.Attributes -bor "Hidden"
        }
    }
}