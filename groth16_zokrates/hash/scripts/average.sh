#!/bin/bash
set -e

nanots() {
  echo $(date +%s%N)
}

duration_ms() {
  echo $((($2 - $1) / 1000000))
}

NUM_RUNS=100
TRIM_PERCENT=5  # Trim 5% lowest and highest values

# Hardcoded inputs
SECRET=1121645852825515626345503741442177404306361956507933536148868635850297893661
HASH=2728569673190821187094419527647561004262639953421171061861302988333198391804

# Result arrays
setup_times=()
witness_times=()
prove_times=()
verify_times=()
proof_sizes=()

echo "Running Poseidon hash benchmark $NUM_RUNS times"
echo ""

cd ..

for i in $(seq 1 $NUM_RUNS); do
  echo "Run #$i"

  zokrates compile -i poseidon_hash.zok > /dev/null

  START=$(nanots)
  zokrates setup > /dev/null
  END=$(nanots)
  setup_times+=($(duration_ms $START $END))

  START=$(nanots)
  zokrates compute-witness -a "$SECRET" "$HASH" > /dev/null
  END=$(nanots)
  witness_times+=($(duration_ms $START $END))

  START=$(nanots)
  zokrates generate-proof -j proof.json > /dev/null
  END=$(nanots)
  prove_times+=($(duration_ms $START $END))

  proof_sizes+=($(du -b proof.json | awk '{print $1}'))

  START=$(nanots)
  zokrates verify -j proof.json > /dev/null
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
echo "Trimmed Average Poseidon Hash Results ($NUM_RUNS runs, $TRIM_PERCENT% trim):"
echo "Setup:           $avg_setup ms"
echo "Compute-witness: $avg_witness ms"
echo "Generate-proof:  $avg_prove ms"
echo "Verify:          $avg_verify ms"
echo "Proof size:      $avg_proof_kb KB"
echo "================================"
