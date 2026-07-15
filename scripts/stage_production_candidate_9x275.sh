#!/usr/bin/env bash

set -euo pipefail

BASE=/w/hallb-scshelf2102/clas12/cpaudel/EIC/g5_djangoh_test
SRCROOT=$BASE/npsim_transport_inputs
SRC=$SRCROOT/9x275/q2binned

TAG=DJANGOH4.6.10-1.0
STAGE=$BASE/production_candidate_${TAG}

SOURCE_MANIFEST=$SRCROOT/manifest.tsv
DATASET_MANIFEST=$STAGE/metadata/datasets.tsv

rm -rf "$STAGE"

mkdir -p \
  "$STAGE/metadata" \
  "$STAGE/scripts" \
  "$STAGE/steering_files/9x275"

printf \
"release_tag\tprocess\tsubprocess\tbeam\tq2_range\trun\tevents\tcross_section_pb\tsize_bytes\tsource_file\tstaged_file\n" \
> "$DATASET_MANIFEST"

stage_one() {
    local source_file=$1
    local subprocess_dir=$2
    local subprocess_label=$3
    local q2_range=$4
    local cross_section_pb=$5

    if [ ! -s "$source_file" ]; then
        echo "ERROR: source file is missing or empty:"
        echo "$source_file"
        exit 1
    fi

    local entries

    entries=$(
        awk -F'\t' -v target="$source_file" '
        NR>1 && $5==target {
            print $7
            exit
        }' "$SOURCE_MANIFEST"
    )

    if ! [[ "${entries:-}" =~ ^[0-9]+$ ]]; then
        echo "ERROR: could not find event count in manifest for:"
        echo "$source_file"
        exit 1
    fi

    local destination_dir
    destination_dir=$STAGE/DIS/CC/$subprocess_dir/$TAG/9x275/q2_$q2_range

    mkdir -p "$destination_dir"

    local filename
    filename=${TAG}_DIS-CC-${subprocess_label}_9x275_q2_${q2_range}_run001.hepmc3.tree.root

    local destination
    destination=$destination_dir/$filename

    # Use a hard link when possible to avoid duplicating large files.
    ln "$source_file" "$destination" 2>/dev/null ||
    cp -p "$source_file" "$destination"

    local bytes
    bytes=$(stat -c '%s' "$destination")

    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
      "$TAG" \
      "DIS-CC" \
      "$subprocess_dir" \
      "9x275" \
      "$q2_range" \
      "001" \
      "$entries" \
      "$cross_section_pb" \
      "$bytes" \
      "$source_file" \
      "$destination" \
      >> "$DATASET_MANIFEST"

    echo "STAGED: $destination"
    echo "EVENTS: $entries"
}

# ============================================================
# eMinus-pPlus
# ============================================================

stage_one \
  "$SRC/cc_g5_eMinus_pPlus_9x275_q2_100to1000.transport_clean_keepbeams.eicsmear.ab.hepmc3.tree.root" \
  "eMinus_pPlus" \
  "eMinus-pPlus" \
  "100to1000" \
  "21.440"

stage_one \
  "$SRC/cc_g5_eMinus_pPlus_9x275_q2_1000to3000.transport_clean_keepbeams.eicsmear.ab.hepmc3.tree.root" \
  "eMinus_pPlus" \
  "eMinus-pPlus" \
  "1000to3000" \
  "10.321"

stage_one \
  "$SRC/cc_g5_eMinus_pPlus_9x275_q2_3000to9000.transport_clean_keepbeams.eicsmear.ab.hepmc3.tree.root" \
  "eMinus_pPlus" \
  "eMinus-pPlus" \
  "3000to9000" \
  "1.2666"

# ============================================================
# eMinus-pMinus
# ============================================================

stage_one \
  "$SRC/cc_g5_eMinus_pMinus_9x275_q2_100to1000.transport_clean_keepbeams.eicsmear.ab.hepmc3.tree.root" \
  "eMinus_pMinus" \
  "eMinus-pMinus" \
  "100to1000" \
  "9.5747"

stage_one \
  "$SRC/cc_g5_eMinus_pMinus_9x275_q2_1000to3000.transport_clean_keepbeams.eicsmear.ab.hepmc3.tree.root" \
  "eMinus_pMinus" \
  "eMinus-pMinus" \
  "1000to3000" \
  "3.0338"

stage_one \
  "$SRC/cc_g5_eMinus_pMinus_9x275_q2_3000to9000.transport_clean_keepbeams.eicsmear.ab.hepmc3.tree.root" \
  "eMinus_pMinus" \
  "eMinus-pMinus" \
  "3000to9000" \
  "0.30165"

# ============================================================
# Reproduction scripts
# ============================================================

cp -p \
  "$SRCROOT/scripts/clean_hepmc_keep_beams_stream.py" \
  "$STAGE/scripts/"

cp -p \
  "$SRCROOT/scripts/prepare_one_transport_sample.sh" \
  "$STAGE/scripts/"

cp -p \
  "$SRCROOT/scripts/prepare_all_transport_samples.sh" \
  "$STAGE/scripts/"

cp -p \
  "$SRCROOT/scripts/validate_9x275_q2binned_100events.sh" \
  "$STAGE/scripts/" 2>/dev/null || true

# ============================================================
# Validation metadata
# ============================================================

if [ -f "$SRCROOT/validation/npsim_validation.tsv" ]; then
    cp -p \
      "$SRCROOT/validation/npsim_validation.tsv" \
      "$STAGE/metadata/npsim_10event_validation_all.tsv"
fi

if [ -f "$SRCROOT/validation100_9x275_q2binned/npsim_100event_validation.tsv" ]; then
    cp -p \
      "$SRCROOT/validation100_9x275_q2binned/npsim_100event_validation.tsv" \
      "$STAGE/metadata/npsim_100event_validation.tsv"
fi

# ============================================================
# Steering cards
# ============================================================

find "$BASE/djangoh_q2binned_9x275" \
  -maxdepth 1 \
  -type f \
  -name '*.in' \
  -exec cp -p {} "$STAGE/steering_files/9x275/" \; \
  2>/dev/null || true

# ============================================================
# Checksums
# ============================================================

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

# ============================================================
# README
# ============================================================

cat > "$STAGE/README.md" <<EOF
# DJANGOH 9x275 Charged-Current DIS Production Inputs

## Release tag

\`$TAG\`

The release name follows the EIC convention for an externally maintained
generator with locally maintained steering and preprocessing:

- DJANGOH generator version: 4.6.10
- Steering/preprocessing release: 1.0

The Git repository containing the steering files and preprocessing scripts
must use the matching release tag:

\`$TAG\`

## Included datasets

This package contains exactly six production input files:

- eMinus-pPlus, Q2 = 100--1000 GeV2
- eMinus-pPlus, Q2 = 1000--3000 GeV2
- eMinus-pPlus, Q2 = 3000--9000 GeV2
- eMinus-pMinus, Q2 = 100--1000 GeV2
- eMinus-pMinus, Q2 = 1000--3000 GeV2
- eMinus-pMinus, Q2 = 3000--9000 GeV2

No 1k, 5k, or 18x275 files are included.

## Physics process

Charged-current deep-inelastic scattering at 9x275 GeV:

\`e- + p -> neutrino + X\`

The pPlus and pMinus labels identify the two polarization configurations
used in the DJANGOH steering files.

## Preprocessing chain

1. Generate events with DJANGOH 4.6.10 and HERACLES.
2. Convert DJANGOH event output using eic-smear BuildTree.
3. Convert the eic-smear tree with TreeToHepMC in HepMC3 mode.
4. Construct a transport-level event record:
   - retain incoming status-4 electron and proton beam particles;
   - retain status-1 final-state detector particles;
   - remove generator-history partons, W bosons, strings and diquarks;
   - omit final-state neutrinos from detector transport.
5. Apply the EIC afterburner profile:
   \`ip6_hidiv_275x9\`
6. Store the resulting events in:
   \`hepmc3.tree.root\`
7. Validate every file with npsim using the epic_craterlake detector geometry.

## Required filename format

\`<release-tag>_<process>_<beam>_q2_<range>_run<index>.hepmc3.tree.root\`

Example:

\`DJANGOH4.6.10-1.0_DIS-CC-eMinus-pPlus_9x275_q2_100to1000_run001.hepmc3.tree.root\`

## Directory organization

\`DIS/CC/<polarization>/<release-tag>/9x275/q2_<range>/<filename>\`

## Metadata

- \`metadata/datasets.tsv\`: event totals, cross sections, source paths and
  staged paths.
- \`metadata/checksums.sha256\`: SHA-256 checksums.
- \`metadata/npsim_100event_validation.tsv\`: 100-event npsim validation.
- \`steering_files/9x275/\`: DJANGOH steering cards.
- \`scripts/\`: transport cleaning, afterburner and validation scripts.

## Repository

Current working repository:

\`https://github.com/churamani100/djangoh_production\`

For formal campaign acceptance, the repository and matching release tag
should be transferred to or mirrored under an EIC, Jefferson Lab or BNL
GitHub organization.
EOF

echo
echo "============================================================"
echo "Staging completed:"
echo "$STAGE"
echo
echo "Number of production ROOT files:"
find "$STAGE/DIS" \
  -type f \
  -name '*.hepmc3.tree.root' |
wc -l
echo "============================================================"
