#include "HepMC3/ReaderAscii.h"
#include "HepMC3/WriterAscii.h"
#include "HepMC3/GenEvent.h"
#include "HepMC3/GenVertex.h"
#include "HepMC3/GenParticle.h"
#include "HepMC3/Print.h"
#include <iostream>
#include <memory>

using namespace HepMC3;

int main(int argc, char** argv) {
    if (argc < 3) {
        std::cerr << "Usage: " << argv[0] << " input.hepmc output.hepmc\n";
        return 1;
    }

    ReaderAscii reader(argv[1]);
    WriterAscii writer(argv[2]);

    GenEvent evt;
    int evcount = 0;
    const int max_events = 1e2;
    while (!reader.failed() && evcount < max_events) {
        reader.read_event(evt);
        if (reader.failed()) break;

        GenEvent new_evt(evt.momentum_unit(), evt.length_unit());
        new_evt.set_event_number(evt.event_number());

        // Put all kept particles into a dummy vertex at origin
        auto vtx = std::make_shared<GenVertex>();
        vtx->set_position(FourVector(0,0,0,0));

    // Check to see if we have an unhadronized parton
    bool finalstate_parton = false;

        for (auto p : evt.particles()) {

        // If we use p->momentum() directly when building the new particles,
        // we sometimes get slightly negative masses due to rounding, which leads to some ddsim warnings.
        // The approach below uses the 3-momentum and the true mass to build the FourVector.
        auto px = p->momentum().px();
        auto py = p->momentum().py();
            auto pz = p->momentum().pz();
        auto ptot = p->momentum().p3mod();
        auto mass = (p->generated_mass() > 0.0) ? p->generated_mass() : 0.0;

        FourVector plmom( px, py, pz, std::hypot(ptot,mass) );

        bool is_beam_particle (p->status()==4);
        if(is_beam_particle){
        auto new_p = std::make_shared<GenParticle>(plmom, p->pid(), p->status());
        vtx->add_particle_in(new_p);
        }
            bool is_final_by_status = (p->status()==1);
            if (is_final_by_status) {
                auto new_p = std::make_shared<GenParticle>(plmom, p->pid(), p->status());
        vtx->add_particle_out(new_p);

        if (std::abs(p->pid()) == 1 || std::abs(p->pid()) == 2 || std::abs(p->pid()) == 3 ||
             std::abs(p->pid()) == 4 || std::abs(p->pid()) == 5 || std::abs(p->pid()) == 6 ||
             std::abs(p->pid()) == 21 ||
            std::abs(p->pid()) == 90 || std::abs(p->pid()) == 91 || std::abs(p->pid()) == 92 ||
             std::abs(p->pid()) == 1103 || std::abs(p->pid()) == 2101 || std::abs(p->pid()) == 2103 || // diquarks
             std::abs(p->pid()) == 2203 || std::abs(p->pid()) == 3101 || std::abs(p->pid()) == 3103 ||
             std::abs(p->pid()) == 3201 || std::abs(p->pid()) == 3203 || std::abs(p->pid()) == 3303 ||
             std::abs(p->pid()) == 4101 || std::abs(p->pid()) == 4103 || std::abs(p->pid()) == 4201 ||
             std::abs(p->pid()) == 4203 || std::abs(p->pid()) == 4301 || std::abs(p->pid()) == 4303 ||
             std::abs(p->pid()) == 4403 || std::abs(p->pid()) == 5101 || std::abs(p->pid()) == 5103 ||
             std::abs(p->pid()) == 5201 || std::abs(p->pid()) == 5203 || std::abs(p->pid()) == 5301 ||
             std::abs(p->pid()) == 5303 || std::abs(p->pid()) == 5401 || std::abs(p->pid()) == 5403 || std::abs(p->pid()) == 5403)
        {
            finalstate_parton = true;
            break;
        }
            }
        } // Loop over particles

    // Do not write out event with unhadronized parton
    if (finalstate_parton){
        std::cout<<"Skipped event "<< evt.event_number() <<" (unhadronized partons)\n";
        continue;
    }

        if (!vtx->particles_out().empty()) {
        new_evt.add_vertex(vtx);
            writer.write_event(new_evt);
            std::cout << "Wrote event " << new_evt.event_number()
                      << " with " << vtx->particles_out().size()
                      << " final particles\n";
        } else {
            std::cout << "Skipped event " << evt.event_number()
                      << " (no final particles)\n";
        }

    if (evcount == 0) {
              std::cout << "First event: " << std::endl;
            Print::listing(evt);
        std::cout << " " << std::endl;
        Print::listing(new_evt);
        }

        evt.clear();
        ++evcount;
    } // Loop over events

    reader.close();
    writer.close();
    std::cout << "Processed " << evcount << " events\n";
    return 0;
}
