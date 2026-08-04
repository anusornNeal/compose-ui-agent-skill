[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,

    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,

    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RequiredPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Description,

        [ValidateSet('Container', 'Leaf')]
        [string]$PathType
    )

    if (-not (Test-Path -LiteralPath $Path -PathType $PathType)) {
        throw "$Description not found: $Path"
    }

    return (Resolve-Path -LiteralPath $Path).Path
}

function Remove-InlineComment {
    param([string]$Value)

    $inSingleQuote = $false
    $inDoubleQuote = $false
    $builder = New-Object System.Text.StringBuilder
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq "'" -and -not $inDoubleQuote) {
            $inSingleQuote = -not $inSingleQuote
        } elseif ($character -eq '"' -and -not $inSingleQuote) {
            $inDoubleQuote = -not $inDoubleQuote
        } elseif ($character -eq '#' -and -not $inSingleQuote -and -not $inDoubleQuote) {
            break
        }

        [void]$builder.Append($character)
    }

    return $builder.ToString().TrimEnd()
}

function Convert-Scalar {
    param([string]$Value)

    $trimmed = $Value.Trim()
    $startsDouble = $trimmed.StartsWith('"')
    $endsDouble = $trimmed.EndsWith('"')
    $startsSingle = $trimmed.StartsWith("'")
    $endsSingle = $trimmed.EndsWith("'")
    if (($startsDouble -xor $endsDouble) -or ($startsSingle -xor $endsSingle)) {
        throw "Unterminated quoted config scalar: $trimmed"
    }
    if ($startsDouble -and $endsDouble -and $trimmed.Substring(1, $trimmed.Length - 2).Contains('\')) {
        throw "Unsupported escape in quoted config scalar: $trimmed"
    }
    if (($startsDouble -and $endsDouble) -or ($startsSingle -and $endsSingle)) {
        return $trimmed.Substring(1, $trimmed.Length - 2)
    }

    if ($trimmed -eq 'true') { return $true }
    if ($trimmed -eq 'false') { return $false }

    $integer = 0
    if ([int]::TryParse($trimmed, [ref]$integer)) { return $integer }
    $decimalNumber = [double]0
    if ([double]::TryParse($trimmed, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$decimalNumber)) { return $decimalNumber }
    return $trimmed
}

function Parse-SimpleYaml {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$AllowedPaths
    )

    $root = @{}
    $stack = New-Object System.Collections.Generic.List[object]
    [void]$stack.Add([pscustomobject]@{ Indent = -1; Path = ''; Value = $root; Keys = @{} })

    foreach ($rawLine in [System.IO.File]::ReadAllLines($Path)) {
        $line = Remove-InlineComment -Value $rawLine
        if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith('-')) { continue }
        if ($line -match "`t") { throw "Tab indentation is not supported: $rawLine" }

        $indent = $line.Length - $line.TrimStart(' ').Length
        if ($line -notmatch '^\s*([A-Za-z0-9_]+):\s*(.*)$') {
            throw "Unsupported config line: $rawLine"
        }

        $key = $matches[1]
        $rawValue = $matches[2]
        while ($stack.Count -gt 1 -and $indent -le $stack[$stack.Count - 1].Indent) {
            $stack.RemoveAt($stack.Count - 1)
        }

        $parent = $stack[$stack.Count - 1].Value
        $parentFrame = $stack[$stack.Count - 1]
        $expectedIndent = if ($parentFrame.Indent -lt 0) { 0 } else { $parentFrame.Indent + 2 }
        if ($indent -ne $expectedIndent) { throw "Invalid config indentation: $rawLine" }
        $path = if ($parentFrame.Path) { "$($parentFrame.Path).$key" } else { $key }
        if ($AllowedPaths -notcontains $path) { throw "Unsupported config key: $path" }
        if ($parentFrame.Keys.ContainsKey($key)) { throw "Duplicate config key: $path" }
        $parentFrame.Keys[$key] = $true
        if ([string]::IsNullOrWhiteSpace($rawValue)) {
            $child = @{}
            $parent[$key] = $child
            [void]$stack.Add([pscustomobject]@{ Indent = $indent; Path = $path; Value = $child; Keys = @{} })
        } else {
            $parent[$key] = Convert-Scalar -Value $rawValue
        }
    }

    return $root
}

function Get-ConfigValue {
    param(
        [hashtable]$Config,
        [string[]]$Path,
        [switch]$Optional
    )

    $current = $Config
    foreach ($segment in $Path) {
        if (-not ($current -is [hashtable]) -or -not $current.ContainsKey($segment)) {
            if ($Optional) { return $null }
            throw "Missing required config value: $($Path -join '.')"
        }

        $current = $current[$segment]
    }

    return $current
}

function Test-ConfigInteger {
    param([object]$Value)

    return $null -ne $Value -and $Value -isnot [bool] -and (
        $Value -is [byte] -or $Value -is [sbyte] -or
        $Value -is [int16] -or $Value -is [uint16] -or
        $Value -is [int32] -or $Value -is [uint32] -or
        $Value -is [int64] -or $Value -is [uint64]
    )
}

function Test-ConfigNumber {
    param([object]$Value)

    return (Test-ConfigInteger -Value $Value) -or $Value -is [single] -or $Value -is [double] -or $Value -is [decimal]
}

function Assert-ConfigSchema {
    param([hashtable]$Config)

    foreach ($path in @('device_profiles.primary.width_dp', 'device_profiles.primary.height_dp')) {
        $value = Get-ConfigValue -Config $Config -Path ($path -split '\.') -Optional
        if ($null -ne $value -and (-not (Test-ConfigInteger -Value $value) -or $value -lt 1)) {
            throw "Config value must be a positive integer: $path"
        }
    }

    $density = Get-ConfigValue -Config $Config -Path @('device_profiles', 'primary', 'density') -Optional
    if ($null -ne $density -and (-not (Test-ConfigNumber -Value $density) -or $density -le 0)) {
        throw 'Config value must be a positive number: device_profiles.primary.density'
    }

    foreach ($path in @('acceptance.visual_parity_min', 'acceptance.ux_quality_min')) {
        $value = Get-ConfigValue -Config $Config -Path ($path -split '\.') -Optional
        if ($null -ne $value -and (-not (Test-ConfigInteger -Value $value) -or $value -lt 1 -or $value -gt 5)) {
            throw "Config value must be an integer between 1 and 5: $path"
        }
    }

    $maxIterations = Get-ConfigValue -Config $Config -Path @('acceptance', 'max_iterations') -Optional
    if ($null -ne $maxIterations -and (-not (Test-ConfigInteger -Value $maxIterations) -or $maxIterations -lt 1 -or $maxIterations -gt 5)) {
        throw 'Config value must be an integer between 1 and 5: acceptance.max_iterations'
    }

    foreach ($path in @('capture.record_logcat', 'acceptance.require_emulator_truth', 'acceptance.require_functional_checks')) {
        $value = Get-ConfigValue -Config $Config -Path ($path -split '\.') -Optional
        if ($null -ne $value -and $value -isnot [bool]) {
            throw "Config value must be boolean: $path"
        }
    }
}

function Get-ModuleToken {
    param([string]$Module)

    if ([string]::IsNullOrWhiteSpace($Module)) { throw 'Missing required config value: project.module' }
    if ($Module -notmatch '^:?([A-Za-z0-9_-]+(?::[A-Za-z0-9_-]+)*)$') { throw "Unsupported module name: $Module" }
    if ($Module.StartsWith(':')) { return $Module }
    return ':' + $Module
}

function Get-GradleVariantName {
    param([string]$Variant)

    if ([string]::IsNullOrWhiteSpace($Variant) -or $Variant -notmatch '^[A-Za-z0-9_-]+$') {
        throw "Unsupported variant name: $Variant"
    }

    $parts = @($Variant -split '[-_]' | Where-Object { $_ -ne '' })
    return (($parts | ForEach-Object { $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1) }) -join '')
}

function Test-ModuleExists {
    param([string]$Root, [string]$ModuleToken)

    $settings = @(
        (Join-Path $Root 'settings.gradle'),
        (Join-Path $Root 'settings.gradle.kts')
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
    $settings = @($settings)
    if ($settings.Count -eq 0) { return $false }
    foreach ($settingsFile in $settings) {
        $content = [System.IO.File]::ReadAllText($settingsFile)
        foreach ($pattern in @(
            'include\s*\(([^)]*)\)',
            '(?m)^\s*include\s+(["'']:[A-Za-z0-9_:-]+["''](?:\s*,\s*["'']:[A-Za-z0-9_:-]+["''])*)(?:\s*;.*)?\r?$'
        )) {
            foreach ($match in [regex]::Matches($content, $pattern)) {
                foreach ($moduleMatch in [regex]::Matches($match.Groups[1].Value, '["''](:[A-Za-z0-9_:-]+)["'']')) {
                    if ($moduleMatch.Groups[1].Value -eq $ModuleToken) { return $true }
                }
            }
        }
    }

    return $false
}

function Test-VariantExists {
    param([string]$Root, [string]$ModuleToken, [string]$Variant)

    $modulePath = Join-Path $Root ($ModuleToken.TrimStart(':').Replace(':', '\'))
    $srcPath = Join-Path $modulePath 'src'
    if ($Variant -in @('debug', 'release')) { return $true }
    if (Test-Path -LiteralPath (Join-Path $srcPath $Variant) -PathType Container) { return $true }

    $buildFiles = @(
        (Join-Path $modulePath 'build.gradle'),
        (Join-Path $modulePath 'build.gradle.kts')
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
    foreach ($buildFile in $buildFiles) {
        $content = [System.IO.File]::ReadAllText($buildFile)
        if ($content -match "\b$([regex]::Escape($Variant))\b") { return $true }
    }

    return $false
}

function Test-ActivityTarget {
    param([string]$Root, [string]$ModuleToken, [string]$Target)

    if ($Target -notmatch '^[A-Za-z0-9_.]+/[A-Za-z0-9_.$]+$') {
        throw "Unsupported launch target: $Target"
    }

    $manifestRoot = Join-Path $Root ($ModuleToken.TrimStart(':').Replace(':', '\'))
    $manifests = @(Get-ChildItem -LiteralPath $manifestRoot -Filter AndroidManifest.xml -File -Recurse -ErrorAction SilentlyContinue)
    if ($manifests.Count -eq 0) { throw "No AndroidManifest.xml found for module: $ModuleToken" }

    $activity = ($Target -split '/', 2)[1]
    $activityName = $activity.TrimStart('.')
    foreach ($manifest in $manifests) {
        $content = [System.IO.File]::ReadAllText($manifest.FullName)
        if ($content -match [regex]::Escape($activity) -or $content -match [regex]::Escape($activityName)) { return $true }
    }

    throw "Launch activity was not found in module manifests: $Target"
}

$resolvedProjectRoot = Resolve-RequiredPath -Path $ProjectRoot -Description 'Project root' -PathType Container
$resolvedConfigPath = Resolve-RequiredPath -Path $ConfigPath -Description 'Config file' -PathType Leaf
$configAllowedPaths = @(
    'project', 'project.root', 'project.module', 'project.package_name', 'project.variant',
    'device_profiles', 'device_profiles.primary', 'device_profiles.primary.name', 'device_profiles.primary.serial',
    'device_profiles.primary.width_dp', 'device_profiles.primary.height_dp', 'device_profiles.primary.density',
    'launch', 'launch.mode', 'launch.target', 'launch.activity', 'launch.deeplink', 'launch.entry_state',
    'capture', 'capture.reference_dir', 'capture.actual_dir', 'capture.diff_dir', 'capture.record_logcat',
    'acceptance', 'acceptance.visual_parity_min', 'acceptance.ux_quality_min', 'acceptance.max_iterations',
    'acceptance.require_emulator_truth', 'acceptance.require_functional_checks'
)
$config = Parse-SimpleYaml -Path $resolvedConfigPath -AllowedPaths $configAllowedPaths
Assert-ConfigSchema -Config $config

$moduleToken = Get-ModuleToken -Module ([string](Get-ConfigValue -Config $config -Path @('project', 'module')))
$variant = [string](Get-ConfigValue -Config $config -Path @('project', 'variant'))
$variantName = Get-GradleVariantName -Variant $variant
$launchMode = [string](Get-ConfigValue -Config $config -Path @('launch', 'mode'))
if ($launchMode -notin @('activity', 'deeplink')) { throw "Unsupported launch.mode: $launchMode" }

if (-not (Test-ModuleExists -Root $resolvedProjectRoot -ModuleToken $moduleToken)) {
    throw "Configured module was not found: $moduleToken"
}
if (-not (Test-VariantExists -Root $resolvedProjectRoot -ModuleToken $moduleToken -Variant $variant)) {
    throw "Configured variant was not found: $variant"
}

$serial = [string](Get-ConfigValue -Config $config -Path @('device_profiles', 'primary', 'serial') -Optional)
$target = [string](Get-ConfigValue -Config $config -Path @('launch', 'target') -Optional)
$legacyActivity = [string](Get-ConfigValue -Config $config -Path @('launch', 'activity') -Optional)
$deeplink = [string](Get-ConfigValue -Config $config -Path @('launch', 'deeplink') -Optional)
if ($launchMode -eq 'activity') {
    if ([string]::IsNullOrWhiteSpace($target)) { $target = $legacyActivity }
    if ([string]::IsNullOrWhiteSpace($target)) { throw 'Missing required config value: launch.target' }
    [void](Test-ActivityTarget -Root $resolvedProjectRoot -ModuleToken $moduleToken -Target $target)
    $launchArguments = if ($serial) { @('-s', $serial, 'shell', 'am', 'start', '-n', $target) } else { @('shell', 'am', 'start', '-n', $target) }
} else {
    if ([string]::IsNullOrWhiteSpace($deeplink)) { throw 'Missing required config value: launch.deeplink' }
    $launchArguments = if ($serial) { @('-s', $serial, 'shell', 'am', 'start', '-a', 'android.intent.action.VIEW', '-d', $deeplink) } else { @('shell', 'am', 'start', '-a', 'android.intent.action.VIEW', '-d', $deeplink) }
}

$preferredWrapper = Join-Path $resolvedProjectRoot 'gradlew.bat'
$shellWrapper = Join-Path $resolvedProjectRoot 'gradlew'
if (Test-Path -LiteralPath $preferredWrapper -PathType Leaf) { $wrapperPath = $preferredWrapper }
elseif (Test-Path -LiteralPath $shellWrapper -PathType Leaf) { $wrapperPath = $shellWrapper }
else { throw "Gradle wrapper not found under project root: $resolvedProjectRoot" }

$assembleCommand = @($wrapperPath, "$moduleToken`:assemble$variantName")
$installCommand = @($wrapperPath, "$moduleToken`:install$variantName")
Write-Output ("ASSEMBLE: " + ($assembleCommand -join ' '))
Write-Output ("INSTALL: " + ($installCommand -join ' '))
Write-Output ("LAUNCH: adb " + ($launchArguments -join ' '))
if ($DryRun) { Write-Output 'DRY-RUN'; return }

& $assembleCommand[0] $assembleCommand[1]
if ($LASTEXITCODE -ne 0) { throw "Gradle assemble command failed with exit code $LASTEXITCODE" }
& $installCommand[0] $installCommand[1]
if ($LASTEXITCODE -ne 0) { throw "Gradle install command failed with exit code $LASTEXITCODE" }
$adbCommand = Get-Command adb -ErrorAction SilentlyContinue
if ($null -eq $adbCommand) { throw 'adb command not found on PATH' }
& $adbCommand.Source @launchArguments
if ($LASTEXITCODE -ne 0) { throw "adb launch command failed with exit code $LASTEXITCODE" }
