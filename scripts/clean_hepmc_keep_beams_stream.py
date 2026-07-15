#!/usr/bin/env python3

from pathlib import Path
import sys


BAD_ABS_PDGS = {
    1, 2, 3, 4, 5, 6, 21,
    23, 24, 25,
    91, 92,
    1101, 1103,
    2101, 2103,
    2203,
    3101, 3103,
    3201, 3203,
    3303,
}

# Neutrinos are physical final-state particles but do not need Geant4
# transport through the detector.
DROP_ABS_PDGS = {12, 14, 16}


def write_event(fout, event_lines, output_event_number):
    beams = []
    final_particles = []
    weight_line = "W 1.0000000000000000000000e+00"

    for line in event_lines:
        if line.startswith("W "):
            weight_line = line.rstrip()
            continue

        if not line.startswith("P "):
            continue

        fields = line.split()
        if len(fields) < 10:
            continue

        try:
            pdg = int(fields[3])
            status = int(fields[9])
        except ValueError:
            continue

        abs_pdg = abs(pdg)

        px = fields[4]
        py = fields[5]
        pz = fields[6]
        energy = fields[7]
        mass = fields[8]

        # Preserve incoming e- and proton beams for afterburner.
        if status == 4 and pdg in (11, 2212):
            beams.append((pdg, px, py, pz, energy, mass))
            continue

        # Remove partons, strings, bosons and diquarks.
        if abs_pdg in BAD_ABS_PDGS:
            continue

        # Do not transport neutrinos.
        if abs_pdg in DROP_ABS_PDGS:
            continue

        # Keep only final-state detector particles.
        if status == 1:
            final_particles.append(
                (pdg, px, py, pz, energy, mass)
            )

    total_particles = len(beams) + len(final_particles)

    fout.write(f"E {output_event_number} 1 {total_particles}\n")
    fout.write("U GEV CM\n")
    fout.write(weight_line + "\n")

    particle_id = 1
    beam_ids = []

    for pdg, px, py, pz, energy, mass in beams:
        fout.write(
            f"P {particle_id} 0 {pdg} "
            f"{px} {py} {pz} {energy} {mass} 4\n"
        )
        beam_ids.append(str(particle_id))
        particle_id += 1

    incoming = ",".join(beam_ids) if beam_ids else "0"

    fout.write(
        f"V -1 0 [{incoming}] @ "
        "0.0000000000000000e+00 "
        "0.0000000000000000e+00 "
        "0.0000000000000000e+00 "
        "0.0000000000000000e+00\n"
    )

    for pdg, px, py, pz, energy, mass in final_particles:
        fout.write(
            f"P {particle_id} -1 {pdg} "
            f"{px} {py} {pz} {energy} {mass} 1\n"
        )
        particle_id += 1

    return len(beams), len(final_particles)


def main():
    if len(sys.argv) != 3:
        print(
            f"Usage: {sys.argv[0]} input_evt.hepmc output_clean.hepmc",
            file=sys.stderr,
        )
        return 2

    input_path = Path(sys.argv[1]).resolve()
    output_path = Path(sys.argv[2]).resolve()

    if not input_path.is_file():
        print(f"ERROR: input not found: {input_path}", file=sys.stderr)
        return 1

    output_path.parent.mkdir(parents=True, exist_ok=True)

    events_written = 0
    beam_warning_events = 0
    zero_final_events = 0
    current_event = []

    with input_path.open("r", errors="replace") as fin, \
            output_path.open("w") as fout:

        fout.write("HepMC::Version 3.02.04\n")
        fout.write("HepMC::Asciiv3-START_EVENT_LISTING\n")
        fout.write("W default\n")
        fout.write(
            "T DJANGOH_transport_clean_keepbeams"
            "|1.0|npsim transport input\n"
        )

        for line in fin:
            if line.startswith("E "):
                if current_event:
                    events_written += 1
                    nbeams, nfinal = write_event(
                        fout,
                        current_event,
                        events_written,
                    )

                    if nbeams != 2:
                        beam_warning_events += 1
                    if nfinal == 0:
                        zero_final_events += 1

                    if events_written % 10000 == 0:
                        print(
                            f"Processed {events_written} events",
                            file=sys.stderr,
                            flush=True,
                        )

                current_event = [line]
                continue

            if line.startswith("HepMC::Asciiv3-END_EVENT_LISTING"):
                if current_event:
                    events_written += 1
                    nbeams, nfinal = write_event(
                        fout,
                        current_event,
                        events_written,
                    )

                    if nbeams != 2:
                        beam_warning_events += 1
                    if nfinal == 0:
                        zero_final_events += 1

                    current_event = []

                break

            if current_event:
                current_event.append(line)

        if current_event:
            events_written += 1
            nbeams, nfinal = write_event(
                fout,
                current_event,
                events_written,
            )

            if nbeams != 2:
                beam_warning_events += 1
            if nfinal == 0:
                zero_final_events += 1

        fout.write("HepMC::Asciiv3-END_EVENT_LISTING\n")

    print(f"INPUT={input_path}")
    print(f"OUTPUT={output_path}")
    print(f"EVENTS_WRITTEN={events_written}")
    print(f"BEAM_WARNING_EVENTS={beam_warning_events}")
    print(f"ZERO_FINAL_EVENTS={zero_final_events}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
