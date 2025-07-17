#!/bin/bash
set -e

# Millisecond timing helper
millis() {
  date +%s%3N
}

cd ..

# Load inputs
SECRET=1121645852825515626345503741442177404306361956507933536148868635850297893661
HASH=2728569673190821187094419527647561004262639953421171061861302988333198391804

# Compile circuit
zokrates compile -i poseidon_hash.zok > /dev/null

# Setup
START=$(millis)
zokrates setup > /dev/null
END=$(millis)
SETUP_MS=$((END - START))

# Compute witness
START=$(millis)
zokrates compute-witness -a "$SECRET" "$HASH" > /dev/null
END=$(millis)
WITNESS_MS=$((END - START))

# Generate proof
START=$(millis)
zokrates generate-proof -j proof.json > /dev/null
END=$(millis)
PROVE_MS=$((END - START))

# Get proof size
PROOF_SIZE=$(du -b proof.json | awk '{print $1}')
PROOF_SIZE_KB=$(awk "BEGIN {printf \"%.1f\", $PROOF_SIZE/1024}")

# Verify proof
START=$(millis)
if zokrates verify -j proof.json > /dev/null; then
  END=$(millis)
  VERIFY_MS=$((END - START))
  VERIFIED=true
else
  END=$(millis)
  VERIFY_MS=$((END - START))
  VERIFIED=false
fi

# Output results
echo ""
echo "============================="
echo "Zokrates Poseidon Hash Benchmark"
echo "============================="
echo "Setup time:     ${SETUP_MS} ms"
echo "Witness time:   ${WITNESS_MS} ms"
echo "Proving time:   ${PROVE_MS} ms"
echo "Proof size:     ${PROOF_SIZE_KB} KB"
echo "Verification time: ${VERIFY_MS} ms"
echo "============================="
