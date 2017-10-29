.syntax unified
.cpu cortex-m4
.thumb

.data
    student_id1: .byte 0, 4, 1, 0, 1, 3, 7 //TODO: put your student id here
    student_id2: .byte 0, 4, 1, 6, 3, 2, 4
    fib_ans: .asciz "01123581321345589144233377610987159725844181676510946177112865746368750251213931964183178115142298320401346269217830935245785702887922746514930352241578173908816963245986:1"
    ans_digit: .byte 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x2, 0x2, 0x2, 0x2, 0x2, 0x3, 0x3, 0x3, 0x3, 0x3, 0x4, 0x4, 0x4, 0x4, 0x5, 0x5, 0x5, 0x5, 0x5, 0x6, 0x6, 0x6, 0x6, 0x6, 0x7, 0x7, 0x7, 0x7, 0x7, 0x8, 0x8, 0x8, 0x8, 0x2

.text
    .global main
    .equ	RCC_AHB2ENR,	0x4002104C
    .equ	GPIOA_MODER,	0x48000000
    .equ	GPIOA_OSPEEDER,	0x48000008
    .equ	GPIOA_PUPDR,	0x4800000C
    .equ	GPIOA_IDR,		0x48000010
    .equ	GPIOA_ODR,		0x48000014
    .equ	GPIOA_BSRR,		0x48000018 //set bit
    .equ	GPIOA_BRR,		0x48000028 //clear bit

    //Din, CS, CLK offset
    .equ 	DIN,	0b100000 	//PA5
    .equ	CS,		0b1000000	//PA6
    .equ	CLK,	0b10000000	//PA7

    //max7219
    .equ	DECODE,			0x19 //�ѽX����
    .equ	INTENSITY,		0x1A //�G�ױ���
    .equ	SCAN_LIMIT,		0x1B //�]�w���ܽd��
    .equ	SHUT_DOWN,		0x1C //����
    .equ	DISPLAY_TEST,	0x1F //���ܴ���

    //button
    /*GPIOC for button*/
    .equ GPIOC_MODER  , 0x48000800
    .equ GPIOC_OTYPER ,	0x48000804
    .equ GPIOC_OSPEEDR,	0x48000808
    .equ GPIOC_PUPDR  ,	0x4800080c
    .equ GPIOC_IDR    , 0x48000810

    //
    .equ one_sec, 5400000
main:
    BL   GPIO_init
    BL   max7219_init

    BL	Display_fibo_number
    BX LR
//use r0 for digit of current number, in ans_digit, or the accumulation in fibonacci
//use r1 for get data in fibonacci array
//use r2 for accumulation the pointer in fibonacci array
//use r3 for the address of fibonacci array
//use r4 for get the current digit
//use r5 to get the button data
//use r8 to get data from button
Display_fibo_number:
    ldr r3, =fib_ans
    ldr r0, =ans_digit
    ldrb r0, [r0,r4]
display_loop:

    subs r0, r0, 1 //digit -1
    ldrb r1, [r3,r2]

    push {r0}
    mov r0, 0x0

    b check_button
    check_end:

    pop {r0}
    bl MAX7219Send

    adds r2, r2, 1 //arr idex +1
    cmp r0, 0 //digit == 1
    bne display_loop

    b Display_fibo_number

check_button: //check every cycle, and accumulate 1
    ldr r5, [r8] //fetch the data from button
    lsr r5, r5, #13
    and r5, r5, 0x1 //filter the signal

    cmp r5, #0 //FUCK DONT KNOW WHY THE PRESSED SIGNAL IS 0
    it eq
    addeq r0, r0 ,#1 //accumulate until the threshol

    cmp r5, #1 //not stable, go back to accumulate again
    it eq
    moveq r0, #0

    cmp r0, #1000 //threshold achieved BREAKDOWN!
    it eq
    addeq r4, r4, 0x1//go to next fibonacci digit

    cmp r0, #1000 //threshold achieved BREAKDOWN!
    it eq
    addeq r2, r2, 0x1 //move to the start of next fibonacci digit

    ldr r9, =one_sec
    cmp r0, r9
    beq clear_to_zero

    b check_end
clear_to_zero:
    mov r1,0x0
    mov r0,0x1
    b check_end
GPIO_init:
    //TODO: Initialize three GPIO pins as output for max7219 DIN, CS and CLK
    //RCC_AHB2ENR: enable GPIOA
    mov r0, 0b1
    ldr r1, =RCC_AHB2ENR
    str r0, [r1]

    //GPIOA_MODER: PA2,1,0: output
    ldr r0, =0b010101
    lsl r0, 10
    ldr r1, =GPIOA_MODER
    ldr r2, [r1]
    and r2, 0xFFFF03FF //clear 2 1 0
    orrs r2, r2, r0 //2 1 0 --> output
    str r2, [r1]

    //GPIOA_OTYPER: push-pull (reset state)
    //GPIO_OSPEEDR: high speed
    mov r0, 0b101010 //PA2,1,0: high speed
    lsl r0, 10
    ldr r1, =GPIOA_OSPEEDER
    ldr r2, [r1]
    and r2, 0xFFFF03FF
    orrs r2, r2, r0
    str r0, [r1]


    //enable the port c GPIOC_MODER for input mode
	ldr r0, =GPIOC_MODER
	ldr r1, [r0]
	//clear pc13 to zero
	and r1, r1, 0xf3ffffff

	str r1,	[r0]

	//otype is default to pp , no need to change

	//usage r4 for button data input value address in the future

	ldr r8, =GPIOC_IDR
  	BX LR


    BX LR

MAX7219Send:
    //input parameter: r0 is ADDRESS , r1 is DATA
    //TODO: Use this function to send a message to max7219
    push {r0, r1, r2, r3, r4, r5, r6, r7, LR}
    lsl	r0, 8 //move to D15-D8
    add r0, r1 //r0 == din
    ldr r1, =DIN
    ldr r2, =CS
    ldr r3, =CLK
    ldr r4, =GPIOA_BSRR //-> 1
    ldr r5, =GPIOA_BRR //-> 0
    ldr r6, =0xF //now sending (r6)-th bit
    //b send_loop

send_loop:
    mov r7, 1
    lsl r7, r6 //left shift to get the data in current digit
    str r3, [r5] //CLK -> 0
    tst r0, r7 //同ANDS但不存結果 (update condition flags)
    beq bit_not_set //r0要送的那位!=1
    sub r1, r1, #48
    str r1, [r4] //din -> 1
    b if_done

bit_not_set: //send clear bit
    str r1, [r5] //din -> 0

if_done:
    str r3, [r4] //CLK -> 1 r3 use as clock
    subs r6, 0x1
    bge send_loop
    str r2, [r5] //CS -> 0
    str r2, [r4] //CS -> 1
    pop {r0, r1, r2, r3, r4, r5, r6, r7, PC}
    BX LR

max7219_init:
    //TODO: Initialize max7219 registers
    push {r0, r1, LR}
    ldr r0, =DECODE
    ldr r1, =0xFF //CODE B decode for digit 0-7
    bl MAX7219Send

    ldr r0, =DISPLAY_TEST
    ldr r1, =0x0 //normal operation
    bl MAX7219Send

    ldr r0, =INTENSITY
    ldr r1, =0xA //�G�� 21/32
    bl MAX7219Send

    ldr r0, =SCAN_LIMIT
    ldr r1, =0x6 //light up digit 0-6
    bl MAX7219Send

    ldr r0, =SHUT_DOWN
    ldr r1, =0x1 //normal operation
    bl MAX7219Send

    pop {r0, r1, PC}
    BX LR