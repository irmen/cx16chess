%import board

sprites {
    const ubyte sprite_num_crosshair1 = 33
    const ubyte sprite_num_crosshair2 = 34
    const ubyte palette_offset_color = 32
    const ubyte palette_offset_color_crosshair = palette_offset_color + 16

    const uword sprite_data_base = $04000 >> 5      ; pre-shifted for vera
    const uword VERA_SPRITEREGS = $fc00

    ; sprite 0 = the mouse pointer
    word[35] sprites_x
    word[35] sprites_y

    sub init() {
        ; Scan the cells and place a sprite for the cell containing a piece
        ; this will result in 32 sprites being used for all initial pieces (16 black, 16 white).
        ;  Sprite 0 = system mouse pointer.
        ;    First 8 sprites (1-8) = black pieces  RNBQKBNR
        ;  Second 8 sprites (9-16) = black pawns   PPPPPPPP
        ;  Third 8 sprites (17-24) = white pawns   pppppppp
        ; Fourth 8 sprites (25-32) = white pieces  rnbqkbnr
        ;  Last 2 sprites (33, 34) = crosshair 1, crosshair 2
        ; the crosshairs will fall behind the pieces.
        ; note that they have their own palette after the 16 colors of the pieces.
        cx16.VERA_DC_VIDEO |= %01000000             ; enable sprites globally
        ubyte sprite_num = 1
        ubyte piece
        ubyte ci
        for ci in 0 to 127 {
            if ci & $88 == 0 {              ; valid cell on the board?
                piece = board.cells[ci]
                if piece {
                    if piece & 128
                        init_sprite(sprite_num, image_for_piece(piece), 100, (sprite_num & 15) * 16 + (60 as word))
                    else
                        init_sprite(sprite_num, image_for_piece(piece), 500, (sprite_num & 15) * 16 + (60 as word))
                    sprite_num++
                }
            }
        }
        sys.wait(30)
        sprite_num = 1
        for ci in 0 to 127 {
            if ci & $88 == 0 {              ; valid cell on the board?
                piece = board.cells[ci]
                if piece {
                    move_to(sprite_num, sx_for_cell(ci), sy_for_cell(ci), 8)
                    sprite_num++
                }
            }
        }

        piece = image_for_piece('<')
        init_sprite(sprite_num, piece, sx_for_cell($43), sy_for_cell($45))
        set_palette_offset(sprite_num, palette_offset_color_crosshair)
        sprite_num++
        piece = image_for_piece('>')
        init_sprite(sprite_num, piece, sx_for_cell($45), sy_for_cell($45))
        set_palette_offset(sprite_num, palette_offset_color_crosshair)
        sprite_num++
    }
    
    sub init_sprite(ubyte sprite_num, ubyte bitmap_idx, word x, word y) {
        ; initialize a single 32x32 16 color sprite
        ; https://www.8bitcoding.com/p/sprites-in-basic.html

        ; sprite registers base in VRAM:  $1fc00
        ;        Sprite 0:          $1FC00 - $1FC07     ; used by the kernal for mouse pointer
        ;        Sprite 1:          $1FC08 - $1FC0F
        ;        Sprite 2:          $1FC10 - $1FC17
        ;        …
        ;        Sprite 127:        $1FFF8 - $1FFFF
        uword sprite_data_ptr = sprite_data_base + (bitmap_idx*$0010)
        uword sprite_regs = VERA_SPRITEREGS+sprite_num*$0008
        cx16.vpoke(1, sprite_regs, lsb(sprite_data_ptr))              ; sprite data ptr bits 5-12
        cx16.vpoke(1, sprite_regs+1, msb(sprite_data_ptr))            ; mode bit (16 colors) and sprite dataptr bits 13-16
        cx16.vpoke(1, sprite_regs+7, %10100000 | palette_offset_color>>4)   ; 32x32 pixels, palette offset
        move(sprite_num, x, y)
        cx16.vpoke(1, sprite_regs+6, cx16.vpeek(1, sprite_regs+6) | %00001100)    ; enable sprite, z depth %11 = before both layers
    }

    sub set_palette_offset(ubyte sprite_num, ubyte offset) {
        cx16.vpoke(1, VERA_SPRITEREGS+sprite_num*$0008+7, %10100000 | offset>>4)   ; 32x32 pixels, palette offset
    }

    sub move(ubyte sprite_num, word x, word y) {
        sprites_x[sprite_num] = x
        sprites_y[sprite_num] = y
        uword sprite_pos_regs = VERA_SPRITEREGS+sprite_num*$0008 + 2
        cx16.vpoke(1, sprite_pos_regs, lsb(x))
        cx16.vpoke(1, sprite_pos_regs+1, msb(x))
        cx16.vpoke(1, sprite_pos_regs+2, lsb(y))
        cx16.vpoke(1, sprite_pos_regs+3, msb(y))
    }

    sub move_to(ubyte sprite_num, word dest_x, word dest_y, ubyte speed) {
        cx16.r10s = sprites_x[sprite_num]
        cx16.r11s = sprites_y[sprite_num]
        word dx = (dest_x - cx16.r10s) / speed
        word dy = (dest_y - cx16.r11s) / speed
        repeat speed {
            cx16.r10s += dx
            cx16.r11s += dy
            move(sprite_num, cx16.r10s, cx16.r11s)
            sys.waitvsync()
        }
        move(sprite_num, dest_x, dest_y)
    }

    ; sprite images in the bitmap are in this order:
    ;   0 = R (black rook)
    ;   1 = B (black bishop)
    ;   2 = Q (black queen)
    ;   3 = K (black king)
    ;   4 = N (black knight)
    ;   5 = P (black pawn)
    ;   6-11 are the same pieces, but for the white player ('rbqknp' lowercase)
    ; K (king), Q (queen), R (rook), B (bishop), and N (knight). P (pawn)
    ;   Then we have '<' and '>' in their own bitmap + palette that are the crosshairs.

    sub image_for_piece(ubyte piece) -> ubyte {
        when piece {
            'R' -> return 0
            'B' -> return 1
            'Q' -> return 2
            'K' -> return 3
            'N' -> return 4
            'P' -> return 5
            'r' -> return 6
            'b' -> return 7
            'q' -> return 8
            'k' -> return 9
            'n' -> return 10
            'p' -> return 11
            '<' -> return 12
            '>' -> return 13
            else -> return 255
        }
    }

    sub sx_for_cell(ubyte ci) -> word {
        return (ci & $0f as word) * board.square_size * 8 + board.board_col * 8 + 4
    }

    sub sy_for_cell(ubyte ci) -> word {
        return ((ci & $f0)>>1 as word) * board.square_size + board.board_row *8 + 4
    }

}
