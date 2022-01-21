%import textio
%zeropage basicsafe
%option no_sysinit

main {
    sub start() {
        txt.lowercase()
        txt.color2(1, 6)
        txt.clear_screen()
        cx16.mouse_config(1, 0)
        txt.print("Chess.")
        board.print_board()

        board.place_start_pieces()

        show_sprite()

;        repeat {
;            ubyte mb = mouse.mouse_pos()
;            txt.print_uw(cx16.r0)
;            txt.spc()
;            txt.print_uw(cx16.r1)
;            txt.spc()
;            txt.print_ub(mb)
;            txt.nl()
;        }
    }

    sub show_sprite() {
        ; experiment: show a single 32x32 16 color sprite
        ; https://www.8bitcoding.com/p/sprites-in-basic.html

        ; sprite registers base in VRAM:  $1fc00
        ;        Sprite 0:          $1FC00 - $1FC07     ; used by the kernal for mouse pointer
        ;        Sprite 1:          $1FC08 - $1FC0F
        ;        Sprite 2:          $1FC10 - $1FC17
        ;        …
        ;        Sprite 127:        $1FFF8 - $1FFFF

        cx16.VERA_DC_VIDEO |= %01000000     ; enable sprites globally
        cx16.vpoke(1, $fc08, $00)           ; sprite data ptr bits 5-12
        cx16.vpoke(1, $fc08+1, %00000010)   ; mode bit (16 colors) and sprite dataptr bits 13-16
        cx16.vpoke(1, $fc08+2, 20)          ; x lo
        cx16.vpoke(1, $fc08+3, 0)           ; x hi
        cx16.vpoke(1, $fc08+4, 100)         ; y lo
        cx16.vpoke(1, $fc08+5, 0)           ; y hi
        cx16.vpoke(1, $fc08+7, %10100000)       ; 32x32 pixels, palette offset 0
        cx16.vpoke(1, $fc08+6, cx16.vpeek(1, $fc08+6) | %00001100)    ; enable sprite, z depth %11 = before both layers

    }
}

mouse {
    asmsub mouse_pos() -> ubyte @A {
        ; -- short wrapper around mouse_get() kernal routine:
        ; -- gets the position of the mouse cursor in cx16.r0 and cx16.r1 (x/y coordinate), returns mouse button status.
        %asm {{
            phx
            ldx  #cx16.r0
            jsr  cx16.mouse_get
            plx
            rts
        }}
    }
}

board {
    const ubyte board_col = txt.DEFAULT_WIDTH / 2 - 20
    const ubyte board_row = 5
    const ubyte square_size = 5
    const ubyte white_square_color = 15
    const ubyte black_square_color = 12

    sub print_board() {
        ubyte col = board_col
        ubyte row = board_row
        ubyte line
        txt.color(9)
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

    ; K (king), Q (queen), R (rook), B (bishop), and N (knight). P (pawn), but often empty/space.
    str pieces = "KQRBNP"

    sub place_start_pieces() {
        ubyte col = 'a'
        ubyte piece
        for piece in "RNBQKBNR" {
            place_piece(0, piece, col, 8)
            place_piece(1, piece, col, 1)
            col++
        }
        repeat 8 {
            col--
            place_piece(0, 'P', col, 7)
            place_piece(1, 'P', col, 2)
        }
    }

    sub square_screen_col(ubyte col) -> ubyte {
        return (col-'a')*square_size + board_col
    }

    sub square_screen_row(ubyte row) -> ubyte {
        return (8-row as byte) as ubyte*square_size + board_row
    }

    sub erase_piece(ubyte col, ubyte row) {
        col = square_screen_col(col)+1
        row = square_screen_row(row)+1
        const ubyte piece_size = 3
        repeat piece_size {
            txt.plot(col, row)
            txt.print(" " * piece_size)
            row++
        }
    }

    sub place_piece(ubyte player, ubyte piece, ubyte col, ubyte row) {
        if (col+row) & 1
            txt.color2(player, white_square_color)
        else
            txt.color2(player, black_square_color)
        col = square_screen_col(col)+1
        row = square_screen_row(row)+1
        const ubyte piece_size = 3
        repeat piece_size {
            txt.plot(col, row)
            repeat piece_size {
                txt.chrout(piece)
            }
            row++
        }
    }
}