%import textio
%import palette
%import cx16diskio
%zeropage basicsafe
%option no_sysinit

main {
    sub start() {
        txt.print("loading...")
        if not cx16diskio.vload("chesspieces.bin", 8, 0, $4000)
           or not cx16diskio.vload("chesspieces.pal", 8, 1, $fa00 + sprites.palette_offset*2) {
            txt.print("load error\n")
            sys.exit(1)
        }
        txt.color2(1, 6)
        txt.clear_screen()
        txt.lowercase()
        txt.print("\n\n  Chess.\n")
        board.print_board_bg()
        board.init()
        board.place_pieces()

        cx16.mouse_config2(1)
        sprites.enable()

        sys.wait(60)
        word[33] sprites_x = sprites.sprites_x
        word[33] sprites_y = sprites.sprites_y
        ubyte arc = 0
        repeat {
            sys.waitvsync()
            ubyte spr
            for spr in 1 to 32 {
                word sx = sprites_x[spr]+(sin8(arc) as word)*2
                word sy = sprites_y[spr]+cos8(arc)
                sprites.move(spr, sx, sy)
            }
            arc++
        }
    }
}

board {
    const ubyte board_col = 20
    const ubyte board_row = 5
    const ubyte square_size = 5
    const ubyte white_square_color = 15
    const ubyte black_square_color = 12

    %option align_page

    ubyte[64] chessboard
    ; lowercase 'rnbqkbnr' and 'p' -> white player's pieces
    ; uppercase 'RNBQKBNR' and 'P' -> black player's pieces
    ; something else -> no piece on this square
    ; row 0 of the chessboard array = bottom row (1) on screen
    ; row 7 of the chessboard array = top row (8) on screen
    ; column 0-7 in the array = column a-h on screen

    sub init() {
        sys.memset(&chessboard+2*8, len(chessboard)-2*8, 0)
        sys.memset(&chessboard+1*8, 8, 'p')
        sys.memset(&chessboard+6*8, 8, 'P')
        sys.memcopy("rnbqkbnr", &chessboard+0*8, 8)
        sys.memcopy("RNBQKBNR", &chessboard+7*8, 8)
    }

    sub print_board_bg() {
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

    sub place_pieces() {
        ubyte sprite_num = 1
        ubyte pi
        ubyte piece
        for piece in chessboard {
            piece = sprites.image_for_piece(piece)
            if piece!=255 {
                 word sx = sprites.col_x((pi & 7) + 'a')
                 word sy = sprites.col_y((pi >> 3) + 1)
                 sprites.init(sprite_num, piece, sx, sy)
                 sprite_num++
            }
            pi++
        }
    }

;    sub square_screen_col(ubyte col) -> ubyte {
;        return (col-'a')*square_size + board_col
;    }

;    sub square_screen_row(ubyte row) -> ubyte {
;        return (8-row as byte) as ubyte*square_size + board_row
;    }
}

sprites {
    const ubyte palette_offset = 32
    const uword sprite_data_base = $04000 >> 5      ; pre-shifted for vera
    const uword VERA_SPRITEREGS = $fc00

    sub enable() {
        cx16.VERA_DC_VIDEO |= %01000000                         ; enable sprites globally
    }

    word[33] sprites_x
    word[33] sprites_y

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
        cx16.vpoke(1, sprite_regs+7, %10100000 | palette_offset>>4)   ; 32x32 pixels, palette offset
        move(sprite_num, x, y)
        cx16.vpoke(1, sprite_regs+6, cx16.vpeek(1, sprite_regs+6) | %00001100)    ; enable sprite, z depth %11 = before both layers
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

    ; sprite images are in this order:
    ;   0 = R (black rook)
    ;   1 = B (black bishop)
    ;   2 = Q (black queen)
    ;   3 = K (black king)
    ;   4 = N (black knight)
    ;   5 = P (black pawn)
    ;   6-11 are the same pieces, but for the white player ('rbqknp' lowercase)
    ; K (king), Q (queen), R (rook), B (bishop), and N (knight). P (pawn)

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
            else -> return 255
        }
    }

    sub col_x(ubyte column) -> word {
        return (column-'a' as uword) * board.square_size * 8 + board.board_col * 8 + 4
    }

    sub col_y(ubyte row) -> word {
        return (8-row as word) * board.square_size * 8 + board.board_row *8 +4
    }
}
