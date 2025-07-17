#!/bin/bash
set -e

millis() {
  date +%s%3N
}

N=64

EXPECTED_RESULT=$(python3 -c "a, b = 1, 1
for _ in range(1, $N):
    a, b = b, a+b
print(b)")

echo "Compiling circuit..."
circom fibonacci64.circom --r1cs --wasm --sym > /dev/null

echo "Generating input.json..."
echo "{ \"expected_result\": $EXPECTED_RESULT }" > input.json

# Check if WASM and JS witness generator were created
if [ ! -f fibonacci64_js/generate_witness.js ]; then
  echo "Compilation failed or wrong directory. Exiting."
  exit 1
fi

START=$(millis)
node fibonacci64_js/generate_witness.js fibonacci64_js/fibonacci64.wasm input.json witness.wtns > /dev/null
END=$(millis)
COMPUTE_MS=$(($END-$START))
echo "Computed Fibonacci sequence up to ${N}th term in ${COMPUTE_MS} ms"
echo "Expected result: $EXPECTED_RESULT"

# Generate trusted setup file if missing
if [ ! -f pot12_final.ptau ]; then
  echo "Performing powers of tau (trusted setup)..."
  snarkjs powersoftau new bn128 12 pot12_0000.ptau -v
  snarkjs powersoftau contribute pot12_0000.ptau pot12_0001.ptau --name="First contribution" -v
  snarkjs powersoftau prepare phase2 pot12_0001.ptau pot12_final.ptau -v
fi

START=$(millis)
snarkjs plonk setup fibonacci64.r1cs pot12_final.ptau circuit_final.zkey > /dev/null
END=$(millis)
SETUP_MS=$(($END-$START))

snarkjs zkey export verificationkey circuit_final.zkey verification_key.json > /dev/null

START=$(millis)
snarkjs plonk prove circuit_final.zkey witness.wtns proof.json public.json > /dev/null
END=$(millis)
PROVE_MS=$(($END-$START))

PROOF_SIZE=$(du -b proof.json | awk '{print $1}')
PROOF_SIZE_KB=$(awk "BEGIN {printf \"%.1f\",$PROOF_SIZE/1024}")

START=$(millis)
snarkjs plonk verify verification_key.json public.json proof.json > /dev/null
END=$(millis)
VERIFY_MS=$(($END-$START))

echo ""
echo "================================"
echo "Summary:"
echo "Setup completed in ${SETUP_MS} ms"
echo "Proof generated in ${PROVE_MS} ms"
echo "Proof size: $PROOF_SIZE_KB KB"
echo "Proof verified in ${VERIFY_MS} ms"
echo "================================"