param(
    [Parameter(Mandatory=$true)][string]$RepoOwner,
    [Parameter(Mandatory=$true)][string]$RepoName,
    [Parameter(Mandatory=$true)][string]$CurrentVersion,
    [string]$Channel = "stable",
    [ValidateSet("CheckOnly","Prompt","Force")][string]$Mode = "Prompt"
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Info($msg) {
    Write-Host "[INFO] $msg"
}

function Write-WarnMsg($msg) {
    Write-Host "[WARN] $msg"
}

function Normalize-Version([string]$v) {
    return ($v.Trim() -replace '^v','')
}

function Compare-Version([string]$a, [string]$b) {
    try {
        $va = [version](Normalize-Version $a)
        $vb = [version](Normalize-Version $b)
        return $va.CompareTo($vb)
    } catch {
        return [string]::Compare((Normalize-Version $a), (Normalize-Version $b), $true)
    }
}

function Show-Changelog($meta) {
    Write-Host ""
    Write-Host "=============================================="
    Write-Host " Update verfuegbar: $($meta.version)"
    Write-Host " Aktuelle Version: $CurrentVersion"
    Write-Host "=============================================="

    if ($meta.release_title) {
        Write-Host "Titel: $($meta.release_title)"
    }

    if ($meta.published_at) {
        Write-Host "Veroeffentlicht: $($meta.published_at)"
    }

    Write-Host ""
    Write-Host "Changelog:"

    $hasLines = $false

    if ($meta.changelog -is [System.Array]) {
        foreach ($line in $meta.changelog) {
            if ($line) {
                Write-Host " - $line"
                $hasLines = $true
            }
        }
    } elseif ($meta.changelog) {
        $meta.changelog.ToString().Split("`n") | ForEach-Object {
            $trim = $_.Trim()
            if ($trim) {
                Write-Host " - $trim"
                $hasLines = $true
            }
        }
    }

    if (-not $hasLines -and $meta.release_notes) {
        $meta.release_notes.ToString().Split("`n") | ForEach-Object {
            $trim = $_.Trim()
            if ($trim) {
                Write-Host " - $trim"
                $hasLines = $true
            }
        }
    }

    if (-not $hasLines) {
        Write-Host " - Kein Changelog hinterlegt."
    }

    Write-Host ""
}

$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$tempDir = Join-Path $env:TEMP "IT49_Update"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$versionUrl = "https://raw.githubusercontent.com/$RepoOwner/$RepoName/main/version.json"
Write-Info "Lade Versionsdatei: $versionUrl"

try {
    $meta = Invoke-RestMethod -Uri $versionUrl -UseBasicParsing
} catch {
    Write-WarnMsg "Versionsdatei konnte nicht geladen werden. Updatepruefung wird uebersprungen."
    exit 0
}

if ($meta.channel -and $Channel -ne $meta.channel) {
    Write-WarnMsg "Kanal stimmt nicht ueberein. Erwartet: $Channel / Datei: $($meta.channel)"
}

$latestVersion = Normalize-Version $meta.version
$currentVersion = Normalize-Version $CurrentVersion
$downloadUrl = $meta.download_url
$assetName = $meta.asset_name

if (-not $latestVersion -or -not $downloadUrl -or -not $assetName) {
    Write-WarnMsg "version.json ist unvollstaendig. Benoetigt: version, download_url, asset_name"
    exit 1
}

$cmp = Compare-Version $latestVersion $currentVersion
if ($cmp -le 0) {
    Write-Info "Keine neuere Version gefunden. Installiert: $currentVersion"
    exit 0
}

Show-Changelog $meta

if ($Mode -eq "CheckOnly") {
    exit 0
}

if ($latestVersion -eq $CurrentVersion) {
    Write-Info "Keine neuere Version gefunden. Installiert: $CurrentVersion"
    exit 0
}

if ($Mode -eq "Prompt") {
    $choice = Read-Host "Update jetzt herunterladen und installieren? (J/N)"
    if ($choice.ToLower() -ne "j") {
        Write-Info "Update abgebrochen."
        exit 0
    }

    Clear-Host
    Write-Host ""
    Write-Host "Information zum Update: Bitte Enter druecken" -ForegroundColor Red
    Read-Host

    Clear-Host
    Write-Host "Information zum Update:" -ForegroundColor Red
    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host "Falls das Script geupdated wird, bitte hier warten."
    Write-Host "Sobald das Update fertig ist, oeffnet sich ein neues Fenster"
    Write-Host "und dieses kann geschlossen werden."
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host ""
    Write-Host 'Steht oben "Keine neuere Version gefunden. Installiert: x.x.x"'
    Write-Host 'einfach "Enter" druecken und fortfahren.'
    Write-Host ""
    Read-Host
}

$downloadTarget = Join-Path $tempDir $assetName
Write-Info "Lade neue Version herunter..."
Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadTarget -UseBasicParsing

if (-not (Test-Path $downloadTarget)) {
    Write-WarnMsg "Download fehlgeschlagen."
    exit 1
}

$runningExe = Join-Path $baseDir $assetName
$backupExe = "$runningExe.bak"
$replaceScript = Join-Path $tempDir "replace_it49.cmd"

$replaceContent = @"
@echo off
setlocal EnableExtensions
cd /d "$baseDir"
for /l %%i in (1,1,20) do (
    taskkill /im "$assetName" /f >nul 2>&1
    timeout /t 1 >nul
)
if exist "$backupExe" del /f /q "$backupExe" >nul 2>&1
if exist "$runningExe" move /y "$runningExe" "$backupExe" >nul 2>&1
move /y "$downloadTarget" "$runningExe" >nul 2>&1
if not exist "$runningExe" (
    echo Update fehlgeschlagen.
    pause
    exit /b 1
)
start "" "$runningExe"
exit /b 0
"@

Set-Content -Path $replaceScript -Value $replaceContent -Encoding ASCII

Write-Info "Starte Ersetzungsskript..."
Start-Process -FilePath "cmd.exe" -ArgumentList "/c","$replaceScript" -WindowStyle Hidden
Write-Info "Updater beendet sich jetzt."
exit 0
