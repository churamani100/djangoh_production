#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage:"
  echo "  $0 input_evt.hepmc afterburner_profile output_directory"
  exit 2
fi

INPUT_EVT=$(readlink -f "$1")
PROFILE=$2
OUTPUT_DIR=$(readlink -m "$3")

TRANSPORT_ROOT=/w/hallb-scshelf2102/clas12/cpaudel/EIC/g5_djangoh_test/npsim_transport_inputs

CLEANER=$TRANSPORT_ROOT/scripts/clean_hepmc_keep_beams_stream.py
AB=/w/hallb-scshelf2102/clas12/cpaudel/EIC/afterburner/install/bin/abconv
ABLIB=$TRANSPORT_ROOT/compat_ab_libs

mkdir -p "$OUTPUT_DIR/logs"

if [ ! -f "$INPUT_EVT" ]; then
  echo "ERROR: missing input: $INPUT_EVT"
  exit 1
fi

if [ ! -x "$CLEANER" ]; then
  echo "ERROR: missing cleaner: $CLEANER"
  exit 1
fi

if [ ! -x "$AB" ]; then
  echo "ERROR: missing abconv: $AB"
  exit 1
fi

BASE=$(basename "$INPUT_EVT" _evt.hepmc)

CLEAN_HEPMC=$OUTPUT_DIR/${BASE}.transport_clean_keepbeams.hepmc
OUTPUT_PREFIX=$OUTPUT_DIR/${BASE}.transport_clean_keepbeams.eicsmear.ab
OUTPUT_ROOT=${OUTPUT_PREFIX}.hepmc3.tree.root

CLEAN_LOG=$OUTPUT_DIR/logs/${BASE}.clean.log
AB_LOG=$OUTPUT_DIR/logs/${BASE}.abconv.log
ROOT_LOG=$OUTPUT_DIR/logs/${BASE}.root_check.log

echo "============================================================"
echo "Input:   $INPUT_EVT"
echo "Profile: $PROFILE"
echo "Output:  $OUTPUT_DIR"
echo "============================================================"

if [ -s "$OUTPUT_ROOT" ] && [ "${FORCE:-0}" != "1" ]; then
  echo "SKIP: output already exists:"
  echo "$OUTPUT_ROOT"
  exit 0
fi

echo "[1/3] Cleaning generator history"

python3 "$CLEANER" \
  "$INPUT_EVT" \
  "$CLEAN_HEPMC" \
  2>&1 | tee "$CLEAN_LOG"

CLEAN_EVENTS=$(
  awk -F= '/^EVENTS_WRITTEN=/{print $2}' "$CLEAN_LOG" |
  tail -1
)

if [ -z "$CLEAN_EVENTS" ] || [ "$CLEAN_EVENTS" -le 0 ]; then
  echo "ERROR: no events written by cleaner"
  exit 1
fi

echo "[2/3] Running afterburner"

LD_LIBRARY_PATH=$ABLIB:/opt/local/lib \
"$AB" \
  -p "$PROFILE" \
  "$CLEAN_HEPMC" \
  -o "$OUTPUT_PREFIX" \
  > "$AB_LOG" 2>&1

if [ ! -s "$OUTPUT_ROOT" ]; then
  echo "ERROR: afterburned ROOT file was not created"
  tail -80 "$AB_LOG"
  exit 1
fi

echo "[3/3] Checking hepmc3_tree entries"

LD_LIBRARY_PATH=/opt/local/lib:$ABLIB \
/opt/local/bin/root \
  -l -b -q "$OUTPUT_ROOT" \
  -e '
    TTree *t=(TTree*)_file0->Get("hepmc3_tree");
    if(t) {
      cout << "ENTRIES " << t->GetEntries() << endl;
    } else {
      cout << "ENTRIES MISSING" << endl;
    }
  ' > "$ROOT_LOG" 2>&1

ROOT_EVENTS=$(
  awk '/ENTRIES [0-9]+/{print $2}' "$ROOT_LOG" |
  tail -1
)

echo
echo "Cleaned events: $CLEAN_EVENTS"
echo "ROOT entries:   ${ROOT_EVENTS:-UNKNOWN}"
echo "ROOT file:      $OUTPUT_ROOT"

MANIFEST=$TRANSPORT_ROOT/manifest.tsv

if [ ! -f "$MANIFEST" ]; then
  printf "sample\tprofile\tinput_evt\tclean_hepmc\tafterburned_root\tclean_events\troot_entries\n" \
    > "$MANIFEST"
fi

printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
  "$BASE" \
  "$PROFILE" \
  "$INPUT_EVT" \
  "$CLEAN_HEPMC" \
  "$OUTPUT_ROOT" \
  "$CLEAN_EVENTS" \
  "${ROOT_EVENTS:-UNKNOWN}" \
  >> "$MANIFEST"

if [ -n "${ROOT_EVENTS:-}" ] &&
   [ "$ROOT_EVENTS" != "$CLEAN_EVENTS" ]; then
  echo "WARNING: event-count mismatch"
  exit 3
fi

echo "DONE: $BASE"
