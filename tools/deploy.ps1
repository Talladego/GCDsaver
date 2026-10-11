# Deploy only runtime addon files from this repo to the live RoR AddOns folder.
# Copies: GCDsaver.mod, GCDsaver.lua, GCDsaver_Config.lua, libs\
# Removes anything else under Dest (docs, tools, README, .git, leftover fork files, etc.).
#
# Usage:
#   .\tools\deploy.ps1
#   .\tools\deploy.ps1 -WhatIf
#   .\tools\deploy.ps1 -Dest "D:\Games\...\Interface\AddOns\GCDsaver"

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$Dest = "C:\Users\talla\Games\Return of Reckoning\Interface\AddOns\GCDsaver"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$DestParent = Split-Path -Parent $Dest
$ModSrc = Join-Path $RepoRoot "GCDsaver.mod"
$LuaSrc = Join-Path $RepoRoot "GCDsaver.lua"
$ConfigSrc = Join-Path $RepoRoot "GCDsaver_Config.lua"
$LibsSrc = Join-Path $RepoRoot "libs"

if (-not (Test-Path -LiteralPath $ModSrc)) {
    throw "GCDsaver.mod missing under $RepoRoot - refuse to deploy"
}
if (-not (Test-Path -LiteralPath $LuaSrc)) {
    throw "GCDsaver.lua missing under $RepoRoot - refuse to deploy"
}
if (-not (Test-Path -LiteralPath $ConfigSrc)) {
    throw "GCDsaver_Config.lua missing under $RepoRoot - refuse to deploy"
}
if (-not (Test-Path -LiteralPath $LibsSrc)) {
    throw "libs\ missing under $RepoRoot - refuse to deploy"
}
if (-not (Test-Path -LiteralPath $DestParent)) {
    throw "AddOns parent missing: $DestParent"
}

Write-Host "Repo:   $RepoRoot"
Write-Host "Dest:   $Dest"
Write-Host "Copy:   GCDsaver.mod + GCDsaver.lua + GCDsaver_Config.lua + libs\"

if (-not $PSCmdlet.ShouldProcess($Dest, "Deploy runtime addon files and prune extras")) {
    exit 0
}

New-Item -ItemType Directory -Force -Path $Dest | Out-Null

$DestLibs = Join-Path $Dest "libs"
$DestMod = Join-Path $Dest "GCDsaver.mod"
$DestLua = Join-Path $Dest "GCDsaver.lua"
$DestConfig = Join-Path $Dest "GCDsaver_Config.lua"

# Mirror libs\ only (adds, updates, deletes stale files under Dest\libs).
$robocopyArgs = @(
    $LibsSrc,
    $DestLibs,
    "/MIR",
    "/XF", "*.bak", "*.tmp", "*.log", "Thumbs.db", ".DS_Store",
    "/XD", "__pycache__",
    "/R:2", "/W:1",
    "/NFL", "/NDL", "/NP", "/NJH"
)
& robocopy @robocopyArgs
$rc = $LASTEXITCODE
# Robocopy: 0-7 = success (with optional extras); >=8 = failure
if ($rc -ge 8) {
    throw "robocopy libs failed with exit code $rc"
}

Copy-Item -LiteralPath $ModSrc -Destination $DestMod -Force
Copy-Item -LiteralPath $LuaSrc -Destination $DestLua -Force
Copy-Item -LiteralPath $ConfigSrc -Destination $DestConfig -Force

# Keep Dest as a runtime-only tree: remove anything that is not a shipped file/dir.
$allowed = @{
    "GCDsaver.mod"        = $true
    "GCDsaver.lua"        = $true
    "GCDsaver_Config.lua" = $true
    "libs"                = $true
}
Get-ChildItem -LiteralPath $Dest -Force | ForEach-Object {
    if ($allowed.ContainsKey($_.Name)) { return }
    Write-Host "Prune: $($_.FullName)"
    Remove-Item -LiteralPath $_.FullName -Recurse -Force
}

if (-not (Test-Path -LiteralPath $DestMod) -or -not (Test-Path -LiteralPath $DestLua) -or -not (Test-Path -LiteralPath $DestConfig) -or -not (Test-Path -LiteralPath $DestLibs)) {
    throw "Deploy incomplete: missing GCDsaver.mod, lua, config, or libs under $Dest"
}

$copied = (Get-ChildItem -LiteralPath $Dest -Recurse -File).Count
Write-Host "Deploy OK (files: $copied, robocopy exit $rc). Reload UI in-game (/reload)."
exit 0
