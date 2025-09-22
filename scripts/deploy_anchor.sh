#!/bin/bash
set -euo pipefail

# -----------------------------
# Anchor deployment script
# -----------------------------

PROGRAM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="$PROGRAM_DIR/target/deploy"

echo "🚀 Starting Anchor deployment..."
echo "Project directory: $PROGRAM_DIR"

# 1. Build program
echo "🔨 Building Anchor program..."
anchor build

# 2. Extract program keypair name
PROGRAM_KEYPAIR=$(basename "$(ls $TARGET_DIR/*.json | head -n 1)" .json)
echo "📂 Program keypair: $PROGRAM_KEYPAIR"

# 3. Deploy program
echo "📡 Deploying to Solana cluster..."
solana program deploy "$TARGET_DIR/${PROGRAM_KEYPAIR}.so" \
  --program-id "$TARGET_DIR/${PROGRAM_KEYPAIR}.json"

# 4. Update Anchor.toml with new program ID (optional step)
PROGRAM_ID=$(solana address -k "$TARGET_DIR/${PROGRAM_KEYPAIR}.json")
ANCHOR_TOML="$PROGRAM_DIR/Anchor.toml"

if [ -f "$ANCHOR_TOML" ]; then
  echo "📝 Updating Anchor.toml with new program ID..."
  sed -i.bak "s/\(programs\.localnet.*=.*\"\).*\(\".*\)/\1$PROGRAM_ID\2/" "$ANCHOR_TOML" || true
fi

echo "✅ Deployment complete!"
echo "Program ID: $PROGRAM_ID"
