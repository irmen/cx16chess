%import textio
%import palette
%import cx16diskio
%import math
%import board
%import sprites
%zeropage basicsafe
%option no_sysinit

; references for tiny chess:
; https://github.com/maksimKorzh/6502-chess/blob/main/src/chess_tty_cc65.c ?
; https://home.hccnet.nl/h.g.muller/board.html
;    makes the move generation look easy with the move_offsets lists.

; TODO show movelists per piece that is clicked


main {
    sub start() {
        palette.set_c64pepto()
        load_resources()
        txt.color2(1, 6)
        txt.clear_screen()
        txt.lowercase()
        board.init()
        board.print_board_bg()
        sprites.init()
        cx16.mouse_config2(1)   ; enable mouse cursor (sprite 0)

        demo_follow_mouse()
    }

    ubyte previous_ci
    sub demo_follow_mouse() {
        repeat {
            sys.waitvsync()
            sys.waitvsync()
            demo_flash_crosshairs()
            ubyte buttons = cx16.mouse_pos()
            ubyte ci = board.cell_for_screen(cx16.r0s, cx16.r1s)
            if ci & $88 == 0 {
                if buttons {
                    sprites.move(sprites.sprite_num_crosshair1, sprites.sx_for_cell(ci), sprites.sy_for_cell(ci))

                    txt.plot(10,10)
                    txt.print(board.notation_for_cell(ci))

                    board.print_square(ci, 10)
                }
                if not buttons or previous_ci != ci {
                    board.print_square(previous_ci, 0)
                    previous_ci = ci
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
