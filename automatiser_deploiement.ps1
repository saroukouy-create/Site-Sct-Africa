param(
    [string]$FtpHost = '89.117.9.205',
    [int]$Port = 21,
    [string]$User = $env:HOSTINGER_FTP_USER,
    [string]$Password = $env:HOSTINGER_FTP_PASSWORD,
    [string]$RemoteDir = '/',
    [string]$CredentialPath = (Join-Path $PSScriptRoot '.secrets\hostinger-ftp.xml'),
    [switch]$SkipPrepare,
    [switch]$SkipVerification,
    [switch]$OpenSite
)

$ErrorActionPreference = 'Stop'
$workspaceRoot = $PSScriptRoot
$deployDir = Join-Path $workspaceRoot 'deploy'
$publicHtmlDir = Join-Path $workspaceRoot 'public_html'
$prepareScript = Join-Path $workspaceRoot 'prepare_deploy.ps1'
function Write-Step {
    param([string]$Message)
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Sync-LocalPublicHtml {
    param(
        [string]$SourceDir,
        [string]$TargetDir
    )

    if (-not (Test-Path $SourceDir)) {
        throw "Source introuvable pour la synchronisation locale : $SourceDir"
    }

    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }

    & robocopy.exe $SourceDir $TargetDir /MIR /NFL /NDL /NJH /NJS /NP | Out-Null

    if ($LASTEXITCODE -ge 8) {
        throw "Echec de synchronisation locale vers public_html (code robocopy : $LASTEXITCODE)."
    }
}

function Get-PlainPassword {
    param([string]$CurrentPassword)

    if (-not [string]::IsNullOrWhiteSpace($CurrentPassword)) {
        return $CurrentPassword
    }

    $securePassword = Read-Host 'Mot de passe FTP Hostinger' -AsSecureString
    $credential = [System.Net.NetworkCredential]::new('', $securePassword)
    return $credential.Password
}

function Get-StoredCredential {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return $null
    }

    try {
        return Import-Clixml -Path $Path
    } catch {
        throw "Impossible de lire le fichier d'identifiants : $Path"
    }
}

function Save-StoredCredential {
    param(
        [string]$Path,
        [string]$Username,
        [string]$PlainPassword
    )

    $parent = Split-Path -Path $Path -Parent
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $securePassword = ConvertTo-SecureString -String $PlainPassword -AsPlainText -Force
    $credential = [PSCredential]::new($Username, $securePassword)
    $credential | Export-Clixml -Path $Path
}

function Assert-Tool {
    param([string]$CommandName)

    if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
        throw "Outil manquant : $CommandName"
    }
}

function Invoke-LoggedCommand {
    param(
        [scriptblock]$ScriptBlock,
        [string]$ErrorMessage
    )

    & $ScriptBlock
    if ($LASTEXITCODE -ne 0) {
        throw $ErrorMessage
    }
}

function Invoke-FtpDelete {
    param(
        [string]$HostName,
        [string]$Username,
        [string]$PlainPassword,
        [string]$RemotePath,
        [string]$RemoteName
    )

    $remoteUri = Get-RemoteUri -HostName $HostName -RemotePath $RemotePath -RelativePath ''
    & curl.exe --silent --show-error --ftp-pasv --connect-timeout 15 --max-time 30 --user "${Username}:$PlainPassword" $remoteUri -Q "DELE $RemoteName" 2>$null | Out-Null
}

function Remove-DefaultPhp {
    param(
        [string]$HostName,
        [string]$Username,
        [string]$PlainPassword,
        [string]$RemotePath
    )

    Invoke-FtpDelete -HostName $HostName -Username $Username -PlainPassword $PlainPassword -RemotePath $RemotePath -RemoteName 'default.php'
}

function Remove-LegacyRouteFiles {
    param(
        [string]$HostName,
        [string]$Username,
        [string]$PlainPassword,
        [string]$RemotePath,
        [string[]]$RouteNames
    )

    foreach ($routeName in $RouteNames) {
        Invoke-FtpDelete -HostName $HostName -Username $Username -PlainPassword $PlainPassword -RemotePath $RemotePath -RemoteName $routeName
    }
}

function Get-RelativeRemotePath {
    param(
        [string]$BasePath,
        [string]$FilePath
    )

    return $FilePath.Substring($BasePath.Length).TrimStart('\').Replace('\', '/')
}

function Get-RemoteUri {
    param(
        [string]$HostName,
        [string]$RemotePath,
        [string]$RelativePath
    )

    $normalizedRemote = if ([string]::IsNullOrWhiteSpace($RemotePath) -or $RemotePath -eq '/') {
        ''
    } else {
        '/' + $RemotePath.Trim('/')
    }

    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        return "ftp://$HostName$normalizedRemote/"
    }

    return "ftp://$HostName$normalizedRemote/$RelativePath"
}

function Upload-DeployFolder {
    param(
        [string]$HostName,
        [string]$Username,
        [string]$PlainPassword,
        [string]$LocalDeployDir,
        [string]$RemotePath
    )

    $resolvedDeployDir = (Resolve-Path $LocalDeployDir).Path
    $files = Get-ChildItem -Path $resolvedDeployDir -Recurse -File | Sort-Object FullName
    $total = $files.Count
    $index = 0

    foreach ($file in $files) {
        $index++
        $relativePath = Get-RelativeRemotePath -BasePath $resolvedDeployDir -FilePath $file.FullName
        $remoteUri = Get-RemoteUri -HostName $HostName -RemotePath $RemotePath -RelativePath $relativePath

        Write-Host ("[{0}/{1}] {2}" -f $index, $total, $relativePath) -ForegroundColor DarkGray
        & curl.exe --silent --show-error --ftp-pasv --ftp-create-dirs --retry 3 --retry-all-errors --connect-timeout 30 --max-time 180 --user "${Username}:$PlainPassword" -T $file.FullName $remoteUri

        if ($LASTEXITCODE -ne 0) {
            Write-Host ("Nouvelle tentative pour : {0}" -f $relativePath) -ForegroundColor Yellow
            & curl.exe --silent --show-error --ftp-pasv --ftp-create-dirs --retry 3 --retry-all-errors --connect-timeout 30 --max-time 180 --user "${Username}:$PlainPassword" -T $file.FullName $remoteUri
        }

        if ($LASTEXITCODE -ne 0) {
            throw "Echec d'upload : $relativePath"
        }
    }

    Write-Host ("Upload termine : {0} fichiers" -f $total) -ForegroundColor Green
}

function Test-PublicSite {
    param([string]$HostName)

    & curl.exe -I -L -k --resolve "sct-africa.site:80:$HostName" --resolve "sct-africa.site:443:$HostName" https://sct-africa.site
    if ($LASTEXITCODE -ne 0) {
        throw 'La verification HTTP a echoue.'
    }
}

Assert-Tool -CommandName 'curl.exe'

$storedCredential = Get-StoredCredential -Path $CredentialPath
if ($storedCredential) {
    if ([string]::IsNullOrWhiteSpace($User)) {
        $User = $storedCredential.UserName
    }

    if ([string]::IsNullOrWhiteSpace($Password)) {
        $Password = ([System.Net.NetworkCredential]::new('', $storedCredential.Password)).Password
    }
}

if ([string]::IsNullOrWhiteSpace($User)) {
    $User = Read-Host 'Utilisateur FTP Hostinger'
}

if ([string]::IsNullOrWhiteSpace($User)) {
    throw 'Utilisateur FTP manquant.'
}

$Password = Get-PlainPassword -CurrentPassword $Password
if ([string]::IsNullOrWhiteSpace($Password)) {
    throw 'Mot de passe FTP manquant.'
}

if (-not $storedCredential -or $storedCredential.UserName -ne $User) {
    Save-StoredCredential -Path $CredentialPath -Username $User -PlainPassword $Password
    Write-Host "Identifiants FTP enregistres localement : $CredentialPath" -ForegroundColor DarkGray
}

if (-not $SkipPrepare) {
    if (-not (Test-Path $prepareScript)) {
        throw 'prepare_deploy.ps1 est introuvable.'
    }

    Write-Step -Message 'Preparation du package deploy'
    & $prepareScript
    if (-not (Test-Path $deployDir)) {
        throw 'Le dossier deploy n a pas ete genere.'
    }
}

if (-not (Test-Path $deployDir)) {
    throw 'Le dossier deploy est introuvable.'
}

Write-Step -Message 'Synchronisation locale de public_html'
Sync-LocalPublicHtml -SourceDir $deployDir -TargetDir $publicHtmlDir
Write-Host 'public_html synchronise avec deploy.' -ForegroundColor Green

Write-Step -Message 'Nettoyage de la racine distante'
try {
    Remove-DefaultPhp -HostName $FtpHost -Username $User -PlainPassword $Password -RemotePath $RemoteDir
    Write-Host 'default.php supprime si present.' -ForegroundColor Green
} catch {
    Write-Host 'default.php absent ou suppression non necessaire.' -ForegroundColor Yellow
}

try {
    Remove-LegacyRouteFiles -HostName $FtpHost -Username $User -PlainPassword $Password -RemotePath $RemoteDir -RouteNames @(
        'about',
        'contact',
        'devis',
        'engagements',
        'missions',
        'products-accessoires',
        'products-imprimantes',
        'products-scanners'
    )
    Write-Host 'Anciennes routes plates supprimees si presentes.' -ForegroundColor Green
} catch {
    Write-Host 'Aucune route plate bloquante detectee ou suppression non necessaire.' -ForegroundColor Yellow
}

Write-Step -Message 'Upload du site vers Hostinger'
Upload-DeployFolder -HostName $FtpHost -Username $User -PlainPassword $Password -LocalDeployDir $deployDir -RemotePath $RemoteDir

if (-not $SkipVerification) {
    Write-Step -Message 'Verification HTTP finale'
    Test-PublicSite -HostName $FtpHost
}

Write-Host "`nDeploiement automatise termine." -ForegroundColor Green
Write-Host 'Site cible : https://sct-africa.site' -ForegroundColor Green

if ($OpenSite) {
    Start-Process 'https://sct-africa.site'
}