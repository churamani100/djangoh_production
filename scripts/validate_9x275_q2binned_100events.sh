#!/usr/bin/env bash

set -u

TRANSPORT_ROOT=/w/hallb-scshelf2102/clas12/cpaudel/EIC/g5_djangoh_test/npsim_transport_inputs
Q2DIR=$TRANSPORT_ROOT/9x275/q2binned
VAL=$TRANSPORT_ROOT/validation100_9x275_q2binned

mkdir -p "$VAL/logs" "$VAL/root"

if [ -z "${DETECTOR_PATH:-}" ]; then
    echo "ERROR: DETECTOR_PATH is not set"
    exit 1
fi

COMPACT=$DETECTOR_PATH/epic_craterlake.xml

if [ ! -f "$COMPACT" ]; then
    echo "ERROR: detector compact file not found:"
    echo "$COMPACT"
    exit 1
fi

EPIC_PREFIX=$(dirname "$(dirname "$DETECTOR_PATH")")
export LD_LIBRARY_PATH=$EPIC_PREFIX/lib:$EPIC_PREFIX/lib64:${LD_LIBRARY_PATH:-}
export DD4HEP_LIBRARY_PATH=$EPIC_PREFIX/lib:$EPIC_PREFIX/lib64:${DD4HEP_LIBRARY_PATH:-}

SUMMARY=$VAL/npsim_100event_validation.tsv

printf "sample\tinput_root\texit_code\tevents_saved\toutput_size_bytes\tstatus\n" \
    > "$SUMMARY"

mapfile -t INPUTS < <(
    find "$Q2DIR" -maxdepth 1 -type f \
      -name '*.transport_clean_keepbeams.eicsmear.ab.hepmc3.tree.root' \
      | sort
)

echo "Found ${#INPUTS[@]} q2-binned input files."

if [ "${#INPUTS[@]}" -ne 6 ]; then
    echo "WARNING: expected 6 files but found ${#INPUTS[@]}"
fi

for INPUT in "${INPUTS[@]}"; do
    SAMPLE=$(basename "$INPUT" \
      .transport_clean_keepbeams.eicsmear.ab.hepmc3.tree.root)

    OUTPUT=$VAL/root/${SAMPLE}.test100.edm4hep.root
    LOG=$VAL/logs/${SAMPLE}.test100.log

    echo
    echo "============================================================"
    echo "Testing 100 events:"
    echo "$SAMPLE"
    echo "============================================================"

    rm -f "$OUTPUT" "$LOG"

    npsim \
      --compactFile "$COMPACT" \
      --inputFiles "$INPUT" \
      --outputFile "$OUTPUT" \
      --numberOfEvents 100 \
      > "$LOG" 2>&1

    EC=$?

    SAVED=$(grep -c "Saving EDM4hep event" "$LOG" 2>/dev/null || true)
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
    echo "output bytes: $SIZE"
    echo "status:       $STATUS"

    if [ "$STATUS" = "FAIL" ]; then
        echo "Last 60 log lines:"
        tail -60 "$LOG"
    fi
done

echo
echo "================ FINAL SUMMARY ================"

awk -F'\t' '
NR==1 {
    printf "%-67s %-6s %-8s %-8s\n",
           "SAMPLE", "EXIT", "SAVED", "STATUS"
    next
}
{
    printf "%-67s %-6s %-8s %-8s\n",
           $1, $3, $4, $6
}' "$SUMMARY"

echo
awk -F'\t' '
NR>1 {
    total++
    if ($6=="PASS") pass++
    else fail++
}
END {
    print "Total samples:", total
    print "PASS:", pass+0
    print "FAIL:", fail+0
}' "$SUMMARY"
