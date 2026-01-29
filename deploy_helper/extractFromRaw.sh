#!/bin/bash
set -e

if [ -f .env ]; then
  export $(cat .env | sed 's/#.*//g' | xargs)
fi

RAW_TMP="$(dirname "$0")/raw.tmp"
DEPLOYMENT_FILE="$(dirname "$0")/out/deployment.json"
OUT_FILE="$(dirname "$0")/out/out.json"
DAPP_PATH="../frontend/src/assets"

# Fetch network ID from the RPC URL
NETWORK_ID=$(curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' \
  "$RPC_URL" | grep -o '"result":"[^"]*' | grep -o '[^"]*$')

# Validate NETWORK_ID
if [ -z "$NETWORK_ID" ]; then
  echo "Error: Failed to fetch network ID."
  exit 1
fi

# Build network entry into a temporary variable
NETWORK_ENTRY=""
while IFS= read -r line; do
  key=$(echo "$line" | awk -F: '{print $1}' | awk '{print $1}')
  address=$(echo "$line" | awk -F: '{print $2}' | xargs)

  if [ -n "$key" ] && [ -n "$address" ]; then
    NETWORK_ENTRY="${NETWORK_ENTRY}    \"$key\": \"$address\",\n"
  fi
done < "$RAW_TMP"

# Remove trailing comma from network entry
NETWORK_ENTRY=$(printf "%b" "$NETWORK_ENTRY" | sed '$ s/,$//')

# Check if we're in multi-network mode
if [ "$MULTI_NETWORK_MODE" = "true" ]; then
  # Read existing deployment.json
  EXISTING_CONTENT=$(cat "$DEPLOYMENT_FILE")

  # Check if this network already exists in the file
  if grep -q "\"$NETWORK_ID\":" "$DEPLOYMENT_FILE"; then
    # Network exists - merge the entries
    # We'll use a temporary file to rebuild the JSON with merged data
    TMP_FILE=$(mktemp)

    # Parse existing data for this network and merge with new data
    # Create a combined entry by extracting old entries and adding new ones
    EXISTING_ENTRIES=$(grep -A 100 "\"$NETWORK_ID\":" "$DEPLOYMENT_FILE" | sed -n '/{/,/}/p' | grep -o '"[^"]*": "[^"]*"' || true)
    NEW_ENTRIES=$(printf "%s" "$NETWORK_ENTRY" | grep -o '"[^"]*": "[^"]*"' || true)

    # Combine and deduplicate (new entries override old ones)
    COMBINED=""
    # First add all new entries
    while IFS= read -r entry; do
      if [ -n "$entry" ]; then
        COMBINED="${COMBINED}    ${entry},\n"
      fi
    done <<EOF
$NEW_ENTRIES
EOF

    # Then add old entries that aren't in new entries
    while IFS= read -r entry; do
      if [ -n "$entry" ]; then
        key=$(echo "$entry" | cut -d: -f1)
        # Check if this key exists in new entries
        if ! echo "$NEW_ENTRIES" | grep -q "$key"; then
          COMBINED="${COMBINED}    ${entry},\n"
        fi
      fi
    done <<EOF
$EXISTING_ENTRIES
EOF

    COMBINED=$(printf "%b" "$COMBINED" | sed '$ s/,$//')

    # Now rebuild the entire JSON file
    # Remove the network entry for this ID and rebuild
    sed -i "/\"$NETWORK_ID\":/,/^  }/d" "$DEPLOYMENT_FILE"

    # Check if file is now empty or just has braces
    if [ "$(cat "$DEPLOYMENT_FILE" | tr -d '\n\r\t ')" = "{}" ] || [ "$(cat "$DEPLOYMENT_FILE" | tr -d '\n\r\t ')" = "{" ]; then
      # File is empty, start fresh
      echo "{" > "$DEPLOYMENT_FILE"
      echo "  \"$NETWORK_ID\": {" >> "$DEPLOYMENT_FILE"
      printf "%s\n" "$COMBINED" >> "$DEPLOYMENT_FILE"
      echo "  }" >> "$DEPLOYMENT_FILE"
      echo "}" >> "$DEPLOYMENT_FILE"
    else
      # There are other networks, add this one back
      sed -i '$ d' "$DEPLOYMENT_FILE"  # Remove closing }
      echo "  }," >> "$DEPLOYMENT_FILE"
      echo "  \"$NETWORK_ID\": {" >> "$DEPLOYMENT_FILE"
      printf "%s\n" "$COMBINED" >> "$DEPLOYMENT_FILE"
      echo "  }" >> "$DEPLOYMENT_FILE"
      echo "}" >> "$DEPLOYMENT_FILE"
    fi
  elif [ "$EXISTING_CONTENT" = "{}" ]; then
    # First network - no comma needed
    echo "{" > "$DEPLOYMENT_FILE"
    echo "  \"$NETWORK_ID\": {" >> "$DEPLOYMENT_FILE"
    printf "%s\n" "$NETWORK_ENTRY" >> "$DEPLOYMENT_FILE"
    echo "  }" >> "$DEPLOYMENT_FILE"
    echo "}" >> "$DEPLOYMENT_FILE"
  else
    # Additional NEW network - need to add comma and append
    # Remove the closing brace
    sed -i '$ d' "$DEPLOYMENT_FILE"
    # Add comma after previous network entry
    echo "  }," >> "$DEPLOYMENT_FILE"
    # Add new network entry
    echo "  \"$NETWORK_ID\": {" >> "$DEPLOYMENT_FILE"
    printf "%s\n" "$NETWORK_ENTRY" >> "$DEPLOYMENT_FILE"
    echo "  }" >> "$DEPLOYMENT_FILE"
    # Close JSON
    echo "}" >> "$DEPLOYMENT_FILE"
  fi
else
  # Single network mode - check if we need to merge or overwrite
  if [ -f "$DEPLOYMENT_FILE" ] && grep -q "\"$NETWORK_ID\":" "$DEPLOYMENT_FILE"; then
    # Network exists - merge entries
    EXISTING_ENTRIES=$(grep -A 100 "\"$NETWORK_ID\":" "$DEPLOYMENT_FILE" | sed -n '/{/,/}/p' | grep -o '"[^"]*": "[^"]*"' || true)
    NEW_ENTRIES=$(printf "%s" "$NETWORK_ENTRY" | grep -o '"[^"]*": "[^"]*"' || true)

    # Combine and deduplicate (new entries override old ones)
    COMBINED=""
    # First add all new entries
    while IFS= read -r entry; do
      if [ -n "$entry" ]; then
        COMBINED="${COMBINED}    ${entry},\n"
      fi
    done <<EOF
$NEW_ENTRIES
EOF

    # Then add old entries that aren't in new entries
    while IFS= read -r entry; do
      if [ -n "$entry" ]; then
        key=$(echo "$entry" | cut -d: -f1)
        if ! echo "$NEW_ENTRIES" | grep -q "$key"; then
          COMBINED="${COMBINED}    ${entry},\n"
        fi
      fi
    done <<EOF
$EXISTING_ENTRIES
EOF

    COMBINED=$(printf "%b" "$COMBINED" | sed '$ s/,$//')

    echo "{ \"$NETWORK_ID\": {" > "$DEPLOYMENT_FILE"
    printf "%s\n" "$COMBINED" >> "$DEPLOYMENT_FILE"
    echo "}}" >> "$DEPLOYMENT_FILE"
  else
    # Overwrite with new data
    echo "{ \"$NETWORK_ID\": {" > "$DEPLOYMENT_FILE"
    printf "%s\n" "$NETWORK_ENTRY" >> "$DEPLOYMENT_FILE"
    echo "}}" >> "$DEPLOYMENT_FILE"
  fi
fi

# Create out.json with specific keys
echo "{ \"$NETWORK_ID\": {" > "$OUT_FILE"
for key in "IDOHelper" "ModelHelper" "ExchangeHelper" "Proxy" "Factory" "Updater" "Resolver"; do
  address=$(grep -o "\"$key\": \".*\"" "$DEPLOYMENT_FILE" | awk -F: '{print $2}' | xargs)
  if [ -n "$address" ]; then
    echo "  \"$key\": \"$address\"," >> "$OUT_FILE"
  fi
done
sed -i '$ s/,$//' "$OUT_FILE"
echo "}}" >> "$OUT_FILE"

# Create out_dummy.json with Resolver, Factory, and ModelHelper as zero address
OUT_DUMMY_FILE="$(dirname "$0")/out/out_dummy.json"
echo "{ \"$NETWORK_ID\": {" > "$OUT_DUMMY_FILE"
# Resolver
resolver_address=$(grep -o "\"Resolver\": \".*\"" "$DEPLOYMENT_FILE" | awk -F: '{print $2}' | xargs)
if [ -n "$resolver_address" ]; then
  echo "  \"Resolver\": \"$resolver_address\"," >> "$OUT_DUMMY_FILE"
fi
# Factory
factory_address=$(grep -o "\"Factory\": \".*\"" "$DEPLOYMENT_FILE" | awk -F: '{print $2}' | xargs)
if [ -n "$factory_address" ]; then
  echo "  \"Factory\": \"$factory_address\"," >> "$OUT_DUMMY_FILE"
fi
# ModelHelper as zero address
echo "  \"ModelHelper\": \"0x0000000000000000000000000000000000000000\"" >> "$OUT_DUMMY_FILE"
echo "  }" >> "$OUT_DUMMY_FILE"
echo "}" >> "$OUT_DUMMY_FILE"

# Update .env file to be in the root directory of the project
ENV_FILE="$(cd "$(dirname "$0")"/.. && pwd)/.env"

# Process individual environment variables
for env_var in "MODEL_HELPER_ADDRESS=ModelHelper" "POOL_ADDRESS=Pool" "VAULT_ADDRESS=Vault"; do
  env_name=$(echo "$env_var" | awk -F= '{print $1}')
  json_key=$(echo "$env_var" | awk -F= '{print $2}')
  address=$(grep -o "\"$json_key\": \".*\"" "$DEPLOYMENT_FILE" | tail -1 | awk -F: '{print $2}' | xargs)

  if [ -n "$address" ]; then
    # Check if the variable exists in the .env file and replace it
    if grep -q "^$env_name=" "$ENV_FILE"; then
      sed -i "s/^$env_name=.*/$env_name=$address/" "$ENV_FILE"
    else
      # Append the variable to the .env file
      echo "$env_name=$address" >> "$ENV_FILE"
    fi
  fi
done

# Display the resulting files
echo "Deployment addresses saved to $DEPLOYMENT_FILE and $OUT_FILE:"
cat "$DEPLOYMENT_FILE"
cat "$OUT_FILE"
echo ".env updated with selected addresses:"
cat "$ENV_FILE"

# Copy to frontend, backend, and bot paths (only if not in multi-network mode)
if [ "$MULTI_NETWORK_MODE" != "true" ]; then
  FRONTEND_PATH="../frontend/src/assets"
  BACKEND_PATH="../wss/data"
  BOT_PATH="../trading-bot/assets"

  echo ""
  echo "Copying deployment.json to project paths..."

  if [ -d "$FRONTEND_PATH" ]; then
    cp "$DEPLOYMENT_FILE" "$FRONTEND_PATH/deployment.json"
    echo "✓ Copied to frontend: $FRONTEND_PATH/deployment.json"
  fi

  if [ -d "$BACKEND_PATH" ]; then
    cp "$DEPLOYMENT_FILE" "$BACKEND_PATH/deployment.json"
    echo "✓ Copied to backend: $BACKEND_PATH/deployment.json"
  fi

  if [ -d "$BOT_PATH" ]; then
    cp "$DEPLOYMENT_FILE" "$BOT_PATH/deployment.json"
    echo "✓ Copied to bot: $BOT_PATH/deployment.json"
  fi
fi