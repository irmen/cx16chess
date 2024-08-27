%import board
%import sprites

pieces {
    const ubyte sprite_num_crosshair1 = 33
    const ubyte sprite_num_crosshair2 = 34
    const ubyte sprite_palette_offset = 2
    const ubyte sprite_palette_offset_crosshair = sprite_palette_offset + 1

    const uword sprite_data_base = $4000
    ubyte[35] sprites_cell

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
        sprites_cell[0] = $ff
        ubyte sprite_num = 1
        ubyte piece
        uword sprite_data_ptr
        ubyte ci
        for ci in 0 to 127 {
            if ci & $88 == 0 {              ; valid cell on the board?
                piece = board.cells[ci]
                if piece!=0 {
                    sprite_data_ptr = sprite_data_base + (image_for_piece(piece)*$0200)
                    sprites.init(sprite_num, 0, sprite_data_ptr, sprites.SIZE_32, sprites.SIZE_32, sprites.COLORS_16, sprite_palette_offset)
                    sprites.pos(sprite_num, sx_for_cell(ci), sy_for_cell(ci))
                    sprites_cell[sprite_num] = ci
                    sprite_num++
                }
            }
        }

        sprite_data_ptr = sprite_data_base + (image_for_piece('<')*$0200)
        sprites.init(sprite_num_crosshair1, 0, sprite_data_ptr, sprites.SIZE_32, sprites.SIZE_32, sprites.COLORS_16, sprite_palette_offset_crosshair)
        sprite_data_ptr = sprite_data_base + (image_for_piece('>')*$0200)
        sprites.init(sprite_num_crosshair2, 0, sprite_data_ptr, sprites.SIZE_32, sprites.SIZE_32, sprites.COLORS_16, sprite_palette_offset_crosshair)
        set_invalid_crosshair2()
        sprites.hide(sprite_num_crosshair1)
        sprites.hide(sprite_num_crosshair2)
    }
    
    sub move_between_cells(ubyte from_cell, ubyte to_cell) {
        ubyte sprite_num = sprite_in_cell(from_cell)
        move_to(sprite_num, sx_for_cell(to_cell), sy_for_cell(to_cell), 32)
        sprites_cell[sprite_num] = to_cell
    }

    sub move_to(ubyte sprite_num, word dest_x, word dest_y, ubyte speed) {
        ; to move more precisely, first scale the coordinates by a factor of four.
        cx16.r10s = sprites.getx(sprite_num) * 4
        cx16.r11s = sprites.gety(sprite_num) * 4
        word dx = (dest_x*4 - cx16.r10s) / speed
        word dy = (dest_y*4 - cx16.r11s) / speed
        repeat speed {
            cx16.r10s += dx
            cx16.r11s += dy
            sys.waitvsync()
            sprites.pos(sprite_num, cx16.r10s/4, cx16.r11s/4)
        }
        sprites.pos(sprite_num, dest_x, dest_y)
    }

    sub set_invalid_crosshair2() {
        sprites.data(sprite_num_crosshair2, 0, sprite_data_base + image_for_piece('>')*$0200)
    }

    sub set_valid_crosshair2() {
        sprites.data(sprite_num_crosshair2, 0, sprite_data_base + image_for_piece('<')*$0200)
    }

    sub hide_all() {
        ubyte sprite_num
        for sprite_num in 1 to 34 {
            sprites.hide(sprite_num)
        }
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

    sub sprite_in_cell(ubyte ci) -> ubyte {
        for cx16.r0L in 0 to len(sprites_cell)-1 {
            if sprites_cell[cx16.r0L]==ci
                return cx16.r0L
        }
        return 0
    }

}
