[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,

    [string]$OutputPath
)

# Deprecated compatibility shim. The implementation lives in compose-ui-delivery.
$target = Join-Path $PSScriptRoot '../skills/compose-ui-delivery/scripts/discover-project.ps1'
& $target @PSBoundParameters
