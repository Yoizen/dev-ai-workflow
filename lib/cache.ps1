# ============================================================================
# Guardian Agent - Windows PowerShell Cache Management
# ============================================================================

# ============================================================================
# Cache Directory Management
# ============================================================================

function Get-CacheDir {
    $cache_base = "$env:USERPROFILE\.cache\ga"
    
    if (-not (Test-Path $cache_base)) {
        New-Item -ItemType Directory -Path $cache_base -Force | Out-Null
    }
    
    return $cache_base
}

function Get-ProjectCacheDir {
    $git_root = Get-GitRoot
    if ([string]::IsNullOrEmpty($git_root)) {
        return $null
    }
    
    $project_hash = Get-StringHash $git_root
    $cache_base = Get-CacheDir
    $project_cache = "$cache_base\$project_hash"
    
    if (-not (Test-Path $project_cache)) {
        New-Item -ItemType Directory -Path $project_cache -Force | Out-Null
    }
    
    return $project_cache
}

# ============================================================================
# Hash Functions
# ============================================================================

function Get-StringHash {
    param([string]$String)
    
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($String)
    $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    $hashString = -join ($hash | ForEach-Object { "{0:x2}" -f $_ })
    
    return $hashString.Substring(0, 8)
}

function Get-FileHash {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        return $null
    }
    
    $content = Get-Content -Path $FilePath -Raw -Encoding UTF8
    return Get-StringHash $content
}

# ============================================================================
# Git Functions
# ============================================================================

function Get-GitRoot {
    $output = & git rev-parse --show-toplevel 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        return $output
    }
    
    return $null
}

function Get-StagedFiles {
    # Get all staged files (added, copied, modified, renamed)
    $output = @(& git diff --cached --name-only --diff-filter=ACMR 2>$null)
    
    if ($LASTEXITCODE -eq 0) {
        return $output
    }
    
    return @()
}

# ============================================================================
# Cache Operations
# ============================================================================

function Clear-ProjectCache {
    $project_cache = Get-ProjectCacheDir
    
    if ([string]::IsNullOrEmpty($project_cache)) {
        Write-Host "Not in a git repository" -ForegroundColor Red
        return 1
    }
    
    if (Test-Path $project_cache) {
        Remove-Item -Path $project_cache -Recurse -Force
        Write-Host "[OK] Cleared cache for current project" -ForegroundColor Green
    } else {
        Write-Host "[i] No cache found for current project" -ForegroundColor Blue
    }
    
    return 0
}

function Clear-AllCache {
    $cache_base = Get-CacheDir
    
    if (Test-Path $cache_base) {
        Remove-Item -Path $cache_base -Recurse -Force
        Write-Host "[OK] Cleared all cache data" -ForegroundColor Green
    } else {
        Write-Host "[i] No cache found" -ForegroundColor Blue
    }
    
    return 0
}

function Get-CacheStatus {
    $project_cache = Get-ProjectCacheDir
    
    if ([string]::IsNullOrEmpty($project_cache)) {
        Write-Host "Not in a git repository" -ForegroundColor Red
        return 1
    }
    
    Write-Host ""
    Write-Host "Cache Status:" -ForegroundColor Cyan -NoNewline
    Write-Host ""
    Write-Host ""
    Write-Host "  Cache directory: $project_cache" -ForegroundColor Cyan
    
    if (-not (Test-Path $project_cache)) {
        Write-Host "  Cache validity: " -NoNewline
        Write-Host "Empty" -ForegroundColor Yellow
        Write-Host "  Cached files: 0"
        Write-Host "  Cache size: 0 KB"
    } else {
        $files = @(Get-ChildItem -Path "$project_cache\files" -ErrorAction SilentlyContinue)
        $size = "{0:N1}" -f ((Get-ChildItem -Path $project_cache -Recurse | Measure-Object -Property Length -Sum).Sum / 1024)
        
        Write-Host "  Cache validity: " -NoNewline
        Write-Host "Valid" -ForegroundColor Green
        Write-Host "  Cached files: $($files.Count)"
        Write-Host "  Cache size: ${size} KB"
    }
    
    Write-Host ""
    return 0
}

# ============================================================================
# Cache Validation
# ============================================================================

function Is-CacheValid {
    param(
        [string]$Provider,
        [string]$RulesFile,
        [string]$ConfigFile
    )
    
    $project_cache = Get-ProjectCacheDir
    
    if ([string]::IsNullOrEmpty($project_cache) -or -not (Test-Path $project_cache)) {
        return $false
    }
    
    $metadata_file = "$project_cache\metadata"
    
    if (-not (Test-Path $metadata_file)) {
        return $false
    }
    
    $current_rules_hash = Get-FileHash $RulesFile
    $current_config_hash = Get-FileHash $ConfigFile
    $current_hash = "$current_rules_hash$current_config_hash"
    
    $stored_hash = Get-Content -Path $metadata_file -Raw -ErrorAction SilentlyContinue
    
    return ($current_hash -eq $stored_hash)
}

function Update-CacheMetadata {
    param(
        [string]$RulesFile,
        [string]$ConfigFile
    )
    
    $project_cache = Get-ProjectCacheDir
    
    if ([string]::IsNullOrEmpty($project_cache)) {
        return
    }
    
    $current_rules_hash = Get-FileHash $RulesFile
    $current_config_hash = Get-FileHash $ConfigFile
    $current_hash = "$current_rules_hash$current_config_hash"
    
    $metadata_file = "$project_cache\metadata"
    Set-Content -Path $metadata_file -Value $current_hash -NoNewline -Encoding UTF8
}

# ============================================================================
# File Caching
# ============================================================================

function Get-CachedFileStatus {
    param([string]$FilePath)
    
    $project_cache = Get-ProjectCacheDir
    
    if ([string]::IsNullOrEmpty($project_cache)) {
        return $null
    }
    
    $file_hash = Get-FileHash $FilePath
    $cache_file = "$project_cache\files\$file_hash"
    
    if (Test-Path $cache_file) {
        $status = Get-Content -Path $cache_file -Raw -ErrorAction SilentlyContinue
        return $status.Trim()
    }
    
    return $null
}

function Set-CachedFileStatus {
    param(
        [string]$FilePath,
        [string]$Status
    )
    
    $project_cache = Get-ProjectCacheDir
    
    if ([string]::IsNullOrEmpty($project_cache)) {
        return
    }
    
    $files_dir = "$project_cache\files"
    if (-not (Test-Path $files_dir)) {
        New-Item -ItemType Directory -Path $files_dir -Force | Out-Null
    }
    
    $file_hash = Get-FileHash $FilePath
    $cache_file = "$files_dir\$file_hash"
    
    Set-Content -Path $cache_file -Value $Status -NoNewline -Encoding UTF8
}
