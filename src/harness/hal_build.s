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
* P2.4 — this file is now the KERNEL TRANSLATION UNIT. Under -DOBJTARGET each
* included module opens `section code` and exports its hal.inc entry points, and
* the whole thing assembles to ONE object that programs link against. `org` is
* absolute-only: in the object build the linker script places the section, and an
* `org` inside a section is not meaningful.
                ifdef   OBJTARGET
                else
                org     $2000
                endc
                include "src/hal/coco3-dsk/hal_globals.s"
                include "src/hal/coco3-dsk/sys.s"
                include "src/hal/coco3-dsk/time.s"
                include "src/hal/coco3-dsk/irq_vbl.s"
                include "src/hal/coco3-dsk/gfx.s"
                include "src/hal/coco3-dsk/input.s"
                include "src/hal/coco3-dsk/sound.s"
                include "src/hal/coco3-dsk/file.s"
                include "src/hal/coco3-dsk/mem.s"
* The WD1773 read primitive, shared byte-for-byte with karateka. P3.4 gave it
* its first POP client: the intro loads its screen straight off raw tracks.
                include "src/hal/coco3-dsk/disk_read.s"
                end
