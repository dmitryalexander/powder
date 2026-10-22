[CmdletBinding(SupportsShouldProcess = $true)]
param([Parameter(Mandatory = $true)][string]$GamePath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$addonName = 'R1Delta.Powder'
$gameRoot = [IO.Path]::GetFullPath($GamePath)
$r1Root = Join-Path $gameRoot 'r1'
if (!(Test-Path -LiteralPath (Join-Path $gameRoot 'Titanfall.exe') -PathType Leaf) -or
    !(Test-Path -LiteralPath (Join-Path $r1Root 'GameInfo.txt') -PathType Leaf)) {
    throw 'Choose the Titanfall 1 game folder containing Titanfall.exe and r1/GameInfo.txt. This is not a Northstar/Titanfall 2 mod.'
}
$source = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot $addonName))
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'MANIFEST.json') -Raw | ConvertFrom-Json
if ($manifest.name -ne $addonName) { throw 'Unexpected package identity.' }
$files = @($manifest.files.PSObject.Properties)
if ($files.Count -eq 0) { throw 'Empty package manifest.' }
$addonsRoot = [IO.Path]::GetFullPath((Join-Path $r1Root 'addons'))
$destination = [IO.Path]::GetFullPath((Join-Path $addonsRoot $addonName))
if (!$destination.StartsWith($addonsRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Destination escaped the requested addon directory.'
}
if (Test-Path -LiteralPath $destination) { throw 'Addon folder already exists. Nothing was overwritten. Back up the previous version outside addons before installing an update.' }
if (Test-Path -LiteralPath (Join-Path $addonsRoot 'R1Delta.Sliding')) {
    throw 'The personal R1Delta.Sliding prototype is present. Keep it as your working build or back it up outside addons before installing this release; do not run both.'
}
if (Test-Path -LiteralPath (Join-Path $addonsRoot 'R1Delta.PilotMovement')) {
    throw 'The older Pilot Movement addon is present. Back it up outside addons before installing Powder; do not run both.'
}
if (Test-Path -LiteralPath $addonsRoot) {
    $item = Get-Item -LiteralPath $addonsRoot
    if (!$item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw 'Addons must be an ordinary directory for the checked installer.'
    }
}

# Validate the entire payload before creating any destination files.
foreach ($file in $files) {
    $relative = [string]$file.Name
    if ([IO.Path]::IsPathRooted($relative) -or ($relative.Split([char[]]@(47,92)) -contains '..')) { throw 'Unsafe package path.' }
    $fullSource = [IO.Path]::GetFullPath((Join-Path $source $relative))
    if (!$fullSource.StartsWith($source + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe package source.' }
    $sourceItem = Get-Item -LiteralPath $fullSource
    if ($sourceItem.PSIsContainer -or ($sourceItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Unexpected payload entry.' }
    if ((Get-FileHash -LiteralPath $fullSource -Algorithm SHA256).Hash -ne [string]$file.Value) { throw "Package checksum failed: $relative" }
}

# Loose-file overlaps are runtime conflicts even when different folders are used.
if (Test-Path -LiteralPath $addonsRoot) {
    foreach ($other in Get-ChildItem -LiteralPath $addonsRoot -Directory) {
        if ($other.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'A linked addon cannot be audited automatically; use the manual compatibility review.' }
        foreach ($file in $files) {
            if ($file.Name -notmatch '^(scripts|materials|cfg)/') { continue }
            if (Test-Path -LiteralPath (Join-Path $other.FullName $file.Name) -PathType Leaf) {
                throw "Conflicting addon file: $($other.Name)/$($file.Name). Nothing was installed. Review compatibility first."
            }
        }
    }
}

if (!$PSCmdlet.ShouldProcess($destination, 'Install a new addon folder; leave settings, addonlist and existing addons untouched')) { return }
[IO.Directory]::CreateDirectory($addonsRoot) | Out-Null
New-Item -ItemType Directory -Path $destination | Out-Null
foreach ($file in $files) {
    $target = [IO.Path]::GetFullPath((Join-Path $destination $file.Name))
    if (!$target.StartsWith($destination + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe target path.' }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
    [IO.File]::Copy((Join-Path $source $file.Name), $target, $false)
    if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne [string]$file.Value) { throw "Installed checksum failed: $($file.Name)" }
}
Write-Output "Installed: $destination"
Write-Output 'No settings or addonlist files were changed. Enable Powder in the R1Delta Addons menu, then restart the game. See INSTALL.md for optional key bindings.'
