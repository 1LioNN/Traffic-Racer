###################################################################### 
# CSCB58 Summer 2022 Project 
# University of Toronto, Scarborough 
# 
# Student Name: Lion Su, Student Number: 1007271523, UTorID: sulion 
# 
# Bitmap Display Configuration: 
# - Unit width in pixels: 8 
# - Unit height in pixels: 8 
# - Display width in pixels: 512 
# - Display height in pixels: 512 
# - Base Address for Display: 0x10008000 
# 
# Basic features that were implemented successfully 
# -  Display the number of remaining lives
# -  Cars spawn at random timings at random speeds in different lanes 
# -  Game Over/ Retry screen for winning and losing (same text but different colours)
#    with retry option (Press "Q") and exit option (Press "X")
# 
# Additional features that were implemented successfully 
# - Score/Progress Bar
# - 2 Types of power ups
#	1. Extra Life, self explanatory, player gains a life but no more than 3
#	2. Shield, player gains immunity for the next car collision, but not roadside collision
# - Harder Level, starts when score bar is half filled, permanently blocks off a random lane by spawning roadblocks 
#   in that lane. Roadblock position is pre-generated at the start of the game cycle, it will be different for every game
#
# Link to the video demo 
# - Youtube: https://youtu.be/FMfxsoYwGcU
# - Google Drive Download: https://drive.google.com/file/d/1up7-T9Z_W7B0Uz52GtEPrWa5hd7I8M-V/view?usp=sharing
# 
# Any additional information that the TA needs to know: 
# - Since you can't draw objects outside the screen (before the address of the display)
#   it will seem that cars will appear and disappear on the top of the screen randomly
#   this should not affect gameplay as the player can't ever collide with cars at the
#   top of the screen, but may seem weird.
# - A lot of the code in this program is just manual drawing of the graphics (Because it's fun!)
# - Cars on the right spawn at max speed, and slow down when player "speeds up" while cars on the left spawn at min speed
#   There are 3 speed levels at speed level 2 left lane and right lane cars are at the same speed 
# - For level 2, roadblocks are basically walls on the road that continously spawn in their lane,
#   essentially giving the player only one free lane to drive in
#  
###################################################################### 
#                         Global Variables
# $gp = A, the base display address that copies from displayAddress
# $s0 = Speed lvl
# $s1 = roadblock
# $s2 = Player 
# $s3 = car1 (left lane)
# $s4 = car2 (right lane)
# $s5 = powerUp
# $s6 = lives
# $s7 = score
# $t6 = speed of car 1
# $t7 = speed of car 2 


.data 
A:                 .word 0x10008000		  # Stores the actual display address for the game 
displayAddress:    .word 0x10000000               # Stores the base address for the display, used for drawing the background
player:            .word 0x10001F70  		  # Stores the base address for the player
car1:              .word 0x10000008     	  # Stores the base address for car1
car2:              .word 0x10004C8C               # Stores the base address for car2
roadblock:         .word 0x10000008 
speedlvl:          .word 0		 	  # Stores the additional vertical speed of cars, cars default to 256 or 512 speed 
lives:             .word 3                        # Stores lives of the player  
powerUp:           .word 0x10000008               # Stores base address for powerups
PUspeed:           .word 256                      # Speed of the powerups, used for spawning
PUType:            .word 0                        # Power up type, 0 for life, 1 for shield
PUShield:          .word 0                        # Boolean for shield, 0 if player has no shield, 1 if player has shield
blockedlane:       .word 0                        # Indicator for which lane has the roadblock, indicated by 0, 1, 2 ,3 
RBspeed:           .word 256
.text  

# This the welcome screen for the game, the user can press Q to start
#-------------------------------------------------------------------------------------------#	
#                                    Welcome Screen                                         #
#-------------------------------------------------------------------------------------------#	
Welcome: 
	# Keyboard checking to see if "q" is pressed
	li $t9, 0xffff0000 
	lw $t8, 0($t9) 
	beq $t8, 1, keypress_happened_welcome 
	lw $t0, displayAddress  
	lw $s2, player  
	# Draw background
	jal drawRoad
	# Draw player
	addi $sp, $sp, -4
	sw $s2, 0($sp)
	jal drawPlayer	
	# Draw title 
	jal drawTitle
	# Draw prompt to start game
	jal drawPressQ
	# Load displayAddress into $gp
	li $t5, 0
loop3:  beq $t5, 16384, end3
	lw $t4, 0($t0)
	sw $t4, 0($gp)
	addi $t5, $t5, 4
	addi $gp, $gp, 4
	addi $t0, $t0, 4
	j loop3
end3:	
	# Sleep
	li $v0, 32  
	li $a0, 100 
	syscall 
	j Welcome
# This the main game loop for the game, the user can press Q to restart
# W, A, S, D to move
#-------------------------------------------------------------------------------------------#	
#                                      Main Loop                                            #
#-------------------------------------------------------------------------------------------#	
startGame:
	# Initialize global variables
	lw $s0 speedlvl
	jal initCar1                  
	jal initCar2
	jal initPU
	lw $s2, player  
	lw $s6, lives
	li $s7, 0
	# Pick a random lane that will get road blocked in level 2, store it in blockedlane
	# Random Pos
	li $t0, 4
	# Pass $t0 = 4
	addi $sp, $sp, -4
	sw $t0, 0($sp) 
	jal random
	lw $t1, 0($sp)     	# $t1 = random RB pos
	addi $sp, $sp, 4 
	addi $sp, $sp, -4
	sw $t1, 0($sp) 
	sw $t1, blockedlane     # store blocked lane in memory
	# Pass $t1 to initRB
	jal initRB	
gameLoop:
	beq $s6, 0, gameOver
	beq $s7, 3868, gameOver
    	#KEYBOARD CHECKING
	li $t9, 0xffff0000 
	lw $t8, 0($t9) 
	beq $t8, 1, keypress_happened 

	jal drawRoad	
	
	# Check if hard mode
	bgt $s7, 1938, spawnRB
	j noRB
spawnRB:	
	# Pass player current address to drawRoadBlock(adr) and draw player
	lw $t9, RBspeed
	add $s1, $s1, $t9
RBOOB: 	bgt $s1, 0x10005000, THEN4
	j cont4
THEN4:	
	lw $t5, blockedlane
	addi $sp, $sp, -4
	sw $t5, 0($sp) 
	jal initRB
	# Pass RB current address to drawPU
cont4:	addi $sp, $sp, -4
	sw $s1, 0($sp) 
	jal drawRoadBlock
	
noRB:		
	# Update car1			
	add $s3, $s3, $t6
	# If car1 out of bounds, then reinitialize car1
C1OOB:	bgt $s3, 0x10005000, THEN1          
	j cont1
THEN1:  jal initCar1
	# Pass car1 current address to drawCar1(adr) and draw car1
cont1:	addi $sp, $sp, -4
	sw $s3, 0($sp)
	jal drawCar1

	
	# Update Car 2
	add $s4, $s4, $t7
	# If car2 out of bounds or not initialized, then reinitialize car1
C2OOB:	blt $s4, 0x10000000, THEN2
	beq $s4, 0x10004C8C, THEN2
	j cont2
THEN2:	jal initCar2
	# Pass car2 current address to drawCar2(adr) and draw car2
cont2:  addi $sp, $sp, -4
	sw $s4, 0($sp)
	jal drawCar2
	
	# Update PU
	lw $t9, PUspeed
	add $s5, $s5, $t9
	# If PU out of bounds or PU not spawned then reinitialize PU
PUOOB:  bgt $s5, 0x10005000, THEN3
	j cont3
THEN3:	jal initPU
	# Pass PU current address to drawPU
cont3:	addi $sp, $sp, -4
	sw $s5, 0($sp)
	jal drawPU
	
	# Pass player current address to drawPlayer(adr) and draw player
	addi $sp, $sp, -4
	sw $s2, 0($sp) 
	jal drawPlayer	
	
	# Pass remaining no. of lives to drawLives(lives) and draw lives
	addi $sp, $sp, -4
	sw $s6, 0($sp)
	jal drawLives
	
	# Increment score
	addi $sp, $sp, -4
	sw $s7, 0($sp)
	jal drawScore	
	addi $s7, $s7, 4
	
# Load from memory location A to gp
	li $t5, 0
loop2:  beq $t5, 16384, end2
	lw $t4, 0($t0)
	sw $t4, 0($gp) 
	addi $t5, $t5, 4
	addi $gp, $gp, 4
	addi $t0, $t0, 4
	j loop2
end2:	
# Sleep
	li $v0, 32  
	li $a0, 50 
	syscall  
	j gameLoop
# This is the game over screen for the game, press Q to restart or X to terminate t
# the program
#-------------------------------------------------------------------------------------------#	
#                                    Game Over Screen                                       #
#-------------------------------------------------------------------------------------------#	
gameOver:
#Keyboard checking to see if "q" is pressed to retry
	li $t9, 0xffff0000 
	lw $t8, 0($t9) 
	beq $t8, 1, keypress_happened_GO
	lw $s2, player  
	jal drawRoad
	jal drawGameOver
	jal drawPressQ
	li $t5, 0
loop4:  beq $t5, 16384, end4
	lw $t4, 0($t0)
	sw $t4, 0($gp)
	addi $t5, $t5, 4
	addi $gp, $gp, 4
	addi $t0, $t0, 4
	j loop4
end4:	
	li $v0, 32  
	li $a0, 100 
	syscall 
	j gameOver
Exit:
li $v0, 10 # terminate the program  
syscall  

#-------------------------------------------------------------------------------------------#	
#                                    Keyboard Input                                         #
#-------------------------------------------------------------------------------------------#	
keypress_happened_welcome:
	lw $t2, 4($t9)   
	beq $t2, 0x71, q
	j Welcome
#-------------------------------------------------------------------------------------------#
keypress_happened:
	lw $t2, 4($t9)  
	beq $t2, 0x61, a 
	beq $t2, 0x64, d
	beq $t2, 0x77, w 
	beq $t2, 0x73, s
	beq $t2, 0x71, q
	j gameLoop
#-------------------------------------------------------------------------------------------#	
keypress_happened_GO:
	lw $t2, 4($t9)   
	beq $t2, 0x71, q
	beq $t2, 0x78, x
	j gameOver
#-------------------------------------------------------------------------------------------#	
# If A is pressed
a:	addi $s2, $s2, -16
# Collision with left roadside
IfLeft: blt $s2, 0x10001F00, loseLife
	j gameLoop
# If D is pressed, move right 
d: 	addi $s2, $s2, 16	
# Collision with right roadside
IfRight: bgt $s2, 0x10001FE0, loseLife  
	j gameLoop
	
# If w is pressed, left cars speed up, right cars slow down
w:	beq   $s0, 512, gameLoop
	addi  $s0, $s0, 256
	
	# Change Roadblock speed
	lw $t9, RBspeed
	addi $t9, $t9, 256
	sw $t9, RBspeed
	
	# Change car speeds
checkC1W:	
	beq   $s3, 0x10005004, checkC2W 
	addi  $t6, $t6, 256
checkC2W:	
	beq   $s4, 0x10004C8C, gameLoop 	
	addi  $t7, $t7, 256 
			
	j gameLoop
	
# If s is pressed, right cars speed up left cars slow down 
s: 	beq   $s0, 0, gameLoop	
	addi  $s0, $s0, -256 
	
	#Change Roadblock speed
	lw $t9, RBspeed
	addi $t9, $t9, -256
	sw $t9, RBspeed
	
	# Change car speeds
checkC1S:	
	beq   $s3, 0x10005004, checkC2S 
	addi  $t6, $t6, -256
checkC2S:	
	beq   $s4, 0x10004C8C, gameLoop 	
  	addi  $t7, $t7,-256 
				
	j gameLoop
	
# If q is pressed, reset the game	
q:      li $t9, 0
	sw $t9, PUShield
	j startGame

# If x is pressed, quit the game
x:      j Exit
#-------------------------------------------------------------------------------------------#
#                                    COLLISION BRANCH                                       #
#-------------------------------------------------------------------------------------------#
# Player loses life hitting a wall, resets all car positions and player position and lose a life
loseLife:
	lw $s2, player
	jal initCar1
	jal initCar2
	addi $s6, $s6, -1
	j gameLoop
# Player loses life hitting car 1, if player has shield, reset car 1 and destroy shield
# otherwise, reset all car positions, player position and lose a life
loseLife1:	
	# Check if shielded
	lw $t9, PUShield
	beq $t9, 1, block1
	lw $s2, player
	jal initCar2
	addi $s6, $s6, -1	
block1:	jal initCar1
	li $t9, 0
	sw $t9, PUShield
	# Offset stack to account for returning to main instead of drawCar()
	addi $sp, $sp, 8
	j gameLoop
	
# Player loses life hitting car 2, if player has shield, reset car 2 and destroy shield
# otherwise, reset all car positions, player position and lose a life	
loseLife2:
	# Check if shielded
	lw $t9, PUShield
	beq $t9, 1, block2
	lw $s2, player
	jal initCar1
	addi $s6, $s6, -1
	
block2:	jal initCar2
	li $t9, 0
	sw $t9, PUShield
	# Offset stack to account for returning to main instead of drawCar()
	addi $sp, $sp, 8
	j gameLoop
# Player loses life hitting RB, if player has shield, destroy shield
# otherwise, reset RB and lose a life		
loseLife3:
	lw $t9, PUShield
	beq $t9, 1, block3
	lw $s2, player
	jal initCar1
	jal initCar2
	addi $s6, $s6, -1	
block3:	jal initRB
	li $t9, 0
	sw $t9, PUShield
	# Offset stack to account for returning to main instead of drawCar()
	addi $sp, $sp, 8
	j gameLoop

# Player gains life hitting extra life power up
gainLife:
	jal initPU
	beq $s6, 3, gameLoop 
	addi $s6, $s6, 1
	# Offset stack to account for returning to main instead of drawCar()
	addi $sp, $sp, 8
	j gameLoop
# Player gains shield hitting shield power up	
gainShield:
	jal initPU
	lw $t9, PUShield
	beq $t9, 1, gameLoop 
	li $t9, 1
	sw $t9, PUShield
	# Offset stack to account for returning to main instead of drawCar()
	addi $sp, $sp, 8
	j gameLoop

#-------------------------------------------------------------------------------------------#
#                                      INIT FUNCTIONS                                       #
#-------------------------------------------------------------------------------------------#
#----------------void initRB(pos)------------------# 
# This function initializes a road object          #
# randomly at a random location at the top of the  #
# screen                                           #  
#                                                  #  
# Arguments                                        #
# None                                             #          
#--------------------------------------------------#
initRB:
	lw $t0, 0($sp)  
	addi $sp, $sp, 4                    # $t0 stores the randomly generated blocked lane 
	
	# Check which lane is blocked
	beq $t0, 0, blockLL
	beq $t0, 1, blockLR
	beq $t0, 2, blockRL
	beq $t0, 3, blockRR
	# Inititalize position based on blocked lane
blockLL:
	lw $s1, roadblock
	j ExitRB
blockLR:
	lw $s1, roadblock
	addi $s1, $s1, 68
	j ExitRB
blockRL:
	lw $s1, roadblock
	addi $s1, $s1, 132
	j ExitRB
blockRR:
	lw $s1, roadblock
	addi $s1, $s1, 200
	j ExitRB
ExitRB:	
	jr $ra


#----------------void initPU()---------------------# 
# This function initializes a power up object      #
# randomly at a random location at the top of the  #
# screen                                           #  
#                                                  #  
# Arguments                                        #
# None                                             #          
#--------------------------------------------------#
initPU:
	# Random Timing
	li $t0, 225
	# Pass $ra
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	# Pass $t0 = 2
	addi $sp, $sp, -4
	sw $t0, 0($sp) 
	jal random
	lw $t1, 0($sp)     	# $t1 = random timing
	lw $ra, 4($sp)
	addi $sp, $sp, 8  
	# if $t1 = 23, then spawn PU, otherwise, don't spawn PU in this cycle
	beq $t1, 23, Spawn
	lw $s5, powerUp
	add $s5, $s5, 20476
	li $t5, 0
	sw $t5, PUspeed
	j ExitFpu
	# Spawn PU
Spawn:
	# Random Pos
	li $t0, 54
	# Pass $ra
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	# Pass $t0 = 2
	addi $sp, $sp, -4
	sw $t0, 0($sp) 
	jal random
	lw $t2, 0($sp)     	# $t2 = random PU pos
	lw $ra, 4($sp)
	addi $sp, $sp, 8  
	# Generate Position
Position: 
	li $t5, 4
	mult $t2, $t5
	mflo $t4               # Spawn position of PU
	lw $s5, powerUp
	add $s5, $s5, $t4
	li $t5, 256
	sw $t5, PUspeed		
	
	#Generate Type
Type:
	# Random Pos
	li $t0, 2
	# Pass $ra
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	# Pass $t0 = 2
	addi $sp, $sp, -4
	sw $t0, 0($sp) 
	jal random
	lw $t3, 0($sp)     	# $t3 = random PU type
	lw $ra, 4($sp)
	addi $sp, $sp, 8  
	
	sw $t3, PUType	
	
ExitFpu:	
	jr $ra
	
#----------------void initCar1()-------------------# 
# This function initializes a car in the left lane #
# between the left or right lane                   #  
#                                                  #  
# Arguments                                        #
# None                                             #          
#--------------------------------------------------#		
initCar1:
	# Random Pos
	li $t0, 12
	# Pass $ra
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	# Pass $t0 = 2
	addi $sp, $sp, -4
	sw $t0, 0($sp) 
	jal random
	lw $t3, 0($sp)     	# $t3 = random timing
	lw $ra, 4($sp)
	addi $sp, $sp, 8  
	# if $t3 = 4, then spawn car, otherwise don't spawn a car in this cycle
	beq $t3, 4, spawncar1
	lw $s3, car1
	add $s3, $s3, 20476
	li $t6, 0
	j ExitF
	
spawncar1:	
	li $t0, 4
	# Random Speed
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	# Pass $t0 = 2
	addi $sp, $sp, -4
	sw $t0, 0($sp) 
	jal random
	lw $t2, 0($sp)    	# $t2 = random car speed
	lw $ra, 4($sp)
	addi $sp, $sp, 8  
	
	
	# Setting car spawning speed	
IFS:    beq $t2, 0, speed1
	beq $t2, 2, speed1
	li $t6, 256
	add $t6, $t6, $s0
	j POS1
speed1: li $t6, 512
	add $t6, $t6, $s0

POS1:				
	li $t0, 2
	#  Random Pos
	# Pass $ra
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	# Pass $t0 = 2
	addi $sp, $sp, -4
	sw $t0, 0($sp) 
	jal random
	lw $t1, 0($sp)     	# $t1 = random car pos
	lw $ra, 4($sp)
	addi $sp, $sp, 8  				
	# Setting car spawning position
	bgt $s7, 1936, hard
	j easy
	# If in hard mode, check which lane is blocked, else jump to easy
hard:	

	lw $t5, blockedlane
	# If blocked lane is 0 or 1, then block left if 0, block right if 1, other wise if 2 or 3, go to easy
	beq $t5, 0, blockL
	beq $t5, 1, blockR
	beq $t5, 2, easy
	beq $t5, 3, easy
	
	
blockL: lw $s3, car1
	addi $s3, $s3 68
	j ExitF
	
blockR: lw $s3, car1
	j ExitF

	# If easy mode 
easy:
		
IF1:	beq $t1, 0, LEFT
ELSE:   beq $t1, 1, RIGHT


LEFT:	lw $s3, car1
	j ExitF
	
RIGHT:  lw $s3, car1
	addi $s3, $s3 68
	j ExitF	
	
	
ExitF:	jr $ra
#----------------void initCar2()-------------------# 
# This function initializes a car in the right lane#
# between the left or right lane                   #  
#                                                  #  
# Arguments                                        #
# None                                             #          
#--------------------------------------------------#	
initCar2:
	# Random Timing
	li $t0, 12
	# Pass $ra
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	# Pass $t0 = 2
	addi $sp, $sp, -4
	sw $t0, 0($sp) 
	jal random
	lw $t3, 0($sp)     	# $t3 = random timing
	lw $ra, 4($sp)
	addi $sp, $sp, 8  
	beq $t3, 2, spawncar2
	lw $s4, car2
	li $t7, 0
	j ExitF2

spawncar2:
	# Generate Speed of Car
	li $t0, 4
	# Pass $ra
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	# Pass $t0 = 2
	addi $sp, $sp, -4
	sw $t0, 0($sp) 
	jal random
	lw $t2, 0($sp)    	# $t2 = random car speed
	lw $ra, 4($sp)
	addi $sp, $sp, 8  
	
	
IFS2:   beq $t2, 1, speed2
 	beq $t2, 3, speed2
	li $t7, -768
	add $t7, $t7, $s0
	j POS2
speed2: li $t7, -1024
	add $t7, $t7, $s0

POS2:	

	li $t0, 2
	# Generate Position of Car
	# Pass $ra
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	# Pass $t0 = 2
	addi $sp, $sp, -4
	sw $t0, 0($sp) 
	jal random
	lw $t1, 0($sp)
	lw $ra, 4($sp)
	addi $sp, $sp, 8  

	# Setting car spawning position
	bgt $s7, 1936, hard1
	j easy1
	# If in hard mode, check which lane is blocked, else jump to easy
hard1:	
	lw $t5, blockedlane
	# If blocked lane is 2 or 3, then block left if 2, block right if 3, other wise if 1 or 0, go to easy
	beq $t5, 0, easy1
	beq $t5, 1, easy1
	beq $t5, 2, blockL1
	beq $t5, 3, blockR1
	
	
blockL1:lw $s4, car2
	addi $s4, $s4 68
	j ExitF2	

blockR1: lw $s4, car2
	j ExitF2
	
	# If easy mode 
easy1:		
IF2:	beq $t1, 0, LEFT1
ELSE2:  beq $t1, 1, RIGHT1
	
LEFT1:	lw $s4, car2
	j ExitF2
RIGHT1: lw $s4, car2
	addi $s4, $s4 68
	j ExitF2	
	
	
ExitF2:	jr $ra
	
	
#-------------------------------------------------------------------------------------------#
#                                   LOGICAL FUNCTIONS                                       #
#-------------------------------------------------------------------------------------------#
#------------void Collision(adr)-------------------# 
# Function that checks if player has collided with #
# another car. Takes the address of where the      #
# player would be drawn and checks if the colour   #
# at the drawn location is an obstacle/powerup     #    
#                                                  #  
# Arguments                                        #
# $a0 = Address of car                             #                
#--------------------------------------------------#
Collision:
	lw $a0, 0($sp)                      # $a0 is the address passed in by initPlayer()
	addi $sp, $sp, 4 
	
	
# Random cars are always wider than the player car, so all this does is check if the left or
# right edges of the player car is drawing on a color that belongs to any of the random cars
	li $t5, 0			    # $t5 = i
checkCollision:
	beq $t5, 16, endCollision            
	
	lw $a1, 0($a0)                      # $a1 = left edge of car
	lw $a2, 28($a0)                     # $a2 = right edge of car
	
	# CAR COLLISION
	# If left edge draws on any of these colors, reset the position of player and all
	# Obstacles. The player loses a life
	beq $a1, 0xD3D3D3, loseLife1  
	beq $a1, 0xEDEDED, loseLife1
	beq $a1, 0x680000, loseLife2
	beq $a1, 0x5A0000, loseLife2
	# If right edge draws on any of these colors, reset the position of player and all
	# Obstacles. The player loses a life
	beq $a2, 0x680000, loseLife2
	beq $a2, 0x5A0000, loseLife2
	beq $a2, 0xD3D3D3, loseLife1
	beq $a2, 0xEDEDED, loseLife1
	
	# RB COLLISION
	# If left edge draws on any of these colors, reset the position of rb, the player loses a life
	beq $a1, 0xd4d4d2, loseLife3  
	# If right edge draws on any of these colors, reset the position of rb, the player loses a life
	beq $a2, 0xd4d4d2, loseLife3
	
	# LIFE COLLISION
	# If left edge draws on any of these colors, gain a life up to 3
	beq $a1, 0x068199, gainLife  
	beq $a1, 0xff0303, gainLife
	# If right edge draws on any of these colors, gain a life up to 3
	beq $a2, 0x068199, gainLife
	beq $a2, 0xff0303, gainLife
	
	# SHIELD COLLISION
	# If left edge draws on any of these colors, gain a shield
	beq $a1, 0x058719, gainShield 
	beq $a1, 0x8c8c8c, gainShield
	# If right edge draws on any of these colors, gain a shield
	beq $a2, 0x058719, gainShield
	beq $a2, 0x8c8c8c, gainShield
	
	#Increment counter and check the next row
	addi $t5, $t5, 1
	addi $a0, $a0, 256
	j checkCollision
endCollision:
	# END OF FUNCTION
	jr $ra
#-------------------------------------------------------------------------------------------#	
	
#-----------------int random(max)------------------# 
# This function generates a random number between  #
# 0 and max                                        #
#                                                  #  
# Arguments                                        #
# $t0 = max range                                  #
# Return Values                                    #        
# $t1 = random number                              #       
#--------------------------------------------------#	

random: 
	lw $t0, 0($sp)
	addi $sp, $sp, 4
	
	li $v0, 42  
	li $a0, 0  
	move $a1, $t0 
	syscall  
	
	move $t1, $a0
	addi $sp, $sp, -4
	sw $t1, 0($sp)
	
	jr $ra
#-------------------------------------------------------------------------------------------#
#                                     DRAW FUNCTIONS                                        #
#-------------------------------------------------------------------------------------------#
#------------void drawRoad()-----------------------#
# This function draws the background for our game. #
# It fills the screen with grey pixesl then draws  #
# the other details afterward                      #
#                                                  #
# Arguments:                                       #
# None                                             #
#--------------------------------------------------#
drawRoad:		
	lw $t0, displayAddress              # $t0 stores the base address for display  
	li $t1, 0xffffff                    # $t1 stores the white colour code  
	li $t2, 0xbea401                    # $t2 stores the yellow colour code  
	li $t3, 0x444444                    # $t3 stores the grey colour code  
	li $t5, 0		            

# Fill the screen with grey                        
drawGrey:   bgt $t5, 16384, endGrey 
	sw $t3, 0($t0)   
	addi $t0, $t0, 4
	addi $t5, $t5, 4		
	j drawGrey		
endGrey:  
#Reset t0 to base address, and i to 0
	lw $t0, displayAddress
	addi $t0, $t0, 124
	li $t5, 0

# Draw yellow line down the center of the road.    
drawYellow: bgt $t5, 16384, endYellow
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	addi $t0, $t0, 256
	addi $t5, $t5, 256
	j drawYellow
endYellow:
#Reset the address and counter
	lw $t0, displayAddress
	addi $t0, $t0, 60
	li $t5, 0
	li $t9, 1024

# Draw white dash lines on both sides of the road. 
# Outer loop creates the gaps between the dashes   
# and Inner loop draws the white pixels            
drawWhite:  bgt $t5, 16384 , endWhite
wInner: bgt  $t5, $t9, endwInner
	sw $t1, 0($t0)
	sw $t1, 132($t0)
	addi $t0, $t0, 256	
	addi $t5, $t5, 256
	j wInner 
endwInner:	
	addi $t0, $t0, 1280
	addi $t5, $t5, 1280
	addi $t9, $t9, 2560
	j drawWhite
endWhite:
	lw $gp, A
	lw $t0, displayAddress
	#END OF FUNCTION
	jr $ra
#--------------void drawPlayer(adr)----------------#
# This function draws the player car at the given  #
# position                                         #                            
#                                                  #
# Arguments:                                       #
# Address = $t0                                    #
#--------------------------------------------------#
drawPlayer:                  
	lw $t0, 0($sp)  
	addi $sp, $sp, 4                    # $t0 stores the base address for display  
	lw $t5, PUShield
	beq $t5, 1, shielded
	j normal
shielded:
	li $t1, 0xC0C0C0                    # $t1 stores the silver colour code  
	li $t2, 0xf5f507                    # $t2 stores the light blue colour code  
	li $t3, 0x000000                    # $t3 stores the black colour code  
	li $t4, 0xb8b806		    # $t4 stores the blue colour code 
	j cont7
normal:	
	li $t1, 0xC0C0C0                    # $t1 stores the silver colour code  
	li $t2, 0x006590                    # $t2 stores the light blue colour code  
	li $t3, 0x000000                    # $t3 stores the black colour code  
	li $t4, 0x004B6B		    # $t4 stores the blue colour code 
cont7:	
	
	# CHECK COLLISION
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	addi $sp, $sp, -4
	sw $t0, 0($sp) 
	jal Collision
	lw $ra, 0($sp)
	addi $sp, $sp, 4  
	
	# DRAW THE CAR 
	li $t5, 0          		   
	# Drawing the very front of the car so it looks round
	sw $t2, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t1, 20($t0)
	sw $t2, 24($t0)
	#Go to next row
	addi $t0, $t0, 256
	# Drawing the front of the car row by row
front:  beq $t5, 3, endFront	
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t1, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t5, $t5, 1 
	addi $t0, $t0, 256
	j front
endFront:
	# Drawing the front windshield part of the car
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0, $t0, 256
	# Drawing the front windshield part of the car
	sw $t4, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t4, 28($t0)
	addi $t0, $t0, 256
	# Reset counter to draw the main body of the car
	li $t5, 0	
body:   beq $t5, 6, endBody
	sw $t4, 0($t0)
	sw $t4, 4($t0)
	sw $t1, 8($t0)
	sw $t4, 12($t0)
	sw $t4, 16($t0)
	sw $t1, 20($t0)
	sw $t4, 24($t0)
	sw $t4, 28($t0)
	addi $t5, $t5, 1 
	addi $t0, $t0, 256
	j body
endBody:
	# Draw the back of the car, no iteration due to different colors for every row
	# Drawing back windshield layer 1
	sw $t4, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t4, 28($t0)
	addi $t0, $t0, 256
	# Drawing back windshield layer 2
	sw $t4, 0($t0)
	sw $t4, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t4, 24($t0)
	sw $t4, 28($t0)
	addi $t0, $t0, 256
	# Drawing back windshield layer 3
	sw $t2, 0($t0)
	sw $t4, 4($t0)
	sw $t4, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t4, 20($t0)
	sw $t4, 24($t0)
	sw $t2, 28($t0)
	addi $t0, $t0, 256
	# Drawing back trunk layer 1
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t1, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0, $t0, 256
	# Drawing back trunk layer 1
	sw $t2, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t1, 20($t0)
	sw $t2, 24($t0)
	#END OF FUNCTION
	lw $gp, A
	lw $t0, displayAddress	
	jr $ra
#-----------------void car1(adr)-------------------#
# This function sets the attributes of the car in  #                      
# the bottom left of the right lane, then draws    #  
# the car                                          #
#                                                  #
# Arguments:                                       #
# None                                             #
#--------------------------------------------------#
drawCar1:
	lw $t0, 0($sp)  
	addi $sp, $sp, 4                     # $t0 stores the base address for display  
	li $t1, 0xEDEDED                    # $t1 stores the white colour code  
	li $t2, 0xD3D3D3                    # $t2 stores the grey colour code  
	li $t3, 0x000000                    # $t3 stores the black colour code  
	#addi $t0, $t0, 11404
	j drawCar

#-----------------void car2(adr)-------------------#
# This function sets the attributes of the car in  #                      
# the right lane, then draws the car               #  
#                                                  #
#                                                  #
# Arguments:                                       #
# Address - where the car is drawn                 #
#--------------------------------------------------#
drawCar2:
	lw $t0, 0($sp)  
	addi $sp, $sp, 4              # $t0 stores the base address for display  
	li $t1, 0x680000              # $t1 stores the red colour code  
	li $t2, 0x5A0000              # $t2 stores the dark red colour code  
	li $t3, 0x000000              # $t3 stores the black colour code  
	#addi $t0, $t0, 264
	j drawCar
	
#--------------------------------------------------# 
# This is not a function, but rather code that all #                      
# nonplayer cars use, after car is drawn, return   #
# to main                                          #                                                 
#--------------------------------------------------#
drawCar: 	
	li $t5, 0 # $t5 = i, for drawing the body and the front of the car
	# Drawing the very front of the car so it looks round
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	#Go to next row
	addi $t0, $t0, 256
	# Drawing the front of the car row by row
front1:  beq $t5, 3, endFront1	
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	sw $t1, 36($t0)
	addi $t5, $t5, 1 
	addi $t0, $t0, 256
	j front1
endFront1:
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	sw $t1, 32($t0)
	sw $t1, 36($t0)
	addi $t0, $t0, 256
	# Drawing the front windshield part of the car
	sw $t2, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	sw $t3, 32($t0)
	sw $t2, 36($t0)
	addi $t0, $t0, 256
	# Reset counter to draw the main body of the car
	li $t5, 0	
body1:  beq $t5, 6, endBody1
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	sw $t2, 32($t0)
	sw $t2, 36($t0)
	addi $t5, $t5, 1 
	addi $t0, $t0, 256
	j body1
endBody1:
	# Draw the back of the car, no iteration due to different colors for every row
	# Drawing back windshield layer 1
	sw $t2, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	sw $t3, 32($t0)
	sw $t2, 36($t0)
	addi $t0, $t0, 256
	# Drawing back windshield layer 2
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	sw $t2, 32($t0)
	sw $t2, 36($t0)
	addi $t0, $t0, 256
	# Drawing back windshield layer 3
	sw $t1, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t2, 28($t0)
	sw $t2, 32($t0)
	sw $t1, 36($t0)
	addi $t0, $t0, 256
	# Drawing back trunk layer 1
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	sw $t1, 36($t0)
	addi $t0, $t0, 256
	# Drawing back trunk layer 1
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	#END OF FUNCTION
	lw $gp, A
	lw $t0, displayAddress
	jr $ra
#---------------void drawScore(score)--------------#
# This function draws the no. of lives remaining   #  
#                                                  #
# Arguments:                                       #
# -score remaining                                 #
#--------------------------------------------------#
drawScore:
	lw $t0, displayAddress          # $t0 stores the base displayAddress
	lw $t1, 0($sp)                  # $t1 stores the score
	addi $sp, $sp, 4
	li $t2, 0xb9f007                # $t2 stores green
	li $t3, 0x1f1e1d                # $t3 stores black   
	div $t4, $t1, 60                # Increment score bar every 800ms
	li $t5, 0                       # $t5 = i 
# Draw Empty Bar
drawBar:
	beq $t5, 256, endBar
	sw $t3, 0($t0)
	sw $t3, 256($t0)
	addi $t0, $t0, 4
	add $t5, $t5, 4
	j drawBar
endBar:
	
	lw $t0, displayAddress
	li $t5, 0
# Draw Score Bar
updateScore:
	beq $t5, $t4, endUpdate
	sw $t2, 0($t0)
	sw $t2, 256($t0)
	addi $t0, $t0, 4
	add $t5, $t5, 1
	j updateScore
endUpdate:

	#END OF FUNCTION
	lw $gp, A
	lw $t0, displayAddress
	jr $ra

#---------------void drawLives(lives)--------------#
# This function draws the no. of lives remaining   #  
#                                                  #
# Arguments:                                       #
# - $t1 = lives remaining                          #
#--------------------------------------------------#
drawLives:
	lw $t0, displayAddress          # $t0 stores the base displayAddress
	lw $t1, 0($sp)                  # $t1 stores the number of lives remaining 
	addi $sp, $sp, 4
	addi $t0, $t0, 516		# Offset for where to draw hearts
	li $t2, 0xff0303                # $t2 stores red
	li $t3, 0x000000                # $t3 stores black   
	li $t5, 0                       # $t5 = i 
	# Draw number of hearts equal to number of lives remaining
drawHearts: 
	beq $t5, $t1, endHearts
	
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	addi $t0, $t0, 256
	
	
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t3, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t3, 24($t0)
	addi $t0, $t0, 256
	
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t3, 24($t0)
	addi $t0, $t0, 256
	
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t3, 24($t0)
	addi $t0, $t0, 256
	

	sw $t3, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t3, 20($t0)
	addi $t0, $t0, 256
	

	sw $t3, 8($t0)
	sw $t2, 12($t0)
	sw $t3, 16($t0)
	addi $t0, $t0, 256
	
	sw $t3, 12($t0)
	
	addi $t0, $t0 -1504
	addi $t5, $t5, 1
	j drawHearts
endHearts:
	lw $gp, A
	lw $t0, displayAddress
	# End of Function
	jr $ra
#---------------void drawTitle()-------------------#
# This function draws the title for the game       #  
#                                                  #
# Arguments:                                       #
# -None                                            #
#--------------------------------------------------#
drawTitle:
	lw $t0, displayAddress              # $t0 stores the base address for display  
	li $t1, 0xffffff                    # $t1 stores white 
	li $t2, 0x000000 		    # $t2 stores black
	addi $t0, $t0, 1540
# TRAFFIC
drawT: 	# 1st Row
	sw $t2, 0($t0)
	sw $t2, 4($t0)
  	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 2nd Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256


	# 3rd Row
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	
	# 4-6th Row
	li $t5, 0
T3:     beq $t5, 3, endT3	
	sw $t2, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t2, 20($t0)
	addi $t0 $t0, 256
	addi $t5, $t5, 1
	j T3
endT3:	
	
	# 7th Row
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	addi $t0, $t0, -1500
drawR:
	# 1st Row
 	sw $t2, 0($t0)
	sw $t2, 4($t0)
  	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	addi $t0 $t0, 256
	# 2nd Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 3rd Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 4th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 5th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t1, 20($t0)
	sw $t2, 24($t0)
	addi $t0 $t0, 256
	# 6th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 20($t0)
	sw $t1, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 7th Row
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0, $t0, -1500
drawA:
	# 1st Row
	sw $t2, 4($t0)
  	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	addi $t0 $t0, 256
	
	# 2nd Row
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 3rd + 4th Row
	li $t5, 0
A1:     beq $t5, 2, endA1
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t2, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	addi $t5, $t5, 1
	j A1
endA1:	
	# 5th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 6th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t1, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 7th Row
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0, $t0, -1500
drawF:
	# 1st Row
	sw $t2, 0($t0)
	sw $t2, 4($t0)
  	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 2nd Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 3rd Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 4th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t2 20($t0)
	addi $t0 $t0, 256
	# 5th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	addi $t0 $t0, 256
	# 6th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	addi $t0 $t0, 256
	# 7th Row
	sw $t2, 0($t0)
	sw $t2, 4($t0)
  	sw $t2, 8($t0)
	sw $t2, 12($t0)
	addi $t0, $t0, -1500
	
drawF2:
	# 1st Row
	sw $t2, 0($t0)
	sw $t2, 4($t0)
  	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 2nd Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 3rd Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 4th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t2 20($t0)
	addi $t0 $t0, 256
	# 5th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	addi $t0 $t0, 256
	# 6th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	addi $t0 $t0, 256
	# 7th Row
	sw $t2, 0($t0)
	sw $t2, 4($t0)
  	sw $t2, 8($t0)
	sw $t2, 12($t0)
	addi $t0, $t0, -1500
drawI:
	# 1st Row
	sw $t2, 0($t0)
	sw $t2, 4($t0)
  	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 2nd Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 3rd Row
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 4th Row
	sw $t2, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t2, 20($t0)
	addi $t0 $t0, 256
	# 5th Row
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 6th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 7th Row
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0, $t0, -1500
drawC:
	# 1st Row
	sw $t2, 0($t0)
	sw $t2, 4($t0)
  	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 2nd Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 3rd Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	#4th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	addi $t0 $t0, 256
	#5th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 6th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 7th Row
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0, $t0, 332
# RACER 
drawR2:
	# 1st Row
 	sw $t2, 0($t0)
	sw $t2, 4($t0)
  	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	addi $t0 $t0, 256
	# 2nd Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 3rd Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 4th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 5th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t1, 20($t0)
	sw $t2, 24($t0)
	addi $t0 $t0, 256
	# 6th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 20($t0)
	sw $t1, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 7th Row
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0, $t0, -1500
drawA2:

	# 1st Row
	sw $t2, 4($t0)
  	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	addi $t0 $t0, 256
	
	# 2nd Row
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 3rd + 4th Row
	li $t5, 0
A2:     beq $t5, 2, endA2
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t2, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	addi $t5, $t5, 1
	j A2
endA2:	
	# 5th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 6th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t1, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 7th Row
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0, $t0, -1500
drawC2:
	# 1st Row
	sw $t2, 0($t0)
	sw $t2, 4($t0)
  	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 2nd Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 3rd Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	#4th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	addi $t0 $t0, 256
	#5th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 6th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 7th Row
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0, $t0, -1500


drawE:
	# 1st Row
	sw $t2, 0($t0)
	sw $t2, 4($t0)
  	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 2nd Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 3rd Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 4th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1 20($t0)
	sw $t2 24($t0)
	addi $t0 $t0, 256
	# 5th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 6th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 7th Row
	sw $t2, 0($t0)
	sw $t2, 4($t0)
  	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0, $t0, -1500
	

drawR3:
	# 1st Row
 	sw $t2, 0($t0)
	sw $t2, 4($t0)
  	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	addi $t0 $t0, 256
	# 2nd Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 3rd Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 4th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 5th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t1, 20($t0)
	sw $t2, 24($t0)
	addi $t0 $t0, 256
	# 6th Row
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 20($t0)
	sw $t1, 24($t0)
	sw $t2, 28($t0)
	addi $t0 $t0, 256
	# 7th Row
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	lw $gp, A
	lw $t0, displayAddress
	# End of Function
	jr $ra
#---------------void drawPressQ()------------------#
# This function draws the prompt to start the game #  
#                                                  #
# Arguments:                                       #
# -None                                            #
#--------------------------------------------------#
drawPressQ:
	lw $t0, displayAddress              # $t0 stores the base address for display  
	li $t1, 0xffdd00                     # $t1 stores the yellow colour code  
	li $t2, 0xffffff
	li $t3, 0x000000
	addi $t0, $t0, 12572
# Draw Q
	# 1st Row
	sw $t3, 4($t0)
  	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	addi $t0 $t0, 256
	
	# 2nd Row
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# 3rd Row
	sw $t3, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	
	#4th Row
	sw $t3, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t3, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256

	# 5th Row
	sw $t3, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t3, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# 6th Row
	sw $t3, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256

	# 7th Row
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# 8th Row
	sw $t3, 4($t0)
  	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0, $t0, -988
	
# Draw " - "	
	# 1st Row
	sw $t3, 4($t0)
  	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	addi $t0 $t0, 256
	# 2nd Row
	sw $t3, 4($t0)
  	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t3, 20($t0)
	addi $t0 $t0, 256
	# 3rd Row
	sw $t3, 4($t0)
  	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	addi $t0, $t0, -1248
# Draw P
	# 1st Row
 	sw $t3, 0($t0)
	sw $t3, 4($t0)
  	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	addi $t0 $t0, 256
	# 2nd Row
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# 3rd Row
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t3, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# 4th Row
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t3, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# 5th Row
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# 6th Row
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	addi $t0 $t0, 256
	# 7th Row
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t3, 12($t0)

	addi $t0 $t0, 256
	# 8th Row
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	addi $t0, $t0, -1756
# Draw L
	# Row 1
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	addi $t0 $t0, 256
	# Row 2
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t3, 12($t0)
	addi $t0 $t0, 256
	# Row 3
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t3, 12($t0)
	addi $t0 $t0, 256
	# Row 4
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t3, 12($t0)
	addi $t0 $t0, 256
	# Row 5
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t3, 12($t0)
	addi $t0 $t0, 256
	# Row 6
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 7
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 8
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0, $t0, -1756
# DRAW A
	# 1st Row
	sw $t3, 4($t0)
  	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	addi $t0 $t0, 256
	
	# 2nd Row
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# 3rd + 4th Row
	li $t5, 0
A3:     beq $t5, 2, endA3
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t3, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	addi $t5, $t5, 1
	j A3
endA3:	
	# 5th Row
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# 6th Row
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# 7th Row
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# 8th Row
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0, $t0, -1756
# Draw Y
	# Row 1
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 2
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 3
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 4
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 5
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 6
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 7
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 8
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)

	lw $gp, A
	lw $t0, displayAddress
	# End of Function
	jr $ra
	
	
#--------------void drawGameOver()-----------------#
# This function draws the title for the game       #  
#                                                  #
# Arguments:                                       #
# -None                                            #
#--------------------------------------------------#
drawGameOver:
	lw $t0, displayAddress              # $t0 stores the base address for display  
	# If you win the game, letters are green and white, if you lose, letters are orange and yellow
	beq $s7, 3868, green	
orange: li $t1, 0xeb7a34   		    # $t1 stores the orange colour code  
	li $t2, 0xffdd00  		    # $t2 stores the yellow colour code  
	j cont6
green:  li $t1, 0xb9f007		    # $t1 stores the green colour code  
	li $t2, 0xffffff                    # $t2 stores the white colour code
cont6:	li $t3, 0x000000		    # $t3 stores the black colour code
	addi $t0, $t0, 3128
# GAME
# DRAW G	
	# Row 1
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 2
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 3
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 4
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t3, 12($t0)
	addi $t0 $t0, 256
	# Row 5
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 6
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 7
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 8
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0, $t0, -1756
# DRAW A
	# 1st Row
	sw $t3, 4($t0)
  	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	addi $t0 $t0, 256
	
	# 2nd Row
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# 3rd + 4th Row
	li $t5, 0
A4:     beq $t5, 2, endA4
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t3, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	addi $t5, $t5, 1
	j A4
endA4:	
	# 5th Row
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# 6th Row
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# 7th Row
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# 8th Row
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0, $t0, -1756
# DRAW M
	# Row 1
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 2
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t3, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 3
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 4
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t3, 12($t0)
	sw $t2, 16($t0)
	sw $t3, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 5
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 6
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t3, 12($t0)

	sw $t3, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 7
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t3, 12($t0)

	sw $t3, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 8
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)

	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0, $t0, -1756
# DRAW E
	# Row 1
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 2
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 3
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 4
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t3, 24($t0)
	addi $t0 $t0, 256
	# Row 5
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 6
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 7
	sw $t3, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 8
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0, $t0, 408
# OVER
# DRAW O
	# 1st Row
	sw $t3, 4($t0)
  	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	addi $t0 $t0, 256
	
	# 2nd Row
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# 3rd Row
	sw $t3, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	
	#4th Row
	sw $t3, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t3, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256

	# 5th Row
	sw $t3, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t3, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# 6th Row
	sw $t3, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256

	# 7th Row
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# 8th Row
	sw $t3, 4($t0)
  	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	addi $t0, $t0, -1756
# Draw V
	# 1st Row
	sw $t3, 0($t0)
	sw $t3, 4($t0)
  	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	
	# 2nd Row
	sw $t3, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 20($t0)
	sw $t1, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# 3rd Row
	sw $t3, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 20($t0)
	sw $t1, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	
	#4th Row
	sw $t3, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 20($t0)
	sw $t1, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256

	# 5th Row
	sw $t3, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t3, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# 6th Row
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256

	# 7th Row

	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)

	addi $t0 $t0, 256
	# 8th Row

  	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)

	addi $t0, $t0, -1756
# Draw E
	# Row 1
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 2
	sw $t3, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 3
	sw $t3, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 4
	sw $t3, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t3, 24($t0)
	addi $t0 $t0, 256
	# Row 5
	sw $t3, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 6
	sw $t3, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 7
	sw $t3, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# Row 8
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0, $t0, -1756
# Draw R
	# 1st Row
 	sw $t3, 0($t0)
	sw $t3, 4($t0)
  	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	addi $t0 $t0, 256
	# 2nd Row
	sw $t3, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# 3rd Row
	sw $t3, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# 4th Row
	sw $t3, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# 4th Row
	sw $t3, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# 6th Row
	sw $t3, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t1, 20($t0)
	sw $t3, 24($t0)
	addi $t0 $t0, 256
	# 7th Row
	sw $t3, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 20($t0)
	sw $t1, 24($t0)
	sw $t3, 28($t0)
	addi $t0 $t0, 256
	# 8th Row
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	# END OF FUNCTION
	lw $gp, A
	lw $t0, displayAddress
	jr $ra
#--------------void drawPU(adr)--------------------# 
# This function draws a power up object  	   #
# at a given location at the top of the screen     #  
#                                                  #  
# Arguments                                        #
# adr                                              #          
#--------------------------------------------------#	
	
drawPU: 
	# Load adr
	lw $t0, 0($sp)
	addi $sp ,$sp, 4
	
	lw $t5, PUType
	beq $t5, 0, life
	beq $t5, 1, shield
	
life:	li $t1, 0x068199
	li $t2, 0xff0303	
	li $t3, 0x000000
	
	
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	addi $t0, $t0, 256
	
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t1, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	addi $t0, $t0, 256
	
	sw $t1, 0($t0)
	sw $t3, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t3, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	sw $t1, 32($t0)
	addi $t0, $t0, 256
	
	sw $t1, 0($t0)
	sw $t3, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	sw $t1, 32($t0)
	addi $t0, $t0, 256
	
	sw $t1, 0($t0)
	sw $t3, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	sw $t1, 32($t0)
	addi $t0, $t0, 256
	
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t3, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t3, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	addi $t0, $t0, 256
	

	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t3, 12($t0)
	sw $t2, 16($t0)
	sw $t3, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	addi $t0, $t0, 256
	
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t3, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	addi $t0, $t0, 256
	
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	addi $t0, $t0, 256
	j endDPU
# SHIELD
shield: li $t1, 0x058719
	li $t2, 0x8c8c8c
	li $t3, 0x000000
	
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	addi $t0, $t0, 256
	
	sw $t1, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	sw $t1, 32($t0)
	addi $t0, $t0, 256
	
	sw $t1, 0($t0)
	sw $t3, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	sw $t1, 32($t0)
	addi $t0, $t0, 256
	
	sw $t1, 0($t0)
	sw $t3, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	sw $t1, 32($t0)
	addi $t0, $t0, 256
	
	sw $t1, 0($t0)
	sw $t3, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	sw $t1, 32($t0)
	addi $t0, $t0, 256
	
	sw $t1, 0($t0)
	sw $t3, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	sw $t3, 28($t0)
	sw $t1, 32($t0)
	addi $t0, $t0, 256
	

	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t3, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t3, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	addi $t0, $t0, 256
	
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	addi $t0, $t0, 256
	
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	addi $t0, $t0, 256	
										
endDPU:												
	lw $gp, A
	lw $t0, displayAddress
	#END OF FUNCTION
	jr $ra

#-------------void drawRoadBlock(adr)--------------# 
# This function draws the roadblock for level 2    #
# at a given location at the top of the screen     #  
#                                                  #  
# Arguments                                        #
# adr                                              #          
#--------------------------------------------------#
drawRoadBlock:
	# Load adr
	lw $t0, 0($sp)
	addi $sp ,$sp, 4 
	li $t1, 0xd4d4d2             # $t1 stores light grey
	
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	sw $t1, 36($t0)
	addi $t0, $t0, 256
	
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	sw $t1, 36($t0)
	addi $t0, $t0, 256
	
	lw $gp, A
	lw $t0, displayAddress
	#END OF FUNCTION
	jr $ra














	
	
	
