#!/bin/bash
set -e

# Helper for ms timing
millis() {
  date +%s%3N
}

# Set hard-coded n (loop bound must match circuit!)
N=64

EXPECTED_RESULT=$(python3 -c "a, b = 1, 1
for i in range(2, $N):
    a, b = b, a+b
print(b)")


zokrates compile -i fibonacci.zok > /dev/null

START=$(millis)
zokrates compute-witness -a $EXPECTED_RESULT > /dev/null
END=$(millis)
COMPUTE_MS=$(($END-$START))
echo "Computed Fibonacci sequence up to ${N}th term in ${COMPUTE_MS} ms"
echo "Expected result: $EXPECTED_RESULT"

START=$(millis)
zokrates setup > /dev/null
END=$(millis)
SETUP_MS=$(($END-$START))

START=$(millis)
zokrates generate-proof > /dev/null
END=$(millis)
PROVE_MS=$(($END-$START))

PROOF_SIZE=$(du -b proof.json | awk '{print $1}')
PROOF_SIZE_KB=$(awk "BEGIN {printf \"%.1f\",$PROOF_SIZE/1024}")

START=$(millis)
zokrates verify > /dev/null
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
