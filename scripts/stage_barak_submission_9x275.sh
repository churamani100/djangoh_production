#!/usr/bin/env bash

set -euo pipefail

BASE=/w/hallb-scshelf2102/clas12/cpaudel/EIC/g5_djangoh_test
SRC=$BASE/barak_filter_production/9x275/q2binned
MANIFEST=$SRC/barak_filter_manifest.tsv
VALIDATION=$BASE/barak_filter_production/9x275/npsim_validation100/barak_npsim_100event_validation.tsv

TAG=${TAG:?Set TAG before running this script}
STAGE=$BASE/production_candidate_${TAG}

rm -rf "$STAGE"

mkdir -p \
  "$STAGE/metadata" \
  "$STAGE/scripts" \
  "$STAGE/steering_files/9x275"

DATASETS=$STAGE/metadata/datasets.tsv

printf \
"release_tag\tprocess\tsubprocess\tbeam\tq2_range\trun\tinput_events\twritten_events\tskipped_parton\tskipped_empty\troot_entries\tcross_section_pb\tsize_bytes\trelative_path\n" \
> "$DATASETS"

stage_one() {
    local sample=$1
    local subprocess_dir=$2
    local subprocess_label=$3
    local q2=$4
    local xsec=$5

    local source_root
    source_root=$SRC/${sample}.barak_filtered.eicsmear.ab.hepmc3.tree.root

    if [ ! -s "$source_root" ]; then
        echo "ERROR: missing source file:"
        echo "$source_root"
        exit 1
    fi

    local row
    row=$(
        awk -F'\t' -v sample="$sample" '
        NR>1 && $1==sample {
            print
            exit
        }' "$MANIFEST"
    )

    if [ -z "$row" ]; then
        echo "ERROR: sample missing from Barak manifest:"
        echo "$sample"
        exit 1
    fi

    local manifest_sample input_events written_events
    local skipped_parton skipped_empty root_entries status

    IFS=$'\t' read -r \
      manifest_sample input_events written_events \
      skipped_parton skipped_empty root_entries status \
      <<< "$row"

    if [ "$status" != "PASS" ] ||
       [ "$written_events" != "$root_entries" ]; then
        echo "ERROR: filtering/ROOT validation failed for $sample"
        exit 1
    fi

    if ! awk -F'\t' -v sample="$sample" '
        NR>1 &&
        $1==sample &&
        $3==0 &&
        $4==100 &&
        $6=="PASS" {
            found=1
        }
        END {
            exit(found ? 0 : 1)
        }' "$VALIDATION"
    then
        echo "ERROR: 100-event npsim validation missing or failed:"
        echo "$sample"
        exit 1
    fi

    local destination_dir
    destination_dir=$STAGE/DIS/CC/$subprocess_dir/$TAG/9x275/q2_$q2

    mkdir -p "$destination_dir"

    local filename
    filename=${TAG}_DIS-CC-${subprocess_label}_9x275_q2_${q2}_run001.hepmc3.tree.root

    local destination
    destination=$destination_dir/$filename

    ln "$source_root" "$destination" 2>/dev/null ||
    cp -p "$source_root" "$destination"

    local bytes relative
    bytes=$(stat -c '%s' "$destination")
    relative=${destination#"$STAGE/"}

    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
      "$TAG" \
      "DIS-CC" \
      "$subprocess_dir" \
      "9x275" \
      "$q2" \
      "001" \
      "$input_events" \
      "$written_events" \
      "$skipped_parton" \
      "$skipped_empty" \
      "$root_entries" \
      "$xsec" \
      "$bytes" \
      "$relative" \
      >> "$DATASETS"

    echo "STAGED: $relative"
    echo "EVENTS: $root_entries"
}

stage_one \
  cc_g5_eMinus_pPlus_9x275_q2_100to1000 \
  eMinus_pPlus eMinus-pPlus 100to1000 21.440

stage_one \
  cc_g5_eMinus_pPlus_9x275_q2_1000to3000 \
  eMinus_pPlus eMinus-pPlus 1000to3000 10.321

stage_one \
  cc_g5_eMinus_pPlus_9x275_q2_3000to9000 \
  eMinus_pPlus eMinus-pPlus 3000to9000 1.2666

stage_one \
  cc_g5_eMinus_pMinus_9x275_q2_100to1000 \
  eMinus_pMinus eMinus-pMinus 100to1000 9.5747

stage_one \
  cc_g5_eMinus_pMinus_9x275_q2_1000to3000 \
  eMinus_pMinus eMinus-pMinus 1000to3000 3.0338

stage_one \
  cc_g5_eMinus_pMinus_9x275_q2_3000to9000 \
  eMinus_pMinus eMinus-pMinus 3000to9000 0.30165

# Filtering metadata
cp -p \
  "$MANIFEST" \
  "$STAGE/metadata/barak_filter_manifest.tsv"

awk -F'\t' '
BEGIN { OFS="\t" }
NR==1 {
    print "sample","exit_code","events_saved",
          "output_size_bytes","status"
    next
}
{
    print $1,$3,$4,$5,$6
}' "$VALIDATION" \
> "$STAGE/metadata/npsim_100event_validation.tsv"

# Barak filter source and production scripts
cp -p \
  "$BASE/baraks_filter/rewrite_hepmc.cxx" \
  "$STAGE/scripts/"

cp -p \
  "$BASE/baraks_filter/rewrite_hepmc_production.cxx" \
  "$STAGE/scripts/"

cp -p \
  "$BASE/baraks_filter/Makefile" \
  "$STAGE/scripts/"

cp -p \
  "$BASE/baraks_filter/run_all_barak_9x275.sh" \
  "$STAGE/scripts/"

cp -p \
  "$BASE/baraks_filter/validate_barak_9x275_100events.sh" \
  "$STAGE/scripts/"

# Steering cards
find "$BASE/djangoh_q2binned_9x275" \
  -maxdepth 1 \
  -type f \
  -name '*.in' \
  -exec cp -p {} "$STAGE/steering_files/9x275/" \;

# Checksums
(
    cd "$STAGE"

    find DIS \
      -type f \
      -name '*.hepmc3.tree.root' \
      -print0 |
    sort -z |
    xargs -0 sha256sum \
      > metadata/checksums.sha256
)

cat > "$STAGE/README.md" <<EOF
# DJANGOH 9x275 Charged-Current DIS Production Inputs

## Release tag

\`$TAG\`

- Generator: DJANGOH 4.6.10 with HERACLES
- Steering and preprocessing release: 1.0
- Beam energy: 9x275 GeV
- Process: charged-current DIS

## Included datasets

Exactly six production inputs are included:

- eMinus-pPlus, Q2 100 to 1000 GeV2
- eMinus-pPlus, Q2 1000 to 3000 GeV2
- eMinus-pPlus, Q2 3000 to 9000 GeV2
- eMinus-pMinus, Q2 100 to 1000 GeV2
- eMinus-pMinus, Q2 1000 to 3000 GeV2
- eMinus-pMinus, Q2 3000 to 9000 GeV2

No 1k, 5k or 18x275 datasets are included.

## Processing chain

1. Generate events using DJANGOH 4.6.10 and HERACLES.
2. Convert the DJANGOH event output using eic-smear BuildTree.
3. Convert to HepMC3 using TreeToHepMC.
4. Apply the Barak transport filtering program.
5. Retain incoming status-4 beam particles and status-1 final-state particles.
6. Recompute particle energy from momentum and generated mass.
7. Skip an event if an unhadronized final-state parton, string or diquark is found.
8. Apply the EIC afterburner profile \`ip6_hidiv_275x9\`.
9. Store the result in \`hepmc3.tree.root\` format.
10. Validate 100 events from every production input using npsim and the
    epic_craterlake detector geometry.

## Directory structure

\`DIS/CC/<polarization>/<release-tag>/9x275/q2_<range>/<filename>\`

## Filename convention

\`<release-tag>_<process>_<beam>_q2_<range>_run<index>.hepmc3.tree.root\`

## Metadata

- \`metadata/datasets.tsv\`: dataset event counts, cross sections and paths.
- \`metadata/barak_filter_manifest.tsv\`: filtering and ROOT-entry validation.
- \`metadata/npsim_100event_validation.tsv\`: npsim validation results.
- \`metadata/checksums.sha256\`: SHA-256 checksums.
- \`steering_files/9x275/\`: DJANGOH steering cards.
- \`scripts/\`: filtering, afterburner and validation programs.

## Repository

\`https://github.com/churamani100/djangoh_production\`
EOF

echo
echo "Production files:"
find "$STAGE/DIS" \
  -type f \
  -name '*.hepmc3.tree.root' |
sort

echo
echo "ROOT file count:"
find "$STAGE/DIS" \
  -type f \
  -name '*.hepmc3.tree.root' |
wc -l

echo
echo "Submission directory:"
echo "$STAGE"
