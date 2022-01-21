.PHONY:  all clean emu

all:  chess.prg

clean:
	rm -f *.prg *.asm *.vice-*

emu:  chess.prg
	box16 -sdcard ~/cx16sdcard.img -scale 2 -quality best -run -prg $<

chess.prg: chess.p8
	p8compile $< -target cx16
