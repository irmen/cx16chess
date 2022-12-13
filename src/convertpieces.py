from PIL import Image
from PIL import ImageDraw


def convert_palette(palette, num_colors):
    pal = []
    for ci in range(num_colors):
        r = palette[ci * 3] >> 4
        g = palette[ci * 3 + 1] >> 4
        b = palette[ci * 3 + 2] >> 4
        pal.append((r, g, b))
    return pal


def extract32x32(img, outf, x, y, piece_name):
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


def extract_titlescreen_lores256(img, outf):
    outf.write(img.tobytes())


def extract_titlescreen_hires16(img, outf):
    for y in range(400):
        for xpair in range(640//2):
            pix1 = img.getpixel((xpair * 2, y))
            pix2 = img.getpixel((xpair * 2 + 1, y))
            assert 0 <= pix1 <= 15
            assert 0 <= pix2 <= 15
            pix = pix1 << 4 | pix2
            outf.write(bytes([pix]))


if __name__ == "__main__":
    img = Image.open("pics/pieces-small.png")
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
        # outf.write(bytes([0,0]))    # CBM prg header, no longer needed with vload_headerless
        for r, g, b in convert_palette(img.getpalette(), 16):
            # note: have to convert to different order when writing as binary file!
            # rgb = (r << 8) | (g << 4) | b
            # print(f"\t.word  ${rgb:04x}")
            outf.write(bytes([g<<4 | b, r]))

    # the two crosshairs
    img = Image.open("pics/crosshairs.png")
    with open("CROSSHAIRS.BIN", "wb") as outf:
        extract32x32(img, outf, 0, 0, "_crosshair_from")
        extract32x32(img, outf, 32, 0, "_crosshair_to")
    with open("CROSSHAIRS.PAL", "wb") as outf:
        for r, g, b in convert_palette(img.getpalette(), 16):
            # note: have to convert to different order when writing as binary file!
            # rgb = (r << 8) | (g << 4) | b
            # print(f"\t.word  ${rgb:04x}")
            outf.write(bytes([g<<4 | b, r]))

    # the title screen
    img = Image.open("pics/titlescreen.png")
    with open("TITLESCREEN.BIN", "wb") as outf:
        extract_titlescreen_lores256(img, outf)
    with open("TITLESCREEN.PAL", "wb") as outf:
        palette = img.getpalette()
        for r, g, b in convert_palette(palette, len(palette)//3):
            # note: have to convert to different order when writing as binary file!
            # rgb = (r << 8) | (g << 4) | b
            # print(f"\t.word  ${rgb:04x}")
            outf.write(bytes([g<<4 | b, r]))

    # the title screen (hires version)
    img = Image.open("pics/titlescreen-hires.png")
    with open("TITLESCREEN640.BIN", "wb") as outf:
        extract_titlescreen_hires16(img, outf)
    with open("TITLESCREEN640.PAL", "wb") as outf:
        palette = img.getpalette()
        for r, g, b in convert_palette(palette, len(palette)//3):
            # note: have to convert to different order when writing as binary file!
            # rgb = (r << 8) | (g << 4) | b
            # print(f"\t.word  ${rgb:04x}")
            outf.write(bytes([g<<4 | b, r]))

