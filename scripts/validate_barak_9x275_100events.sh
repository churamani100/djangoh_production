#!/usr/bin/env bash

set -u

BASE=/w/hallb-scshelf2102/clas12/cpaudel/EIC/g5_djangoh_test
INPUT_DIR=$BASE/barak_filter_production/9x275/q2binned
VAL=$BASE/barak_filter_production/9x275/npsim_validation100

mkdir -p "$VAL/logs" "$VAL/root"

if [ -z "${DETECTOR_PATH:-}" ]; then
    echo "ERROR: DETECTOR_PATH is not set"
    exit 1
fi

COMPACT=$DETECTOR_PATH/epic_craterlake.xml

EPIC_PREFIX=$(dirname "$(dirname "$DETECTOR_PATH")")
export LD_LIBRARY_PATH=$EPIC_PREFIX/lib:$EPIC_PREFIX/lib64:${LD_LIBRARY_PATH:-}
export DD4HEP_LIBRARY_PATH=$EPIC_PREFIX/lib:$EPIC_PREFIX/lib64:${DD4HEP_LIBRARY_PATH:-}

SUMMARY=$VAL/barak_npsim_100event_validation.tsv

printf \
"sample\tinput_root\texit_code\tevents_saved\toutput_size_bytes\tstatus\n" \
> "$SUMMARY"

mapfile -t INPUTS < <(
    find "$INPUT_DIR" -maxdepth 1 -type f \
      -name '*.barak_filtered.eicsmear.ab.hepmc3.tree.root' |
    sort
)

echo "Found ${#INPUTS[@]} Barak-filtered files."

if [ "${#INPUTS[@]}" -ne 6 ]; then
    echo "ERROR: expected 6 files"
    exit 2
fi

for INPUT in "${INPUTS[@]}"; do
    SAMPLE=$(basename "$INPUT" \
      .barak_filtered.eicsmear.ab.hepmc3.tree.root)

    OUTPUT=$VAL/root/${SAMPLE}.barak_test100.edm4hep.root
    LOG=$VAL/logs/${SAMPLE}.barak_test100.log

    echo
    echo "============================================================"
    echo "Testing: $SAMPLE"
    echo "============================================================"

    rm -f "$OUTPUT" "$LOG"

    npsim \
      --compactFile "$COMPACT" \
      --inputFiles "$INPUT" \
      --outputFile "$OUTPUT" \
      --numberOfEvents 100 \
      > "$LOG" 2>&1

    EC=$?
    SAVED=$(grep -c 'Saving EDM4hep event' "$LOG" 2>/dev/null || true)
    SIZE=$(stat -c '%s' "$OUTPUT" 2>/dev/null || echo 0)

    if [ "$EC" -eq 0 ] &&
       [ "$SAVED" -eq 100 ] &&
       [ "$SIZE" -gt 1000 ]; then
        STATUS=PASS
    else
        STATUS=FAIL
    fi

    printf "%s\t%s\t%s\t%s\t%s\t%s\n" \
      "$SAMPLE" "$INPUT" "$EC" "$SAVED" "$SIZE" "$STATUS" \
      >> "$SUMMARY"

    echo "exit code:    $EC"
    echo "events saved: $SAVED"
    echo "status:       $STATUS"

    if [ "$STATUS" = "FAIL" ]; then
        tail -60 "$LOG"
    fi
done

echo
awk -F'\t' '
NR>1 {
    total++
    if ($6=="PASS") pass++
    else {
        fail++
        print "FAILED:", $1
    }
}
END {
    print "Total:", total
    print "PASS: ", pass+0
    print "FAIL: ", fail+0
}' "$SUMMARY"
