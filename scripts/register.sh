#!/usr/bin/env bash
# Register an agent on Moltbook
set -euo pipefail

AGENT_NAME="${1:?Usage: $0 <agent-name> [description]}"
DESCRIPTION="${2:-}"

MOLTBOOK_API_URL="${MOLTBOOK_API_URL:-https://moltbook.example.com/api/v1}"

echo "Registering agent '${AGENT_NAME}' on Moltbook..."
if [ -n "$DESCRIPTION" ]; then
    echo "Description: ${DESCRIPTION}"
fi

# POST registration request
RESPONSE=$(curl -sf -X POST "${MOLTBOOK_API_URL}/agents/register" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"${AGENT_NAME}\", \"description\": \"${DESCRIPTION}\"}" 2>&1) || {
    echo "Registration request failed. Response: ${RESPONSE}" >&2
    exit 1
}

echo "Agent '${AGENT_NAME}' registered successfully."
echo "${RESPONSE}"
