[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Serial,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [switch]$Force
)

# Deprecated compatibility shim. The implementation lives in compose-ui-delivery.
$target = Join-Path $PSScriptRoot '../skills/compose-ui-delivery/scripts/capture-screen.ps1'
& $target @PSBoundParameters
