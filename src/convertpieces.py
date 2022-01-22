from PIL import Image
from PIL import ImageDraw


def convert_palette(palette):
    pal = []
    for ci in range(16):
        r = palette[ci * 3] >> 4
        g = palette[ci * 3 + 1] >> 4
        b = palette[ci * 3 + 2] >> 4
        pal.append((r, g, b))
    return pal


def extract(outf, x, y, piece_name):
    piece = img.crop((x, y, x + 32, y + 32))
    # draw = ImageDraw.Draw(piece)
    # draw.line((0,0,31,0,31,31,0,31,0,0), 15)
    for y in range(32):
        for xpair in range(16):
            pix1 = piece.getpixel((xpair * 2, y))
            pix2 = piece.getpixel((xpair * 2 + 1, y))
            assert 0 <= pix1 <= 15
            assert 0 <= pix2 <= 15
            pix = pix1 << 4 | pix2
            outf.write(bytes([pix]))
    # piece.save(f"piece-{piece_name}.png")


if __name__ == "__main__":
    img = Image.open("pics/pieces-small.png")
    # K (king), Q (queen), R (rook), B (bishop), and N (knight). P (pawn), but often empty/space.
    pieces = "RBQKNP"

    with open("CHESSPIECES.BIN", "wb") as outf:
        outf.write(bytes([0,0]))    # CBM prg header
        # black pieces
        for pn, letter in enumerate(pieces):
            x = pn * 33 + 2
            y = 6
            extract(outf, x, y, f'_black_{letter}')

        # white pieces
        for pn, letter in enumerate(pieces):
            x = pn * 33 + 2
            y = 47
            extract(outf, x, y, f'_white_{letter}')

    with open("CHESSPIECES.PAL", "wb") as outf:
        outf.write(bytes([0,0]))    # CBM prg header
        for r, g, b in convert_palette(img.getpalette()):
            # note: have to convert to different order when writing as binary file!
            # rgb = (r << 8) | (g << 4) | b
            # print(f"\t.word  ${rgb:04x}")
            outf.write(bytes([g<<4 | b, r]))
