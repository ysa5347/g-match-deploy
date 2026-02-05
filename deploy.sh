#!/bin/bash
# =============================================================================
# G-Match Deploy Script (Helm wrapper)
#
# Usage:
#   ./deploy.sh install              # First-time install via Helm
#   ./deploy.sh upgrade [tag]        # Upgrade with optional image tag
#   ./deploy.sh rollback [revision]  # Rollback to a specific revision
#   ./deploy.sh status               # Show deployment status
#   ./deploy.sh uninstall            # Remove the Helm release
#   ./deploy.sh template             # Render templates locally (dry-run)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHART_DIR="${SCRIPT_DIR}/charts/g-match"
RELEASE_NAME="g-match"
NAMESPACE="g-match"
SECRETS_FILE="${SECRETS_FILE:-${SCRIPT_DIR}/secrets.yaml}"
TIMEOUT="600s"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[DEPLOY]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ---------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------

check_helm() {
    if ! command -v helm &>/dev/null; then
        err "helm is not installed. Please install Helm 3: https://helm.sh/docs/intro/install/"
        exit 1
    fi
}

check_secrets() {
    if [ ! -f "$SECRETS_FILE" ]; then
        err "Secrets file not found: ${SECRETS_FILE}"
        echo ""
        echo "Create a secrets.yaml file with your actual secret values:"
        echo ""
        echo "  secrets:"
        echo "    secretKey: \"your-django-secret-key\""
        echo "    dbPassword: \"your-db-password\""
        echo "    dbRootPassword: \"your-db-root-password\""
        echo "    redisPassword: \"your-redis-password\""
        echo "    gistOidcClientSecret: \"your-oidc-client-secret\""
        echo "    dockerconfigjson: \"base64-encoded-docker-config\""
        echo ""
        echo "Or set SECRETS_FILE env var to point to your secrets file."
        exit 1
    fi
}

# ---------------------------------------------------
# Commands
# ---------------------------------------------------

do_install() {
    check_secrets
    log "Installing G-Match (first-time deploy)..."
    helm install "$RELEASE_NAME" "$CHART_DIR" \
        --namespace "$NAMESPACE" \
        --create-namespace \
        -f "$SECRETS_FILE" \
        --wait \
        --timeout "$TIMEOUT"
    log "Install complete!"
    do_status
}

do_upgrade() {
    local tag="${1:-}"
    local extra_args=""

    if [ -n "$tag" ]; then
        log "Upgrading G-Match with image tag: ${tag}"
        extra_args="--set image.django.tag=${tag} --set image.matcher.tag=${tag}"
    else
        log "Upgrading G-Match with latest chart values..."
    fi

    helm upgrade "$RELEASE_NAME" "$CHART_DIR" \
        --namespace "$NAMESPACE" \
        --reuse-values \
        ${extra_args} \
        --wait \
        --timeout "$TIMEOUT"
    log "Upgrade complete!"
    do_status
}

do_rollback() {
    local revision="${1:-}"
    if [ -z "$revision" ]; then
        log "Release history:"
        helm history "$RELEASE_NAME" -n "$NAMESPACE"
        echo ""
        err "Please specify a revision number: ./deploy.sh rollback <revision>"
        exit 1
    fi

    log "Rolling back to revision ${revision}..."
    helm rollback "$RELEASE_NAME" "$revision" \
        --namespace "$NAMESPACE" \
        --wait \
        --timeout "$TIMEOUT"
    log "Rollback complete!"
    do_status
}

do_status() {
    log "=== Deployment Status ==="
    echo ""
    helm status "$RELEASE_NAME" -n "$NAMESPACE" 2>/dev/null || warn "Release not found"
    echo ""
    kubectl get pods -n "$NAMESPACE" -o wide 2>/dev/null || true
    echo ""
    kubectl get deployments -n "$NAMESPACE" 2>/dev/null || true
    echo ""
    kubectl get statefulsets -n "$NAMESPACE" 2>/dev/null || true
    echo ""
    kubectl get jobs -n "$NAMESPACE" 2>/dev/null || true
    echo ""
    kubectl get pvc -n "$NAMESPACE" 2>/dev/null || true
}

do_uninstall() {
    log "Uninstalling G-Match..."
    helm uninstall "$RELEASE_NAME" --namespace "$NAMESPACE"
    log "Uninstall complete. PVCs are preserved."
    warn "To also delete PVCs: kubectl delete pvc --all -n ${NAMESPACE}"
}

do_template() {
    check_secrets
    log "Rendering templates (dry-run)..."
    helm template "$RELEASE_NAME" "$CHART_DIR" \
        --namespace "$NAMESPACE" \
        -f "$SECRETS_FILE"
}

# ---------------------------------------------------
# Main
# ---------------------------------------------------

check_helm

case "${1:-help}" in
    install)
        do_install
        ;;
    upgrade)
        do_upgrade "${2:-}"
        ;;
    rollback)
        do_rollback "${2:-}"
        ;;
    status)
        do_status
        ;;
    uninstall)
        do_uninstall
        ;;
    template)
        do_template
        ;;
    help|*)
        echo "G-Match Deploy Script (Helm wrapper)"
        echo ""
        echo "Usage: $0 <command> [args]"
        echo ""
        echo "Commands:"
        echo "  install              First-time install via Helm"
        echo "  upgrade [tag]        Upgrade (optionally with new image tag)"
        echo "  rollback [revision]  Rollback to a specific Helm revision"
        echo "  status               Show deployment status"
        echo "  uninstall            Remove the Helm release"
        echo "  template             Render templates locally (dry-run)"
        echo ""
        echo "Environment variables:"
        echo "  SECRETS_FILE         Path to secrets.yaml (default: ./secrets.yaml)"
        echo ""
        echo "Examples:"
        echo "  $0 install                    # First deploy"
        echo "  $0 upgrade                    # Upgrade with current values"
        echo "  $0 upgrade sha-abc123         # Upgrade with specific image tag"
        echo "  $0 rollback 1                 # Rollback to revision 1"
        ;;
esac
