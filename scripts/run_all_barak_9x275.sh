#!/usr/bin/env bash

set -euo pipefail

BASE=/w/hallb-scshelf2102/clas12/cpaudel/EIC/g5_djangoh_test
SRC=$BASE/djangoh_q2binned_9x275_official_converted
OUT=$BASE/barak_filter_production/9x275/q2binned

FILTER=$BASE/baraks_filter/rewrite_hepmc_production
AB=/w/hallb-scshelf2102/clas12/cpaudel/EIC/afterburner/install/bin/abconv
ABLIB=$BASE/npsim_transport_inputs/compat_ab_libs

mkdir -p "$OUT/logs"

MANIFEST=$OUT/barak_filter_manifest.tsv

printf \
"sample\tinput_events\twritten_events\tskipped_parton\tskipped_empty\troot_entries\tstatus\n" \
> "$MANIFEST"

process_one() {
    local sample=$1

    local input=$SRC/${sample}_evt.hepmc
    local filtered=$OUT/${sample}.barak_filtered.hepmc
    local prefix=$OUT/${sample}.barak_filtered.eicsmear.ab
    local root=${prefix}.hepmc3.tree.root
    local filter_log=$OUT/logs/${sample}.filter.log
    local ab_log=$OUT/logs/${sample}.abconv.log
    local root_log=$OUT/logs/${sample}.root_check.log

    echo
    echo "============================================================"
    echo "Processing: $sample"
    echo "============================================================"

    if [ ! -s "$input" ]; then
        echo "ERROR: missing input $input"
        exit 1
    fi

    "$FILTER" "$input" "$filtered" > "$filter_log" 2>&1

    local input_events
    local written_events
    local skipped_parton
    local skipped_empty

    input_events=$(
        awk -F= '/^SUMMARY_INPUT_EVENTS=/{print $2}' "$filter_log"
    )
    written_events=$(
        awk -F= '/^SUMMARY_WRITTEN_EVENTS=/{print $2}' "$filter_log"
    )
    skipped_parton=$(
        awk -F= '/^SUMMARY_SKIPPED_PARTON_EVENTS=/{print $2}' "$filter_log"
    )
    skipped_empty=$(
        awk -F= '/^SUMMARY_SKIPPED_EMPTY_EVENTS=/{print $2}' "$filter_log"
    )

    echo "Input events:       $input_events"
    echo "Written events:     $written_events"
    echo "Skipped partons:    $skipped_parton"
    echo "Skipped empty:      $skipped_empty"

    LD_LIBRARY_PATH=$ABLIB:/opt/local/lib \
    "$AB" \
      -p ip6_hidiv_275x9 \
      "$filtered" \
      -o "$prefix" \
      > "$ab_log" 2>&1

    if [ ! -s "$root" ]; then
        echo "ERROR: afterburned ROOT file not created"
        tail -60 "$ab_log"
        exit 1
    fi

    LD_LIBRARY_PATH=/opt/local/lib:$ABLIB \
    /opt/local/bin/root -l -b -q "$root" \
      -e '
        TTree *t=(TTree*)_file0->Get("hepmc3_tree");
        if(t) cout << "ENTRIES=" << t->GetEntries() << endl;
      ' > "$root_log" 2>&1

    local root_entries
    root_entries=$(
        awk -F= '/^ENTRIES=/{print $2}' "$root_log" |
        tail -1
    )

    local status=PASS

    if [ "$written_events" != "$root_entries" ]; then
        status=FAIL
    fi

    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
      "$sample" \
      "$input_events" \
      "$written_events" \
      "$skipped_parton" \
      "$skipped_empty" \
      "$root_entries" \
      "$status" \
      >> "$MANIFEST"

    echo "ROOT entries:       $root_entries"
    echo "Status:             $status"

    if [ "$status" != "PASS" ]; then
        exit 2
    fi
}

for polarization in pMinus pPlus; do
    for q2 in 100to1000 1000to3000 3000to9000; do
        process_one \
          "cc_g5_eMinus_${polarization}_9x275_q2_${q2}"
    done
done

echo
echo "All six Barak-filtered datasets completed."
echo "Manifest: $MANIFEST"
