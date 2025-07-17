#!/bin/bash
set -e

# Helper: milliseconds
millis() { date +%s%3N; }

BUILD_DIR="../build"
CIRCUIT_NAME="circuit"
PTAU="../powersOfTau28_hez_final_10.ptau"
INPUT_JSON="../input.json"

# Setup (timed)
setup_start=$(millis)
snarkjs plonk setup \
  $BUILD_DIR/${CIRCUIT_NAME}.r1cs \
  $PTAU \
  $BUILD_DIR/${CIRCUIT_NAME}_plonk.zkey > /dev/null
setup_end=$(millis)
SETUP_MS=$((setup_end - setup_start))

# Witness (timed)
witness_start=$(millis)
node $BUILD_DIR/${CIRCUIT_NAME}_js/generate_witness.js \
  $BUILD_DIR/${CIRCUIT_NAME}_js/${CIRCUIT_NAME}.wasm \
  $INPUT_JSON \
  $BUILD_DIR/witness.wtns > /dev/null
witness_end=$(millis)
WITNESS_MS=$((witness_end - witness_start))

# Prove (timed)
prove_start=$(millis)
snarkjs plonk prove \
  $BUILD_DIR/${CIRCUIT_NAME}_plonk.zkey \
  $BUILD_DIR/witness.wtns \
  $BUILD_DIR/proof.json \
  $BUILD_DIR/public.json > /dev/null
prove_end=$(millis)
PROVE_MS=$((prove_end - prove_start))

# Proof size, in KB with 1 decimal
PROOF_SIZE=$(du -b $BUILD_DIR/proof.json | awk '{print $1}')
PROOF_KB=$(awk "BEGIN {printf \"%.1f\", $PROOF_SIZE/1024}")

# Verify (timed)
verify_start=$(millis)
snarkjs plonk verify \
  $BUILD_DIR/verification_key.json \
  $BUILD_DIR/public.json \
  $BUILD_DIR/proof.json > /dev/null
verify_end=$(millis)
VERIFY_MS=$((verify_end - verify_start))

# Output - always in your precise format
echo ""
echo "============================="
echo "Setup time:     ${SETUP_MS} ms"
echo "Witness time:   ${WITNESS_MS} ms"
echo "Proving time:   ${PROVE_MS} ms"
echo "Proof size:     ${PROOF_KB} KB"
echo "Verification time: ${VERIFY_MS} ms"
echo "============================="