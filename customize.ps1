<#
.SYNOPSIS
    Customize the GitHub Profile Kit username/branding and optionally push to GitHub.
.EXAMPLE
    .\customize.ps1 -Username "D250180B"
.EXAMPLE
    .\customize.ps1 -Username "hyik007" -Push
#>
param(
    [string]$Username,
    [string]$DisplayName,
    [string]$Email,
    [switch]$UpdateProjectLinks,
    [switch]$Push
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

$ReadmePath  = Join-Path $Root "README.md"
$BannerPath  = Join-Path $Root "assets\banner.svg"
$PreviewPath = Join-Path $Root "preview.html"

# Detect currently configured profile username from README streak-stats URL
$readmeContent = Get-Content -Path $ReadmePath -Raw -Encoding UTF8
$currentMatch = [regex]::Match($readmeContent, 'streak-stats\.demolab\.com\?user=([A-Za-z0-9-]+)')
$CurrentUser = if ($currentMatch.Success) { $currentMatch.Groups[1].Value } else { "hyik007" }

if ($Username -and $Username -ne $CurrentUser) {
    Write-Host "Switching profile identity from '$CurrentUser' -> '$Username'..." -ForegroundColor Cyan

    $targets = @($ReadmePath, $BannerPath, $PreviewPath)
    foreach ($file in $targets) {
        if (-not (Test-Path $file)) { continue }
        $text = Get-Content -Path $file -Raw -Encoding UTF8

        # Update profile-specific URLs & handles while preserving actual project repo URLs unless requested
        $text = $text -replace "streak-stats\.demolab\.com\?user=$([regex]::Escape($CurrentUser))", "streak-stats.demolab.com?user=$Username"
        $text = $text -replace "img\.shields\.io/github/followers/$([regex]::Escape($CurrentUser))", "img.shields.io/github/followers/$Username"
        $text = $text -replace "https://github\.com/$([regex]::Escape($CurrentUser))(?![/A-Za-z0-9_-])", "https://github.com/$Username"
        $text = $text -replace "@$([regex]::Escape($CurrentUser))\b", "@$Username"
        $text = $text -replace "$([regex]::Escape($CurrentUser)) — telemetry\.zsh", "$Username — telemetry.zsh"

        if ($UpdateProjectLinks) {
            $text = $text -replace "github\.com/$([regex]::Escape($CurrentUser))/", "github.com/$Username/"
        }

        [System.IO.File]::WriteAllText($file, $text, [System.Text.UTF8Encoding]::new($false))
    }

    $CurrentUser = $Username
    Write-Host "Updated README.md, assets/banner.svg, and preview.html for @$Username." -ForegroundColor Green
}

if ($DisplayName) {
    foreach ($file in @($ReadmePath, $BannerPath, $PreviewPath)) {
        if (Test-Path $file) {
            $text = Get-Content -Path $file -Raw -Encoding UTF8
            $text = $text -replace "Hong Yik", $DisplayName
            [System.IO.File]::WriteAllText($file, $text, [System.Text.UTF8Encoding]::new($false))
        }
    }
    Write-Host "Updated display name to '$DisplayName'." -ForegroundColor Green
}

if ($Email) {
    foreach ($file in @($ReadmePath, $PreviewPath)) {
        if (Test-Path $file) {
            $text = Get-Content -Path $file -Raw -Encoding UTF8
            $text = $text -replace "d250180b@sc\.edu\.my", $Email
            [System.IO.File]::WriteAllText($file, $text, [System.Text.UTF8Encoding]::new($false))
        }
    }
    Write-Host "Updated contact email to '$Email'." -ForegroundColor Green
}

if ($Push) {
    $TargetRepo = "$CurrentUser/$CurrentUser"
    $RemoteUrl  = "https://github.com/$TargetRepo.git"
    Write-Host "`nPreparing to deploy to $RemoteUrl ..." -ForegroundColor Cyan

    Push-Location $Root
    try {
        if (-not (Test-Path ".git")) {
            git init -b main
        }

        git add -A
        $status = git status --porcelain
        if ($status) {
            git commit -m "feat: sleek minimalist GitHub profile for @$CurrentUser"
        }

        $existingOrigin = git remote get-url origin 2>$null
        if (-not $existingOrigin) {
            git remote add origin $RemoteUrl
        } elseif ($existingOrigin -ne $RemoteUrl) {
            git remote set-url origin $RemoteUrl
        }

        $ghCmd = Get-Command gh -ErrorAction SilentlyContinue
        if ($ghCmd) {
            $null = gh repo view $TargetRepo 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Creating public profile repo $TargetRepo via GitHub CLI..." -ForegroundColor Yellow
                gh repo create $TargetRepo --public --source=. --remote=origin --push
                return
            }
        }

        Write-Host "Pushing to origin main ($RemoteUrl)..." -ForegroundColor Yellow
        git push -u origin main
        Write-Host "`nDone! View your profile at: https://github.com/$CurrentUser" -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
}
