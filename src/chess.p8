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

; TODO pawn special moves: only straight 1 or 2 squares if initial move, unless it can take a piece
; TODO castling
; TODO pawn promotion
; TODO check, checkmate, stalemate (partly?)
; TODO resignation, restart
; TODO choose side that you want to play (currently always white)
; TODO en-passant capturing of pawn
; TODO fix vga/composite screen mode (see gfx2)

main {
    ubyte player        ; 1=white, 2=black
    ubyte turn
    uword black_time
    uword white_time

    sub start() {
        cx16.mouse_config2(1)   ; enable mouse cursor (sprite 0)
        ; show_titlescreen_lores()
        show_titlescreen_hires()

        cx16.mouse_config2(1)   ; enable mouse cursor (sprite 0)
        txt.clear_screen()
        txt.lowercase()
        palette.set_c64pepto()
        ; TODO no longer needed if using title screen pic:  show_instructions()
        load_resources()
        new_game()
        gameloop()
    }

    sub show_titlescreen_lores() {
        void cx16.screen_mode(128, false)   ; 256 colors lores
        if not cx16diskio.vload_raw("titlescreen.pal", 8, 1, $fa00)
           or not cx16diskio.vload_raw("titlescreen.bin", 8, 0, $0000) {
            void cx16.screen_mode(0, false)
            txt.print("load error\n")
            sys.wait(120)
            sys.exit(1)
        }
        txt.lowercase()
        txt.color2(15,12)
        txt.plot(10, 2)
        txt.print("The game of Chess")
        txt.color(14)
        txt.plot(2, 6)
        txt.print("Pieces are moved using the mouse.")
        txt.plot(2, 7)
        txt.print("Mouse button 1 selects a piece,")
        txt.plot(2, 8)
        txt.print("then dragging to the desired")
        txt.plot(2, 9)
        txt.print("destination square prepares a move.")
        txt.plot(2, 13)
        txt.print("You can freely change your mind,")
        txt.plot(2, 14)
        txt.print("until you confirm the move")
        txt.plot(2, 15)
        txt.print("by pressing mouse button 2.")
        txt.plot(2, 19)
        txt.print("At this time, you'll always play")
        txt.plot(2, 20)
        txt.print("white and the opponent plays black.")
        txt.plot(2, 24)
        txt.color2(13,5)
        txt.print("Press any mouse button to start.")
        txt.color2(15,0)
        txt.plot(0, 28)
        txt.print("A game by DesertFish")
        txt.plot(0, 29)
        txt.print("written in Prog8")
        while not cx16.mouse_pos() {
            ; nothing
        }
        while cx16.mouse_pos() {
            ; nothing
        }
        void cx16.screen_mode(0, false)
    }

    sub show_titlescreen_hires() {
        ; 640x400 16 colors
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

        if not cx16diskio.vload_raw("titlescreen640.pal", 8, 1, $fa00)
           or not cx16diskio.vload_raw("titlescreen640.bin", 8, 0, $0000) {
            sys.reset_system()
        }
        while not cx16.mouse_pos() {
            ; nothing
        }
        while cx16.mouse_pos() {
            ; nothing
        }

        cx16.VERA_CTRL = %10000000  ; reset vera
        c64.CINT()
        txt.fix_autostart_square()
        txt.lowercase()
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
        txt.print("until you confirm the move by pressing mouse button 2.")
        txt.plot(10, 20)
        txt.print("At this time, you'll always play with \x05white\x9b,")
        txt.plot(12, 21)
        txt.print("and the computer will play \x90black.")
        txt.plot(10, 25)
        txt.color(14)
        txt.print("Press any mouse button to continue.")
        txt.plot(58, 57)
        txt.color(10)
        txt.print("A game by DesertFish")
        txt.plot(62, 58)
        txt.print("written in Prog8")
        while not cx16.mouse_pos() {
            ; nothing
        }
        while cx16.mouse_pos() {
            ; nothing
        }
    }

    sub load_resources() {
        txt.print("loading...")
        if not cx16diskio.vload_raw("chesspieces.pal", 8, 1, $fa00 + sprites.palette_offset_color*2)
           or not cx16diskio.vload_raw("chesspieces.bin", 8, 0, $4000) {
            txt.print("load error\n")
            sys.wait(120)
            sys.exit(1)
        }

        if not cx16diskio.vload_raw("crosshairs.pal", 8, 1, $fa00 + sprites.palette_offset_color_crosshair*2)
           or not cx16diskio.vload_raw("crosshairs.bin", 8, 0, $4000 + 12*32*32/2) {
            txt.print("load error\n")
            sys.wait(120)
            sys.exit(1)
        }
    }

    sub new_game() {
        txt.clear_screen()
        board.init()
        sprites.init()
        player = 1      ; white player always starts, for now.
        turn = 0
        black_time = 0
        white_time = 0
    }

    sub gameloop() {
        ubyte from_cell = $ff
        ubyte to_cell = $ff
        bool button_pressed = false
        ubyte ci

        show_player()
        c64.SETTIM(0,0,0)

        repeat {
            sys.waitvsync()
            flash_crosshairs()
            update_clocks()
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
        }

        sub update_clocks() {
            txt.color(12)
            if c64.RDTIM16()>59 {
                c64.SETTIM(0,0,0)
                when player {
                    1 -> white_time++
                    2 -> black_time++
                }
            }

            print_time(1, white_time)
            print_time(2, black_time)

            sub print_time(ubyte whose, uword seconds) {
                when whose {
                    1 -> {
                        txt.plot(2, 57)
                        txt.print("white ")
                    }
                    2 -> {
                        txt.plot(2, 54)
                        txt.print("black ")
                    }
                }
                uword hours = seconds/(60*60)
                seconds -= hours*60*60
                uword minutes = seconds/60
                seconds -= minutes*60
                txt.print_ub0(lsb(hours))
                txt.print_ub0(lsb(minutes))
                txt.print_ub0(lsb(seconds))
                when whose {
                    1 -> fixup(57)
                    2 -> fixup(54)
                }

                sub fixup(ubyte row) {
                    txt.plot(8, row)
                    txt.chrout(' ')
                    txt.plot(11, row)
                    txt.chrout(':')
                    txt.plot(14, row)
                    txt.chrout(':')
                }
            }
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
        }

        sub log_move() {
            ubyte move = turn / 2
            txt.color(14)
            if turn & 1 {
                txt.plot(72, move+board.board_row+1)
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
            c64.SETTIM(0,0,0)
            show_player()
        }

        sub move_piece() {
            sprites.move_between_cells(from_cell, to_cell)
            board.cells[to_cell] = board.cells[from_cell]
            board.cells[from_cell] = 0
        }

        sub show_player() {
            txt.plot(30,55)
            txt.color(15)
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
}
