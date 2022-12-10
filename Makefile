.PHONY:  all clean emu

all:  chess.prg

clean:
	rm -f *.prg *.asm *.vice-*

emu:  chess.prg
	# box16 -scale 2 -run -prg $<
	PULSE_LATENCY_MSEC=20 x16emu -scale 2 -quality best -run -prg $<

chess.prg: src/chess.p8 src/board.p8 src/sprites.p8 CHESSPIECES.BIN CHESSPIECES.PAL CROSSHAIRS.BIN CROSSHAIRS.PAL
	p8compile $< -target cx16

CHESSPIECES.BIN CHESSPIECES.PAL CROSSHAIRS.BIN CROSSHAIRS.PAL: pics/pieces-small.png pics/crosshairs.png src/convertpieces.py
	python src/convertpieces.py
