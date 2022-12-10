%import textio

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

        for line in 0 to 127 {
            if line & $88 == 0 {
                print_square(line, 0)
            }
        }

        row = board_row + square_size*8 + 1
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

    sub print_square(ubyte ci, ubyte color_override) {
        if color_override
            txt.color(color_override)
        else {
            if not (ci>>4 ^ ci) & 1
                txt.color(white_square_color)
            else
                txt.color(black_square_color)
        }
        ubyte cx = cx_for_cell(ci)
        ubyte cy = cy_for_cell(ci)
        repeat square_size {
            txt.plot(cx, cy)
            cy++
            txt.chrout('\x12') ; reverse
            txt.print(" "*square_size)
            txt.chrout('\x92') ; reverse off
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


    sub cx_for_cell(ubyte ci) -> ubyte {
        return (ci & $0f) * board.square_size + board.board_col
    }

    sub cy_for_cell(ubyte ci) -> ubyte {
        return ((ci & $f0)>>4) * board.square_size + board.board_row
    }

    sub movelist(ubyte piece) -> uword {
        when(piece) {
            'P' -> return [0,1,2,3]   ; black pawn
            'p' -> return [0,1,2,3]   ; white pawn
            'R' -> return [0,1,2,3]   ; black rook
            'r' -> return [0,1,2,3]   ; white rook
            'N' -> return [0,1,2,3]   ; black knight
            'n' -> return [0,1,2,3]   ; white knight
            'B' -> return [0,1,2,3]   ; black bishop
            'b' -> return [0,1,2,3]   ; white bishop
            'Q' -> return [0,1,2,3]   ; black queen
            'q' -> return [0,1,2,3]   ; white queen
            'K' -> return [0,1,2,3]   ; black king
            'k' -> return [0,1,2,3]   ; white king
        }
        return 0
    }
}
