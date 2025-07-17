#!/bin/bash
set -e

nanots() {
  echo $(date +%s%N)
}

duration_ms() {
  echo $((($2 - $1) / 1000000))
}

N=64  # Fibonacci number to compute
NUM_RUNS=100
TRIM_PERCENT=5  # percent of high and low values to trim

compute_times=()
setup_times=()
prove_times=()
verify_times=()
proof_sizes=()

EXPECTED_RESULT=$(python3 -c "a, b = 1, 1
for i in range(2, $N):
    a, b = b, a+b
print(b)")

echo "Running benchmark $NUM_RUNS times with hardcoded n = $N"
echo "Expected result: $EXPECTED_RESULT"
echo ""

for i in $(seq 1 $NUM_RUNS); do
  echo "Run #$i"

  zokrates compile -i fibonacci.zok > /dev/null

  START=$(nanots)
  zokrates compute-witness -a $EXPECTED_RESULT > /dev/null
  END=$(nanots)
  compute_times+=($(duration_ms $START $END))

  START=$(nanots)
  zokrates setup > /dev/null
  END=$(nanots)
  setup_times+=($(duration_ms $START $END))

  START=$(nanots)
  zokrates generate-proof > /dev/null
  END=$(nanots)
  prove_times+=($(duration_ms $START $END))

  proof_sizes+=($(du -b proof.json | awk '{print $1}'))

  START=$(nanots)
  zokrates verify > /dev/null
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
