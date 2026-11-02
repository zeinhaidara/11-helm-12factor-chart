#!/usr/bin/env bash
set -uo pipefail

cd "$(dirname "$0")/.."

CHART=charts/app
fail=0

check() {
  local desc="$1"
  local rc="$2"
  if [ "$rc" = "0" ]; then
    echo "PASS: $desc"
  else
    echo "FAIL: $desc"
    fail=1
  fi
}

out="$(helm template "$CHART")"
out_prod="$(helm template "$CHART" -f "$CHART/values-prod.yaml")"

# 1. default values render a Deployment with 2 replicas and no HPA
echo "$out" | grep -A8 "kind: Deployment" | grep -q "replicas: 2"
check "default values give 2 replicas" "$?"

echo "$out" | grep -q "kind: HorizontalPodAutoscaler"
[ "$?" = "1" ]
check "no HPA by default" "$?"

# 2. values-prod.yaml renders an HPA and a PDB with minAvailable 2
echo "$out_prod" | grep -q "kind: HorizontalPodAutoscaler"
check "prod values render an HPA" "$?"

echo "$out_prod" | grep -A8 "kind: PodDisruptionBudget" | grep -q "minAvailable: 2"
check "prod PDB has minAvailable 2" "$?"

# 3. the NetworkPolicy allows ingress only from the allowed-ingress label
echo "$out" | grep -A20 "kind: NetworkPolicy" | grep -q "allowed-ingress"
check "NetworkPolicy restricts to allowed-ingress label" "$?"

# 4. secrets disabled means no ExternalSecret in the output
echo "$out" | grep -q "kind: ExternalSecret"
[ "$?" = "1" ]
check "no ExternalSecret when secrets disabled" "$?"

# 5. a bad value (port as a string) is rejected by values.schema.json
helm template "$CHART" --set port=abc >/tmp/bad-port.out 2>&1
[ "$?" != "0" ]
check "bad port value is rejected by schema" "$?"

exit $fail
