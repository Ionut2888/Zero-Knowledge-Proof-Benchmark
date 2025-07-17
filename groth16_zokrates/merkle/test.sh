#!/bin/bash
set -e

# Helper for ms timing
millis() {
  date +%s%3N
}

LEAF=15

# 15 dummy sibling node values for the proof
PROOF="101 102 103 104 105 106 107 108 109 110 111 112 113 114 115"

# indexBits for membership at leaf index 15 (i.e., 0b0000000000001111)
# LSB first: 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0
INDEX_BITS="1 1 1 1 0 0 0 0 0 0 0 0 0 0 0"

ROOT=999999


zokrates compile -i merkle.zok > /dev/null


START=$(millis)
zokrates compute-witness -a $LEAF $PROOF $INDEX_BITS $ROOT > /dev/null
END=$(millis)
COMPUTE_MS=$(($END-$START))


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
echo "Witness computed in ${COMPUTE_MS} ms"
echo "Setup completed in ${SETUP_MS} ms"
echo "Proof generated in ${PROVE_MS} ms"
echo "Proof size: $PROOF_SIZE_KB KB"
echo "Proof verified in ${VERIFY_MS} ms"
echo "================================"