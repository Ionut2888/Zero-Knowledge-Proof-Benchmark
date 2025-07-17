#!/bin/bash
set -e

NUM_RUNS=100
TRIM_PERCENT=5  # Trim 5% lowest and highest values
BUILD_DIR="../build"
CIRCUIT_NAME="circuit"
PTAU="../powersOfTau28_hez_final_10.ptau"
INPUT_JSON="../input.json"

nanots() {
  echo $(date +%s%N)
}
duration_ms() {
  echo $((($2 - $1) / 1000000))
}

setup_times=()
witness_times=()
prove_times=()
verify_times=()
proof_sizes=()

echo "Running PLONK Poseidon hash benchmark $NUM_RUNS times"
echo ""

# Prepare circuit/keys ONCE for all runs, to avoid recompiling/setup overhead every iteration
circom ../${CIRCUIT_NAME}.circom --r1cs --wasm --sym -o $BUILD_DIR > /dev/null

snarkjs plonk setup \
  $BUILD_DIR/${CIRCUIT_NAME}.r1cs \
  $PTAU \
  $BUILD_DIR/${CIRCUIT_NAME}_plonk.zkey > /dev/null

snarkjs zkey export verificationkey \
  $BUILD_DIR/${CIRCUIT_NAME}_plonk.zkey \
  $BUILD_DIR/verification_key.json > /dev/null

for i in $(seq 1 $NUM_RUNS); do
  echo "Run #$i"

  # Setup is technically done above, but we'll time/measure it each run for apples-to-apples with ZoKrates
  START=$(nanots)
  snarkjs plonk setup \
    $BUILD_DIR/${CIRCUIT_NAME}.r1cs \
    $PTAU \
    $BUILD_DIR/${CIRCUIT_NAME}_plonk.zkey > /dev/null
  END=$(nanots)
  setup_times+=($(duration_ms $START $END))

  # Witness
  START=$(nanots)
  node $BUILD_DIR/${CIRCUIT_NAME}_js/generate_witness.js \
    $BUILD_DIR/${CIRCUIT_NAME}_js/${CIRCUIT_NAME}.wasm \
    $INPUT_JSON \
    $BUILD_DIR/witness.wtns > /dev/null
  END=$(nanots)
  witness_times+=($(duration_ms $START $END))

  # Prove
  START=$(nanots)
  snarkjs plonk prove \
    $BUILD_DIR/${CIRCUIT_NAME}_plonk.zkey \
    $BUILD_DIR/witness.wtns \
    $BUILD_DIR/proof.json \
    $BUILD_DIR/public.json > /dev/null
  END=$(nanots)
  prove_times+=($(duration_ms $START $END))

  proof_sizes+=($(du -b $BUILD_DIR/proof.json | awk '{print $1}'))

  # Verify
  START=$(nanots)
  snarkjs plonk verify \
    $BUILD_DIR/verification_key.json \
    $BUILD_DIR/public.json \
    $BUILD_DIR/proof.json > /dev/null
  END=$(nanots)
  verify_times+=($(duration_ms $START $END))

  echo "  setup:   ${setup_times[-1]} ms"
  echo "  witness: ${witness_times[-1]} ms"
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

# KB variant
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

avg_setup=$(trim_and_avg "${setup_times[@]}")
avg_witness=$(trim_and_avg "${witness_times[@]}")
avg_prove=$(trim_and_avg "${prove_times[@]}")
avg_verify=$(trim_and_avg "${verify_times[@]}")
avg_proof_kb=$(trim_and_avg_kb "${proof_sizes[@]}")

echo "================================"
echo "Trimmed Average PLONK Poseidon Hash Results ($NUM_RUNS runs, $TRIM_PERCENT% trim):"
echo "Setup time:     $avg_setup ms"
echo "Witness time:   $avg_witness ms"
echo "Proving time:   $avg_prove ms"
echo "Proof size:     $avg_proof_kb KB"
echo "Verification time: $avg_verify ms"
echo "================================"