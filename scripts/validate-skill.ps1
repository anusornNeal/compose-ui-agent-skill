[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SkillRoot
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

function Test-RequiredPatterns {
    param(
        [string]$Content,
        [string]$Label,
        [string[]]$Patterns,
        [System.Collections.Generic.List[string]]$Errors
    )

    foreach ($pattern in $Patterns) {
        if ($Content -notmatch $pattern) {
            Add-ValidationError -Errors $Errors -Message "$Label is missing required pattern: $pattern"
        }
    }
}

function Get-LocalMarkdownTargets {
    param(
        [string]$SourcePath,
        [string]$Content
    )

    $matches = [System.Text.RegularExpressions.Regex]::Matches($Content, '\[[^\]]+\]\(([^)#?]+)\)')
    foreach ($match in $matches) {
        $target = $match.Groups[1].Value.Trim()
        if ([string]::IsNullOrWhiteSpace($target) -or $target.StartsWith('http://') -or $target.StartsWith('https://') -or $target.StartsWith('mailto:')) {
            continue
        }

        [pscustomobject]@{
            Source = $SourcePath
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
    if ($parseErrors.Count -gt 0) {
        $messages = ($parseErrors | ForEach-Object { $_.Message }) -join '; '
        Add-ValidationError -Errors $Errors -Message "PowerShell syntax error in $Path`: $messages"
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
        if ($trimmed.Length -lt 2) { throw "Empty quoted YAML scalar: $trimmed" }
        return $trimmed.Substring(1, $trimmed.Length - 2)
    }
    if ([string]::IsNullOrWhiteSpace($trimmed)) { throw 'Empty YAML scalar' }
    if ($trimmed -eq 'true') { return $true }
    if ($trimmed -eq 'false') { return $false }
    $number = 0
    if ([int]::TryParse($trimmed, [ref]$number)) { return $number }
    $decimalNumber = [double]0
    if ([double]::TryParse($trimmed, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$decimalNumber)) { return $decimalNumber }
    if ($trimmed -match ':') { throw "Unsupported unquoted YAML scalar: $trimmed" }
    return $trimmed
}

function Test-JsonInteger {
    param([object]$Value)

    return $null -ne $Value -and $Value -isnot [bool] -and (
        $Value -is [byte] -or $Value -is [sbyte] -or
        $Value -is [int16] -or $Value -is [uint16] -or
        $Value -is [int32] -or $Value -is [uint32] -or
        $Value -is [int64] -or $Value -is [uint64]
    )
}

function Test-JsonNumber {
    param([object]$Value)

    return (Test-JsonInteger -Value $Value) -or (
        $Value -is [single] -or $Value -is [double] -or $Value -is [decimal]
    )
}

function Parse-ConstrainedYaml {
    param(
        [string[]]$Lines,
        [string]$Label,
        [string[]]$AllowedPaths,
        [System.Collections.Generic.List[string]]$Errors
    )

    $values = @{}
    $stack = New-Object System.Collections.Generic.List[object]
    [void]$stack.Add([pscustomobject]@{ Indent = -1; Path = ''; Keys = @{} })
    foreach ($rawLine in $Lines) {
        if ([string]::IsNullOrWhiteSpace($rawLine) -or $rawLine.TrimStart().StartsWith('#')) { continue }
        if ($rawLine -match "`t") {
            Add-ValidationError -Errors $Errors -Message "$Label contains tab indentation."
            continue
        }

        $indent = $rawLine.Length - $rawLine.TrimStart(' ').Length
        if ($rawLine -notmatch '^\s*(?<key>[A-Za-z0-9_]+):\s*(?<value>.*)$') {
            Add-ValidationError -Errors $Errors -Message "$Label contains malformed YAML: $rawLine"
            continue
        }

        while ($stack.Count -gt 1 -and $indent -le $stack[$stack.Count - 1].Indent) {
            $stack.RemoveAt($stack.Count - 1)
        }
        $parent = $stack[$stack.Count - 1]
        $expectedIndent = if ($parent.Indent -lt 0) { 0 } else { $parent.Indent + 2 }
        if ($indent -ne $expectedIndent) {
            Add-ValidationError -Errors $Errors -Message "$Label has invalid indentation at: $rawLine"
            continue
        }
        $key = $matches['key']
        $path = if ($parent.Path) { "$($parent.Path).$key" } else { $key }
        if ($parent.Keys.ContainsKey($key)) {
            Add-ValidationError -Errors $Errors -Message "$Label contains duplicate key: $path"
            continue
        }
        $parent.Keys[$key] = $true
        if ($AllowedPaths -notcontains $path) {
            Add-ValidationError -Errors $Errors -Message "$Label contains unsupported key: $path"
        }

        $valueText = $matches['value']
        if ([string]::IsNullOrWhiteSpace($valueText)) {
            $values[$path] = $null
            [void]$stack.Add([pscustomobject]@{ Indent = $indent; Path = $path; Keys = @{} })
            continue
        }

        try {
            $values[$path] = Convert-YamlScalar -Value $valueText
        } catch {
            Add-ValidationError -Errors $Errors -Message "$Label has invalid value at $path`: $($_.Exception.Message)"
        }
    }

    return $values
}

function Test-RequiredValuePaths {
    param(
        [hashtable]$Values,
        [string]$Label,
        [string[]]$Paths,
        [System.Collections.Generic.List[string]]$Errors
    )

    foreach ($path in $Paths) {
        if (-not $Values.ContainsKey($path)) {
            Add-ValidationError -Errors $Errors -Message "$Label is missing required key: $path"
        }
    }
}

$root = [System.IO.Path]::GetFullPath($SkillRoot).TrimEnd('\')
$rootPrefix = $root + '\'
$errors = [System.Collections.Generic.List[string]]::new()

$requiredFiles = @(
    'SKILL.md',
    'agents/openai.yaml',
    'references/reference-mode.md',
    'references/designer-mode.md',
    'references/visual-review.md',
    'references/compose-patterns.md',
    'references/rubrics/visual-parity.md',
    'references/rubrics/ux-quality.md',
    'references/rubrics/anti-ai-slop.md',
    'templates/compose-ui-agent.yaml',
    'templates/screen-spec.md',
    'templates/visual-review.json',
    'scripts/discover-project.ps1',
    'scripts/build-and-launch.ps1',
    'scripts/capture-screen.ps1',
    'scripts/collect-ui-evidence.ps1',
    'scripts/compare-images.py',
    'scripts/test_compare_images.py'
)

$productionFiles = [System.Collections.Generic.List[string]]::new()
foreach ($relativePath in $requiredFiles) {
    $fullPath = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        Add-ValidationError -Errors $errors -Message "Missing required file: $relativePath"
    } else {
        [void]$productionFiles.Add($fullPath)
    }
}

$skillFile = Join-Path $root 'SKILL.md'
$metadataFile = Join-Path $root 'agents/openai.yaml'
$skillContent = if (Test-Path -LiteralPath $skillFile -PathType Leaf) { Get-Content -LiteralPath $skillFile -Raw } else { $null }
$metadataContent = if (Test-Path -LiteralPath $metadataFile -PathType Leaf) { Get-Content -LiteralPath $metadataFile -Raw } else { $null }

if ($null -ne $skillContent) {
    $frontmatter = [System.Text.RegularExpressions.Regex]::Match($skillContent, '\A---\r?\n(?<front>[\s\S]*?)\r?\n---\r?\n')
    if (-not $frontmatter.Success) {
        Add-ValidationError -Errors $errors -Message 'SKILL.md must start with YAML frontmatter and a closing delimiter.'
    } else {
        $frontmatterValues = Parse-ConstrainedYaml -Lines ($frontmatter.Groups['front'].Value -split '\r?\n') -Label 'SKILL.md frontmatter' -AllowedPaths @('name', 'description') -Errors $errors
        Test-RequiredValuePaths -Values $frontmatterValues -Label 'SKILL.md frontmatter' -Paths @('name', 'description') -Errors $errors
        if ($frontmatterValues.ContainsKey('name') -and $frontmatterValues['name'] -cne 'compose-ui-agent-skill') {
            Add-ValidationError -Errors $errors -Message 'SKILL.md frontmatter name must be compose-ui-agent-skill.'
        }
        if ($frontmatterValues.ContainsKey('description') -and $frontmatterValues['description'] -notmatch '^Use when\s+') {
            Add-ValidationError -Errors $errors -Message 'SKILL.md frontmatter description must start with Use when.'
        }
    }

    $markdownFiles = @($skillFile)
    $referenceRoot = Join-Path $root 'references'
    if (Test-Path -LiteralPath $referenceRoot -PathType Container) {
        $markdownFiles += Get-ChildItem -LiteralPath $referenceRoot -Filter '*.md' -File -Recurse | ForEach-Object { $_.FullName }
    }
    foreach ($markdownFile in $markdownFiles) {
        $markdownContent = Get-Content -LiteralPath $markdownFile -Raw
        [void]$productionFiles.Add($markdownFile)
        foreach ($link in Get-LocalMarkdownTargets -SourcePath $markdownFile -Content $markdownContent) {
            if (-not $link.FullPath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                Add-ValidationError -Errors $errors -Message "Markdown link escapes skill root: $($link.Source) -> $($link.Target)"
            } elseif (-not (Test-Path -LiteralPath $link.FullPath -PathType Leaf)) {
                Add-ValidationError -Errors $errors -Message "Missing markdown link target: $($link.Source) -> $($link.Target)"
            }
        }
    }
}

if ($null -ne $metadataContent) {
    $metadataValues = Parse-ConstrainedYaml -Lines ($metadataContent -split '\r?\n') -Label 'agents/openai.yaml' -AllowedPaths @('interface', 'interface.display_name', 'interface.short_description', 'interface.default_prompt') -Errors $errors
    Test-RequiredValuePaths -Values $metadataValues -Label 'agents/openai.yaml' -Paths @('interface.display_name', 'interface.short_description', 'interface.default_prompt') -Errors $errors
    if ($metadataValues.ContainsKey('interface.display_name') -and ($metadataValues['interface.display_name'] -isnot [string] -or [string]::IsNullOrWhiteSpace($metadataValues['interface.display_name']))) {
        Add-ValidationError -Errors $errors -Message 'agents/openai.yaml interface.display_name must be a non-empty string.'
    }
    if ($metadataValues.ContainsKey('interface.short_description') -and ($metadataValues['interface.short_description'] -isnot [string] -or $metadataValues['interface.short_description'].Length -lt 25 -or $metadataValues['interface.short_description'].Length -gt 64)) {
        Add-ValidationError -Errors $errors -Message 'agents/openai.yaml interface.short_description must be a 25–64 character string.'
    }
    if ($metadataValues.ContainsKey('interface.default_prompt')) {
        if ($metadataValues['interface.default_prompt'] -isnot [string] -or [string]::IsNullOrWhiteSpace($metadataValues['interface.default_prompt'])) {
            Add-ValidationError -Errors $errors -Message 'agents/openai.yaml interface.default_prompt must be a non-empty string.'
        } elseif ($metadataValues['interface.default_prompt'] -notmatch '\$compose-ui-agent-skill') {
            Add-ValidationError -Errors $errors -Message 'agents/openai.yaml interface.default_prompt must mention $compose-ui-agent-skill.'
        }
    }
}

$jsonTemplatePath = Join-Path $root 'templates/visual-review.json'
if (Test-Path -LiteralPath $jsonTemplatePath -PathType Leaf) {
    try {
        $jsonTemplate = Get-Content -LiteralPath $jsonTemplatePath -Raw | ConvertFrom-Json
        foreach ($property in @('screen', 'state', 'iteration', 'scores', 'fixed', 'remaining', 'regressions', 'evidence_paths', 'functional_checks')) {
            if (-not ($jsonTemplate.PSObject.Properties.Name -contains $property)) {
                Add-ValidationError -Errors $errors -Message "templates/visual-review.json is missing property: $property"
            }
        }
        foreach ($property in @('screen', 'state')) {
            if (($jsonTemplate.PSObject.Properties.Name -contains $property) -and ($jsonTemplate.$property -isnot [string] -or [string]::IsNullOrWhiteSpace($jsonTemplate.$property))) {
                Add-ValidationError -Errors $errors -Message "templates/visual-review.json $property must be a non-empty string."
            }
        }
        if ($null -eq $jsonTemplate.scores -or $jsonTemplate.scores -isnot [pscustomobject]) {
            Add-ValidationError -Errors $errors -Message 'templates/visual-review.json scores must be an object.'
        } else {
            foreach ($property in @('visual_parity', 'ux_quality', 'anti_ai_slop')) {
                if (-not ($jsonTemplate.scores.PSObject.Properties.Name -contains $property)) {
                    Add-ValidationError -Errors $errors -Message "templates/visual-review.json scores is missing property: $property"
                }
            }
            foreach ($property in @('visual_parity', 'ux_quality')) {
                if ($jsonTemplate.scores.PSObject.Properties.Name -contains $property) {
                    $score = $jsonTemplate.scores.$property
                    if (-not (Test-JsonNumber -Value $score)) {
                        Add-ValidationError -Errors $errors -Message "templates/visual-review.json scores.$property must be numeric."
                    } elseif ($score -lt 1 -or $score -gt 5) {
                        Add-ValidationError -Errors $errors -Message "templates/visual-review.json scores.$property must be between 1 and 5."
                    }
                }
            }
            if ($jsonTemplate.scores.PSObject.Properties.Name -contains 'anti_ai_slop') {
                if ($jsonTemplate.scores.anti_ai_slop -isnot [string]) {
                    Add-ValidationError -Errors $errors -Message 'templates/visual-review.json scores.anti_ai_slop must be a string.'
                } elseif ($jsonTemplate.scores.anti_ai_slop -notin @('pass', 'fail', 'blocked')) {
                    Add-ValidationError -Errors $errors -Message 'templates/visual-review.json scores.anti_ai_slop must be pass, fail, or blocked.'
                }
            }
        }
        foreach ($collectionProperty in @('fixed', 'remaining', 'regressions')) {
            if ($jsonTemplate.$collectionProperty -isnot [array]) {
                Add-ValidationError -Errors $errors -Message "templates/visual-review.json $collectionProperty must be an array."
            } else {
                foreach ($item in $jsonTemplate.$collectionProperty) {
                    if ($item -isnot [string]) {
                        Add-ValidationError -Errors $errors -Message "templates/visual-review.json $collectionProperty entries must be strings."
                    }
                }
            }
        }
        if (-not (Test-JsonInteger -Value $jsonTemplate.iteration)) {
            Add-ValidationError -Errors $errors -Message 'templates/visual-review.json iteration must be numeric.'
        } elseif ($jsonTemplate.iteration -lt 1 -or $jsonTemplate.iteration -gt 5) {
            Add-ValidationError -Errors $errors -Message 'templates/visual-review.json iteration must be between 1 and 5.'
        }
        if ($null -eq $jsonTemplate.evidence_paths -or $jsonTemplate.evidence_paths -isnot [pscustomobject]) {
            Add-ValidationError -Errors $errors -Message 'templates/visual-review.json evidence_paths must be an object.'
        } else {
            foreach ($property in @('reference_image', 'actual_image', 'diff_image')) {
                if (-not ($jsonTemplate.evidence_paths.PSObject.Properties.Name -contains $property)) {
                    Add-ValidationError -Errors $errors -Message "templates/visual-review.json evidence_paths is missing property: $property"
                } elseif ($jsonTemplate.evidence_paths.$property -isnot [string] -or [string]::IsNullOrWhiteSpace($jsonTemplate.evidence_paths.$property)) {
                    Add-ValidationError -Errors $errors -Message "templates/visual-review.json evidence_paths.$property must be a non-empty string."
                }
            }
        }
        if ($jsonTemplate.functional_checks -isnot [array] -or $jsonTemplate.functional_checks.Count -eq 0) {
            Add-ValidationError -Errors $errors -Message 'templates/visual-review.json functional_checks must be a non-empty array.'
        } else {
            foreach ($check in $jsonTemplate.functional_checks) {
                if ($check -isnot [pscustomobject]) {
                    Add-ValidationError -Errors $errors -Message 'templates/visual-review.json functional_checks entries must be objects.'
                    continue
                }
                if (-not ($check.PSObject.Properties.Name -contains 'name') -or $check.name -isnot [string] -or [string]::IsNullOrWhiteSpace($check.name) -or
                    -not ($check.PSObject.Properties.Name -contains 'result') -or $check.result -isnot [string] -or [string]::IsNullOrWhiteSpace($check.result) -or
                    $check.result -notin @('pass', 'fail', 'blocked')) {
                    Add-ValidationError -Errors $errors -Message 'templates/visual-review.json functional_checks entries need name and result.'
                }
            }
        }
    } catch {
        Add-ValidationError -Errors $errors -Message "templates/visual-review.json is invalid JSON: $($_.Exception.Message)"
    }
}

$configTemplatePath = Join-Path $root 'templates/compose-ui-agent.yaml'
if (Test-Path -LiteralPath $configTemplatePath -PathType Leaf) {
    $configContent = Get-Content -LiteralPath $configTemplatePath -Raw
    $configAllowedPaths = @(
        'project', 'project.root', 'project.module', 'project.package_name', 'project.variant',
        'device_profiles', 'device_profiles.primary', 'device_profiles.primary.name', 'device_profiles.primary.serial',
        'device_profiles.primary.width_dp', 'device_profiles.primary.height_dp', 'device_profiles.primary.density',
        'launch', 'launch.mode', 'launch.target', 'launch.deeplink', 'launch.entry_state',
        'capture', 'capture.reference_dir', 'capture.actual_dir', 'capture.diff_dir', 'capture.record_logcat',
        'acceptance', 'acceptance.visual_parity_min', 'acceptance.ux_quality_min', 'acceptance.max_iterations',
        'acceptance.require_emulator_truth', 'acceptance.require_functional_checks'
    )
    $configValues = Parse-ConstrainedYaml -Lines ($configContent -split '\r?\n') -Label 'templates/compose-ui-agent.yaml' -AllowedPaths $configAllowedPaths -Errors $errors
    Test-RequiredValuePaths -Values $configValues -Label 'templates/compose-ui-agent.yaml' -Paths @(
        'project.root', 'project.module', 'project.variant', 'device_profiles.primary', 'launch.mode', 'launch.target',
        'capture.reference_dir', 'capture.actual_dir', 'capture.diff_dir', 'acceptance.max_iterations'
    ) -Errors $errors
    foreach ($numericPath in @('device_profiles.primary.width_dp', 'device_profiles.primary.height_dp', 'acceptance.max_iterations')) {
        if ($configValues.ContainsKey($numericPath) -and $configValues[$numericPath] -isnot [int]) {
            Add-ValidationError -Errors $errors -Message "templates/compose-ui-agent.yaml key must be an integer: $numericPath"
        }
    }
    if ($configValues.ContainsKey('launch.mode') -and $configValues['launch.mode'] -notin @('activity', 'deeplink')) {
        Add-ValidationError -Errors $errors -Message 'templates/compose-ui-agent.yaml launch.mode must be activity or deeplink.'
    }
    foreach ($boundedPath in @('acceptance.visual_parity_min', 'acceptance.ux_quality_min')) {
        if ($configValues.ContainsKey($boundedPath) -and ($configValues[$boundedPath] -isnot [int] -or $configValues[$boundedPath] -lt 1 -or $configValues[$boundedPath] -gt 5)) {
            Add-ValidationError -Errors $errors -Message "templates/compose-ui-agent.yaml key must be an integer between 1 and 5: $boundedPath"
        }
    }
    if ($configValues.ContainsKey('acceptance.max_iterations') -and ($configValues['acceptance.max_iterations'] -isnot [int] -or $configValues['acceptance.max_iterations'] -lt 1 -or $configValues['acceptance.max_iterations'] -gt 5)) {
        Add-ValidationError -Errors $errors -Message 'templates/compose-ui-agent.yaml acceptance.max_iterations must be an integer between 1 and 5.'
    }
    foreach ($positivePath in @('device_profiles.primary.width_dp', 'device_profiles.primary.height_dp')) {
        if ($configValues.ContainsKey($positivePath) -and ($configValues[$positivePath] -isnot [int] -or $configValues[$positivePath] -lt 1)) {
            Add-ValidationError -Errors $errors -Message "templates/compose-ui-agent.yaml key must be a positive integer: $positivePath"
        }
    }
    if ($configValues.ContainsKey('device_profiles.primary.density') -and (-not (Test-JsonNumber -Value $configValues['device_profiles.primary.density']) -or $configValues['device_profiles.primary.density'] -le 0)) {
        Add-ValidationError -Errors $errors -Message 'templates/compose-ui-agent.yaml device_profiles.primary.density must be a positive number.'
    }
    foreach ($booleanPath in @('capture.record_logcat', 'acceptance.require_emulator_truth', 'acceptance.require_functional_checks')) {
        if ($configValues.ContainsKey($booleanPath) -and $configValues[$booleanPath] -isnot [bool]) {
            Add-ValidationError -Errors $errors -Message "templates/compose-ui-agent.yaml key must be boolean: $booleanPath"
        }
    }
}

$screenTemplatePath = Join-Path $root 'templates/screen-spec.md'
if (Test-Path -LiteralPath $screenTemplatePath -PathType Leaf) {
    $screenContent = Get-Content -LiteralPath $screenTemplatePath -Raw
    Test-RequiredPatterns -Content $screenContent -Label 'templates/screen-spec.md' -Patterns @(
        '(?m)^# Screen Spec\s*$', '(?m)^## Required States\s*$', '(?m)^## Optional States\s*$', '(?m)^## Functional Checks\s*$'
    ) -Errors $errors
}

$scriptsRoot = Join-Path $root 'scripts'
if (Test-Path -LiteralPath $scriptsRoot -PathType Container) {
    foreach ($script in Get-ChildItem -LiteralPath $scriptsRoot -Filter '*.ps1' -File -Recurse) {
        Test-PowerShellSyntax -Path $script.FullName -Errors $errors
    }
}

$templatesRoot = Join-Path $root 'templates'
$referencesRoot = Join-Path $root 'references'
foreach ($directory in @($templatesRoot, $referencesRoot, $scriptsRoot)) {
    if (Test-Path -LiteralPath $directory -PathType Container) {
        foreach ($file in Get-ChildItem -LiteralPath $directory -File -Recurse) {
            [void]$productionFiles.Add($file.FullName)
        }
    }
}

foreach ($file in ($productionFiles | Sort-Object -Unique)) {
    $validatorPath = Join-Path $root 'scripts/validate-skill.ps1'
    if ([System.IO.Path]::GetFullPath($file) -eq [System.IO.Path]::GetFullPath($validatorPath)) {
        continue
    }

    $content = Get-Content -LiteralPath $file -Raw
    if ($content -match '\b(TODO|TBD)\b') {
        $relative = $file.Substring($rootPrefix.Length).Replace('\', '/')
        Add-ValidationError -Errors $errors -Message "Placeholder found in production resource: $relative"
    }
}

if ($errors.Count -gt 0) {
    foreach ($message in $errors) { Write-Error $message }
    exit 1
}

$uniqueFiles = @($productionFiles | Sort-Object -Unique)
Write-Output "Skill validation passed for $root. Checked $($uniqueFiles.Count) production files and $($requiredFiles.Count) required files."
