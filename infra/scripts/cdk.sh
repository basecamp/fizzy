#!/usr/bin/env bash
set -euo pipefail

# CDK wrapper script with named arguments
# Usage: ./cdk.sh <command> --environment=<env> [--profile=<profile>] [--stack=<stack>] [--exclusively] [--force]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

command="${1:-}"
shift || true

environment=""
profile=""
stack=""
exclusively=""
force=""

for arg in "$@"; do
    case "$arg" in
        --environment=*) environment="${arg#*=}" ;;
        --profile=*) profile="${arg#*=}" ;;
        --stack=*) stack="${arg#*=}" ;;
        --exclusively) exclusively="--exclusively" ;;
        --force)
            if [[ "$command" == "import" ]]; then
                force="--force"
            else
                echo "Error: --force is only allowed for import"; exit 1
            fi
            ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

# Validate required arguments
if [[ -z "$environment" ]]; then
    echo "Error: --environment is required (development|production)"
    exit 1
fi

if [[ "$environment" != "development" && "$environment" != "production" ]]; then
    echo "Error: --environment must be 'development' or 'production'"
    exit 1
fi

cd "$PROJECT_DIR"

# Export ENVIRONMENT for CDK config-loader
export ENVIRONMENT="$environment"

profile_flag=""
if [[ -n "$profile" ]]; then
    profile_flag="--profile $profile"
fi

echo "Environment: $environment"
echo "Profile:     ${profile:-"(using environment credentials)"}"
echo ""

case "$command" in
    synth)
        yarn cdk synth $profile_flag $stack $exclusively
        ;;
    diff)
        yarn cdk diff $profile_flag ${stack:-"--all"} $exclusively
        ;;
    deploy)
        yarn cdk deploy --require-approval any-change $profile_flag ${stack:-"--all"} $exclusively
        ;;
    destroy)
        yarn cdk destroy --force $profile_flag ${stack:-"--all"} $exclusively
        ;;
    import)
        yarn cdk import $profile_flag $stack $exclusively $force
        ;;
    *)
        echo "Usage: $0 <synth|diff|deploy|destroy|import> --environment=<development|production> [--profile=<profile>] [--stack=<stack>] [--exclusively] [--force]"
        exit 1
        ;;
esac