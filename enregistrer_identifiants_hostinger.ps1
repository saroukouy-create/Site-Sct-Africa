param(
    [string]$User = 'u249558677.sct-africa.site',
    [string]$CredentialPath = (Join-Path $PSScriptRoot '.secrets\hostinger-ftp.xml')
)

$password = Read-Host 'Mot de passe FTP Hostinger' -AsSecureString
$credential = [PSCredential]::new($User, $password)

$parent = Split-Path -Path $CredentialPath -Parent
if (-not (Test-Path $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}

$credential | Export-Clixml -Path $CredentialPath
Write-Host "Identifiants enregistres : $CredentialPath" -ForegroundColor Green