%import math
%import board

computerplayer {

    sub prepare_move() -> uword {
        ; returns 0 if giving up else move (from, to) in the lsb and msb.

        ; super stupid AI:
        ; - try 50000 random moves to see if one can capture an opponent's piece. If so, take this move.
        ; - if not, repeat this and take any random valid move.

        ; TODO assign value to pieces and capture piece with highest value first

        sys.wait(120)

        ubyte num_moves
        ubyte chosen_move
        ubyte ci
        ubyte cell_with_moves = $ff

        repeat 50000 {
            ci = math.rnd() & $77
            if board.cells[ci] & $80 {
                num_moves = board.build_possible_moves(ci)
                if num_moves>0
                    cell_with_moves = ci
                if board.possible_captures {
                    while num_moves {
                        num_moves--
                        chosen_move = board.possible_moves[num_moves]
                        if board.cells[chosen_move]   ; is this the move that captures a piece?
                            return mkword(chosen_move, ci)
                    }
                }
            }
        }

        ; no move that can capture, try a regular move
        if cell_with_moves & $88 == 0 {
            num_moves = board.build_possible_moves(cell_with_moves)
            if num_moves>0 {
                chosen_move = board.possible_moves[math.rnd() % num_moves]
                return mkword(chosen_move, cell_with_moves)
            }
        }

        return 0
    }
}