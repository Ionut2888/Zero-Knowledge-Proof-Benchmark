#!/bin/bash
set -e

CIRCUIT=merkle
DEPTH=15

# Helper for ms timing
millis() { date +%s%3N; }

usage() {
  echo "Usage: $0 -n DEPTH"
  echo "Supported DEPTH values: 3, 7, 15"
  exit 1
}

# Parse arguments
while getopts "n:" opt; do
  case $opt in
    n)
      DEPTH="$OPTARG"
      ;;
    *)
      usage
      ;;
  esac
done

if [[ -z "$DEPTH" ]]; then
  usage
fi

# Prepare inputs for each supported depth
case "$DEPTH" in
  3)
    LEAF=3
    PROOF=(101 102 103)
    INDEX_BITS=(1 1 0)
    ROOT=12345
    ;;
  7)
    LEAF=7
    PROOF=(101 102 103 104 105 106 107)
    INDEX_BITS=(1 1 1 1 0 0 0)
    ROOT=23456
    ;;
  15)
    LEAF=15
    PROOF=(101 102 103 104 105 106 107 108 109 110 111 112 113 114 115)
    INDEX_BITS=(1 1 1 1 0 0 0 0 0 0 0 0 0 0 0)
    ROOT=999999
    ;;
  *)
    usage
    ;;
esac

INPUT_JSON=input.json
cat > $INPUT_JSON <<EOF
{
  "leaf": $LEAF,
  "proof": [$(IFS=,; echo "${PROOF[*]}")],
  "indexBits": [$(IFS=,; echo "${INDEX_BITS[*]}")],
  "root": $ROOT
}
EOF

echo ""
echo "=============================="
echo " Circuit:    $CIRCUIT.circom"
echo " Input:      $INPUT_JSON"
echo "=============================="
echo ""

echo "Compiling circuit..."
circom $CIRCUIT.circom --r1cs --wasm --sym

# Generate ptau and prepare phase2 if missing
if [ ! -f pot15_final.ptau ]; then
    echo "Generating powers of tau (ptau)..."
    snarkjs powersoftau new bn128 15 pot15_0000.ptau -v
    snarkjs powersoftau contribute pot15_0000.ptau pot15_final.ptau --name="test" -v
fi

if [ ! -f pot15_final_prepared.ptau ]; then
    echo "Preparing powers of tau for phase2..."
    snarkjs powersoftau prepare phase2 pot15_final.ptau pot15_final_prepared.ptau -v
fi

START=$(millis)
echo "Generating witness..."
node ${CIRCUIT}_js/generate_witness.js ${CIRCUIT}_js/${CIRCUIT}.wasm $INPUT_JSON witness.wtns
END=$(millis)
COMPUTE_MS=$(($END-$START))

START=$(millis)
echo "Setting up PLONK zk-SNARK..."
snarkjs plonk setup $CIRCUIT.r1cs pot15_final_prepared.ptau $CIRCUIT.zkey
echo "Exporting verification key..."
snarkjs zkey export verificationkey $CIRCUIT.zkey verification_key.json
END=$(millis)
SETUP_MS=$(($END-$START))

START=$(millis)
echo "Generating PLONK proof..."
snarkjs plonk prove $CIRCUIT.zkey witness.wtns proof.json public.json
END=$(millis)
PROVE_MS=$(($END-$START))

PROOF_SIZE=$(du -b proof.json | awk '{print $1}')
PROOF_SIZE_KB=$(awk "BEGIN {printf \"%.1f\",$PROOF_SIZE/1024}")

START=$(millis)
echo "Verifying PLONK proof..."
snarkjs plonk verify verification_key.json public.json proof.json
END=$(millis)
VERIFY_MS=$(($END-$START))

echo ""
echo "================================"
echo "Summary:"
echo "Witness computed in ${COMPUTE_MS} ms"
echo "Setup completed in ${SETUP_MS} ms"
echo "Proof generated in ${PROVE_MS} ms"
echo "Proof size: $PROOF_SIZE_KB KB"
echo "Proof verified in ${VERIFY_MS} ms"
echo "================================"