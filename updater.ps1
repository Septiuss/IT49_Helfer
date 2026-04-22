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
    Write-Host " Update Version: $([char]27)[1;93m$($meta.version)$([char]27)[0m"
    Write-Host " Aktuelle Version: $([char]27)[1;92m$CurrentVersion$([char]27)[0m"
    Write-Host "=============================================="

    if ($meta.release_title) {
        Write-Host "Titel: $([char]27)[97m$($meta.release_title)$([char]27)[0m"
    }

    if ($meta.published_at) {
        Write-Host "Veroeffentlicht: $([char]27)[4;97m$($meta.published_at)$([char]27)[0m"
    }

    Write-Host ""
    Write-Host "$([char]27)[1;96mChangelog:$([char]27)[0m"

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

if ((Compare-Version $latestVersion $currentVersion) -le 0) {
    Write-Info "$([char]27)[1;97mKeine neuere Version gefunden.$([char]27)[0m Installiert: $([char]27)[1;32m$CurrentVersion$([char]27)[0m"
    Write-Info "$([char]27)[1;97mDu bist auf dem aktuellsten Stand.$([char]27)[0m"
    exit 0
}

Show-Changelog $meta

if ($Mode -eq "CheckOnly") {
    exit 0
}

if ($Mode -eq "Prompt") {
    $choice = Read-Host "$([char]27)[1;97mUpdate jetzt herunterladen und installieren?$([char]27)[0m ($([char]27)[32mJ$([char]27)[0m/$([char]27)[31mN$([char]27)[0m)"
    if ($choice -notmatch '^(J|j|Y|y)$') {
        Write-Info "$([char]27)[31mUpdate abgebrochen.$([char]27)[0m"
        exit 0
    }
}

$downloadTarget = Join-Path $tempDir $assetName
Clear-Host
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host ""
Write-Info "$([char]27)[1;6;91mLade neue Version herunter...$([char]27)[0m"

try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadTarget -UseBasicParsing -ErrorAction Stop
} catch {
    Write-WarnMsg "Invoke-WebRequest fehlgeschlagen - versuche Fallback..."
    try {
        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($downloadUrl, $downloadTarget)
        $wc.Dispose()
    } catch {
        Write-WarnMsg "Download fehlgeschlagen. $($_.Exception.Message)"
        exit 1
    }
}

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
Write-Host ""
Clear-Host
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "Das Update wurde erfolgreich installiert."
Write-Host ""
Write-Host "$([char]27)[1;6;92mDas Programm wird automatisch neugestartet$([char]27)[0m"
Write-Host ""
Write-Host "Dieses Fenster schliesst sich automatisch."
Write-Host ""
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""

$seconds = 10
for ($i = $seconds; $i -gt 0; $i--) {
    Write-Host -NoNewline "`rFenster schliesst in $i Sekunden...   " -ForegroundColor Yellow
    Start-Sleep -Seconds 1
}

[Environment]::Exit(99)