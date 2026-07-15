#!/usr/bin/env bash

set -euo pipefail

BASE=/w/hallb-scshelf2102/clas12/cpaudel/EIC/g5_djangoh_test
TRANSPORT_ROOT=$BASE/npsim_transport_inputs
PREPARE=$TRANSPORT_ROOT/scripts/prepare_one_transport_sample.sh

process_directory() {
  local source_dir=$1
  local profile=$2
  local output_subdir=$3

  echo
  echo "################################################################"
  echo "Source:  $source_dir"
  echo "Profile: $profile"
  echo "Output:  $TRANSPORT_ROOT/$output_subdir"
  echo "################################################################"

  if [ ! -d "$source_dir" ]; then
    echo "SKIP: source directory does not exist"
    return
  fi

  mapfile -t files < <(
    find -L "$source_dir" \
      -maxdepth 1 \
      -type f \
      -name '*_evt.hepmc' |
    sort
  )

  if [ "${#files[@]}" -eq 0 ]; then
    echo "SKIP: no original *_evt.hepmc files found"
    return
  fi

  for evt in "${files[@]}"; do
    name=$(basename "$evt")

    case "$name" in
      *"_event"[0-9]*.hepmc)
        echo "Skipping split test file: $name"
        continue
        ;;
      *npsim_clean*.hepmc)
        echo "Skipping older cleaned file: $name"
        continue
        ;;
      *transport_clean*.hepmc)
        echo "Skipping cleaned output: $name"
        continue
        ;;
    esac

    "$PREPARE" \
      "$evt" \
      "$profile" \
      "$TRANSPORT_ROOT/$output_subdir"
  done
}

process_directory \
  "$BASE/djangoh_18x275_5k_official_converted_corrected" \
  "ip6_hidiv_275x18" \
  "18x275/5k"

process_directory \
  "$BASE/djangoh_18x275_1k_official_converted_corrected" \
  "ip6_hidiv_275x18" \
  "18x275/1k"

process_directory \
  "$BASE/djangoh_18x275_1M_official_converted" \
  "ip6_hidiv_275x18" \
  "18x275/1M"

process_directory \
  "$BASE/djangoh_9x275_5k_official_converted_corrected" \
  "ip6_hidiv_275x9" \
  "9x275/5k"

process_directory \
  "$BASE/djangoh_q2binned_9x275_official_converted" \
  "ip6_hidiv_275x9" \
  "9x275/q2binned"

echo
echo "============================================================"
echo "All existing samples processed."
echo "Manifest:"
echo "$TRANSPORT_ROOT/manifest.tsv"
echo "============================================================"
