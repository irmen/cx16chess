%import textio
%import palette
%import cx16diskio
%import math
%import board
%import sprites
%option no_sysinit

; references for tiny chess:
; https://github.com/maksimKorzh/6502-chess/blob/main/src/chess_tty_cc65.c ?
; https://home.hccnet.nl/h.g.muller/board.html
;    makes the move generation look easy with the move_offsets lists.

; TODO: turns
; TODO: move log
; TODO: various move rules see board
; TODO: pawn promotion
; TODO: winning/losing, forfeit game, restart game
; TODO: choose side that you want to play (currently always white)

main {
    sub start() {
        palette.set_c64pepto()
        load_resources()
        txt.color2(1, 6)
        txt.clear_screen()
        txt.lowercase()
        board.init()
        sprites.init()
        cx16.mouse_config2(1)   ; enable mouse cursor (sprite 0)

        txt.color(7)
        txt.plot(15,55)
        txt.print("Use mouse and button 1 to select and drag a piece.")
        txt.plot(15,56)
        txt.print("Use button 2 to confirm a valid move.")

        demo_move_pieces()
    }

    sub move_piece(ubyte from_ci, ubyte to_ci) {
        sprites.move_between_cells(from_ci, to_ci)
        board.cells[to_ci] = board.cells[from_ci]
        board.cells[from_ci] = 0
    }

    ubyte from_cell = $ff
    ubyte to_cell = $ff
    bool button_pressed = false

    sub demo_move_pieces() {
        ubyte ci
        repeat {
            sys.waitvsync()
            flash_crosshairs()
            ubyte buttons = cx16.mouse_pos()
            ci = board.cell_for_screen(cx16.r0s, cx16.r1s)
            if ci & $88 == 0 {
                if buttons & 1 {
                    if button_pressed {
                        ; dragging - update target square
                        to_cell = $ff
                        if ci!=from_cell and from_cell & $88 == 0 {
                            sprites.move(sprites.sprite_num_crosshair2, sprites.sx_for_cell(ci), sprites.sy_for_cell(ci))
                            if valid_move(from_cell, ci) {
                                to_cell = ci
                                sprites.set_valid_crosshair2()
                            } else {
                                sprites.set_invalid_crosshair2()
                            }
                        }
                    } else {
                        ; first click - update start square
                        sprites.move(sprites.sprite_num_crosshair1, sprites.sx_for_cell(ci), sprites.sy_for_cell(ci))
                        sprites.move(sprites.sprite_num_crosshair2, -32, -32)   ; offscreen
                        to_cell = $ff
                        from_cell = $ff
                        if board.cells[ci] {
                            void board.build_possible_moves(ci)
                            from_cell = ci
                        }
                    }
                    button_pressed = true
                } else if buttons & 2 {
                    ; Confirm move
                    txt.plot(30,2)
                    txt.color(13)
                    if from_cell & $88 or to_cell & $88  {
                        txt.print("invalid         ")
                    } else {
                        txt.print("move: ")
                        txt.chrout(board.cells[from_cell])
                        txt.spc()
                        txt.print(board.notation_for_cell(from_cell))
                        txt.chrout('-')
                        txt.print(board.notation_for_cell(to_cell))
                        sprites.move(sprites.sprite_num_crosshair1, -32, -32)   ; offscreen
                        sprites.move(sprites.sprite_num_crosshair2, -32, -32)   ; offscreen
                        ubyte piece_captured = board.cells[to_cell]
                        ubyte sprite_captured = 0
                        if piece_captured {
                            for sprite_captured in 0 to len(sprites.sprites_cell)-1 {
                                if sprites.sprites_cell[sprite_captured]==to_cell
                                    break
                            }
                        }
                        move_piece(from_cell, to_cell)
                        if piece_captured {
                            if piece_captured & 128 {
                                sprites.move_to(sprite_captured, 80, (sprite_captured & 15) as word *16+32, 32)   ; black piece captured
                            } else {
                                sprites.move_to(sprite_captured, 640-80-32, (sprite_captured & 15) as word *16+32, 32)   ; white piece captured
                            }
                            sprites.sprites_cell[sprite_captured] = $ff
                        }
                    }
                } else {
                    button_pressed = false
                }
            }
        }

        sub valid_move(ubyte from_ci, ubyte to_ci) -> bool {
            ; check if the target cell is in the generated move list.
            cx16.r1L = 0
            repeat {
                cx16.r0L = board.possible_moves[cx16.r1L]
                if cx16.r0L & $88
                    return false
                if cx16.r0L == to_ci
                    return true
                cx16.r1L++
            }
        }
    }

    sub flash_crosshairs() {
        ; rotate the 16 colors (except the 1st) in the crosshair palette
        uword palette_src = $fa00 + sprites.palette_offset_color_crosshair*2
        uword palette_dest = palette_src
        palette_src += 2
        ubyte first_lo = cx16.vpeek(1, palette_dest)
        ubyte first_hi = cx16.vpeek(1, palette_dest+1)
        repeat 30 {
            cx16.r2L = cx16.vpeek(1, palette_src)
            cx16.vpoke(1, palette_dest, cx16.r2L)
            palette_src++
            palette_dest++
        }
        cx16.vpoke(1, palette_dest, first_lo)
        cx16.vpoke(1, palette_dest+1, first_hi)
    }

    sub load_resources() {
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
