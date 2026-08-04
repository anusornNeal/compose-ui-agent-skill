[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Serial,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-CaptureScreen {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeviceSerial,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,

        [switch]$AllowOverwrite
    )

    if ([string]::IsNullOrWhiteSpace($DeviceSerial)) {
        throw 'adb serial is required'
    }

    if ($DeviceSerial -notmatch '^[A-Za-z0-9._:-]+$') {
        throw "Unsupported adb serial: $DeviceSerial"
    }

    $adbCommand = Get-Command adb -ErrorAction SilentlyContinue
    if ($null -eq $adbCommand) {
        throw 'adb command not found on PATH'
    }

    if ((-not $AllowOverwrite) -and (Test-Path -LiteralPath $DestinationPath -PathType Leaf)) {
        throw "Output file already exists: $DestinationPath. Use -Force to overwrite."
    }

    $parent = Split-Path -Parent $DestinationPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    if (-not $parent) {
        $parent = (Get-Location).Path
    }

    $deviceInfo = New-Object System.Diagnostics.ProcessStartInfo
    $deviceInfo.FileName = $adbCommand.Source
    $deviceInfo.Arguments = 'devices'
    $deviceInfo.RedirectStandardOutput = $true
    $deviceInfo.RedirectStandardError = $true
    $deviceInfo.UseShellExecute = $false
    $deviceInfo.CreateNoWindow = $true

    $deviceProcess = New-Object System.Diagnostics.Process
    $deviceProcess.StartInfo = $deviceInfo
    [void]$deviceProcess.Start()
    $serialStdout = $deviceProcess.StandardOutput.ReadToEnd()
    $serialStderr = $deviceProcess.StandardError.ReadToEnd()
    $deviceProcess.WaitForExit()
    if ($deviceProcess.ExitCode -ne 0) {
        throw "adb devices failed with exit code $($deviceProcess.ExitCode)"
    }

    $knownSerials = @()
    foreach ($line in (($serialStdout + [Environment]::NewLine + $serialStderr) -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line -like 'List of devices attached*') {
            continue
        }

        $parts = ($line -split '\s+') | Where-Object { $_ -ne '' }
        if ($parts.Count -ge 2 -and $parts[1] -eq 'device') {
            $knownSerials += $parts[0]
        }
    }

    if ($knownSerials -notcontains $DeviceSerial) {
        throw "adb serial not found among connected devices: $DeviceSerial"
    }

    $tempPath = Join-Path $parent ((Split-Path -Leaf $DestinationPath) + '.tmp.' + [Guid]::NewGuid().ToString('N'))
    try {
        $captureInfo = New-Object System.Diagnostics.ProcessStartInfo
        $captureInfo.FileName = $adbCommand.Source
        $captureInfo.Arguments = "-s $DeviceSerial exec-out screencap -p"
        $captureInfo.RedirectStandardOutput = $true
        $captureInfo.RedirectStandardError = $true
        $captureInfo.UseShellExecute = $false
        $captureInfo.CreateNoWindow = $true

        $captureProcess = New-Object System.Diagnostics.Process
        $captureProcess.StartInfo = $captureInfo
        [void]$captureProcess.Start()
        $stderrTask = $captureProcess.StandardError.ReadToEndAsync()
        $tempStream = [System.IO.File]::Open($tempPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
            $captureProcess.StandardOutput.BaseStream.CopyTo($tempStream)
        } finally {
            $tempStream.Dispose()
        }

        $captureProcess.WaitForExit()
        $stderr = $stderrTask.Result.Trim()
        if ($captureProcess.ExitCode -ne 0) {
            if ($stderr) {
                throw "adb screencap failed with exit code $($captureProcess.ExitCode): $stderr"
            }

            throw "adb screencap failed with exit code $($captureProcess.ExitCode)"
        }

        if (-not (Test-PngStructure -Path $tempPath)) {
            throw "adb screencap did not produce a valid PNG: $DestinationPath"
        }

        if (Test-Path -LiteralPath $DestinationPath -PathType Leaf) {
            if (-not $AllowOverwrite) {
                throw "Output file already exists: $DestinationPath. Use -Force to overwrite."
            }

            [System.IO.File]::Replace($tempPath, $DestinationPath, $null)
        } else {
            [System.IO.File]::Move($tempPath, $DestinationPath)
        }
        $tempPath = $null

        return (Resolve-Path -LiteralPath $DestinationPath).Path
    } catch {
        if ($tempPath -and (Test-Path -LiteralPath $tempPath -PathType Leaf)) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }

        throw
    }
}

function Test-PngStructure {
    param([Parameter(Mandatory = $true)][string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 33) { return $false }
    $signature = [byte[]](137, 80, 78, 71, 13, 10, 26, 10)
    for ($index = 0; $index -lt $signature.Length; $index++) {
        if ($bytes[$index] -ne $signature[$index]) { return $false }
    }

    $offset = 8
    $hasHeader = $false
    $hasData = $false
    $hasEnd = $false
    while ($offset + 12 -le $bytes.Length) {
        $chunkLength = ([uint32]$bytes[$offset] -shl 24) -bor ([uint32]$bytes[$offset + 1] -shl 16) -bor ([uint32]$bytes[$offset + 2] -shl 8) -bor [uint32]$bytes[$offset + 3]
        $chunkEnd = [uint64]$offset + 12 + $chunkLength
        if ($chunkEnd -gt $bytes.Length) { return $false }
        $chunkType = [System.Text.Encoding]::ASCII.GetString($bytes, $offset + 4, 4)
        if ($chunkType -eq 'IHDR' -and $chunkLength -eq 13) { $hasHeader = $true }
        if ($chunkType -eq 'IDAT' -and $chunkLength -gt 0) { $hasData = $true }
        if ($chunkType -eq 'IEND' -and $chunkLength -eq 0) {
            $hasEnd = $true
            $offset = [int]$chunkEnd
            break
        }
        $offset = [int]$chunkEnd
    }

    return $hasHeader -and $hasData -and $hasEnd -and $offset -eq $bytes.Length
}

$capturedPath = Invoke-CaptureScreen -DeviceSerial $Serial -DestinationPath $OutputPath -AllowOverwrite:$Force
Write-Output $capturedPath
