/*gpio reference http://www.nimblemachines.com/stm32-gpio/*/
.syntax unified
.cpu cortex-m4
.thumb

.data
leds: .byte 0

.text
	/*Start from manual p75 of GPIO Address data*/
	.global main
	.equ RCC_AHB2ENR  , 0x4002104C
	.equ GPIOB_MODER  , 0x48000400
	.equ GPIOB_OTYPER , 0x48000404
	.equ GPIOB_OSPEEDR, 0x48000408
	.equ GPIOB_PUPDR  , 0x4800040C
	.equ GPIOB_ODR    , 0x48000414
	.equ onesec, 800000
	.equ interval_cnt, 200000
	/*GPIOC for button*/
	.equ GPIOC_MODER  , 0x48000800
	.equ GPIOC_OTYPER ,	0x48000804
	.equ GPIOC_OSPEEDR,	0x48000808
	.equ GPIOC_PUPDR  ,	0x4800080c
	.equ GPIOC_IDR    , 0x48000810
	//.equ debounce_delay_time,24000 //800k for 1 sec moving the led, button bounce for 10-20m, hence use 800000(30/1000)=24k for interval

main:
    BL GPIO_init
	MOVS	R1, #1
	LDR	R0, =leds
	STRB	R1, [R0]
	mov r6, #1
	bl first_led
	b Loop
	//use r7 for sampling probing logic
	//use r6 for flag of moving, default 1 (moving) 0 stop, eor with 1 for bit inverse
	//use r5 to get data from button
	//use r4 to get the address of button
	//use r3 for counter values	ex for moving and shift left/right
	//use r2 for led data output value address in the future
	//use r1 for output the led data value
first_led:
	mov r1, 0xfff3
	strh r1, [r2]
	bx lr
Loop:
	//TODO: Write the display pattern into leds variable

	//BL		DisplayLED

	switch_left:
	mov r3, 0x0
	b goleft
	switch_right:
	mov r3, 0x0
	b goright
	B		Loop

GPIO_init:
  	//TODO: Initial LED GPIO pins as output
	//enable the gpio port b to do the tasks
	ldr r0, =RCC_AHB2ENR
	mov r1, 0b110
	str r1, [r0]

	//enable the port b GPIOB_MODER for output mode
	ldr r0, =GPIOB_MODER
	ldr r1, [r0] //get originally initilized reset value 0xFFFFFEBF
	mov r2, 0x00001540 //0001010101(pb_mode6 to pb_mode3)000000
	//clear pb6~pb3 to zero
	and r1, r1, 0xFFFFC03F //FFFF1100000000111111 from manual p25
	orr r1, r1, r2 //get the value of  FFFF|11|00000000|111111 or 0000|00|01010101|000000
	str r1,	[r0]

	//otype is default to pp , no need to change
	//set the speed , defulat value is 0x00000000 low speed, now use high speed
	mov r1, 0x00002A80
	ldr r0, =GPIOB_OSPEEDR
	str r1, [r0]
	//usage r2 for led data output value address in the future
	//ldr r2, =GPIOB_ODR

	//enable the port c GPIOC_MODER for input mode
	ldr r0, =GPIOC_MODER
	ldr r1, [r0]
	//clear pc13 to zero
	and r1, r1, 0xf3ffffff

	str r1,	[r0]

	//otype is default to pp , no need to change
	/*mov r1, 0x08000000
	ldr r0, =GPIOC_OSPEEDR
	str r1, [r0]*/
	//usage r4 for button data input value address in the future
	ldr r2, =GPIOB_ODR
	ldr r4, =GPIOC_IDR
  	BX LR
	/*
	DisplayLED:
							//		  76543210
	mov r1, 0xffffffe7 //FFFF|1111111111100111
	strh r1,[r2]
	bx lr
	*/
goleft:
	push {r3}
	ldr r3, =interval_cnt
	mov r0, #0 //threshold 1000 stable 1000 secs
	bl delay

	cmp r6, #0 //1 move 0 stop_move_left
	pop {r3} //regain the moving counter
	beq stop_move_left

	lsl r1, r1, #1 /*cmp r1, 0xffffff38cmp r1, 0b11111111111111111111111100111000 //leftboundary*/

 	cmp r3, #3 //special case of shift logic
 	it eq//special case of shift logic
 	moveq r1,0xff3f //special case of shift logic
	add r3, r3, #1 //move_left_counter++

	stop_move_left:

 	strh r1,[r2] //srote to output value

	cmp r3,#4 //cmp if need to switch direction
	beq switch_right
	bne goleft
goright:
	push {r3}
	ldr r3, =interval_cnt
	mov r0, #0 //threshold 1000 stable 1000 secs
	bl delay

	cmp r6, #0 //1 move 0 stop_move_right
	pop {r3} //regain the moving counter
	beq stop_move_right

	lsr r1, r1, #1 /*cmp r1, 0xffffff38cmp r1, 0b11111111111111111111111111110000 //rightboundary*/
	
	add r3, r3, #1

	stop_move_right:
	strh r1,[r2] //srote to output value

	cmp r3,#4 //cmp if need to switch direction
	beq switch_left
	bne goright

delay:
   //TODO: Write a delay 1sec function
	sub r3, r3, #1

	b check_button
	check_end:
	cmp r3, #0
	bne delay
	bx lr

check_button: //check every cycle, and accumulate 1
	ldr r5, [r4] //fetch the data from button
	lsr r5, r5, #13
	and r5, r5, 0x1 //filter the signal
	cmp r5, #0 //FUCK DONT KNOW WHY THE PRESSED SIGNAL IS 0
	it eq
	addeq r0, r0 ,#1 //accumulate until the threshold

	cmp r5, #1 //not stable, go back to accumulate again
	it eq
	moveq r0, #1

	cmp r0, #1000 //threshold achieved BREAKDOWN!
	it eq
	eoreq r6, r6, #1 //r6^=1

	b check_end
/*
fedbca9876543210
1111111111110011 initialize
1111111111100110 lsl 1
1111111111001100 lsl 2
1111111110011000 lsl 3
1111111100110000 lsl 4
0111111110011000 lsr 1
0011111111001100 lsr 2
0001111111100110 lsr 3
0000111111110011 lsr 4
*/
