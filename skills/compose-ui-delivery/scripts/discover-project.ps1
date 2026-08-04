[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,

    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-NormalizedPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Resolve-Path -LiteralPath $Path).Path
}

function Get-RelativePaths {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string[]]$Paths
    )

    $rootUri = [System.Uri](([System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')) + [System.IO.Path]::DirectorySeparatorChar)
    $results = @()
    foreach ($path in $Paths) {
        $childUri = [System.Uri]([System.IO.Path]::GetFullPath($path))
        $relative = $rootUri.MakeRelativeUri($childUri).ToString().Replace('/', '\')
        $results += [System.Uri]::UnescapeDataString($relative).Replace('\', '/')
    }
    return $results
}

function Get-IncludedModules {
    param([string[]]$SettingsFiles)

    $modules = New-Object System.Collections.Generic.HashSet[string]
    foreach ($settingsFile in $SettingsFiles) {
        foreach ($line in [System.IO.File]::ReadAllLines($settingsFile)) {
            foreach ($match in [regex]::Matches($line, 'include\s*\(([^)]*)\)')) {
                foreach ($moduleMatch in [regex]::Matches($match.Groups[1].Value, '["''](:[^"'']+)["'']')) {
                    [void]$modules.Add($moduleMatch.Groups[1].Value)
                }
            }
            if ($line -match '^\s*include\s+') {
                foreach ($moduleMatch in [regex]::Matches($line, '["''](:[^"'']+)["'']')) {
                    [void]$modules.Add($moduleMatch.Groups[1].Value)
                }
            }
        }
    }
    return @($modules | Sort-Object)
}

function Get-VariantSignals {
    param([string]$Root)

    $variants = New-Object System.Collections.Generic.HashSet[string]
    $srcRoots = @(Get-ChildItem -LiteralPath $Root -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'src' })
    foreach ($srcRoot in $srcRoots) {
        foreach ($variantDir in Get-ChildItem -LiteralPath $srcRoot.FullName -Directory -ErrorAction SilentlyContinue) {
            if ($variantDir.Name -in @('main', 'test', 'androidTest')) { continue }
            [void]$variants.Add($variantDir.Name)
        }
    }
    return @($variants | Sort-Object)
}

function Get-SourceSets {
    param([string]$Root)

    $known = @(
        'commonMain', 'commonTest',
        'androidMain', 'androidUnitTest', 'androidInstrumentedTest',
        'iosMain', 'iosTest', 'iosArm64Main', 'iosX64Main', 'iosSimulatorArm64Main',
        'desktopMain', 'desktopTest', 'jvmMain', 'jvmTest',
        'wasmJsMain', 'wasmJsTest', 'jsMain', 'jsTest'
    )
    $sourceSets = New-Object System.Collections.Generic.HashSet[string]
    $srcRoots = @(Get-ChildItem -LiteralPath $Root -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'src' })
    foreach ($srcRoot in $srcRoots) {
        foreach ($candidate in Get-ChildItem -LiteralPath $srcRoot.FullName -Directory -ErrorAction SilentlyContinue) {
            if ($known -contains $candidate.Name) {
                [void]$sourceSets.Add($candidate.Name)
            }
        }
    }
    return @($sourceSets | Sort-Object)
}

function Get-BuildContent {
    param([string]$Root)

    $files = @(
        @(Get-ChildItem -LiteralPath $Root -Filter 'build.gradle' -File -Recurse -ErrorAction SilentlyContinue)
        @(Get-ChildItem -LiteralPath $Root -Filter 'build.gradle.kts' -File -Recurse -ErrorAction SilentlyContinue)
    ) | Sort-Object -Property FullName -Unique
    $parts = @()
    foreach ($file in $files) {
        $parts += [System.IO.File]::ReadAllText($file.FullName)
    }
    return ($parts -join [Environment]::NewLine)
}

function Get-AdbDevices {
    $adbCommand = Get-Command adb -ErrorAction SilentlyContinue
    if ($null -eq $adbCommand) {
        return @{ available = $false; devices = @() }
    }

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $adbCommand.Source
    $startInfo.Arguments = 'devices'
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) {
        return @{ available = $true; devices = @() }
    }

    $devices = @()
    foreach ($line in (($stdout + [Environment]::NewLine + $stderr) -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line -like 'List of devices attached*') { continue }
        $parts = @(($line -split '\s+') | Where-Object { $_ -ne '' })
        if ($parts.Count -ge 2 -and $parts[1] -eq 'device') {
            $devices += $parts[0]
        }
    }
    return @{ available = $true; devices = @($devices) }
}

if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
    throw "Project root not found: $ProjectRoot"
}

$resolvedProjectRoot = Get-NormalizedPath -Path $ProjectRoot
$gradlew = Join-Path $resolvedProjectRoot 'gradlew'
$gradlewBat = Join-Path $resolvedProjectRoot 'gradlew.bat'
$settingsFiles = @(
    (Join-Path $resolvedProjectRoot 'settings.gradle'),
    (Join-Path $resolvedProjectRoot 'settings.gradle.kts')
) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
$settingsFiles = @($settingsFiles)

$modules = @(Get-IncludedModules -SettingsFiles $settingsFiles)
$manifestFiles = @(Get-ChildItem -LiteralPath $resolvedProjectRoot -Filter AndroidManifest.xml -File -Recurse -ErrorAction SilentlyContinue | Sort-Object -Property FullName)
$manifests = @(
    if ($manifestFiles.Count -gt 0) {
        Get-RelativePaths -Root $resolvedProjectRoot -Paths $manifestFiles.FullName
    }
)
$sourceSets = @(Get-SourceSets -Root $resolvedProjectRoot)
$buildContent = Get-BuildContent -Root $resolvedProjectRoot

$composeSignals = [ordered]@{
    jetbrains_compose_plugin = [bool]($buildContent -match 'org\.jetbrains\.compose')
    kotlin_multiplatform_plugin = [bool]($buildContent -match 'org\.jetbrains\.kotlin\.multiplatform|kotlin\s*\(\s*["'']multiplatform["'']')
    android_compose = [bool](($manifests.Count -gt 0) -or ($buildContent -match 'buildFeatures[\s\S]*compose'))
    wasm_browser = [bool](($sourceSets -contains 'wasmJsMain') -or ($buildContent -match '\bwasmJs\b'))
    js_browser = [bool](($sourceSets -contains 'jsMain') -or ($buildContent -match '\bjs\s*\('))
    desktop_application = [bool](($sourceSets -contains 'desktopMain') -or ($sourceSets -contains 'jvmMain') -or ($buildContent -match 'compose\.desktop'))
}

$platformSet = New-Object System.Collections.Generic.HashSet[string]
$hasIos = @($sourceSets | Where-Object { $_ -like 'ios*Main' }).Count -gt 0
if (($manifests.Count -gt 0) -or ($sourceSets -contains 'androidMain') -or $hasIos) {
    [void]$platformSet.Add('mobile')
}
if ($composeSignals.wasm_browser -or $composeSignals.js_browser) {
    [void]$platformSet.Add('web')
}
if ($composeSignals.desktop_application) {
    [void]$platformSet.Add('desktop')
}
$platforms = @($platformSet | Sort-Object)

$adbInfo = Get-AdbDevices
$signals = [ordered]@{
    gradle_wrapper = (Test-Path -LiteralPath $gradlew -PathType Leaf) -or (Test-Path -LiteralPath $gradlewBat -PathType Leaf)
    gradlew = Test-Path -LiteralPath $gradlew -PathType Leaf
    gradlew_bat = Test-Path -LiteralPath $gradlewBat -PathType Leaf
    settings_gradle = Test-Path -LiteralPath (Join-Path $resolvedProjectRoot 'settings.gradle') -PathType Leaf
    settings_gradle_kts = Test-Path -LiteralPath (Join-Path $resolvedProjectRoot 'settings.gradle.kts') -PathType Leaf
    app_module = $modules -contains ':app'
    manifests_found = $manifests.Count -gt 0
    compose_detected = ($composeSignals.jetbrains_compose_plugin -or $composeSignals.android_compose -or $sourceSets.Count -gt 0)
    adb_available = [bool]$adbInfo.available
    devices_detected = $adbInfo.devices.Count -gt 0
}

$confidenceSignals = @(@(
    $signals.gradle_wrapper,
    $signals.settings_gradle -or $signals.settings_gradle_kts,
    $modules.Count -gt 0,
    $signals.compose_detected
) | Where-Object { $_ })
$confidence = [math]::Round(($confidenceSignals.Count / 4), 2)

$wrapperPath = $null
if (Test-Path -LiteralPath $gradlewBat -PathType Leaf) {
    $wrapperPath = $gradlewBat
} elseif (Test-Path -LiteralPath $gradlew -PathType Leaf) {
    $wrapperPath = $gradlew
}

$payload = [ordered]@{
    project_root = $resolvedProjectRoot
    gradle_wrapper = $wrapperPath
    modules = $modules
    manifests = $manifests
    variants = @(Get-VariantSignals -Root $resolvedProjectRoot)
    source_sets = $sourceSets
    compose_signals = $composeSignals
    platforms = $platforms
    devices = @($adbInfo.devices)
    signals = $signals
    confidence = $confidence
}

$json = $payload | ConvertTo-Json -Depth 7
if ($OutputPath) {
    $outputParent = Split-Path -Parent $OutputPath
    if ($outputParent -and -not (Test-Path -LiteralPath $outputParent)) {
        New-Item -ItemType Directory -Path $outputParent -Force | Out-Null
    }
    $targetPath = $OutputPath
    if ($outputParent) {
        $resolvedParent = Resolve-Path -LiteralPath $outputParent
        $targetPath = Join-Path $resolvedParent.Path (Split-Path -Leaf $OutputPath)
    }
    [System.IO.File]::WriteAllText($targetPath, $json + [Environment]::NewLine)
}

Write-Output $json
