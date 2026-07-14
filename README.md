# DJANGOH/HERACLES 4.6.10 CC DIS 9x275 Production

This repository tracks the steering files, conversion scripts, metadata, and documentation used to generate 9x275 GeV charged-current DIS samples for EIC simulation production.

Large generated files are **not** stored in this repository. The repository is for reproducibility: steering cards, scripts, metadata, cross sections, checksums, and workflow documentation.

## Dataset release tag

DJANGOH-HERACLES4.6.10-1.0

## Generator

Generator: DJANGOH/HERACLES  
Generator version: 4.6.10  
Beam energy: 9x275 GeV  
Process: charged-current DIS  
Reaction: e- p -> nu X

## Spin configurations

- eMinus-pPlus
- eMinus-pMinus

## Q2 bins

- q2_100to1000
- q2_1000to3000
- q2_3000to9000

The higher Q2 bin above 10000 GeV2 is not used for 9x275 because it exceeds the physical kinematic reach.

## Cross sections

The DJANGOH/HERACLES total cross sections for the 9x275 q2-binned samples are stored in:

metadata/9x275/cross_sections_9x275.tsv

| Beam | Process | Spin configuration | Q2 bin | Cross section [pb] |
|---|---|---|---|---:|
| 9x275 | DIS-CC | eMinus-pPlus | q2_100to1000 | 21.440 |
| 9x275 | DIS-CC | eMinus-pMinus | q2_100to1000 | 9.5747 |
| 9x275 | DIS-CC | eMinus-pPlus | q2_1000to3000 | 10.321 |
| 9x275 | DIS-CC | eMinus-pMinus | q2_1000to3000 | 3.0338 |
| 9x275 | DIS-CC | eMinus-pPlus | q2_3000to9000 | 1.2666 |
| 9x275 | DIS-CC | eMinus-pMinus | q2_3000to9000 | 0.30165 |

## Required production output format

Final production files are provided as:

hepmc3.tree.root

Required file naming convention:

<generator repository release tag>_<physics process>_<electron momentum>x<proton momentum>_q2_<minimum q2>to<maximum q2>_run<index>.hepmc3.tree.root

Example:

DJANGOH-HERACLES4.6.10-1.0_DIS-CC-eMinus-pPlus_9x275_q2_100to1000_run001.hepmc3.tree.root

## Production directory convention

DIS/CC/<spin configuration>/DJANGOH-HERACLES4.6.10-1.0/9x275/q2_<minimum q2>to<maximum q2>/

Example:

DIS/CC/eMinus_pPlus/DJANGOH-HERACLES4.6.10-1.0/9x275/q2_100to1000/

## Official preprocessing chain

The validated preprocessing chain is:

DJANGOH 4.6.10 _evt.dat
  -> EIC2020b eic-smear BuildTree
  -> EIC2021a TreeToHepMC(..., false)
  -> HepMC3 Asciiv3
  -> afterburner abconv -p ip6_hidiv_275x9
  -> hepmc3.tree.root

Critical command:

TreeToHepMC("input_evt.root", ".", -1, false);

The final false is required because it writes HepMC3 Asciiv3. The true option writes old HepMC2 and is not used for production.

## Validation

The workflow was first validated using a 4999-event test sample. The final afterburned ROOT output contained:

hepmc3_tree entries = 4999

For each final ROOT file, entries are checked with:

/opt/local/bin/root -l -b -q file.hepmc3.tree.root \
  -e 'TTree *t=(TTree*)_file0->Get("hepmc3_tree"); if(t) cout<<t->GetEntries()<<endl;'

## Metadata files

- metadata/9x275/production_manifest_9x275.tsv
- metadata/9x275/cross_sections_9x275.tsv
- metadata/9x275/sha256sum_9x275_final_root_files.txt

## Repository contents

- steering_cards/9x275/
- scripts/
- metadata/9x275/
- production_notes/

## Large files excluded from Git

The following generated files are not stored in this repository:

- _evt.dat
- .hepmc
- .root
- .hepmc3.tree.root

Final hepmc3.tree.root files should be stored on the appropriate production storage endpoint, such as JLab xrootd or S3.
