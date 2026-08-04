[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,

    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,

    [switch]$DryRun
)

# Deprecated compatibility shim. The implementation lives in compose-ui-delivery.
$target = Join-Path $PSScriptRoot '../skills/compose-ui-delivery/scripts/build-and-launch.ps1'
& $target @PSBoundParameters
