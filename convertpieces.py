from PIL import Image


def convert_palette(palette):
    pal = []
    for ci in range(15):
        r = palette[ci * 3]
        g = palette[ci * 3 + 1]
        b = palette[ci * 3 + 2]
        pal.append((r, g, b))
    return pal


def extract(x, y, piece_name):
    piece = img.crop((x, y, x + 32, y + 32))
    print()
    print(piece_name)
    for y in range(32):
        print("\t.byte  ", end="")
        for xpair in range(16):
            pix1 = piece.getpixel((xpair * 2, y))
            pix2 = piece.getpixel((xpair * 2 + 1, y))
            assert 0 <= pix1 <= 15
            assert 0 <= pix2 <= 15
            pix = pix1 << 4 | pix2
            if pix:
                print(f"${pix:02x}", end=", " if xpair<15 else "")
            else:
                print("  0", end=", " if xpair<15 else "")
        print()
    print()
    # piece.save(f"piece-{piece_name}.png")


img = Image.open("pieces-small.png")

# K (king), Q (queen), R (rook), B (bishop), and N (knight). P (pawn), but often empty/space.
pieces = "RBQKNP"

# black pieces
for pn, letter in enumerate(pieces):
    x = pn * 33 + 2
    y = 6
    extract(x, y, f'black_{letter}')

# white pieces
for pn, letter in enumerate(pieces):
    x = pn * 33 + 2
    y = 47
    extract(x, y, f'white_{letter}')

print("palette")
for r, g, b in convert_palette(img.getpalette()):
    print(f"\t.byte  ${r:02x}, ${g:02x}, ${b:02x}")
