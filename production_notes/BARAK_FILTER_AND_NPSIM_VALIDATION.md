# Barak Filtering and npsim Validation

Release: `DJANGOH4.6.10-2.0`

The six 9x275 Q2-binned DJANGOH charged-current DIS samples were regenerated
using the supplied Barak HepMC filtering code.

Processing sequence:

1. Original pre-afterburner HepMC3 ASCII input.
2. Barak final-state filtering.
3. EIC afterburner profile `ip6_hidiv_275x9`.
4. Output in `hepmc3.tree.root` format.
5. Event-count and ROOT-entry validation.
6. 100-event npsim validation for every file.

All six files passed the filtering, ROOT-entry and npsim checks.

No 1k, 5k or 18x275 datasets are included.
