# 8088 assembly car racing game

a simple, retro arcade car racing game built from scratch in 16-bit 8088 assembly language. 

## what this does
* **direct vram access:** draws graphics directly by writing characters and colors to the `0xB800` video segment.
* **optimized memory copies:** uses word transfers (`movsw`) instead of byte transfers (`movsb`) to speed up screen buffer rendering on the 8088 data bus.
* **safe stack management:** fixed a bug in the player car routines where duplicate pushes scrambled register values on return.
* **proper interrupt chaining:** hooks into the timer and keyboard interrupts but chains back to the original `INT 08h` bios handler so the system clock doesn't freeze while the game runs.

## how to run (via DOSBox)
you need an emulator like DOSBox to run this on modern systems.

1. clone the repo.
2. open DOSBox and mount your folder:
   ```text
   mount c c:\path\to\your\folder
   c:
3. run the executable:
   game.com
4. controls:
   left arrow: move left
   right arrow: move right
   esc: quit game