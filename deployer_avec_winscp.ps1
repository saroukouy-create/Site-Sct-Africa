param(
    [string]$FtpHost = '89.117.9.205',
    [string]$User = 'u249558677.sct-africa.site',
    [string]$CredentialPath = (Join-Path $PSScriptRoot '.secrets\hostinger-ftp.xml'),
    [string]$RemoteDir = '/',
    [switch]$OpenSite
)

$ErrorActionPreference = 'Stop'

$workspaceRoot = $PSScriptRoot
$prepareScript = Join-Path $workspaceRoot 'prepare_deploy.ps1'
$credentialSetupScript = Join-Path $workspaceRoot 'enregistrer_identifiants_hostinger.ps1'
$deployDir = Join-Path $workspaceRoot 'deploy'
$publicHtmlDir = Join-Path $workspaceRoot 'public_html'
$winscpCandidates = @(
    'C:\Users\Mahmoud SAROUKOU\AppData\Local\Programs\WinSCP\WinSCP.com',
    'C:\Users\Mahmoud SAROUKOU\AppData\Local\Programs\WinSCP\WinSCP.exe',
    'C:\Program Files (x86)\WinSCP\WinSCP.com',
    'C:\Program Files (x86)\WinSCP\WinSCP.exe',
    'C:\Program Files\WinSCP\WinSCP.exe',
    'C:\Program Files\WinSCP\WinSCP.com'
)

function Write-Step {
    param([string]$Message)
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Invoke-PrepareDeploy {
    param(
        [string]$ScriptPath,
        [string]$DeployPath
    )

    $tempLog = [System.IO.Path]::GetTempFileName()
    try {
        $global:LASTEXITCODE = 0
        & $ScriptPath *> $tempLog

        if (-not $? -or -not (Test-Path $DeployPath)) {
            $logTail = (Get-Content $tempLog -Tail 60) -join "`n"
            throw "La preparation du package deploy a echoue.`n$logTail"
        }

        $fileCount = (Get-ChildItem -Path $DeployPath -Recurse -File | Measure-Object).Count
        Write-Host ("Package deploy pret : {0} fichier(s)." -f $fileCount) -ForegroundColor Green
    } finally {
        if (Test-Path $tempLog) {
            Remove-Item $tempLog -Force
        }
    }
}

function Get-StoredCredential {
    param(
        [string]$Path,
        [string]$Username
    )

    if (-not (Test-Path $Path)) {
        if (-not (Test-Path $credentialSetupScript)) {
            throw "Fichier d'identifiants introuvable : $Path"
        }

        Write-Host 'Aucun identifiant Hostinger enregistre. Saisie du mot de passe FTP...' -ForegroundColor Yellow
        & $credentialSetupScript -User $Username -CredentialPath $Path

        if (-not $?) {
            throw 'L enregistrement des identifiants Hostinger a echoue.'
        }
    }

    if (-not (Test-Path $Path)) {
        throw "Fichier d'identifiants introuvable apres enregistrement : $Path"
    }

    return Import-Clixml -Path $Path
}

function Get-WinScpExecutable {
    foreach ($candidate in $winscpCandidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    throw 'WinSCP.com est introuvable. Installe WinSCP d abord.'
}

function Sync-LocalPublicHtml {
    param(
        [string]$SourceDir,
        [string]$TargetDir
    )

    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }

    & robocopy.exe $SourceDir $TargetDir /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) {
        throw "Echec de synchronisation locale vers public_html (code robocopy : $LASTEXITCODE)."
    }
}

function Invoke-WinScpSync {
    param(
        [string]$WinScpPath,
        [string]$HostName,
        [string]$Username,
        [string]$PlainPassword,
        [string]$LocalDir,
        [string]$RemotePath
    )

    $encodedUser = [System.Uri]::EscapeDataString($Username)
    $encodedPassword = [System.Uri]::EscapeDataString($PlainPassword)
    $sessionUrl = "ftp://${encodedUser}:${encodedPassword}@${HostName}/"
    $localFileCount = (Get-ChildItem -Path $LocalDir -Recurse -File | Measure-Object).Count

    $scriptContent = @(
        'option batch abort',
        'option confirm off',
        "open `"$sessionUrl`" -passive=on",
        "synchronize remote `"$LocalDir`" `"$RemotePath`"",
        'exit'
    ) -join "`r`n"

    $tempScript = [System.IO.Path]::GetTempFileName()
    $tempLog = [System.IO.Path]::ChangeExtension($tempScript, '.log')
    try {
        [System.IO.File]::WriteAllText($tempScript, $scriptContent, [System.Text.Encoding]::ASCII)
        Write-Host ("Synchronisation WinSCP en cours : {0} fichier(s) locaux." -f $localFileCount) -ForegroundColor DarkGray
        & $WinScpPath "/ini=nul" "/log=$tempLog" "/script=$tempScript" | Out-Null

        if ($LASTEXITCODE -ne 0) {
            $logTail = if (Test-Path $tempLog) {
                (Get-Content $tempLog -Tail 40) -join "`n"
            } else {
                'Journal WinSCP indisponible.'
            }

            throw "Synchronisation WinSCP echouee (code : $LASTEXITCODE).`n$logTail"
        }

        Write-Host ("Synchronisation WinSCP terminee : {0} fichier(s) traites." -f $localFileCount) -ForegroundColor Green
    } finally {
        if (Test-Path $tempScript) {
            Remove-Item $tempScript -Force
        }

        if (Test-Path $tempLog) {
            Remove-Item $tempLog -Force
        }
    }
}

function Test-PublicSite {
    param([string]$HostName)

    $statusCode = & curl.exe --silent --show-error --output NUL --write-out "%{http_code}" -L -k --resolve "sct-africa.site:80:$HostName" --resolve "sct-africa.site:443:$HostName" https://sct-africa.site

    if ($LASTEXITCODE -ne 0) {
        throw 'La verification HTTP a echoue.'
    }

    if ($statusCode -notmatch '^2\d\d$') {
        throw "La verification HTTP a renvoye un statut inattendu : $statusCode"
    }

    Write-Host ("Verification HTTP OK : {0}" -f $statusCode) -ForegroundColor Green
}

$storedCredential = Get-StoredCredential -Path $CredentialPath -Username $User
$plainPassword = ([System.Net.NetworkCredential]::new('', $storedCredential.Password)).Password
$winscpPath = Get-WinScpExecutable

Write-Step -Message 'Preparation du package deploy'
Invoke-PrepareDeploy -ScriptPath $prepareScript -DeployPath $deployDir

Write-Step -Message 'Synchronisation locale de public_html'
Sync-LocalPublicHtml -SourceDir $deployDir -TargetDir $publicHtmlDir
Write-Host 'public_html synchronise avec deploy.' -ForegroundColor Green

Write-Step -Message 'Publication via WinSCP'
Invoke-WinScpSync -WinScpPath $winscpPath -HostName $FtpHost -Username $User -PlainPassword $plainPassword -LocalDir $publicHtmlDir -RemotePath $RemoteDir
Write-Host 'Synchronisation distante terminee.' -ForegroundColor Green

Write-Step -Message 'Verification HTTP finale'
Test-PublicSite -HostName $FtpHost

Write-Host "`nDeploiement WinSCP termine." -ForegroundColor Green
Write-Host 'Site cible : https://sct-africa.site' -ForegroundColor Green

if ($OpenSite) {
    Start-Process 'https://sct-africa.site'
}