%import textio
%import palette
%import diskio
%import math
%import board
%import sprites
%import computerplayer
%import chessclock
%option no_sysinit

; references for tiny chess:
; https://github.com/maksimKorzh/6502-chess/blob/main/src/chess_tty_cc65.c ?
; https://home.hccnet.nl/h.g.muller/board.html
;    makes the move generation look easy with the move_offsets lists.

; TODO fix bug: sometimes at game start, pawn sprite at C2 or D2 doesn't appear !?
; TODO castling (see board.castling_possible)
; TODO king in check
; TODO pawn promotion
; TODO checkmate, stalemate (partly?)
; TODO choose side that you want to play (currently always white)
; TODO en-passant capturing of pawn

main {
    ubyte player        ; 1=white, 2=black
    ubyte turn
    bool versus_human
    ubyte winner

    sub start() {
        ; show_titlescreen_lores()
        show_titlescreen_hires()
        txt.lowercase()
        palette.set_c64pepto()
        load_resources()
        chessclock.init()
        cx16.mouse_config2(1)   ; enable mouse cursor (sprite 0)

        repeat {
            sprites.hide_all()
            show_instructions()
            new_game()
            gameloop()
        }
    }

    sub wait_mousebutton() {
        while not cx16.mouse_pos() {
            ; nothing
        }
        while cx16.mouse_pos() {
            ; nothing
        }
    }

    sub show_titlescreen_lores() {
        void cx16.screen_mode(128, false)   ; 256 colors lores
        if not diskio.vload_raw("titlescreen.pal", 1, $fa00)
           or not diskio.vload_raw("titlescreen.bin", 0, $0000) {
            void cx16.screen_mode(0, false)
            txt.print("load error\n")
            sys.wait(120)
            sys.exit(1)
        }
        txt.lowercase()
        txt.color2(1,15)
        txt.plot(2,27)
        txt.print("Click any ")
        txt.print("mouse button")
        cx16.mouse_config2(1)   ; enable mouse cursor (sprite 0)
        wait_mousebutton()
        void cx16.screen_mode(0, false)
    }

    sub show_titlescreen_hires() {
        ; 640x400 16 colors
        cx16.mouse_config2(1)   ; enable mouse cursor (sprite 0)
        cx16.VERA_CTRL=0
        cx16.VERA_ADDR_L=0
        cx16.VERA_ADDR_M=0
        cx16.VERA_ADDR_H=%00010000  ; autoincrement
        cx16.memory_fill(&cx16.VERA_DATA0, 65535, 0)    ; first clear screen
        cx16.memory_fill(&cx16.VERA_DATA0, 64000, 0)    ; first clear screen second half
        cx16.VERA_DC_VIDEO = (cx16.VERA_DC_VIDEO & %11001111) | %00100000      ; enable only layer 1, no vram for text/tile layer
        cx16.VERA_DC_HSCALE = 128
        cx16.VERA_DC_VSCALE = 128
        cx16.VERA_CTRL = %00000010
        cx16.VERA_DC_VSTART = 20
        cx16.VERA_DC_VSTOP = 400 /2 -1 + 20 ; clip off screen that overflows vram
        cx16.VERA_L1_CONFIG = %00000110     ; 16 colors bitmap mode
        cx16.VERA_L1_MAPBASE = 0
        cx16.VERA_L1_TILEBASE = %00000001   ; hires

        ; use blank sprite bitmap as pointer to make it invisible
        cx16.vpoke(1, sprites.VERA_SPRITEREGS, $a0)
        cx16.vpoke(1, sprites.VERA_SPRITEREGS+1, $0f)

        if not diskio.vload_raw("titlescreen640.pal", 1, $fa00)
           or not diskio.vload_raw("titlescreen640.bin", 0, $0000) {
            sys.reset_system()
        }
        wait_mousebutton()
        cx16.r15L = cx16.VERA_DC_VIDEO & %00000111 ; retain chroma + output mode
        cbm.CINT()
        cx16.VERA_DC_VIDEO = (cx16.VERA_DC_VIDEO & %11111000) | cx16.r15L
    }

    sub show_instructions() {
        txt.clear_screen()
        txt.color2(13, 6)
        txt.plot(15, 6)
        txt.print("The game of Chess")
        txt.color(15)
        txt.plot(10, 10)
        txt.print("Pieces are moved using the mouse.")
        txt.plot(10, 12)
        txt.print("Mouse button 1 selects a piece, then dragging to")
        txt.plot(12, 13)
        txt.print("the desired destination square prepares a move.")
        txt.plot(10, 15)
        txt.print("You can freely change your mind,")
        txt.plot(12, 16)
        txt.print("until you confirm the move by pressing ")
        txt.print("mouse button")
        txt.print(" 2.")
        txt.plot(10, 20)
        txt.print("At this time, you'll always play with \x05white\x9b,")
        txt.plot(12, 21)
        txt.print("and the computer will play \x90black.")

        txt.plot(10, 26)
        txt.color(14)
        txt.print("Press:")
        txt.plot(10, 28)
        txt.print("mouse button")
        txt.print(" 1 ")
        txt.print("for game vs. ")
        txt.print("computer")
        txt.plot(10, 30)
        txt.print("mouse button")
        txt.print(" 2 ")
        txt.print("for game vs. ")
        txt.print("human")

        txt.plot(57, 56)
        txt.color(10)
        txt.print("A game by DesertFish")
        txt.plot(61, 57)
        txt.print("written in Prog8")

        repeat {
            when cx16.mouse_pos() {
                1 -> {
                    versus_human = false
                    break
                }
                2 -> {
                    versus_human = true
                    break
                }
            }
        }
        while cx16.mouse_pos() {
            ; wait until mouse button release
        }
    }

    sub load_resources() {
        if not diskio.vload_raw("chesspieces.pal", 1, $fa00 + sprites.palette_offset_color*2)
           or not diskio.vload_raw("chesspieces.bin", 0, $4000) {
            txt.print("load error\n")
            sys.wait(120)
            sys.exit(1)
        }

        if not diskio.vload_raw("crosshairs.pal", 1, $fa00 + sprites.palette_offset_color_crosshair*2)
           or not diskio.vload_raw("crosshairs.bin", 0, $4000 + 12*32*32/2) {
            txt.print("load error\n")
            sys.wait(120)
            sys.exit(1)
        }
    }

    sub new_game() {
        txt.clear_screen()
        board.init()
        sprites.init()
        chessclock.reset()
        txt.plot(30,56)
        txt.color(12)
        txt.print("F3 = resign/restart")
        player = 1      ; white player always starts, for now.
        turn = 0
        winner = 0
    }

    sub gameloop() {
        ubyte from_cell = $ff
        ubyte to_cell = $ff
        bool button_pressed = false
        ubyte ci

        show_player()
        chessclock.reset()
        chessclock.switch(player)

        bool continue = true
        while continue {
            sys.waitvsync()
            if player == 1
                continue = human_move()
            else if versus_human
                continue = human_move()
            else {
                uword computer_move = computerplayer.prepare_move()
                if computer_move {
                    from_cell = lsb(computer_move)
                    to_cell = msb(computer_move)
                    confirm_move()
                } else {
                    continue = false
                    chessclock.stop()
                    txt.plot(25,54)
                    txt.color(7)
                    txt.print("I give up! You win! Press any ")
                    txt.print("mouse button")
                    wait_mousebutton()
                }
            }
            if winner
                continue=false
        }
        chessclock.stop()
        if winner {
            show_winner(winner)
        }


        sub human_move() -> bool {
            when cbm.GETIN() {
                134 -> {
                    return false
                }
            }
            ubyte buttons = cx16.mouse_pos()  ; also puts mouse pos in r0s and r1s
            ci = board.cell_for_screen(cx16.r0s, cx16.r1s)
            if ci & $88 == 0 {
                if buttons & 1
                    prepare_move()
                else if buttons & 2
                    confirm_move()
                else
                    button_pressed = false
            }
            return true
        }

        sub prepare_move() {
            if button_pressed {
                ; dragging - update target square
                to_cell = $ff
                if ci!=from_cell and from_cell & $88 == 0 {
                    sprites.move(sprites.sprite_num_crosshair2, sprites.sx_for_cell(ci), sprites.sy_for_cell(ci))
                    if is_valid_move(from_cell, ci) {
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
                ubyte piece = board.cells[ci]
                if piece {
                    if (player==1 and piece&$80==0) or (player==2 and piece&$80) {
                        void board.build_possible_moves(ci)
                        from_cell = ci
                    }
                }
            }
            button_pressed = true
        }

        sub is_valid_move(ubyte from_ci, ubyte to_ci) -> bool {
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

        sub confirm_move() {
            if from_cell & $88 or to_cell & $88
                return      ; move is invalid
            log_move()
            sprites.move(sprites.sprite_num_crosshair1, -32, -32)   ; offscreen
            sprites.move(sprites.sprite_num_crosshair2, -32, -32)   ; offscreen
            ubyte piece_captured = board.cells[to_cell]
            ubyte sprite_captured = sprites.sprite_in_cell(to_cell)
            move_piece()
            if piece_captured {
                if piece_captured & 128 {
                    sprites.move_to(sprite_captured, 32, (sprite_captured & 15) as word *16+50, 32)   ; black piece captured
                } else {
                    sprites.move_to(sprite_captured, 70, (sprite_captured & 15) as word *16+50, 32)   ; white piece captured
                }
                sprites.sprites_cell[sprite_captured] = $ff
            }
            from_cell = $ff
            to_cell = $ff

            when piece_captured {
                'k' -> winner=2
                'K' -> winner=1
                else -> show_player()
            }
        }

        sub log_move() {
            ubyte move = turn / 2
            txt.color(14)
            if turn & 1 {
                txt.plot(73, move+board.board_row+1)
            } else {
                txt.plot(62, move+board.board_row+1)
                txt.print_ub(move+1)
                txt.chrout('.')
                txt.spc()
            }
            ubyte piece = board.cells[from_cell]
            if piece!='p' and piece!='P'
                txt.chrout(board.cells[from_cell] | $80)
            txt.print(board.notation_for_cell(from_cell))
            if board.cells[to_cell]
                txt.chrout('x')
            txt.print(board.notation_for_cell(to_cell))
            turn++
            player++
            if player==3
                player=1
            chessclock.switch(player)
        }

        sub move_piece() {
            when from_cell {
                $00 -> board.black_rook_a_moved = true
                $07 -> board.black_rook_h_moved = true
                $70 -> board.white_rook_a_moved = true
                $77 -> board.white_rook_h_moved = true
                $04 -> board.black_king_moved = true
                $7f -> board.white_king_moved = true
            }
            sprites.move_between_cells(from_cell, to_cell)
            board.cells[to_cell] = board.cells[from_cell]
            board.cells[from_cell] = 0
        }

        sub show_player() {
            txt.plot(30,54)
            txt.color(15)
            if versus_human {
                txt.print("It is ")
                when player {
                    1 -> {
                        txt.color(1)
                        txt.print("white")
                    }
                    2 -> {
                        txt.color(0)
                        txt.print("black")
                    }
                }
                txt.color(15)
                txt.print("'s turn.")
            } else {
                when player {
                    1 -> txt.print("It is your turn, \x05white.")
                    2 -> {
                        txt.color(7)
                        txt.print("I am thinking..........")
                    }
                }
            }
        }

        sub show_winner(ubyte who) {
            txt.plot(30,54)
            txt.color(7)
            if versus_human {
                when who {
                    1 -> txt.print("WHITE")
                    2 -> txt.print("BLACK")
                }
                txt.print(" won! Congratulations!")
            } else {
                when who {
                    1 -> {
                        txt.print("You")
                        txt.print(" won! Congratulations!")
                    }
                    2 -> txt.print("I won. Incredible.")
                }
            }
            txt.plot(30,55)
            txt.print("Press any ")
            txt.print("mouse button")
            wait_mousebutton()
        }
    }
}
