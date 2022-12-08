%import textio
%import palette
%import cx16diskio
%import math
%zeropage basicsafe
%option no_sysinit

; references for tiny chess:
; https://github.com/maksimKorzh/6502-chess/blob/main/src/chess_tty_cc65.c ?
; https://home.hccnet.nl/h.g.muller/board.html
;    makes the move generation look easy with the move_offsets lists.


main {
    sub start() {
        palette.set_c64pepto()
        load_sprites()
        txt.color2(1, 6)
        txt.clear_screen()
        txt.lowercase()
        txt.print("\n\n  Chess.\n")
        board.print_board_bg()
        board.init()
        board.place_pieces_initial()

        cx16.mouse_config2(1)
        sprites.enable()

        demo_follow_mouse()
    }

    sub demo_follow_mouse() {
        repeat {
            sys.waitvsync()
            sys.waitvsync()
            demo_flash_crosshairs()
            ubyte buttons = cx16.mouse_pos()
            if buttons {
                ubyte ci = board.cell_for_screen(cx16.r0s, cx16.r1s)
                if ci & $88 == 0 {
                    sprites.move(sprites.sprite_num_crosshair1, sprites.sx_for_cell(ci), sprites.sy_for_cell(ci))

                    txt.plot(10,10)
                    txt.print(board.notation_for_cell(ci))
                }
            }
        }
    }

    sub demo_flash_crosshairs() {
        ; rotate the 16 colors in the crosshair palette
        uword palette_src = $fa00 + sprites.palette_offset_color_crosshair*2
        uword palette_dest = palette_src
        palette_src += 2
        ubyte first_lo = cx16.vpeek(1, palette_dest)
        ubyte first_hi = cx16.vpeek(1, palette_dest+1)
        repeat 15 {
            cx16.r2L = cx16.vpeek(1, palette_src)
            cx16.vpoke(1, palette_dest, cx16.r2L)
            palette_src++
            palette_dest++
            cx16.r2L = cx16.vpeek(1, palette_src)
            cx16.vpoke(1, palette_dest, cx16.r2L)
            palette_src++
            palette_dest++
        }
        cx16.vpoke(1, palette_dest, first_lo)
        cx16.vpoke(1, palette_dest+1, first_hi)
    }

    sub load_sprites() {
        txt.print("loading...")
        if not cx16diskio.vload_raw("chesspieces.bin", 8, 0, $4000)
           or not cx16diskio.vload_raw("chesspieces.pal", 8, 1, $fa00 + sprites.palette_offset_color*2) {
            txt.print("load error\n")
            sys.exit(1)
        }

        if not cx16diskio.vload_raw("crosshairs.bin", 8, 0, $4000 + 12*32*32/2)
           or not cx16diskio.vload_raw("crosshairs.pal", 8, 1, $fa00 + sprites.palette_offset_color_crosshair*2) {
            txt.print("load error\n")
            sys.exit(1)
        }
    }
}


board {
    %option align_page
    ubyte[128] cells = [
        'R', 'N', 'B', 'Q', 'K', 'B', 'N', 'R',    0,0,0,0,0,0,0,0,     ; black pieces
        'P', 'P', 'P', 'P', 'P', 'P', 'P', 'P',    0,0,0,0,0,0,0,0,     ; black pawns
          0,   0,   0,   0,   0,   0,   0,   0,    0,0,0,0,0,0,0,0,
          0,   0,   0,   0,   0,   0,   0,   0,    0,0,0,0,0,0,0,0,
          0,   0,   0,   0,   0,   0,   0,   0,    0,0,0,0,0,0,0,0,
          0,   0,   0,   0,   0,   0,   0,   0,    0,0,0,0,0,0,0,0,
        'p', 'p', 'p', 'p', 'p', 'p', 'p', 'p',    0,0,0,0,0,0,0,0,     ; white pawns
        'r', 'n', 'b', 'q', 'k', 'b', 'n', 'r',    0,0,0,0,0,0,0,0      ; white pieces
    ]

    ; the board is set up as an array with special 'octal' position encoding:
    ; 00 01 02 03 04 05 06 07       08 09 0a 0b 0c 0d 0e 0f
    ; 10 11 12 13 14 15 16 17       18 19 1a 1b 1c 1d 1e 1f
    ;   ...
    ; 60 61 62 63 64 65 66 67       68 69 6a 6b 6c 6d 6e 6f
    ; 70 71 72 73 74 75 76 77       78 79 7a 7b 7c 7d 7e 7f
    ; only board positions where the nibbles are <=7 are valid
    ; moves that get you outside of the board have the 4th bit set in one or both nibbles
    ; so validity of moves can be easily checked by anding with $88

    const ubyte board_col = 20
    const ubyte board_row = 5
    const ubyte square_size = 5
    const ubyte white_square_color = 8   ; 15
    const ubyte black_square_color = 9   ; 12
    const ubyte board_border_color = 12
    const ubyte labels_color = 3

    sub init() {
        ; nothing yet
    }

    sub place_pieces_initial() {
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
        ubyte sprite_num = 1
        ubyte piece
        ubyte ci
        for ci in 0 to 127 {
            if ci & $88 == 0 {
                ; valid cell on the board
                if cells[ci] {
                    piece = sprites.image_for_piece(cells[ci])
                    sprites.init(sprite_num, piece, sprites.sx_for_cell(ci), sprites.sy_for_cell(ci))
                    sprite_num++
                }
            }
        }

        piece = sprites.image_for_piece('<')
        sprites.init(sprite_num, piece, sprites.sx_for_cell($43), sprites.sy_for_cell($45))
        sprites.set_palette_offset(sprite_num, sprites.palette_offset_color_crosshair)
        sprite_num++
        piece = sprites.image_for_piece('>')
        sprites.init(sprite_num, piece, sprites.sx_for_cell($45), sprites.sy_for_cell($45))
        sprites.set_palette_offset(sprite_num, sprites.palette_offset_color_crosshair)
        sprite_num++
    }

    sub print_board_bg() {
        ubyte col = board_col
        ubyte row = board_row
        ubyte line
        txt.color(board_border_color)
        for line in row to row+8*square_size-1 {
            txt.plot(col-1, line)
            txt.chrout($aa)  ; txt.chrout('▕')
            txt.plot(col+8*square_size, line)
            txt.chrout('▎')  ; txt.chrout('▏')
        }
        for line in col to col+8*square_size-1 {
            txt.plot(line, row-1)
            txt.chrout('▂')  ; txt.chrout('▁')
            txt.plot(line, row+8*square_size)
            txt.chrout($b7)  ; txt.chrout('▔')
        }
        txt.chrout('\x12')  ; reverse video on
        repeat 4 {
            repeat square_size {
                txt.plot(col, row)
                repeat 4 {
                    txt.color(white_square_color)
                    txt.print(" "*square_size)
                    txt.color(black_square_color)
                    txt.print(" "*square_size)
                }
                row++
            }
            repeat square_size {
                txt.plot(col, row)
                repeat 4 {
                    txt.color(black_square_color)
                    txt.print(" "*square_size)
                    txt.color(white_square_color)
                    txt.print(" "*square_size)
                }
                row++
            }
        }
        txt.chrout('\x92') ; reverse video off

        row += 1
        txt.color(labels_color)
        ubyte labelcol = col + 2
        ubyte label
        for label in 'A' to 'H' {
            txt.plot(labelcol, row)
            txt.chrout(label)
            labelcol += square_size
        }
        col -= 2
        row -= 3
        for label in '1' to '8' {
            txt.plot(col, row)
            txt.chrout(label)
            row -= square_size
        }
    }

    sub cell_for_screen(word sx, word sy) -> ubyte {
        sx -= board.board_col * 8
        sx /= 8*board.square_size
        sy -= board.board_row * 8
        sy /= 8*board.square_size
        return (sy << 4) | sx
    }

    sub notation_for_cell(ubyte ci) -> str {
        str notation = "??"
        notation[0] = 'a' + (ci & $0f)
        notation[1] = ('1'-8) + ((~ci & $f0) >>4)
        return notation
    }

;    sub square_screen_col(ubyte col) -> ubyte {
;        return (col-'a')*square_size + board_col
;    }

;    sub square_screen_row(ubyte row) -> ubyte {
;        return (8-row as byte) as ubyte*square_size + board_row
;    }
}

sprites {
    const ubyte sprite_num_crosshair1 = 33
    const ubyte sprite_num_crosshair2 = 34
    const ubyte palette_offset_color = 32
    const ubyte palette_offset_color_crosshair = palette_offset_color + 16

    const uword sprite_data_base = $04000 >> 5      ; pre-shifted for vera
    const uword VERA_SPRITEREGS = $fc00

    sub enable() {
        cx16.VERA_DC_VIDEO |= %01000000             ; enable sprites globally
    }

    ; sprite 0 = the mouse pointer
    word[35] sprites_x
    word[35] sprites_y

    sub init(ubyte sprite_num, ubyte bitmap_idx, word x, word y) {
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
