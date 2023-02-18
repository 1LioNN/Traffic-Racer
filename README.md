# Traffic-Racer in MIPS Assembly

## How to Play
1. Open TrafficRacer.asm with MARS 
2. Open up the Bitmap Display (MARS Tools Menu -> Bitmap Display) and Configure it as listed below
4. Click Connect to MIPS
3. Open up the Keyboard and MMIO Simulator (MARS Tools Menu -> Keyboard and MMIO Simulator) 
5. Click Connect to MIPS

## Controls
- W: Move forward
- A: Move left
- S: Move backward
- D: Move right
- Q: Restart Game
- X: Quit Game

## Bitmap Display Configuration: 
 - Unit width in pixels: 8 
 - Unit height in pixels: 8 
 - Display width in pixels: 512 
 - Display height in pixels: 512 
 - Base Address for Display: 0x10008000 

## Basic features that were implemented successfully 
 -  Display the number of remaining lives
 -  Cars spawn at random timings at random speeds in different lanes 
 -  Game Over/ Retry screen for winning and losing (same text but different colours)
    with retry option (Press "Q") and exit option (Press "X")
 
## Additional features that were implemented successfully 
 - Score/Progress Bar
 - 2 Types of power ups
	1. Extra Life, self explanatory, player gains a life but no more than 3
	2. Shield, player gains immunity for the next car collision, but not roadside collision
 - Harder Level, starts when score bar is half filled, permanently blocks off a random lane by spawning roadblocks 
   in that lane. Roadblock position is pre-generated at the start of the game cycle, it will be different for every game

## Video demo 
 - Youtube: https://youtu.be/FMfxsoYwGcU
 - Google Drive Download: https://drive.google.com/file/d/1up7-T9Z_W7B0Uz52GtEPrWa5hd7I8M-V/view?usp=sharing
