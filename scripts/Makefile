.DELETE_ON_ERROR:

ROOTCONFIG  := root-config
ROOTCFLAGS  := $(shell $(ROOTCONFIG) --cflags)
ROOTLDFLAGS := $(shell $(ROOTCONFIG) --ldflags)
ROOTGLIBS   := $(shell $(ROOTCONFIG) --glibs)

HEPMCCFLAGS := $(shell HepMC3-config --cflags)
HEPMCLIBS   := $(shell HepMC3-config --libs) -lHepMC3rootIO

CXX         := g++
CXXFLAGS    := $(ROOTCFLAGS) $(HEPMCCFLAGS)

LD          := g++
LDFLAGS     := -O2 $(ROOTLDFLAGS)

LIBS        := $(ROOTGLIBS) $(HEPMCLIBS)
SRC_FILES   := $(wildcard *.cxx)
EXE_FILES   := $(SRC_FILES:%.cxx=%)

.PHONY: all clean

all: $(EXE_FILES)

%: %.o
	$(LD) $(LDFLAGS) $^ $(LIBS) -o $@

%.o: %.cxx
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -f $(EXE_FILES:%=%.o) $(EXE_FILES)
