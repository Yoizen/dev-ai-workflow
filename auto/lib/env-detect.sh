#!/bin/bash
# Environment Detection for CI/CD and Non-Interactive Shells

is_interactive_environment() {
    [[ -t 0 && -t 1 ]] || return 1
    
    [[ -z "${CI:-}" && \
       -z "${CONTINUOUS_INTEGRATION:-}" && \
       -z "${JENKINS_HOME:-}" && \
       -z "${TRAVIS:-}" && \
       -z "${CIRCLECI:-}" && \
       -z "${GITLAB_CI:-}" && \
       -z "${GITHUB_ACTIONS:-}" && \
       -z "${BUILDKITE:-}" && \
       -z "${DRONE:-}" ]] || return 1
    
    [[ -z "${DEBIAN_FRONTEND:-}" || "$DEBIAN_FRONTEND" != "noninteractive" ]] || return 1
    
    [[ -z "${TERM:-}" || "$TERM" != "dumb" ]] || return 1
    
    return 0
}

detect_ci_provider() {
    if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        echo "github-actions"
    elif [[ -n "${GITLAB_CI:-}" ]]; then
        echo "gitlab-ci"
    elif [[ -n "${TRAVIS:-}" ]]; then
        echo "travis-ci"
    elif [[ -n "${CIRCLECI:-}" ]]; then
        echo "circleci"
    elif [[ -n "${JENKINS_HOME:-}" ]]; then
        echo "jenkins"
    elif [[ -n "${BUILDKITE:-}" ]]; then
        echo "buildkite"
    elif [[ -n "${DRONE:-}" ]]; then
        echo "drone"
    elif [[ -n "${CI:-}" ]]; then
        echo "generic-ci"
    else
        echo "none"
    fi
}

is_docker_environment() {
    [[ -f /.dockerenv ]] && return 0
    
    grep -q 'docker\|lxc' /proc/1/cgroup 2>/dev/null && return 0
    
    return 1
}

get_environment_type() {
    if is_docker_environment; then
        echo "docker"
    elif [[ "$(detect_ci_provider)" != "none" ]]; then
        echo "ci"
    elif is_interactive_environment; then
        echo "interactive"
    else
        echo "non-interactive"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    ENV_TYPE=$(get_environment_type)
    CI_PROVIDER=$(detect_ci_provider)
    IS_INTERACTIVE=$(is_interactive_environment && echo "true" || echo "false")
    
    echo "Environment Type: $ENV_TYPE"
    echo "CI Provider: $CI_PROVIDER"
    echo "Is Interactive: $IS_INTERACTIVE"
fi
