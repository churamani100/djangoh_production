#!/usr/bin/env bash
set -euo pipefail

INDIR=/w/hallb-scshelf2102/clas12/cpaudel/EIC/g5_djangoh_test/djangoh_q2binned_9x275

for BASE in \
  cc_g5_eMinus_pMinus_9x275_q2_100to1000 \
  cc_g5_eMinus_pMinus_9x275_q2_1000to3000 \
  cc_g5_eMinus_pMinus_9x275_q2_3000to9000
do
  echo "======================================================"
  echo "Converting $BASE"
  echo "======================================================"

  ./convert_one_official_9x275.sh \
    "$INDIR/${BASE}_evt.dat" \
    > "convert_${BASE}.nohup.log" 2>&1

  echo "DONE $BASE"
done
