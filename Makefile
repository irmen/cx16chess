.PHONY:  all clean emu

all:  chess.prg

clean:
	rm -f *.prg *.asm *.vice-*

emu:  chess.prg
	# box16 -scale 2 -run -prg $<
	x16emu -scale 2 -quality best -run -prg $<

chess.prg: src/chess.p8 CHESSPIECES.BIN CHESSPIECES.PAL
	p8compile $< -target cx16

CHESSPIECES.BIN CHESSPIECES.PAL: pics/pieces-small.png src/convertpieces.py
	python src/convertpieces.py
