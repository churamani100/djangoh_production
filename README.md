# DJANGOH 9x275 Charged-Current DIS Production Inputs

## Release tag

`DJANGOH4.6.10-1.0`

The release name follows the EIC convention for an externally maintained
generator with locally maintained steering and preprocessing:

- DJANGOH generator version: 4.6.10
- Steering/preprocessing release: 1.0

The Git repository containing the steering files and preprocessing scripts
must use the matching release tag:

`DJANGOH4.6.10-1.0`

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

`e- + p -> neutrino + X`

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
   `ip6_hidiv_275x9`
6. Store the resulting events in:
   `hepmc3.tree.root`
7. Validate every file with npsim using the epic_craterlake detector geometry.

## Required filename format

`<release-tag>_<process>_<beam>_q2_<range>_run<index>.hepmc3.tree.root`

Example:

`DJANGOH4.6.10-1.0_DIS-CC-eMinus-pPlus_9x275_q2_100to1000_run001.hepmc3.tree.root`

## Directory organization

`DIS/CC/<polarization>/<release-tag>/9x275/q2_<range>/<filename>`

## Metadata

- `metadata/datasets.tsv`: event totals, cross sections, source paths and
  staged paths.
- `metadata/checksums.sha256`: SHA-256 checksums.
- `metadata/npsim_100event_validation.tsv`: 100-event npsim validation.
- `steering_files/9x275/`: DJANGOH steering cards.
- `scripts/`: transport cleaning, afterburner and validation scripts.

## Repository

Current working repository:

`https://github.com/churamani100/djangoh_production`

For formal campaign acceptance, the repository and matching release tag
should be transferred to or mirrored under an EIC, Jefferson Lab or BNL
GitHub organization.
