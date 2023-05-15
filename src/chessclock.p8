%import textio
%import conv

chessclock {

    uword black_time
    uword white_time
    ubyte jiffies
    bool paused
    ubyte side

    sub init() {
        reset()
        sys.set_irq(clock_irq, true)
    }

    sub reset() {
        black_time = 0
        white_time = 0
        jiffies = 0
        paused = true
        txt.color(12)
        txt.plot(5,54)
        txt.print("white:")
        txt.plot(5,56)
        txt.print("black:")
    }

    sub stop() {
        paused = true
    }

    sub switch(ubyte player) {
        jiffies = 0
        paused = false
        side = player
    }

    sub clock_irq() {
        cx16.save_vera_context()
        flash_crosshairs()
        if not paused {
            jiffies++
            if jiffies>=60 {
                jiffies=0
                when side {
                    1 -> {
                        white_time++
                        print_time(1, white_time)
                    }
                    2 -> {
                        black_time++
                        print_time(2, black_time)
                    }
                }
            }
        }
        cx16.restore_vera_context()

        sub print_time(ubyte whose, uword seconds) {
            uword hours = seconds/(60*60)
            seconds -= hours*60*60
            uword minutes = seconds/60
            seconds -= minutes*60
            ubyte ypos
            when whose {
                1 -> ypos = 54
                2 -> ypos = 56
            }

            conv.str_ub0(lsb(hours))
            txt.setcc(12,ypos,conv.string_out[1], 12)
            txt.setcc(13,ypos,conv.string_out[2], 12)
            txt.setcc(14,ypos,':',12)
            conv.str_ub0(lsb(minutes))
            txt.setcc(15,ypos,conv.string_out[1], 12)
            txt.setcc(16,ypos,conv.string_out[2], 12)
            txt.setcc(17,ypos,':',12)
            conv.str_ub0(lsb(seconds))
            txt.setcc(18,ypos,conv.string_out[1], 12)
            txt.setcc(19,ypos,conv.string_out[2], 12)
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
