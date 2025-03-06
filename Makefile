.PHONY:  all clean run zip

PROG8C ?= prog8c       # if that fails, try this alternative (point to the correct jar file location): java -jar prog8c.jar
PYTHON ?= python
ZIP ?= zip


all:  CHESS.PRG

clean:
	rm -f *.prg *.PRG *.asm *.vice-* *.BIN *.PAL *.zip *.7z

run:  CHESS.PRG
	# box16 -scale 2 -run -prg $<
	PULSE_LATENCY_MSEC=20 x16emu -scale 2 -quality best -run -prg $<

CHESS.PRG: src/chess.p8 src/board.p8 src/pieces.p8 src/computerplayer.p8 src/chessclock.p8 CHESSPIECES.BIN CHESSPIECES.PAL CROSSHAIRS.BIN CROSSHAIRS.PAL TITLESCREEN.BIN TITLESCREEN.PAL TITLESCREEN640.BIN TITLESCREEN640.PAL
	$(PROG8C) $< -target cx16 
	mv chess.prg CHESS.PRG

CHESSPIECES.BIN CHESSPIECES.PAL CROSSHAIRS.BIN CROSSHAIRS.PAL TITLESCREEN.BIN TITLESCREEN.PAL TITLESCREEN640.BIN TITLESCREEN640.PAL: pics/pieces-small.png pics/crosshairs.png pics/titlescreen.png pics/titlescreen-hires.png src/convertpieces.py
	$(PYTHON) src/convertpieces.py

zip: all
	rm -f chessx16.zip
	$(ZIP) chessx16.zip CHESS.PRG CHESSPIECES* CROSSHAIRS* TITLESCREEN*
