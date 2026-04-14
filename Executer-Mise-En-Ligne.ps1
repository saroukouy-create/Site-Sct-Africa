param(
    [string]$User = 'u249558677.sct-africa.site'
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Deploiement simple SCT Africa' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Etapes :' -ForegroundColor DarkGray
Write-Host '- generation de deploy' -ForegroundColor DarkGray
Write-Host '- synchronisation de public_html' -ForegroundColor DarkGray
Write-Host '- publication via WinSCP' -ForegroundColor DarkGray
Write-Host '- verification HTTP finale' -ForegroundColor DarkGray
Write-Host ''

$arguments = @(
    '-NoProfile'
    '-ExecutionPolicy', 'Bypass'
    '-File', (Join-Path $PSScriptRoot 'deployer_avec_winscp.ps1')
    '-User', $User
)

& powershell.exe @arguments
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
