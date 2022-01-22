.PHONY:  all clean emu

all:  chess.prg

clean:
	rm -f *.prg *.asm *.vice-*

emu:  chess.prg
	# box16 -scale 2 -quality best -run -prg $<
	x16emu -scale 2 -quality best -run -prg $<

chess.prg: chess.p8 spritedata.asm
	p8compile $< -target cx16

spritedata.asm: pieces-small.png convertpieces.py
	python convertpieces.py > spritedata.asm
