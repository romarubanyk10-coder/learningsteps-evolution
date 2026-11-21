#!/usr/bin/env bash
# Builds a kubeconfig ("access card") for the github-deployer ServiceAccount,
# tests what it can and cannot do, and stores it as the GitHub secret KUBE_CONFIG.
# The token is never printed: it lives only in a temporary file that is deleted at the end.
set -euo pipefail

NAMESPACE="learningsteps"
SERVICE_ACCOUNT="github-deployer"
REPO="romarubanyk10-coder/learningsteps-evolution"
DURATION="720h"   # 30 days, like the ACR token password

# 1) Address of the cluster API and its certificate (public information)
SERVER="$(kubectl config view --minify --raw --output jsonpath='{.clusters[0].cluster.server}')"
CA_DATA="$(kubectl config view --minify --raw --output jsonpath='{.clusters[0].cluster.certificate-authority-data}')"

# 2) A short-lived token for the ServiceAccount (kept only in a variable)
TOKEN="$(kubectl create token "$SERVICE_ACCOUNT" --namespace "$NAMESPACE" --duration "$DURATION")"

# 3) Temporary folder, deleted automatically when the script ends (even on error)
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
KCFG="$TMP_DIR/kubeconfig"
umask 077   # new files readable only by you

cat > "$KCFG" <<KUBECONFIG
apiVersion: v1
kind: Config
clusters:
  - name: aks
    cluster:
      server: ${SERVER}
      certificate-authority-data: ${CA_DATA}
users:
  - name: ${SERVICE_ACCOUNT}
    user:
      token: ${TOKEN}
contexts:
  - name: ci
    context:
      cluster: aks
      user: ${SERVICE_ACCOUNT}
      namespace: ${NAMESPACE}
current-context: ci
KUBECONFIG

# 4) When does the token expire? (prints only the date, never the token)
TOKEN="$TOKEN" python3 -c '
import base64, datetime, json, os
payload = os.environ["TOKEN"].split(".")[1]
payload += "=" * (-len(payload) % 4)
exp = json.loads(base64.urlsafe_b64decode(payload))["exp"]
print("Token expires:", datetime.datetime.fromtimestamp(exp, datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC"))
'
unset TOKEN

# 5) Test the card like an attacker would: what is allowed, what is not?
echo "--- Allowed (expect yes):"
for check in "patch deployment/learningsteps-api" "get deployment/learningsteps-api" "watch deployments"; do
  printf '%-40s ' "$check"; KUBECONFIG="$KCFG" kubectl auth can-i $check --namespace "$NAMESPACE" || true
done
echo "--- Forbidden (expect no):"
for check in "get secrets" "create pods/exec" "delete deployment/learningsteps-api" "patch deployment/other-app" "get pods"; do
  printf '%-40s ' "$check"; KUBECONFIG="$KCFG" kubectl auth can-i $check --namespace "$NAMESPACE" 2>/dev/null || true
done

# 6) Store the whole card as a GitHub secret (read from the file, not printed)
gh secret set KUBE_CONFIG --repo "$REPO" < "$KCFG"
