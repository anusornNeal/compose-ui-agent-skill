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

# Deprecated compatibility shim. The implementation lives in compose-ui-delivery.
$target = Join-Path $PSScriptRoot '../skills/compose-ui-delivery/scripts/collect-ui-evidence.ps1'
& $target @PSBoundParameters
