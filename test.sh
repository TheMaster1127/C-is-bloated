#!/bin/bash
# cib-tier-bench.sh
# Benchmarks every cib tier: 1000 compile iterations + 1000 runtime iterations.
# Prints progress as it goes, logs each tier to bench.log, summary at the end.

TEST_FILE="test.c"
ITERATIONS=1000
LOG_FILE="bench.log"
TIERS=("Z0" "Z1" "Z2" "Z3" "Z4" "Z5" "EC")

declare -A FLAGS=(
    [Z0]="-Z0"
    [Z1]="-Z1"
    [Z2]="-Z2"
    [Z3]="-Z3"
    [Z4]="-Z4"
    [Z5]="-Z5"
    [EC]="-EC"
)

# ---------- Preflight ----------
if [ ! -f "$TEST_FILE" ]; then
    echo "❌ $TEST_FILE not found in current directory."
    exit 1
fi

if ! command -v cib >/dev/null 2>&1; then
    echo "❌ cib not found on PATH."
    echo "   If it's in the current directory, add it to PATH or edit this script."
    exit 1
fi

if ! command -v awk >/dev/null 2>&1; then
    echo "❌ awk not found."
    exit 1
fi

# Truncate the log
: > "$LOG_FILE"

# ---------- Helpers ----------
now() { date +%s.%N; }
elapsed_between() { awk -v s="$1" -v e="$2" 'BEGIN { printf "%.3f", e - s }'; }

log() {
    echo "$@" | tee -a "$LOG_FILE"
}

# ---------- Header ----------
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  cib tier benchmark                                          ║"
echo "╠══════════════════════════════════════════════════════════════╣"
printf "║  File:        %-46s ║\n" "$TEST_FILE"
printf "║  Iterations:  %-46s ║\n" "$ITERATIONS per tier, per phase"
printf "║  Tiers:       %-46s ║\n" "${TIERS[*]}"
printf "║  Log:         %-46s ║\n" "$LOG_FILE"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Started: $(date)"
echo ""

declare -A COMPILE_TIME
declare -A RUNTIME_TIME
declare -A BINARY_SIZE

# ---------- Phase 1: compile ----------
echo "▶ PHASE 1: Compile time ($ITERATIONS iterations per tier)"
echo ""

for tier in "${TIERS[@]}"; do
    flag="${FLAGS[$tier]}"
    echo "  ── $tier ($flag) ──"

    start=$(now)
    fail_count=0
    for i in $(seq "$ITERATIONS"); do
        if ! cib "$flag" "$TEST_FILE" > /dev/null 2>&1; then
            fail_count=$((fail_count + 1))
        fi
        if [ $((i % 100)) -eq 0 ]; then
            printf "\r      %d/%d ..." "$i" "$ITERATIONS"
        fi
    done
    end=$(now)

    elapsed=$(elapsed_between "$start" "$end")
    COMPILE_TIME[$tier]=$elapsed
    printf "\r      %d/%d — %ss (failures: %d)          \n" "$ITERATIONS" "$ITERATIONS" "$elapsed" "$fail_count"
    log "compile $tier $elapsed failures=$fail_count"
    echo ""
done

# ---------- Build final binaries ----------
echo "▶ Building final binaries for size + runtime..."
echo ""

for tier in "${TIERS[@]}"; do
    flag="${FLAGS[$tier]}"
    if cib "$flag" "$TEST_FILE" > /dev/null 2>&1 && [ -f "test" ]; then
        BINARY_SIZE[$tier]=$(stat -c %s "test")
        cp "test" "test_${tier}"
    else
        BINARY_SIZE[$tier]=0
        echo "  ⚠️  $tier build failed"
    fi
done

echo "  Built: $(printf 'test_%s ' "${TIERS[@]}")"
echo ""

# ---------- Phase 2: runtime ----------
echo "▶ PHASE 2: Runtime ($ITERATIONS iterations per tier, output discarded)"
echo ""

for tier in "${TIERS[@]}"; do
    if [ ! -x "./test_${tier}" ]; then
        echo "  ── $tier (skipped — no binary) ──"
        RUNTIME_TIME[$tier]="N/A"
        echo ""
        continue
    fi

    echo "  ── $tier ──"
    start=$(now)
    for i in $(seq "$ITERATIONS"); do
        "./test_${tier}" > /dev/null 2>&1
        if [ $((i % 100)) -eq 0 ]; then
            printf "\r      %d/%d ..." "$i" "$ITERATIONS"
        fi
    done
    end=$(now)

    elapsed=$(elapsed_between "$start" "$end")
    RUNTIME_TIME[$tier]=$elapsed
    printf "\r      %d/%d — %ss          \n" "$ITERATIONS" "$ITERATIONS" "$elapsed"
    log "runtime $tier $elapsed"
    echo ""
done

# ---------- Summary ----------
echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║  RESULTS                                                                  ║"
echo "╠══════════════╦═════════════════╦═════════════════╦═════════════════════════╣"
printf "║  %-11s ║  %-14s ║  %-14s ║  %-20s ║\n" "Tier" "Compile (1000x)" "Runtime (1000x)" "Binary size"
echo "╠══════════════╬═════════════════╬═════════════════╬═════════════════════════╣"

for tier in "${TIERS[@]}"; do
    ct="${COMPILE_TIME[$tier]}"
    rt="${RUNTIME_TIME[$tier]}"
    sz="${BINARY_SIZE[$tier]}"
    printf "║  %-11s ║  %12ss  ║  %12ss  ║  %15s bytes  ║\n" "$tier" "$ct" "$rt" "$sz"
done

echo "╚══════════════╩═════════════════╩═════════════════╩═════════════════════════╝"
echo ""

# ---------- Rankings ----------
echo "🏆 Compile speed (fastest → slowest):"
for tier in "${TIERS[@]}"; do
    echo "${COMPILE_TIME[$tier]} $tier"
done | sort -n | awk '{ printf "   %s  %ss\n", $2, $1 }'
echo ""

echo "🏆 Runtime speed (fastest → slowest):"
for tier in "${TIERS[@]}"; do
    rt="${RUNTIME_TIME[$tier]}"
    [ "$rt" != "N/A" ] && echo "$rt $tier"
done | sort -n | awk '{ printf "   %s  %ss\n", $2, $1 }'
echo ""

echo "🏆 Binary size (smallest → largest):"
for tier in "${TIERS[@]}"; do
    echo "${BINARY_SIZE[$tier]} $tier"
done | sort -n | awk '{ printf "   %s  %s bytes\n", $2, $1 }'
echo ""

# ---------- Cleanup ----------
echo "Binaries left for inspection: $(printf 'test_%s ' "${TIERS[@]}")"
echo "Remove with: rm -f $(printf 'test_%s ' "${TIERS[@]}")"
echo ""
echo "Finished: $(date)"
echo "Full log: $LOG_FILE"
echo "✅ Done."
