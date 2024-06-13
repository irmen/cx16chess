from cx16images import BitmapImage


def extract32x32(img: BitmapImage, outf, x, y, piece_name):
    piece = img.crop(x, y, 32, 32)
    outf.write(piece.get_all_pixels_4bpp())


if __name__ == "__main__":
    img = BitmapImage("pics/pieces-small.png")
    # K (king), Q (queen), R (rook), B (bishop), and N (knight). P (pawn), but often empty/space.
    pieces = "RBQKNP"

    with open("CHESSPIECES.BIN", "wb") as outf:
        # outf.write(bytes([0,0]))    # CBM prg header, no longer needed with vload_headerless
        # black pieces
        for pn, letter in enumerate(pieces):
            x = pn * 33 + 2
            y = 6
            extract32x32(img, outf, x, y, f'_black_{letter}')

        # white pieces
        for pn, letter in enumerate(pieces):
            x = pn * 33 + 2
            y = 47
            extract32x32(img, outf, x, y, f'_white_{letter}')

    with open("CHESSPIECES.PAL", "wb") as outf:
        outf.write(img.get_vera_palette())

    # the two crosshairs
    img = BitmapImage("pics/crosshairs.png")
    with open("CROSSHAIRS.BIN", "wb") as outf:
        extract32x32(img, outf, 0, 0, "_crosshair_from")
        extract32x32(img, outf, 32, 0, "_crosshair_to")
    with open("CROSSHAIRS.PAL", "wb") as outf:
        outf.write(img.get_vera_palette())

    # the title screen
    img = BitmapImage("pics/titlescreen.png")
    with open("TITLESCREEN.BIN", "wb") as outf:
        outf.write(img.get_all_pixels_8bpp())
    with open("TITLESCREEN.PAL", "wb") as outf:
        outf.write(img.get_vera_palette())

    # the title screen (hires version)
    img = BitmapImage("pics/titlescreen-hires.png")
    with open("TITLESCREEN640.BIN", "wb") as outf:
        outf.write(img.get_all_pixels_4bpp())
    with open("TITLESCREEN640.PAL", "wb") as outf:
        outf.write(img.get_vera_palette())
