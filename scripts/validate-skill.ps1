[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Add-ValidationError {
    param(
        [System.Collections.Generic.List[string]]$Errors,
        [string]$Message
    )
    [void]$Errors.Add($Message)
}

function Get-LocalMarkdownTargets {
    param([string]$SourcePath, [string]$Content)

    foreach ($match in [regex]::Matches($Content, '\[[^\]]+\]\(([^)#?]+)\)')) {
        $target = $match.Groups[1].Value.Trim()
        if ([string]::IsNullOrWhiteSpace($target) -or
            $target.StartsWith('http://') -or
            $target.StartsWith('https://') -or
            $target.StartsWith('mailto:')) {
            continue
        }
        [pscustomobject]@{
            Target = $target
            FullPath = [System.IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $SourcePath) $target))
        }
    }
}

function Test-PowerShellSyntax {
    param(
        [string]$Path,
        [System.Collections.Generic.List[string]]$Errors
    )

    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$parseErrors) | Out-Null
    foreach ($parseError in $parseErrors) {
        Add-ValidationError -Errors $Errors -Message "PowerShell syntax error in $Path`: $($parseError.Message)"
    }
}

function Convert-YamlScalar {
    param([string]$Value)

    $trimmed = $Value.Trim()
    $startsDouble = $trimmed.StartsWith('"')
    $endsDouble = $trimmed.EndsWith('"')
    $startsSingle = $trimmed.StartsWith("'")
    $endsSingle = $trimmed.EndsWith("'")
    if ($startsDouble -and $endsDouble) {
        $backslashes = 0
        for ($index = $trimmed.Length - 2; $index -ge 0 -and $trimmed[$index] -eq '\'; $index--) {
            $backslashes++
        }
        if ($backslashes % 2 -eq 1) {
            throw "Unterminated quoted YAML scalar: $trimmed"
        }
        if ($trimmed.Substring(1, $trimmed.Length - 2).Contains('\')) {
            throw "Unsupported escape in quoted YAML scalar: $trimmed"
        }
    }
    if (($startsDouble -xor $endsDouble) -or ($startsSingle -xor $endsSingle)) {
        throw "Unterminated quoted YAML scalar: $trimmed"
    }
    if (($startsDouble -and $endsDouble) -or ($startsSingle -and $endsSingle)) {
        if ($trimmed.Length -lt 2) { throw "Invalid quoted YAML scalar: $trimmed" }
        return $trimmed.Substring(1, $trimmed.Length - 2)
    }
    if ($trimmed -eq 'true') { return $true }
    if ($trimmed -eq 'false') { return $false }
    $integer = 0
    if ([int]::TryParse($trimmed, [ref]$integer)) { return $integer }
    $number = [double]0
    if ([double]::TryParse($trimmed, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$number)) {
        return $number
    }
    return $trimmed
}

function Parse-ConstrainedYaml {
    param(
        [string]$Path,
        [string[]]$AllowedPaths,
        [System.Collections.Generic.List[string]]$Errors
    )

    $values = @{}
    $stack = New-Object System.Collections.Generic.List[object]
    [void]$stack.Add([pscustomobject]@{ Indent = -1; Path = ''; Keys = @{} })
    foreach ($rawLine in [System.IO.File]::ReadAllLines($Path)) {
        if ([string]::IsNullOrWhiteSpace($rawLine) -or $rawLine.TrimStart().StartsWith('#')) { continue }
        if ($rawLine -match "`t") {
            Add-ValidationError -Errors $Errors -Message "YAML contains tab indentation: $Path"
            continue
        }
        if ($rawLine -notmatch '^\s*(?<key>[A-Za-z0-9_]+):\s*(?<value>.*)$') {
            Add-ValidationError -Errors $Errors -Message "Malformed YAML in $Path`: $rawLine"
            continue
        }

        $indent = $rawLine.Length - $rawLine.TrimStart(' ').Length
        while ($stack.Count -gt 1 -and $indent -le $stack[$stack.Count - 1].Indent) {
            $stack.RemoveAt($stack.Count - 1)
        }
        $parent = $stack[$stack.Count - 1]
        $expectedIndent = if ($parent.Indent -lt 0) { 0 } else { $parent.Indent + 2 }
        if ($indent -ne $expectedIndent) {
            Add-ValidationError -Errors $Errors -Message "Invalid YAML indentation in $Path`: $rawLine"
            continue
        }

        $key = $matches['key']
        $yamlPath = if ($parent.Path) { "$($parent.Path).$key" } else { $key }
        if ($parent.Keys.ContainsKey($key)) {
            Add-ValidationError -Errors $Errors -Message "Duplicate YAML key in $Path`: $yamlPath"
            continue
        }
        $parent.Keys[$key] = $true
        if ($AllowedPaths -notcontains $yamlPath) {
            Add-ValidationError -Errors $Errors -Message "Unsupported YAML key in $Path`: $yamlPath"
        }

        $valueText = $matches['value']
        if ([string]::IsNullOrWhiteSpace($valueText)) {
            $values[$yamlPath] = $null
            [void]$stack.Add([pscustomobject]@{ Indent = $indent; Path = $yamlPath; Keys = @{} })
        } else {
            try {
                $values[$yamlPath] = Convert-YamlScalar -Value $valueText
            } catch {
                Add-ValidationError -Errors $Errors -Message "Invalid YAML value in $Path at $yamlPath`: $($_.Exception.Message)"
            }
        }
    }
    return $values
}

function Test-IntegerValue {
    param([object]$Value)
    return $null -ne $Value -and $Value -isnot [bool] -and (
        $Value -is [byte] -or $Value -is [sbyte] -or
        $Value -is [int16] -or $Value -is [uint16] -or
        $Value -is [int32] -or $Value -is [uint32] -or
        $Value -is [int64] -or $Value -is [uint64]
    )
}

$root = (Resolve-Path -LiteralPath $RepoRoot).Path.TrimEnd('\', '/')
$errors = [System.Collections.Generic.List[string]]::new()
$skillNames = @('compose-ui-reference', 'compose-ui-designer', 'compose-ui-delivery')
$seenNames = New-Object System.Collections.Generic.HashSet[string]
$checkedFiles = New-Object System.Collections.Generic.HashSet[string]

foreach ($expectedName in $skillNames) {
    $skillRoot = Join-Path $root "skills/$expectedName"
    if (-not (Test-Path -LiteralPath $skillRoot -PathType Container)) {
        Add-ValidationError -Errors $errors -Message "Missing skill package: $expectedName"
        continue
    }

    $skillFile = Join-Path $skillRoot 'SKILL.md'
    $metadataFile = Join-Path $skillRoot 'agents/openai.yaml'
    foreach ($requiredFile in @($skillFile, $metadataFile)) {
        if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
            Add-ValidationError -Errors $errors -Message "Missing required file for $expectedName`: $requiredFile"
        } else {
            [void]$checkedFiles.Add($requiredFile)
        }
    }
    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf) -or -not (Test-Path -LiteralPath $metadataFile -PathType Leaf)) {
        continue
    }

    $skillContent = Get-Content -LiteralPath $skillFile -Raw
    $frontmatter = [regex]::Match($skillContent, '\A---\r?\n(?<front>[\s\S]*?)\r?\n---\r?\n')
    if (-not $frontmatter.Success) {
        Add-ValidationError -Errors $errors -Message "$expectedName SKILL.md must start with YAML frontmatter"
    } else {
        $front = $frontmatter.Groups['front'].Value
        $nameMatch = [regex]::Match($front, '(?m)^name:\s*(?<value>[A-Za-z0-9_-]+)\s*$')
        $descriptionMatch = [regex]::Match($front, '(?m)^description:\s*(?<value>.+)\s*$')
        if (-not $nameMatch.Success -or $nameMatch.Groups['value'].Value -cne $expectedName) {
            Add-ValidationError -Errors $errors -Message "$expectedName frontmatter name must be $expectedName"
        } elseif (-not $seenNames.Add($expectedName)) {
            Add-ValidationError -Errors $errors -Message "Duplicate skill name: $expectedName"
        }
        if (-not $descriptionMatch.Success -or $descriptionMatch.Groups['value'].Value -notmatch '^Use when\s+') {
            Add-ValidationError -Errors $errors -Message "$expectedName frontmatter description must start with Use when"
        }
    }

    $metadataErrorsBefore = $errors.Count
    $metadataValues = Parse-ConstrainedYaml -Path $metadataFile -AllowedPaths @(
        'interface', 'interface.display_name', 'interface.short_description', 'interface.default_prompt'
    ) -Errors $errors
    if ($errors.Count -gt $metadataErrorsBefore) {
        Add-ValidationError -Errors $errors -Message "Invalid metadata YAML for $expectedName"
    }
    foreach ($field in @('display_name', 'short_description', 'default_prompt')) {
        $path = "interface.$field"
        if (-not $metadataValues.ContainsKey($path) -or
            $metadataValues[$path] -isnot [string] -or
            [string]::IsNullOrWhiteSpace($metadataValues[$path])) {
            Add-ValidationError -Errors $errors -Message "$expectedName agents/openai.yaml is missing interface.$field"
        }
    }
    if ($metadataValues.ContainsKey('interface.default_prompt') -and
        [string]$metadataValues['interface.default_prompt'] -notmatch [regex]::Escape("`$$expectedName")) {
        Add-ValidationError -Errors $errors -Message "$expectedName default_prompt must mention `$$expectedName"
    }
    if ($metadataValues.ContainsKey('interface.short_description') -and
        $metadataValues['interface.short_description'] -is [string] -and
        ($metadataValues['interface.short_description'].Length -lt 25 -or $metadataValues['interface.short_description'].Length -gt 64)) {
        Add-ValidationError -Errors $errors -Message "$expectedName short_description must be 25-64 characters"
    }

    $skillPrefix = [System.IO.Path]::GetFullPath($skillRoot).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $markdownFiles = @(Get-ChildItem -LiteralPath $skillRoot -Filter '*.md' -File -Recurse -ErrorAction SilentlyContinue)
    foreach ($markdownFile in $markdownFiles) {
        [void]$checkedFiles.Add($markdownFile.FullName)
        $markdownContent = Get-Content -LiteralPath $markdownFile.FullName -Raw
        foreach ($link in Get-LocalMarkdownTargets -SourcePath $markdownFile.FullName -Content $markdownContent) {
            if (-not $link.FullPath.StartsWith($skillPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                Add-ValidationError -Errors $errors -Message "Markdown link escapes skill root: $($markdownFile.FullName) -> $($link.Target)"
            } elseif (-not (Test-Path -LiteralPath $link.FullPath -PathType Leaf)) {
                Add-ValidationError -Errors $errors -Message "Missing markdown link target: $($markdownFile.FullName) -> $($link.Target)"
            }
        }
    }

    $textExtensions = @('.md', '.yaml', '.yml', '.json', '.py', '.ps1')
    foreach ($file in Get-ChildItem -LiteralPath $skillRoot -File -Recurse -ErrorAction SilentlyContinue) {
        [void]$checkedFiles.Add($file.FullName)
        if ($textExtensions -contains $file.Extension.ToLowerInvariant()) {
            $content = Get-Content -LiteralPath $file.FullName -Raw
            if ($content -match '\b(TODO|TBD)\b') {
                Add-ValidationError -Errors $errors -Message "Placeholder found in production resource: $($file.FullName)"
            }
        }
    }
}

$deliveryRoot = Join-Path $root 'skills/compose-ui-delivery'
$deliveryRequired = @(
    'references/compose-patterns.md',
    'references/visual-review.md',
    'references/platforms/mobile.md',
    'references/platforms/web.md',
    'references/platforms/desktop.md',
    'references/rubrics/visual-parity.md',
    'references/rubrics/ux-quality.md',
    'references/rubrics/anti-ai-slop.md',
    'templates/compose-ui-delivery.yaml',
    'templates/screen-spec.md',
    'templates/visual-review.json',
    'scripts/discover-project.ps1',
    'scripts/build-and-launch.ps1',
    'scripts/capture-screen.ps1',
    'scripts/collect-ui-evidence.ps1',
    'scripts/compare-images.py',
    'scripts/test_compare_images.py'
)
foreach ($relativePath in $deliveryRequired) {
    $fullPath = Join-Path $deliveryRoot $relativePath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        Add-ValidationError -Errors $errors -Message "Missing delivery resource: $relativePath"
    } else {
        [void]$checkedFiles.Add($fullPath)
    }
}

$configPath = Join-Path $deliveryRoot 'templates/compose-ui-delivery.yaml'
if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    $allowedPaths = @(
        'platform', 'platform.kind', 'platform.target',
        'project', 'project.root', 'project.module', 'project.package_name', 'project.variant',
        'device_profiles', 'device_profiles.primary', 'device_profiles.primary.name', 'device_profiles.primary.serial',
        'device_profiles.primary.width_dp', 'device_profiles.primary.height_dp', 'device_profiles.primary.density',
        'launch', 'launch.mode', 'launch.target', 'launch.deeplink', 'launch.task', 'launch.url', 'launch.window_title', 'launch.entry_state',
        'capture', 'capture.reference_dir', 'capture.actual_dir', 'capture.diff_dir', 'capture.record_logcat',
        'acceptance', 'acceptance.visual_parity_min', 'acceptance.ux_quality_min', 'acceptance.max_iterations',
        'acceptance.require_platform_truth', 'acceptance.require_functional_checks'
    )
    $config = Parse-ConstrainedYaml -Path $configPath -AllowedPaths $allowedPaths -Errors $errors
    foreach ($requiredPath in @('platform.kind', 'platform.target', 'project.root', 'project.module', 'capture.reference_dir', 'capture.actual_dir', 'capture.diff_dir', 'acceptance.max_iterations')) {
        if (-not $config.ContainsKey($requiredPath)) {
            Add-ValidationError -Errors $errors -Message "compose-ui-delivery config is missing $requiredPath"
        }
    }
    if ($config.ContainsKey('platform.kind') -and $config['platform.kind'] -notin @('mobile', 'web', 'desktop')) {
        Add-ValidationError -Errors $errors -Message 'platform.kind must be mobile, web, or desktop'
    }
    if ($config.ContainsKey('platform.target') -and $config['platform.target'] -notin @('android', 'ios', 'browser', 'jvm')) {
        Add-ValidationError -Errors $errors -Message 'platform.target must be android, ios, browser, or jvm'
    }
    if ($config.ContainsKey('platform.kind') -and $config.ContainsKey('platform.target')) {
        $kind = [string]$config['platform.kind']
        $target = [string]$config['platform.target']
        $validCombination = (
            ($kind -eq 'mobile' -and $target -in @('android', 'ios')) -or
            ($kind -eq 'web' -and $target -eq 'browser') -or
            ($kind -eq 'desktop' -and $target -eq 'jvm')
        )
        if (-not $validCombination -and
            $kind -in @('mobile', 'web', 'desktop') -and
            $target -in @('android', 'ios', 'browser', 'jvm')) {
            Add-ValidationError -Errors $errors -Message "Unsupported platform combination: $kind/$target"
        }
    }
    foreach ($path in @('acceptance.visual_parity_min', 'acceptance.ux_quality_min', 'acceptance.max_iterations')) {
        if ($config.ContainsKey($path)) {
            $value = $config[$path]
            if (-not (Test-IntegerValue -Value $value) -or $value -lt 1 -or $value -gt 5) {
                Add-ValidationError -Errors $errors -Message "$path must be an integer between 1 and 5"
            }
        }
    }
    foreach ($path in @('capture.record_logcat', 'acceptance.require_platform_truth', 'acceptance.require_functional_checks')) {
        if ($config.ContainsKey($path) -and $config[$path] -isnot [bool]) {
            Add-ValidationError -Errors $errors -Message "$path must be boolean"
        }
    }
}

$reviewPath = Join-Path $deliveryRoot 'templates/visual-review.json'
if (Test-Path -LiteralPath $reviewPath -PathType Leaf) {
    try {
        $review = Get-Content -LiteralPath $reviewPath -Raw | ConvertFrom-Json
        foreach ($property in @('screen', 'state', 'platform', 'target', 'iteration', 'scores', 'fixed', 'remaining', 'regressions', 'evidence_paths', 'functional_checks')) {
            if (-not ($review.PSObject.Properties.Name -contains $property)) {
                Add-ValidationError -Errors $errors -Message "visual-review.json is missing property: $property"
            }
        }
        foreach ($property in @('screen', 'state', 'platform', 'target')) {
            if (($review.PSObject.Properties.Name -contains $property) -and ($review.$property -isnot [string] -or [string]::IsNullOrWhiteSpace($review.$property))) {
                Add-ValidationError -Errors $errors -Message "visual-review.json $property must be a non-empty string"
            }
        }
        if (-not (Test-IntegerValue -Value $review.iteration) -or $review.iteration -lt 1 -or $review.iteration -gt 5) {
            Add-ValidationError -Errors $errors -Message 'visual-review.json iteration must be an integer between 1 and 5'
        }
        if ($null -eq $review.scores -or $review.scores -isnot [pscustomobject]) {
            Add-ValidationError -Errors $errors -Message 'visual-review.json scores must be an object'
        } else {
            foreach ($property in @('visual_parity', 'ux_quality')) {
                $score = $review.scores.$property
                if (-not (Test-IntegerValue -Value $score) -or $score -lt 1 -or $score -gt 5) {
                    Add-ValidationError -Errors $errors -Message "visual-review.json scores.$property must be an integer between 1 and 5"
                }
            }
            if ($review.scores.anti_ai_slop -notin @('pass', 'fail', 'blocked')) {
                Add-ValidationError -Errors $errors -Message 'visual-review.json scores.anti_ai_slop must be pass, fail, or blocked'
            }
        }
        foreach ($property in @('fixed', 'remaining', 'regressions')) {
            if ($review.$property -isnot [array]) {
                Add-ValidationError -Errors $errors -Message "visual-review.json $property must be an array"
            } else {
                foreach ($item in $review.$property) {
                    if ($item -isnot [string]) {
                        Add-ValidationError -Errors $errors -Message "visual-review.json $property entries must be strings"
                    }
                }
            }
        }
        foreach ($property in @('reference_image', 'actual_image', 'diff_image')) {
            if ($review.evidence_paths.$property -isnot [string] -or [string]::IsNullOrWhiteSpace($review.evidence_paths.$property)) {
                Add-ValidationError -Errors $errors -Message "visual-review.json evidence_paths.$property must be a non-empty string"
            }
        }
        if ($review.functional_checks -isnot [array] -or $review.functional_checks.Count -eq 0) {
            Add-ValidationError -Errors $errors -Message 'visual-review.json functional_checks must be a non-empty array'
        } else {
            foreach ($check in $review.functional_checks) {
                if ($check -isnot [pscustomobject] -or
                    $check.name -isnot [string] -or [string]::IsNullOrWhiteSpace($check.name) -or
                    $check.result -notin @('pass', 'fail', 'blocked')) {
                    Add-ValidationError -Errors $errors -Message 'visual-review.json functional checks require a string name and pass, fail, or blocked result'
                }
            }
        }
    } catch {
        Add-ValidationError -Errors $errors -Message "visual-review.json is invalid: $($_.Exception.Message)"
    }
}

$scriptsRoot = Join-Path $deliveryRoot 'scripts'
if (Test-Path -LiteralPath $scriptsRoot -PathType Container) {
    foreach ($script in Get-ChildItem -LiteralPath $scriptsRoot -Filter '*.ps1' -File -Recurse) {
        Test-PowerShellSyntax -Path $script.FullName -Errors $errors
    }
}

if ($errors.Count -gt 0) {
    foreach ($message in $errors) {
        [Console]::Error.WriteLine($message)
    }
    exit 1
}

Write-Output "Repository skill validation passed for $root. Checked $($skillNames.Count) skill packages and $($checkedFiles.Count) production files."
