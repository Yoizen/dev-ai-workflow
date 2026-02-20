# Environment Detection for CI/CD and Non-Interactive Shells - PowerShell

function Test-InteractiveEnvironment {
    $hasConsoleInput = [Console]::IsInputRedirected -eq $false
    $hasConsoleOutput = [Console]::IsOutputRedirected -eq $false
    
    if (-not ($hasConsoleInput -and $hasConsoleOutput)) {
        return $false
    }
    
    $ciVariables = @(
        "CI",
        "CONTINUOUS_INTEGRATION",
        "JENKINS_HOME",
        "TRAVIS",
        "CIRCLECI",
        "GITLAB_CI",
        "GITHUB_ACTIONS",
        "BUILDKITE",
        "DRONE",
        "TF_BUILD"
    )
    
    foreach ($var in $ciVariables) {
        if (Test-Path "env:$var") {
            return $false
        }
    }
    
    if ((Test-Path "env:DEBIAN_FRONTEND") -and ($env:DEBIAN_FRONTEND -eq "noninteractive")) {
        return $false
    }
    
    return $true
}

function Get-CiProvider {
    if (Test-Path "env:GITHUB_ACTIONS") {
        return "github-actions"
    } elseif (Test-Path "env:GITLAB_CI") {
        return "gitlab-ci"
    } elseif (Test-Path "env:TRAVIS") {
        return "travis-ci"
    } elseif (Test-Path "env:CIRCLECI") {
        return "circleci"
    } elseif (Test-Path "env:JENKINS_HOME") {
        return "jenkins"
    } elseif (Test-Path "env:BUILDKITE") {
        return "buildkite"
    } elseif (Test-Path "env:DRONE") {
        return "drone"
    } elseif (Test-Path "env:TF_BUILD") {
        return "azure-devops"
    } elseif (Test-Path "env:CI") {
        return "generic-ci"
    } else {
        return "none"
    }
}

function Test-DockerEnvironment {
    if (Test-Path "/.dockerenv") {
        return $true
    }
    
    if (Test-Path "/proc/1/cgroup") {
        $content = Get-Content "/proc/1/cgroup" -ErrorAction SilentlyContinue
        if ($content -match "docker|lxc") {
            return $true
        }
    }
    
    return $false
}

function Get-EnvironmentType {
    if (Test-DockerEnvironment) {
        return "docker"
    } elseif ((Get-CiProvider) -ne "none") {
        return "ci"
    } elseif (Test-InteractiveEnvironment) {
        return "interactive"
    } else {
        return "non-interactive"
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $envType = Get-EnvironmentType
    $ciProvider = Get-CiProvider
    $isInteractive = Test-InteractiveEnvironment
    
    Write-Host "Environment Type: $envType"
    Write-Host "CI Provider: $ciProvider"
    Write-Host "Is Interactive: $isInteractive"
}
