#!/bin/bash
set -e

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

nanots() {
  date +%s%N
}

duration_ms() {
  echo $((($2 - $1) / 1000000))
}

NUM_RUNS=100
TRIM_PERCENT=5  # percent of high and low values to trim

compute_times=()
setup_times=()
prove_times=()
verify_times=()
proof_sizes=()

echo "Running Merkle Proof Circom+PLONK benchmark $NUM_RUNS times"
echo "DEPTH: $DEPTH"
echo "LEAF: $LEAF"
echo "PROOF: ${PROOF[*]}"
echo "INDEX_BITS: ${INDEX_BITS[*]}"
echo "ROOT: $ROOT"
echo ""

CIRCUIT=merkle

for i in $(seq 1 $NUM_RUNS); do
  echo "Run #$i"

  # Generate input.json
  cat > input.json <<EOF
{
  "leaf": $LEAF,
  "proof": [$(IFS=,; echo "${PROOF[*]}")],
  "indexBits": [$(IFS=,; echo "${INDEX_BITS[*]}")],
  "root": $ROOT
}
EOF

  circom $CIRCUIT.circom --r1cs --wasm --sym > /dev/null

  START=$(nanots)
  node ${CIRCUIT}_js/generate_witness.js ${CIRCUIT}_js/${CIRCUIT}.wasm input.json witness.wtns > /dev/null
  END=$(nanots)
  compute_times+=($(duration_ms $START $END))

  START=$(nanots)
  snarkjs plonk setup $CIRCUIT.r1cs pot15_final_prepared.ptau $CIRCUIT.zkey > /dev/null
  snarkjs zkey export verificationkey $CIRCUIT.zkey verification_key.json > /dev/null
  END=$(nanots)
  setup_times+=($(duration_ms $START $END))

  START=$(nanots)
  snarkjs plonk prove $CIRCUIT.zkey witness.wtns proof.json public.json > /dev/null
  END=$(nanots)
  prove_times+=($(duration_ms $START $END))

  proof_sizes+=($(du -b proof.json | awk '{print $1}'))

  START=$(nanots)
  snarkjs plonk verify verification_key.json public.json proof.json > /dev/null
  END=$(nanots)
  verify_times+=($(duration_ms $START $END))

  echo "  compute: ${compute_times[-1]} ms"
  echo "  setup:   ${setup_times[-1]} ms"
  echo "  prove:   ${prove_times[-1]} ms"
  echo "  verify:  ${verify_times[-1]} ms"
  echo ""
done

# Helper function to trim and average
trim_and_avg() {
  local arr=($(printf '%s\n' "${@}" | sort -n))
  local count=${#arr[@]}
  local trim=$((count * TRIM_PERCENT / 100))
  local trimmed=("${arr[@]:$trim:$((count - 2 * trim))}")

  local sum=0
  for val in "${trimmed[@]}"; do
    sum=$((sum + val))
  done
  awk "BEGIN {printf \"%.1f\", $sum / ${#trimmed[@]}}"
}

# Convert proof sizes to KB for averaging
trim_and_avg_kb() {
  local arr=($(printf '%s\n' "${@}" | sort -n))
  local count=${#arr[@]}
  local trim=$((count * TRIM_PERCENT / 100))
  local trimmed=("${arr[@]:$trim:$((count - 2 * trim))}")

  local sum=0
  for val in "${trimmed[@]}"; do
    sum=$((sum + val))
  done
  awk "BEGIN {printf \"%.1f\", $sum / ${#trimmed[@]} / 1024}"
}

avg_compute=$(trim_and_avg "${compute_times[@]}")
avg_setup=$(trim_and_avg "${setup_times[@]}")
avg_prove=$(trim_and_avg "${prove_times[@]}")
avg_verify=$(trim_and_avg "${verify_times[@]}")
avg_proof_kb=$(trim_and_avg_kb "${proof_sizes[@]}")

echo "================================"
echo "Trimmed Average Benchmark Results (trimmed $TRIM_PERCENT% top/bottom):"
echo "Compute-witness: $avg_compute ms"
echo "Setup:           $avg_setup ms"
echo "Generate-proof:  $avg_prove ms"
echo "Verify:          $avg_verify ms"
echo "Proof size:      $avg_proof_kb KB"
echo "================================"