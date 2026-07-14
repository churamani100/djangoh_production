#!/usr/bin/env bash
set -euo pipefail

IN_EVT=$(readlink -f "$1")
PROFILE=ip6_hidiv_275x9

BASE=$(basename "$IN_EVT")
BASE=${BASE%_evt.dat}

WORKDIR=$(pwd)
LOGDIR=$WORKDIR/logs_official_conversion
mkdir -p "$LOGDIR" compat_sl7_libs compat_ab_libs

echo "Input   = $IN_EVT"
echo "Base    = $BASE"
echo "Workdir = $WORKDIR"

# ---------- compat libs for EIC2020b/EIC2021a ----------
ln -sf /cvmfs/eic.opensciencegrid.org/singularity/rhic_sl7_ext/usr/lib64/libssl.so.10 compat_sl7_libs/
ln -sf /cvmfs/eic.opensciencegrid.org/singularity/rhic_sl7_ext/usr/lib64/libcrypto.so.10 compat_sl7_libs/
ln -sf /cvmfs/eic.opensciencegrid.org/singularity/rhic_sl7_ext/usr/lib64/libgfortran.so.3 compat_sl7_libs/
ln -sf /cvmfs/eic.opensciencegrid.org/singularity/rhic_sl7_ext/usr/lib64/libtinfo.so.5.9 compat_sl7_libs/libtinfo.so.5
ln -sf /cvmfs/eic.opensciencegrid.org/singularity/rhic_sl7_ext/usr/lib64/libtinfo.so.5.9 compat_sl7_libs/libtinfo.so.5.9
ln -sf /cvmfs/eic.opensciencegrid.org/x8664_sl7/opt/fun4all/utils/stow/pcre-8.42/lib/libpcre.so.1 compat_sl7_libs/
ln -sf /cvmfs/eic.opensciencegrid.org/x8664_sl7/MCEG/releases/env/EIC2020b/gcc-8.3/lib/libLHAPDF.so.0 compat_sl7_libs/

# ---------- compat lib for afterburner ----------
ln -sf /cvmfs/eic.opensciencegrid.org/singularity/.images/14/b16e5ab7b09de714c983dfa87ec7c00f26bbcdbb14bf0c3b7da327698ad0d8/opt/software/linux-x86_64_v2/clhep-2.4.7.1-6nwjzhvkst5jc5kaedrf5p5zgs4rywy5/lib/libCLHEP-2.4.7.1.so compat_ab_libs/libCLHEP-2.4.7.1.so

# ---------- 1. BuildTree with EIC2020b ----------
MCEG20=/cvmfs/eic.opensciencegrid.org/x8664_sl7/MCEG/releases/env/EIC2020b

export EICDIRECTORY=$MCEG20
export PATH=$MCEG20/bin:$MCEG20/root6/bin:$PATH
export LD_LIBRARY_PATH=$WORKDIR/compat_sl7_libs:$MCEG20/lib:$MCEG20/lib64:$MCEG20/root6/lib:$MCEG20/root6/lib64:$MCEG20/gcc-8.3/lib:$MCEG20/lib/LHAPDF5:/opt/local/lib

echo "Checking EIC2020b missing libs:"
ldd $MCEG20/bin/eic-smear | grep "not found" || true

ln -sf "$IN_EVT" ${BASE}_evt.dat

rm -f ${BASE}_evt.root

echo "[1/3] BuildTree"
echo "BuildTree(\"${BASE}_evt.dat\")" | $MCEG20/bin/eic-smear \
  > $LOGDIR/${BASE}_01_BuildTree.log 2>&1

test -f ${BASE}_evt.root

$MCEG20/root6/bin/root -l -b -q ${BASE}_evt.root \
  -e 'TTree *t=(TTree*)_file0->Get("EICTree"); if(t) cout<<"EICTree entries = "<<t->GetEntries()<<endl; else _file0->ls();' \
  > $LOGDIR/${BASE}_01b_EICTree_check.log 2>&1

cat $LOGDIR/${BASE}_01b_EICTree_check.log

# ---------- 2. TreeToHepMC with EIC2021a ----------
MCEG21=/cvmfs/eic.opensciencegrid.org/x8664_sl7/MCEG/releases/env/EIC2021a

export EICDIRECTORY=$MCEG21
export PATH=$MCEG21/bin:$MCEG21/root6/bin:$PATH
export LD_LIBRARY_PATH=$WORKDIR/compat_sl7_libs:$MCEG21/lib:$MCEG21/lib64:$MCEG21/root6/lib:$MCEG21/root6/lib64:$MCEG21/gcc-8.3/lib:$MCEG21/lib/LHAPDF5:/opt/local/lib

cat > run_TreeToHepMC_${BASE}.C <<EOF
#include <string>
#include <iostream>
#include "Rtypes.h"
#include "TSystem.h"

extern Long64_t TreeToHepMC(const std::string&, const std::string&, Long64_t, bool);

void run_TreeToHepMC_${BASE}()
{
  gSystem->Load("libeicsmear");
  gSystem->Load("libeicsmeardetectors");
  Long64_t n = TreeToHepMC("${BASE}_evt.root", ".", -1, false);
  std::cout << "TreeToHepMC returned = " << n << std::endl;
}
EOF

rm -f ${BASE}_evt.hepmc

echo "[2/3] TreeToHepMC HepMC3"
$MCEG21/root6/bin/root -l -b -q run_TreeToHepMC_${BASE}.C \
  > $LOGDIR/${BASE}_02_TreeToHepMC.log 2>&1

test -f ${BASE}_evt.hepmc

echo "HepMC events:"
grep -c '^E ' ${BASE}_evt.hepmc | tee $LOGDIR/${BASE}_02b_HepMC_count.log

# ---------- 3. afterburner ----------
AB=/w/hallb-scshelf2102/clas12/cpaudel/EIC/afterburner/install/bin/abconv

echo "[3/3] abconv"
LD_LIBRARY_PATH=$WORKDIR/compat_ab_libs:/opt/local/lib \
$AB -p $PROFILE ${BASE}_evt.hepmc -o ${BASE}.eicsmear.ab \
  > $LOGDIR/${BASE}_03_abconv.log 2>&1

test -f ${BASE}.eicsmear.ab.hepmc3.tree.root

LD_LIBRARY_PATH=/opt/local/lib:$WORKDIR/compat_ab_libs \
/opt/local/bin/root -l -b -q ${BASE}.eicsmear.ab.hepmc3.tree.root \
  -e 'TTree *t=(TTree*)_file0->Get("hepmc3_tree"); if(t) cout<<"hepmc3_tree entries = "<<t->GetEntries()<<endl; else _file0->ls();' \
  > $LOGDIR/${BASE}_03b_final_tree_check.log 2>&1

cat $LOGDIR/${BASE}_03b_final_tree_check.log

echo "DONE $BASE"
