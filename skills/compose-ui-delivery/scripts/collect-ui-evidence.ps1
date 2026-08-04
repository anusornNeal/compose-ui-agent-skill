[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Serial,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,

    [Parameter(Mandatory = $true)]
    [string]$State,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($State)) {
    throw 'State is required'
}

if ($State -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]*$') {
    throw 'State must contain only letters, numbers, underscores, and hyphens'
}

if (-not (Test-Path -LiteralPath $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

$resolvedOutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).Path
$captureScript = Join-Path $PSScriptRoot 'capture-screen.ps1'
if (-not (Test-Path -LiteralPath $captureScript -PathType Leaf)) {
    throw "Capture script not found: $captureScript"
}

$screenshotPath = Join-Path $resolvedOutputDirectory ($State + '.png')
$metadataPath = Join-Path $resolvedOutputDirectory ($State + '.json')

if (-not $Force -and (Test-Path -LiteralPath $screenshotPath -PathType Leaf)) {
    throw "Evidence screenshot already exists: $screenshotPath. Use -Force to overwrite."
}
if (-not $Force -and (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
    throw "Evidence metadata already exists: $metadataPath. Use -Force to overwrite."
}

$capturedScreenshotPath = [string](& $captureScript -Serial $Serial -OutputPath $screenshotPath -Force:$Force)
if ([string]::IsNullOrWhiteSpace($capturedScreenshotPath) -or -not (Test-Path -LiteralPath $capturedScreenshotPath -PathType Leaf)) {
    throw "Screen capture did not produce an evidence file: $screenshotPath"
}

$metadata = [ordered]@{
    state = $State
    platform = 'mobile'
    target = 'android'
    serial = $Serial
    captured_at = [DateTime]::UtcNow.ToString('o')
    screenshot_path = $capturedScreenshotPath
}

$metadata | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $metadataPath -Encoding UTF8
Write-Output $metadataPath
