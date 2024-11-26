; Programming Games for NES - pong

;*****************************************************************
; Define NES cartridge Header
;*****************************************************************

.segment "HEADER"
INES_MAPPER = 0 ; 0 = NROM
INES_MIRROR = 0 ; 0 = horizontal mirroring, 1 = vertical mirroring
INES_SRAM   = 0 ; 1 = battery backed SRAM at $6000-7FFF

.byte 'N', 'E', 'S', $1A ; ID 
.byte $02 ; 16k PRG bank count
.byte $01 ; 8k CHR bank count
.byte INES_MIRROR | (INES_SRAM << 1) | ((INES_MAPPER & $f) << 4)
.byte (INES_MAPPER & %11110000)
.byte $0, $0, $0, $0, $0, $0, $0, $0 ; padding

;*****************************************************************
; Import both the background and sprite character sets
;*****************************************************************

.segment "TILES"
.incbin "pong_cheat_update.chr"

;*****************************************************************
; Define NES interrupt vectors
;*****************************************************************

.segment "VECTORS"
.word nmi
.word reset
.word irq

;*****************************************************************
; 6502 Zero Page Memory (256 bytes)
;*****************************************************************

.segment "ZEROPAGE"
d_x:	.res 1 ; x velocity of ball
d_y:	.res 1 ; y velocity of ball
player1_score: .res 2 ; Score player 1 
player2_score: .res 2 ; Score player 2

;*****************************************************************
; Sprite OAM Data area - copied to VRAM in NMI routine
;*****************************************************************

.segment "OAM"
oam: .res 256	; sprite OAM data

;*****************************************************************
; Include NES Function Library
;*****************************************************************

.include "neslib.s"

;*****************************************************************
; Remainder of normal RAM area
;*****************************************************************

.segment "BSS"
palette: .res 32 ; current palette buffer

;*****************************************************************
; Main application entry point for starup/reset
;*****************************************************************

.segment "CODE"
.proc reset
	sei			; mask interrupts
	lda #0
	sta PPU_CONTROL	; disable NMI
	sta PPU_MASK	; disable rendering
	sta APU_DM_CONTROL	; disable DMC IRQ
	lda #40
	sta JOYPAD2		; disable APU frame IRQ

	cld			; disable decimal mode
	ldx #$FF
	txs			; initialise stack

	; wait for first vBlank
	bit PPU_STATUS
wait_vblank:
	bit PPU_STATUS
	bpl wait_vblank

	; clear all RAM to 0
	lda #0
	ldx #0
clear_ram:
	sta $0000,x
	sta $0100,x
	sta $0200,x
	sta $0300,x
	sta $0400,x
	sta $0500,x
	sta $0600,x
	sta $0700,x
	inx
	bne clear_ram

	; place all sprites offscreen at Y=255
	lda #255
	ldx #0
clear_oam:
	sta oam,x
	inx
	inx
	inx
	inx
	bne clear_oam

; wait for second vBlank
wait_vblank2:
	bit PPU_STATUS
	bpl wait_vblank2
	
	; NES is initialized and ready to begin
	; - enable the NMI for graphical updates and jump to our main program
	lda #%10001000
	sta PPU_CONTROL
	jmp main
.endproc

;*****************************************************************
; NMI Routine - called every vBlank
;*****************************************************************

.segment "CODE"
.proc nmi
	; save registers
	pha
	txa
	pha
	tya
	pha

	bit PPU_STATUS
	; transfer sprite OAM data using DMA
	lda #>oam
	sta SPRITE_DMA

	; transfer current palette to PPU
	vram_set_address $3F00
	ldx #0 ; transfer the 32 bytes to VRAM
@loop:
	lda palette, x
	sta PPU_VRAM_IO
	inx
	cpx #32
	bcc @loop

	; write current scroll and control settings
	lda #0
	sta PPU_VRAM_ADDRESS1
	sta PPU_VRAM_ADDRESS1
	lda ppu_ctl0
	sta PPU_CONTROL
	lda ppu_ctl1
	sta PPU_MASK

	; flag PPU update complete
	ldx #0
	stx nmi_ready

	; restore registers and return
	pla
	tay
	pla
	tax
	pla
	rti
.endproc

;*****************************************************************
; IRQ Clock Interrupt Routine
;*****************************************************************

.segment "CODE"
irq:
	rti

;*****************************************************************
; Main application logic section includes the game loop
;*****************************************************************
 .segment "CODE"
 .proc main
 	; main application - rendering is currently off

 	; initialize palette table
 	ldx #0

; place our middle bar bat sprite on the screen
 	lda #100
 	sta oam  ; set Y
 	lda #30
 	sta oam  + 3 ; set X
 	lda #6
	sta oam + 1
	lda #0
	sta oam + 2

	; place our top sprite on the screen
 	lda #92
 	sta oam +4  ; set Y
 	lda #30
 	sta oam  +4 + 3 ; set X
 	lda #7
	sta oam + 4 + 1
	lda #0
	sta oam + 4 + 2

	; place our bottom sprite on the screen
 	lda #116
 	sta oam +(2*4)  ; set Y
 	lda #30
 	sta oam  +(2*4) + 3 ; set X
 	lda #7
	sta oam +(2*4)+ 1
	lda #%10000000
	sta oam +(2*4) + 2

	; place our middel bar sprite on the screen
 	lda #108
 	sta oam +(3*4)  ; set Y
 	lda #30
 	sta oam  +(3*4) + 3 ; set X
 	lda #6
	sta oam +(3*4)+ 1
	lda #0
	sta oam +(3*4) + 2

	; place our player sprite on the screen
 	lda #108
 	sta oam +(10*4)  ; set Y
 	lda #23
 	sta oam  +(10*4) + 3 ; set X
 	lda #1
	sta oam +(10*4)+ 1
	lda #0
	sta oam +(10*4) + 2


	;Right Sprite

	; place our right middle bat sprite on the screen
 	lda #100
 	sta oam+(4*4)  ; set Y
 	lda # 256 - 30
 	sta oam+(4*4)  + 3 ; set X
 	lda #6
	sta oam+(4*4) + 1
	lda #%01000001
	sta oam+(4*4) + 2

	; place our right top sprite on the screen
 	lda #92
 	sta oam + (5*4)  ; set Y
 	lda #256 - 30
 	sta oam + (5*4) + 3 ; set X
 	lda #7
	sta oam +(5*4) + 1
	lda #%01000001
	sta oam + (5*4) + 2

	; place our right bottom sprite on the screen
 	lda #116
 	sta oam +(6*4)  ; set Y
 	lda #256 - 30
 	sta oam  +(6*4) + 3 ; set X
 	lda #7
	sta oam +(6*4)+ 1
	lda #%11000001
	sta oam +(6*4) + 2

	; place our right middle sprite on the screen
 	lda #108
 	sta oam +(7*4)  ; set Y
 	lda #256 - 30
 	sta oam  +(7*4) + 3 ; set X
 	lda #6
	sta oam +(7*4)+ 1
	lda #%01000001
	sta oam + (7*4) + 2

	; place our right player sprite on the screen
 	lda #108
 	sta oam +(9*4)  ; set Y
 	lda #256 - 23
 	sta oam  +(9*4) + 3 ; set X
 	lda #1
	sta oam +(9*4)+ 1
	lda #%01000001
	sta oam + (9*4) + 2



; place ball sprite on the screen

 	lda #124
 	sta oam + (8 * 4) ; set Y
 	sta oam + (8 * 4) + 3 ; set X
	lda #03
	sta $0f
 	lda $0f
 	sta oam + (8 * 4) + 1 ; set patter + (1 * 4)n
 	lda #2
 	sta oam + (8 * 4) + 2 ; set atttibutes

 	; set the ball velocity
 	lda #1
 	sta d_x
	lda #0
 	sta d_y

paletteloop:
	lda default_palette, x
	sta palette, x
	inx
	cpx #32
	bcc paletteloop



	jsr ppu_update




 mainloop:
 ; ball animation
	inc $1e
    lda $1e
    cmp #255 ;determens speed of animation
    bne skip_reset
    lda #00
    sta $1e

    inc $1f
    lda $1f
    cmp #06
    bne skip_reset
    lda #03
    sta $1f
    skip_reset:

    lda #124

     lda $1f
     sta oam + (8 * 4) + 1 ; set patter + (1 * 4)n
     lda #2
     sta oam + (8 * 4) + 2 ; set atttibutes

 ; skip reading controls if and change has not been drawn
 	lda nmi_ready
 	cmp #0
 	bne mainloop
 ; read the gamepad
 	jsr gamepad_poll
 	; now move the bat if left or right pressed
 	lda gamepad
 	and #PAD_U
 	beq NOT_GAMEPAD_UP
 		; gamepad has been pressed left
 		lda oam+(1*4) ; get current Y
 		cmp #0
 		beq NOT_GAMEPAD_UP
		lda oam
 		sec
 		sbc #2
 		sta oam ; change Y to the left
		lda oam +(1*4)
		sec
		sbc #2
		sta oam +(1*4)
		lda oam +(2*4)
		sec
		sbc #2
		sta oam +(2*4)
		lda oam +(3*4)
		sec
		sbc #2
		sta oam +(3*4)
		lda oam +(10*4)
		sec
		sbc #2
		sta oam +(10*4)
 NOT_GAMEPAD_UP:
 	lda gamepad
 	and #PAD_D
 	beq NOT_GAMEPAD_DOWN
 		; gamepad has been pressed right
 		lda oam + (2*4) ; get current Y
 		cmp #230
 		beq NOT_GAMEPAD_DOWN
		lda oam
 		clc
 		adc #2
 		sta oam ; change Y to the left
		lda oam +(1*4)
		clc
 		adc #2
		sta oam +(1*4)
		lda oam +(2*4)
		clc
 		adc #2
		sta oam +(2*4)
		lda oam +(3*4)
		clc
 		adc #2
		sta oam +(3*4)
		lda oam +(10*4)
		clc
 		adc #2
		sta oam +(10*4)
 NOT_GAMEPAD_DOWN:

 ; read the gamepad
 	jsr gamepad_poll_2
 	; now move the bat if left or right pressed
 	lda gamepad_2
 	and #PAD_U
 	beq NOT_GAMEPAD_UP_2
 		; gamepad has been pressed left
 		lda oam+(5*4) ; get current Y
 		cmp #0
 		beq NOT_GAMEPAD_UP_2
		lda oam +(4*4)
 		sec
 		sbc #2
 		sta oam +(4*4); change Y to the left
		lda oam +(5*4)
		sec
		sbc #2
		sta oam +(5*4)
		lda oam +(6*4)
		sec
		sbc #2
		sta oam +(6*4)
		lda oam +(7*4)
		sec
		sbc #2
		sta oam +(7*4)
		lda oam +(9*4)
		sec
		sbc #2
		sta oam +(9*4)
 NOT_GAMEPAD_UP_2:
 	lda gamepad_2
 	and #PAD_D
 	beq NOT_GAMEPAD_DOWN_2
 		; gamepad has been pressed right
 		lda oam + (6*4) ; get current Y
 		cmp #230
 		beq NOT_GAMEPAD_DOWN_2
		lda oam+(4*4)
 		clc
 		adc #2
 		sta oam +(4*4); change Y to the left
		lda oam +(5*4)
		clc
 		adc #2
		sta oam +(5*4)
		lda oam +(6*4)
		clc
 		adc #2
		sta oam +(6*4)
		lda oam +(7*4)
		clc
 		adc #2
		sta oam +(7*4)
		lda oam +(9*4)
		clc
 		adc #2
		sta oam +(9*4)
 NOT_GAMEPAD_DOWN_2:

	lda oam + (8 * 4) + 0
	clc
	adc d_y
	sta oam + (8 * 4) + 0
	cmp #0
	bne NOT_HITTOP
	lda #1
	sta d_y
 NOT_HITTOP:
 	lda oam + (8 * 4) + 0
 	cmp #210 ; have we hit the bottom border
 	bne NOT_HITBOTTOM
 		lda #$FF ; reverse direction (-1)
 		sta d_y
 NOT_HITBOTTOM:
 	lda oam + (8 * 4) + 3 ; get the current x
 	clc
 	adc d_x	; add the X velocity
 	sta oam + (8 * 4) + 3
 	cmp #0 ; have we hit the left border
 	bne NOT_HITLEFT
		jsr increment_ScorePlayer2
 		lda #1 ; reverse direction
 		sta d_x
 NOT_HITLEFT:
 	lda oam + (8 * 4) + 3
 	cmp #248 ; have we hit the right border
 	bne NOT_HITRIGHT
		jsr increment_ScorePlayer1
 		lda #$FF ; reverse direction (-1)
 		sta d_x
 NOT_HITRIGHT:

 collision_detection:
	;storing the ball information for collision detection
 	lda oam + (8*4)+3
	sta cx1

	lda oam + (8*4)
	sta cy1

	lda #6
	sta ch1
	sta cw1

TOP_HIT:
	;storing top sprite information for collision detection
	lda oam + (1*4)+3
	sta cx2

	lda oam + (1*4)
	sta cy2

	lda #6
	sta ch2
	sta cw2

	jsr collision_test
	bcc MIDDLE_HIT
	lda #$FF
	sta d_y
	lda #1 ; reverse direction
	sta d_x
	jmp end_of_left_collision
 MIDDLE_HIT:
 ;storing middle top sprite information for collision detection
	lda oam + (0*4)+3
	sta cx2

	lda oam + (0*4)
	sta cy2

	lda #6
	sta ch2
	sta cw2

	jsr collision_test
	bcc MIDDLE_SECOND_HIT
	lda #0
	sta d_y
	lda #2 ; reverse direction
	sta d_x
	jmp end_of_left_collision
MIDDLE_SECOND_HIT:
;storing middle bottom sprite information for collision detection
	lda oam + (3*4)+3
	sta cx2

	lda oam + (3*4)
	sta cy2

	lda #6
	sta ch2
	sta cw2

	jsr collision_test
	bcc BOTTOM_HIT
	lda #0
	sta d_y
	lda #2 ; reverse direction
	sta d_x
	jmp end_of_left_collision
BOTTOM_HIT:
;storing bottom sprite information for collision detection
lda oam + (2*4)+3
	sta cx2

	lda oam + (2*4)
	sta cy2

	lda #6
	sta ch2
	sta cw2

	jsr collision_test
	bcc end_of_left_collision
	lda #1
	sta d_y
	lda #1 ; reverse direction
	sta d_x
	jmp end_of_left_collision
end_of_left_collision:
TOP_HIT_RIGHT:
	;storing top right sprite information for collision detection
	lda oam + (5*4)+3
	sta cx2

	lda oam + (5*4)
	sta cy2

	lda #6
	sta ch2
	sta cw2

	jsr collision_test
	bcc MIDDLE_HIT_RIGHT
	lda #$FF
	sta d_y
	lda #$FF ; reverse direction
	sta d_x
	jmp end_of_right_collision
 MIDDLE_HIT_RIGHT:
 ;storing middle top righ sprite information for collision detection
	lda oam + (4*4)+3
	sta cx2

	lda oam + (4*4)
	sta cy2

	lda #6
	sta ch2
	sta cw2

	jsr collision_test
	bcc MIDDLE_SECOND_HIT_RIGHT
	lda #0
	sta d_y
	lda #$FE ; reverse direction
	sta d_x
	jmp end_of_right_collision
MIDDLE_SECOND_HIT_RIGHT:
;storing middle bottom right sprite information for collision detection
	lda oam + (7*4)+3
	sta cx2

	lda oam + (7*4)
	sta cy2

	lda #6
	sta ch2
	sta cw2

	jsr collision_test
	bcc BOTTOM_HIT_RIGHT
	lda #0
	sta d_y
	lda #$FE ; reverse direction
	sta d_x
	jmp end_of_right_collision
BOTTOM_HIT_RIGHT:
;storing bottom right sprite information for collision detection
lda oam + (6*4)+3
	sta cx2

	lda oam + (6*4)
	sta cy2

	lda #6
	sta ch2
	sta cw2

	jsr collision_test
	bcc end_of_right_collision
	lda #1
	sta d_y
	lda #$FF ; reverse direction
	sta d_x
	jmp end_of_right_collision
end_of_right_collision:

 ; ensure our changes are rendered
 	lda #1
 	sta nmi_ready
 	jmp mainloop

; scores
	increment_ScorePlayer1:
	inc player1_score
	lda #1
	sta d_x
	
	; set ball 
 	lda #124
 	sta oam + (8 * 4) ; set Y
 	sta oam + (8 * 4) + 3 ; set X

 	; set the ball velocity
 	lda #1
 	sta d_x

	lda #0
	sta d_y
	rts

	increment_ScorePlayer2:
	inc player2_score
	
	; set ball position to center
 	lda #124
 	sta oam + (8 * 4) ; set Y
 	sta oam + (8 * 4) + 3 ; set X

 	; set the ball velocity
 	lda #$ff
 	sta d_x

	lda #0
	sta d_y

	rts
	
.endproc

;*****************************************************************
; Display Title Screen
;*****************************************************************

paddr: .res 2 ; 16-bit address pointer

 .segment "CODE"

title_text:
.byte "M E G A  B L A S T",0

press_play_text:
.byte "PRESS FIRE TO BEGIN",0

title_attributes:
.byte %00000101,%00000101,%00000101,%00000101
.byte %00000101,%00000101,%00000101,%00000101

; .proc display_title_screen
; 	jsr ppu_off ; Wait for the screen to be drawn and then turn off drawing

; 	jsr clear_nametable ; Clear the 1st name table

; 	; Write our title text
; 	vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 6)
; 	assign_16i text_address, title_text
; 	jsr write_text

; 	; Write our press play text
; 	vram_set_address (NAME_TABLE_0_ADDRESS + 20 * 32 + 6)
; 	assign_16i text_address, press_play_text
; 	jsr write_text

; 	; Set the title text to use the 2nd palette entries
; 	vram_set_address (ATTRIBUTE_TABLE_0_ADDRESS + 8)
; 	assign_16i paddr, title_attributes
; 	ldy #0
; loop:
; 	lda (paddr),y
; 	sta PPU_VRAM_IO
; 	iny
; 	cpy #8
; 	bne loop

; 	jsr ppu_update ; Wait until the screen has been drawn

; 	rts
; .endproc

;*****************************************************************
; Display Main Game Screen
;*****************************************************************

.segment "RODATA"
; put the data in our data segment of the ROM
game_screen_mountain:
.byte 001,002,003,004,001,002,003,004,001,002,003,004,001,002,003,004
.byte 001,002,003,004,001,002,003,004,001,002,003,004,001,002,003,004
game_screen_scoreline:
.byte "SCORE 0000000"

.segment "CODE"
; .proc display_game_screen
; 	jsr ppu_off ; Wait for the screen to be drawn and then turn off drawing

; 	jsr clear_nametable ; Clear the 1st name table

; 	; output mountain line
; 	vram_set_address (NAME_TABLE_0_ADDRESS + 22 * 32)
; 	assign_16i paddr, game_screen_mountain
; 	ldy #0
; loop:
; 	lda (paddr),y
; 	sta PPU_VRAM_IO
; 	iny
; 	cpy #32
; 	bne loop

; 	; draw a base line
; 	vram_set_address (NAME_TABLE_0_ADDRESS + 26 * 32)
; 	ldy #0
; 	lda #9 ; tile number to repeat
; loop2:
; 	sta PPU_VRAM_IO
; 	iny
; 	cpy #32
; 	bne loop2

; 	; output the score section on the next line
; 	assign_16i paddr, game_screen_scoreline
; 	ldy #0
; loop3:
; 	lda (paddr),y
; 	sta PPU_VRAM_IO
; 	iny
; 	cpy #12
; 	bne loop3

; 	jsr ppu_update ; Wait until the screen has been drawn
; 	rts
; .endproc

;*****************************************************************
; Our default palette table has 16 entries for tiles and 16 entries for sprites
;*****************************************************************

.segment "RODATA"
default_palette:
.byte $0F,$15,$26,$37 ; bg0 purple/pink
.byte $0F,$19,$29,$39 ; bg1 green
.byte $0F,$11,$21,$31 ; bg2 blue
.byte $0F,$00,$10,$30 ; bg3 greyscale
.byte $0F,$34,$03,$12 ; sp0 player 1
.byte $0F,$37,$07,$16 ; sp1 player 2
.byte $0F,$00,$10,$20 ; sp2 ball
.byte $0F,$12,$22,$32 ; sp3 character
