#include "HepMC3/ReaderAscii.h"
#include "HepMC3/WriterAscii.h"
#include "HepMC3/GenEvent.h"
#include "HepMC3/GenVertex.h"
#include "HepMC3/GenParticle.h"

#include <cmath>
#include <cstdlib>
#include <iostream>
#include <memory>

using namespace HepMC3;

static bool is_unhadronized_parton_or_diquark(int pid) {
    const int a = std::abs(pid);

    return
        (a >= 1 && a <= 6) ||
        a == 21 ||
        a == 90 || a == 91 || a == 92 ||
        a == 1103 ||
        a == 2101 || a == 2103 ||
        a == 2203 ||
        a == 3101 || a == 3103 ||
        a == 3201 || a == 3203 ||
        a == 3303 ||
        a == 4101 || a == 4103 ||
        a == 4201 || a == 4203 ||
        a == 4301 || a == 4303 ||
        a == 4403 ||
        a == 5101 || a == 5103 ||
        a == 5201 || a == 5203 ||
        a == 5301 || a == 5303 ||
        a == 5401 || a == 5403;
}

int main(int argc, char** argv) {
    if (argc != 3) {
        std::cerr
            << "Usage: " << argv[0]
            << " input.hepmc output.hepmc\n";
        return 1;
    }

    ReaderAscii reader(argv[1]);
    WriterAscii writer(argv[2]);

    if (reader.failed()) {
        std::cerr << "ERROR: could not open input " << argv[1] << "\n";
        return 2;
    }

    GenEvent evt;

    long long input_events = 0;
    long long written_events = 0;
    long long skipped_parton_events = 0;
    long long skipped_empty_events = 0;

    while (!reader.failed()) {
        evt.clear();
        reader.read_event(evt);

        if (reader.failed()) {
            break;
        }

        ++input_events;

        GenEvent new_evt(evt.momentum_unit(), evt.length_unit());
        new_evt.set_event_number(evt.event_number());

        auto vtx = std::make_shared<GenVertex>();
        vtx->set_position(FourVector(0, 0, 0, 0));

        bool finalstate_parton = false;

        for (const auto& p : evt.particles()) {
            const double px = p->momentum().px();
            const double py = p->momentum().py();
            const double pz = p->momentum().pz();
            const double p3 = p->momentum().p3mod();
            const double mass =
                p->generated_mass() > 0.0 ?
                p->generated_mass() : 0.0;

            const FourVector momentum(
                px,
                py,
                pz,
                std::hypot(p3, mass)
            );

            if (p->status() == 4) {
                auto new_particle = std::make_shared<GenParticle>(
                    momentum,
                    p->pid(),
                    p->status()
                );

                vtx->add_particle_in(new_particle);
            }

            if (p->status() == 1) {
                auto new_particle = std::make_shared<GenParticle>(
                    momentum,
                    p->pid(),
                    p->status()
                );

                vtx->add_particle_out(new_particle);

                if (is_unhadronized_parton_or_diquark(p->pid())) {
                    finalstate_parton = true;
                    break;
                }
            }
        }

        if (finalstate_parton) {
            ++skipped_parton_events;
        } else if (vtx->particles_out().empty()) {
            ++skipped_empty_events;
        } else {
            new_evt.add_vertex(vtx);
            writer.write_event(new_evt);
            ++written_events;
        }

        if (input_events % 10000 == 0) {
            std::cout
                << "Processed " << input_events
                << " input events; wrote " << written_events
                << "; skipped parton " << skipped_parton_events
                << "; skipped empty " << skipped_empty_events
                << "\n";
        }
    }

    reader.close();
    writer.close();

    std::cout << "SUMMARY_INPUT_EVENTS=" << input_events << "\n";
    std::cout << "SUMMARY_WRITTEN_EVENTS=" << written_events << "\n";
    std::cout
        << "SUMMARY_SKIPPED_PARTON_EVENTS="
        << skipped_parton_events << "\n";
    std::cout
        << "SUMMARY_SKIPPED_EMPTY_EVENTS="
        << skipped_empty_events << "\n";

    return 0;
}
