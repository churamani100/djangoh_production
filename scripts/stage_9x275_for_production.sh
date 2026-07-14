#!/usr/bin/env bash
set -euo pipefail

TAG="DJANGOH-HERACLES4.6.10-1.0"
BEAM="9x275"

SRC_DIR=$(pwd)
OUT_BASE=/w/hallb-scshelf2102/clas12/cpaudel/EIC/g5_djangoh_test/production_ready_hepmc3_tree_root

link_or_copy () {
  local src="$1"
  local dst="$2"

  mkdir -p "$(dirname "$dst")"

  # hard-link first to avoid duplicating huge files; if that fails, copy
  ln "$src" "$dst" 2>/dev/null || cp -p "$src" "$dst"
}

stage_one () {
  local spin="$1"
  local q2="$2"

  local src="cc_g5_eMinus_${spin}_9x275_q2_${q2}.eicsmear.ab.hepmc3.tree.root"

  if [ ! -f "$src" ]; then
    echo "MISSING source: $src"
    return 1
  fi

  local proc_dir_spin
  local proc_name_spin

  if [ "$spin" = "pPlus" ]; then
    proc_dir_spin="eMinus_pPlus"
    proc_name_spin="eMinus-pPlus"
  elif [ "$spin" = "pMinus" ]; then
    proc_dir_spin="eMinus_pMinus"
    proc_name_spin="eMinus-pMinus"
  else
    echo "Unknown spin: $spin"
    return 2
  fi

  local q2dir="q2_${q2}"
  local outdir="${OUT_BASE}/DIS/CC/${proc_dir_spin}/${TAG}/${BEAM}/${q2dir}"

  local dst="${outdir}/${TAG}_DIS-CC-${proc_name_spin}_${BEAM}_${q2dir}_run001.hepmc3.tree.root"

  echo "Staging:"
  echo "  from: $src"
  echo "  to  : $dst"

  link_or_copy "$src" "$dst"
}

for spin in pPlus pMinus; do
  for q2 in 100to1000 1000to3000 3000to9000; do
    stage_one "$spin" "$q2"
  done
done

echo
echo "Production-ready staged files:"
find "$OUT_BASE" -name "*.hepmc3.tree.root" -type f | sort
