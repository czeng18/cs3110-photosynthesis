MODULES=board cell hexMap plant player raster store plantInventory playerId game authors ui gui hexUtil
OBJECTS=$(MODULES:=.cmo)
MLS=$(MODULES:=.ml)
MLIS=$(MODULES:=.mli)
TESTNAMES=test testGame testHexmap
TESTS=$(TESTNAMES:=.cmo)
MAINTEST=test.byte
MAIN=main.byte
OCAMLBUILD=ocamlbuild -use-ocamlfind

default: build
	OCAMLRUNPARAM=b utop

build:
	$(OCAMLBUILD) $(OBJECTS)

test:
	$(OCAMLBUILD) -tag 'debug' $(MAINTEST) && ./$(MAINTEST) -runner sequential

play:
	$(OCAMLBUILD) -tag 'debug' $(MAIN) && OCAMLRUNPARAM=b ./$(MAIN)

clean:
	ocamlbuild -clean
	rm -rf _doc.public _doc.private