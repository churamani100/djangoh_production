# Transport-Level Preprocessing and npsim Validation

## Release

`DJANGOH4.6.10-1.0`

## Reason for this update

The original DJANGOH to eic-smear to TreeToHepMC to afterburner files
contained the full generator-history record. Local detector-simulation tests
with npsim 1.6.1 crashed on events containing non-transport generator
objects, including partons, W bosons, diquarks and LUND string records.

The original full-history outputs remain unchanged.

The production-candidate files in this release use an additional
transport-level preprocessing step.

## Transport preprocessing

For every event, the preprocessing retains:

- the incoming status-4 electron;
- the incoming status-4 proton;
- status-1 final-state detector particles.

It removes:

- quarks and gluons;
- W and other generator-level bosons;
- diquarks;
- LUND string records;
- intermediate generator-history records;
- final-state neutrinos from Geant4 detector transport.

The EIC afterburner was then applied again using:

`ip6_hidiv_275x9`

The resulting datasets were stored in:

`hepmc3.tree.root`

format.

## Production datasets

This release contains exactly six 9x275 charged-current DIS inputs:

- eMinus-pPlus, Q2 100 to 1000 GeV2
- eMinus-pPlus, Q2 1000 to 3000 GeV2
- eMinus-pPlus, Q2 3000 to 9000 GeV2
- eMinus-pMinus, Q2 100 to 1000 GeV2
- eMinus-pMinus, Q2 1000 to 3000 GeV2
- eMinus-pMinus, Q2 3000 to 9000 GeV2

No 1k, 5k or 18x275 datasets are included.

## Validation

For all six files:

- source HepMC counts matched cleaned HepMC counts;
- cleaned HepMC counts matched hepmc3 tree entries;
- 10-event npsim validation passed;
- 100-event npsim validation passed.

Validation records are stored under:

`metadata/9x275/`
