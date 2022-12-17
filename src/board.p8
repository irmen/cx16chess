%import textio

board {
    &ubyte[128] cells = $0400       ; cells in golden ram, page aligned

    ; the board is set up as an array with special 'octal' position encoding:
    ; 00 01 02 03 04 05 06 07       08 09 0a 0b 0c 0d 0e 0f
    ; 10 11 12 13 14 15 16 17       18 19 1a 1b 1c 1d 1e 1f
    ;   ...
    ; 60 61 62 63 64 65 66 67       68 69 6a 6b 6c 6d 6e 6f
    ; 70 71 72 73 74 75 76 77       78 79 7a 7b 7c 7d 7e 7f
    ; only board positions where the nibbles are <=7 are valid
    ; moves that get you outside of the board have the 4th bit set in one or both nibbles
    ; so validity of moves can be easily checked with AND $88

    const ubyte board_col = 20
    const ubyte board_row = 5
    const ubyte square_size = 5
    const ubyte white_square_color = 8   ; 15
    const ubyte black_square_color = 9   ; 12
    const ubyte board_border_color = 12
    const ubyte labels_color = 3

    ; for castling:
    bool black_king_moved
    bool black_rook_a_moved
    bool black_rook_h_moved
    bool white_king_moved
    bool white_rook_a_moved
    bool white_rook_h_moved

    sub init() {
        print_board_bg()

        ; setup normal start configuration
        sys.memset(cells, sizeof(cells), 0)
        setrow($00, "RNBQKBNR")
        setrow($10, "PPPPPPPP")
        setrow($60, "pppppppp")
        setrow($70, "rnbqkbnr")

        black_king_moved = false
        black_rook_a_moved = false
        black_rook_h_moved = false
        white_king_moved = false
        white_rook_a_moved = false
        white_rook_h_moved = false

        sub setrow(ubyte row, str pieces) {
            ubyte ix
            for ix in 0 to 7 {
                cells[row+ix] = pieces[ix]
            }
        }
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

    ubyte[32] @requirezp possible_moves
    ubyte possible_captures

    sub build_possible_moves(ubyte ci) -> ubyte {
        ; makes the array 'possible_moves' as a $ff-terminated array of cells that the piece on cell 'ci' could move to
        ; returns the number of moves in the array.
        ; also sets 'possible_captures' to the number of moves that could capture an opponent's piece.

        possible_captures = 0
        possible_moves[0] = $ff
        ubyte piece = board.cells[ci]
        if not piece
            return 0

        uword @requirezp vectors = move_vectors(ci)
        ubyte @requirezp vector_idx = 0
        ubyte @requirezp moves_idx = 0
        ubyte vector = vectors[0]
        ubyte @zp dest_ci
        ubyte @zp piece2

        if piece in "RrBbQq" {
            ; multi-square moves
            while vector {
                dest_ci = ci
                repeat {
                    dest_ci += vector
                    if dest_ci & $88
                        break
                    piece2 = board.cells[dest_ci]
                    if piece2 {
                        if (piece^piece2) & $80 {    ; check for opponent's piece
                            possible_moves[moves_idx] = dest_ci
                            moves_idx++
                            possible_captures++
                        }
                        break
                    }
                    possible_moves[moves_idx] = dest_ci
                    moves_idx++
                }
                vector_idx++
                vector = vectors[vector_idx]
            }
        } else {
            ; single-square move

            if piece & $7f == 'p' {
                ; special rules for pawn:
                ; cannot move diagonally, UNLESS capturing piece
                ; can only move 1 square, UNLESS starting on original starting row and unobstructed
                while vector {
                    ubyte diagonally = vector & 1
                    bool move_ok = false
                    dest_ci = ci + vector
                    if dest_ci & $88 == 0 {
                        piece2 = board.cells[dest_ci]
                        if diagonally and piece2 and (piece^piece2) & $80 {
                            move_ok = true
                            possible_captures++
                        } else if not diagonally and not piece2 {
                            ; check if not obstructed if moving 2 squares
                            if ci & $f0 == $60
                                move_ok = not board.cells[ci - $10]
                            else if ci & $f0 == $10
                                move_ok = not board.cells[ci + $10]
                            else
                                move_ok = true
                        }
                    }
                    if move_ok {
                        possible_moves[moves_idx] = dest_ci
                        moves_idx++
                    }
                    vector_idx++
                    vector = vectors[vector_idx]
                }
            } else {
                while vector {
                    dest_ci = ci + vector
                    if dest_ci & $88 == 0 {
                        piece2 = board.cells[dest_ci]
                        if not piece2 or (piece^piece2) & $80 {
                            possible_moves[moves_idx] = dest_ci
                            moves_idx++
                            possible_captures++
                        }
                    }
                    vector_idx++
                    vector = vectors[vector_idx]
                }
            }
        }

        possible_moves[moves_idx] = $ff
        return moves_idx

        sub move_vectors(ubyte cell) -> uword {
            ; this can be slightly faster when using a lookup table, but that probably requires
            ; identifying the pieces by an index number instead of a legible letter.
            when(board.cells[cell]) {
                'P' -> {    ; black pawn
                    if cell & $f0 == $10
                        return [$0f,$10,$11,$20,0]  ; still at initial row so allow 2 steps forward as well
                    return [$0f,$10,$11,0]
                }
                'p' -> {    ; white pawn
                    if cell & $f0 == $60
                        return [$f1,$f0,$ef,$e0,0]  ; still at initial row so allow 2 steps forward as well
                    return [$f1,$f0,$ef,0]
                }
                'R','r' -> return [$01,$10,$ff,$f0,0]   ; rook
                'N','n' -> return [$0e,$f2,$12,$ee,$1f,$e1,$21,$df,0]   ; knight
                'B','b' -> return [$11,$0f,$ef,$f1,0]   ; bishop
                'Q','q','K','k' -> return [$01,$10,$ff,$f0,$0f,$f1,$11,$ef,0]   ; queen, king
            }
            return 0
        }
    }

    ; TODO finish this:
    sub castling_possible(ubyte player, bool king_in_check) -> ubyte {
        ; returns 0 for not possible, 1 for short, 2 for long side possible, 3 for both sides possible.
        ; castling is allowed if:
        ;    The king and (castling) rook have not yet moved in the game
        ;    The king is not currently in check
        ;    No square the king would castle through is under attack
        ;    The squares between king and rook are unoccupied
        if king_in_check
            return 0
        ubyte possible
        when player {
            1 -> {
                ; white king
                if white_king_moved
                    return 0
                possible = %11
                if white_rook_a_moved {
                    ; TODO check squares not under attack and not occupied
                    possible &= %01
                }
                if white_rook_h_moved {
                    ; TODO check squares not under attack and not occupied
                    possible &= %10
                }
                if possible {
                    ; TODO check black king check
                }
                return possible
            }
            2 -> {
                ; black king
                if black_king_moved
                    return 0
                possible = %11
                if black_rook_a_moved {
                    ; TODO check squares not under attack and not occupied
                    possible &= %01
                }
                if black_rook_h_moved {
                    ; TODO check squares not under attack and not occupied
                    possible &= %10
                }
                if possible {
                    ; TODO check black king check
                }
                return possible
            }
            else -> return 0
        }
    }

}
