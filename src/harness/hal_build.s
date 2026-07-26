* src/harness/hal_build.s
*
* P2.1 build unit for the adopted HAL. Assembles every HAL module POP currently
* takes, so `build.bat` proves the adopted contract still builds.
*
* NOT engine code and NOT a driver - it has no entry point and is never executed.
* When POP's engine arrives it will include these modules itself and this file
* becomes redundant.
*
* mem.s IS NOW BUILT (P2.2 flag 2): the `end boot` directive that used to pin it to
* the end of the build list - and made it unassemblable in POP - has been relocated
* out of the HAL into the engine layer. This is flag 2's concrete payoff for POP.
                org     $2000
                include "src/hal/coco3-dsk/hal_globals.s"
                include "src/hal/coco3-dsk/sys.s"
                include "src/hal/coco3-dsk/time.s"
                include "src/hal/coco3-dsk/irq_vbl.s"
                include "src/hal/coco3-dsk/gfx.s"
                include "src/hal/coco3-dsk/input.s"
                include "src/hal/coco3-dsk/sound.s"
                include "src/hal/coco3-dsk/file.s"
                include "src/hal/coco3-dsk/mem.s"
                end
