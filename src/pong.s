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
.incbin "assets/pong.chr"

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
animbyte: .res 1
timer: .res 1
temp: .res 10

time: .res 2
lasttime: .res 1
level: .res 1
animate: .res 1
enemycooldown: .res 1
score: .res 3
update: .res 1
highscore: .res 3
lives: .res 1
player_dead: .res 1
flash: .res 1
shake: .res 1
enemycount: .res 1
displaylevel: .res 1

;*****************************************************************
; Sprite OAM Data area - copied to VRAM in NMI routine
;*****************************************************************

.segment "OAM"
oam: .res 256	; sprite OAM data

;*****************************************************************
; Include NES Function Library
;*****************************************************************

.include "neslib.s"

;**************************************************************
; Include Sound Engine and Sound Effects Data
;**************************************************************
.segment "CODE"
; FamiStudio config.
FAMISTUDIO_CFG_EXTERNAL = 1
FAMISTUDIO_CFG_DPCM_SUPPORT = 1
FAMISTUDIO_CFG_SFX_SUPPORT = 1
FAMISTUDIO_CFG_SFX_STREAMS = 2
FAMISTUDIO_CFG_EQUALIZER = 1
FAMISTUDIO_USE_VOLUME_TRACK = 1
FAMISTUDIO_USE_PITCH_TRACK = 1
FAMISTUDIO_USE_SLIDE_NOTES = 1
FAMISTUDIO_USE_VIBRATO = 1
FAMISTUDIO_USE_ARPEGGIO = 1
FAMISTUDIO_CFG_SMOOTH_VIBRATO = 1
FAMISTUDIO_USE_RELEASE_NOTES = 1
FAMISTUDIO_DPCM_OFF = $e000

; CA65-specifc config.
.define FAMISTUDIO_CA65_ZP_SEGMENT ZEROPAGE
.define FAMISTUDIO_CA65_RAM_SEGMENT BSS
.define FAMISTUDIO_CA65_CODE_SEGMENT CODE

.include "famistudio_ca65.s"

.include "SoundEngine.s"

.segment "ZEROPAGE"

sfx_channel: .res 1

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

; Play a sound effect
; a = sound effect to play
; sfx_channel = sound effects channel to use
;*********************************************************/
.segment "CODE"

.proc play_sfx
   sta temp+9 ; save sound effect number
   tya ; save current register values
   pha
   txa
   pha

   lda temp+9 ; get the sound effect number
   ldx sfx_channel ; choose the channel to play the sound effect on
   jsr famistudio_sfx_play

   pla ; restore register values
   tax
   pla
   tay
   rts
.endproc

;*****************************************************************
; IRQ Clock Interrupt Routine
;*****************************************************************

.segment "CODE"
irq:
	rti

; Score subroutines


;update_display:
 ;   JSR display_scores
  ;  JMP main

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

	jsr update_score

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

	jsr update_score

	rts

display_scores:
; Set PPU address to the location where the scores will be displayed
    LDA #$20
    STA PPU_VRAM_ADDRESS2
    LDA #$28
    STA PPU_VRAM_ADDRESS2

    ; Display player 1's score
    LDA player1_score
    JSR display_digit

    ; Move to the next position for player 2's score
    LDA #$20
    STA PPU_VRAM_ADDRESS2
    LDA #$37
    STA PPU_VRAM_ADDRESS2

    ; Display player 2's score
    LDA player2_score
    JSR display_digit
    RTS

display_digit:
    ; Convert the score to the corresponding tile number
    CLC
    ADC #$20  ; Tile 20 in CHR corresponds to the number 0
    STA PPU_VRAM_IO
    RTS
;*****************************************************************
; Main application logic section includes the game loop
;*****************************************************************
 .segment "CODE"
 .proc main
 	lda #1 ; C 
    ldx #0 
    ldy #0 
    jsr famistudio_init

    ldx #.lobyte(sounds) ; set address of sound effects
    ldy #.hibyte(sounds)
    jsr famistudio_sfx_init

 	; main application - rendering is currently off
	jsr display_scores
 	; initialize palette table
 	ldx #0



	; place our middle bar bat sprite on the screen
 	lda #118
 	sta oam  ; set Y
 	lda #30
 	sta oam  + 3 ; set X
 	lda #6
	sta oam + 1
	lda #0
	sta oam + 2

	; place our top sprite on the screen
 	lda #110
 	sta oam +4  ; set Y
 	lda #30
 	sta oam  +4 + 3 ; set X
 	lda #7
	sta oam + 4 + 1
	lda #0
	sta oam + 4 + 2

	; place our bottom sprite on the screen
 	lda #134
 	sta oam +(2*4)  ; set Y
 	lda #30
 	sta oam  +(2*4) + 3 ; set X
 	lda #7
	sta oam +(2*4)+ 1
	lda #%10000000
	sta oam +(2*4) + 2

	; place our middel bar sprite on the screen
 	lda #126
 	sta oam +(3*4)  ; set Y
 	lda #30
 	sta oam  +(3*4) + 3 ; set X
 	lda #6
	sta oam +(3*4)+ 1
	lda #0
	sta oam +(3*4) + 2

	; place our player sprite on the screen
 	lda #126
 	sta oam +(10*4)  ; set Y
 	lda #23
 	sta oam  +(10*4) + 3 ; set X
 	lda #1
	sta oam +(10*4)+ 1
	lda #0
	sta oam +(10*4) + 2


	;Right Sprite

	; place our right middle bat sprite on the screen
 	lda #118
 	sta oam+(4*4)  ; set Y
 	lda # 256 - 30
 	sta oam+(4*4)  + 3 ; set X
 	lda #6
	sta oam+(4*4) + 1
	lda #%01000001
	sta oam+(4*4) + 2

	; place our right top sprite on the screen
 	lda #110
 	sta oam + (5*4)  ; set Y
 	lda #256 - 30
 	sta oam + (5*4) + 3 ; set X
 	lda #7
	sta oam +(5*4) + 1
	lda #%01000001
	sta oam + (5*4) + 2

	; place our right bottom sprite on the screen
 	lda #134
 	sta oam +(6*4)  ; set Y
 	lda #256 - 30
 	sta oam  +(6*4) + 3 ; set X
 	lda #7
	sta oam +(6*4)+ 1
	lda #%11000001
	sta oam +(6*4) + 2

	; place our right middle sprite on the screen
 	lda #126
 	sta oam +(7*4)  ; set Y
 	lda #256 - 30
 	sta oam  +(7*4) + 3 ; set X
 	lda #6
	sta oam +(7*4)+ 1
	lda #%01000001
	sta oam + (7*4) + 2

	; place our right player sprite on the screen
 	lda #126
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
 	sta oam + (8 * 4) + 1 ; set patter + (1 * 4)n
 	lda #2
 	sta oam + (8 * 4) + 2 ; set atttibutes

	paletteloop:
	lda default_palette, x
	sta palette, x
	inx
	cpx #32
	bcc paletteloop
	jsr ppu_update


	jsr ppu_off ; Wait for the screen to be drawn and then turn off drawing
 	jsr clear_nametable ; Clear the 1st name table

	;P
	vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 3)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 4)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 5)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 6)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 + 2)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 + 3)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 + 4)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 + 5)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 + 6)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 + 7)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 6 * 32 + 2)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 6 * 32 + 3)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 6 * 32 + 6)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 6 * 32 + 7)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 7 * 32 + 2)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 7 * 32 + 3)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 7 * 32 + 6)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 7 * 32 + 7)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 2)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 3)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 4)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 5)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 6)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 7)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 9 * 32 + 2)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 9 * 32 + 3)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 9 * 32 + 4)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 9 * 32 + 5)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 9 * 32 + 6)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 10 * 32 + 2)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 10 * 32 + 3)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 11 * 32 + 2)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 11 * 32 + 3)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO

;O
	vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 10)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 11)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 12)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 13)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 + 9)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 + 10)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 + 11)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 + 12)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 + 13)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 + 14)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 6 * 32 + 9)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 6 * 32 + 10)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 6 * 32 + 13)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 6 * 32 + 14)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 7 * 32 + 9)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 7 * 32 + 10)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 7 * 32 + 13)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 7 * 32 + 14)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 9)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 10)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 13)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 14)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 9 * 32 + 9)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 9 * 32 + 10)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 9 * 32 + 13)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 9 * 32 + 14)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 10 * 32 + 9)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 10 * 32 + 10)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 10 * 32 + 11)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 10 * 32 + 12)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 10 * 32 + 13)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 10 * 32 + 14)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 11 * 32 + 10)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 11 * 32 + 11)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 11 * 32 + 12)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 11 * 32 + 13)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	
;N
	vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 16)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 17)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 20)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 21)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 + 16)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 + 17)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 + 18)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 + 20)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 + 21)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 6 * 32 + 16)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 6 * 32 + 17)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 6 * 32 + 18)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 6 * 32 + 19)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 6 * 32 + 20)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 6 * 32 + 21)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 7 * 32 + 16)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 7 * 32 + 17)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 7 * 32 + 18)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 7 * 32 + 19)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 7 * 32 + 20)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 7 * 32 + 21)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 16)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 17)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 18)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 19)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 20)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 21)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 9 * 32 + 16)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 9 * 32 + 17)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 9 * 32 + 18)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 9 * 32 + 19)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 9 * 32 + 20)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 9 * 32 + 21)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 10 * 32 + 16)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 10 * 32 + 17)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 10 * 32 + 19)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 10 * 32 + 20)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 10 * 32 + 21)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 11 * 32 + 16)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 11 * 32 + 17)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 11 * 32 + 20)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 11 * 32 + 21)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO

	;G
	vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 24)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 25)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 26)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 27)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 28)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 + 23)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 + 24)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 + 25)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 + 26)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 + 27)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 + 28)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 6 * 32 + 23)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 6 * 32 + 24)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 7 * 32 + 23)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 7 * 32 + 24)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 7 * 32 + 26)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 7 * 32 + 27)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 7 * 32 + 28)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 23)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 24)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 28)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 29)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 9 * 32 + 23)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 9 * 32 + 24)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 9 * 32 + 28)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 9 * 32 + 29)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 10 * 32 + 23)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 10 * 32 + 24)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 10 * 32 + 25)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 10 * 32 + 26)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 10 * 32 + 27)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 10 * 32 + 28)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 10 * 32 + 29)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 11 * 32 + 24)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 11 * 32 + 25)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 11 * 32 + 26)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 11 * 32 + 27)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 11 * 32 + 28)
	ldy #0
	lda #$32 ; tile number to repeat
	sta PPU_VRAM_IO

;BY
	vram_set_address (NAME_TABLE_0_ADDRESS + 20 * 32 + 15)
	ldy #0
	lda #$2D ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 20 * 32 + 16)
	ldy #0
	lda #$44 ; tile number to repeat
	sta PPU_VRAM_IO

;NERDSQUAD
	vram_set_address (NAME_TABLE_0_ADDRESS + 22 * 32 + 12)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 22 * 32 + 13)
	ldy #0
	lda #$30 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 22 * 32 + 14)
	ldy #0
	lda #$3D ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 22 * 32 + 15)
	ldy #0
	lda #$2F ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 22 * 32 + 16)
	ldy #0
	lda #$3E ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 22 * 32 + 17)
	ldy #0
	lda #$3C ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 22 * 32 + 18)
	ldy #0
	lda #$40 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 22 * 32 + 19)
	ldy #0
	lda #$2C ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 22 * 32 + 20)
	ldy #0
	lda #$2F ; tile number to repeat
	sta PPU_VRAM_IO

;A TWO PLAYER
	vram_set_address (NAME_TABLE_0_ADDRESS + 26 * 32 + 3)
	ldy #0
	lda #$2C ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 26 * 32 + 5)
	ldy #0
	lda #$3F ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 26 * 32 + 6)
	ldy #0
	lda #$42 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 26 * 32 + 7)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 26 * 32 + 9)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 26 * 32 + 10)
	ldy #0
	lda #$37 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 26 * 32 + 11)
	ldy #0
	lda #$2C ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 26 * 32 + 12)
	ldy #0
	lda #$44 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 26 * 32 + 13)
	ldy #0
	lda #$30 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 26 * 32 + 14)
	ldy #0
	lda #$3D ; tile number to repeat
	sta PPU_VRAM_IO

;B ONE PLAYER
	vram_set_address (NAME_TABLE_0_ADDRESS + 26 * 32 + 17)
	ldy #0
	lda #$2D ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 26 * 32 + 19)
	ldy #0
	lda #$3A ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 26 * 32 + 20)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 26 * 32 + 21)
	ldy #0
	lda #$30 ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 26 * 32 + 23)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 26 * 32 + 24)
	ldy #0
	lda #$37 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 26 * 32 + 25)
	ldy #0
	lda #$2C ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 26 * 32 + 26)
	ldy #0
	lda #$44 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 26 * 32 + 27)
	ldy #0
	lda #$30 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 26 * 32 + 28)
	ldy #0
	lda #$3D ; tile number to repeat
	sta PPU_VRAM_IO

	jsr ppu_update	

title_screen:

jsr gamepad_poll
 	lda gamepad
 	and #PAD_A
 	beq NOT_A
		jmp multi_setup
NOT_A:
	lda gamepad
 	and #PAD_B
 	beq NOT_START
		jmp single_setup
NOT_START:
	

jmp title_screen

single_setup:
jsr display_game_screen
; place our middle bar bat sprite on the screen
 	lda #118
 	sta oam  ; set Y
 	lda #30
 	sta oam  + 3 ; set X
 	lda #6
	sta oam + 1
	lda #0
	sta oam + 2

	; place our top sprite on the screen
 	lda #110
 	sta oam +4  ; set Y
 	lda #30
 	sta oam  +4 + 3 ; set X
 	lda #7
	sta oam + 4 + 1
	lda #0
	sta oam + 4 + 2

	; place our bottom sprite on the screen
 	lda #134
 	sta oam +(2*4)  ; set Y
 	lda #30
 	sta oam  +(2*4) + 3 ; set X
 	lda #7
	sta oam +(2*4)+ 1
	lda #%10000000
	sta oam +(2*4) + 2

	; place our middel bar sprite on the screen
 	lda #126
 	sta oam +(3*4)  ; set Y
 	lda #30
 	sta oam  +(3*4) + 3 ; set X
 	lda #6
	sta oam +(3*4)+ 1
	lda #0
	sta oam +(3*4) + 2

	; place our player sprite on the screen
 	lda #126
 	sta oam +(10*4)  ; set Y
 	lda #23
 	sta oam  +(10*4) + 3 ; set X
 	lda #1
	sta oam +(10*4)+ 1
	lda #0
	sta oam +(10*4) + 2


	;Right Sprite

	; place our right middle bat sprite on the screen
 	lda #118
 	sta oam+(4*4)  ; set Y
 	lda # 256 - 30
 	sta oam+(4*4)  + 3 ; set X
 	lda #6
	sta oam+(4*4) + 1
	lda #%01000001
	sta oam+(4*4) + 2

	; place our right top sprite on the screen
 	lda #110
 	sta oam + (5*4)  ; set Y
 	lda #256 - 30
 	sta oam + (5*4) + 3 ; set X
 	lda #7
	sta oam +(5*4) + 1
	lda #%01000001
	sta oam + (5*4) + 2

	; place our right bottom sprite on the screen
 	lda #134
 	sta oam +(6*4)  ; set Y
 	lda #256 - 30
 	sta oam  +(6*4) + 3 ; set X
 	lda #7
	sta oam +(6*4)+ 1
	lda #%11000001
	sta oam +(6*4) + 2

	; place our right middle sprite on the screen
 	lda #126
 	sta oam +(7*4)  ; set Y
 	lda #256 - 30
 	sta oam  +(7*4) + 3 ; set X
 	lda #6
	sta oam +(7*4)+ 1
	lda #%01000001
	sta oam + (7*4) + 2

	; place our right player sprite on the screen
 	lda #126
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
 	sta oam + (8 * 4) + 1 ; set patter + (1 * 4)n
 	lda #2
 	sta oam + (8 * 4) + 2 ; set atttibutes

 	; set the ball velocity
 	lda #1
 	sta d_x
	lda #0
 	sta d_y

;place spectator sprite on screen;
	lda #215
 	sta oam + (11 * 4) ; set Y
	lda #100
 	sta oam + (11 * 4) + 3 ; set X
	lda #43
 	sta oam + (11 * 4) + 1 ; set patter + (1 * 4)n
 	lda #0
 	sta oam + (11 * 4) + 2 ; set atttibutes

	lda #215
 	sta oam + (12 * 4) ; set Y
	lda #125
 	sta oam + (12 * 4) + 3 ; set X
	lda #1
 	sta oam + (12 * 4) + 1 ; set patter + (1 * 4)n
 	lda #0
 	sta oam + (12 * 4) + 2 ; set atttibutes

	lda #215
 	sta oam + (13 * 4) ; set Y
	lda #150
 	sta oam + (13 * 4) + 3 ; set X
	lda #1
 	sta oam + (13 * 4) + 1 ; set patter + (1 * 4)n
 	lda #0
 	sta oam + (13 * 4) + 2 ; set atttibutes

	lda #215
 	sta oam + (14 * 4) ; set Y
	lda #175
 	sta oam + (14 * 4) + 3 ; set X
	lda #1
 	sta oam + (14 * 4) + 1 ; set patter + (1 * 4)n
 	lda #0
 	sta oam + (14 * 4) + 2 ; set atttibutes

	lda #215
 	sta oam + (15 * 4) ; set Y
	lda #75
 	sta oam + (15 * 4) + 3 ; set X
	lda #1
 	sta oam + (15 * 4) + 1 ; set patter + (1 * 4)n
 	lda #0
 	sta oam + (15 * 4) + 2 ; set atttibutes


	lda #215
 	sta oam + (17 * 4) ; set Y
	lda #50
 	sta oam + (17 * 4) + 3 ; set X
	lda #1
 	sta oam + (17 * 4) + 1 ; set patter + (1 * 4)n
 	lda #0
 	sta oam + (17 * 4) + 2 ; set atttibutes

	lda #215
 	sta oam + (18 * 4) ; set Y
	lda #200
 	sta oam + (18 * 4) + 3 ; set X
	lda #1
 	sta oam + (18 * 4) + 1 ; set patter + (1 * 4)n
 	lda #0
 	sta oam + (18 * 4) + 2 ; set atttibutes

	;bottom row of spectators

	lda #232
 	sta oam + (19 * 4) ; set Y
	lda #100
 	sta oam + (19 * 4) + 3 ; set X
	lda #1
 	sta oam + (19 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000001
 	sta oam + (19 * 4) + 2 ; set atttibutes

	lda #232
 	sta oam + (20 * 4) ; set Y
	lda #125
 	sta oam + (20 * 4) + 3 ; set X
	lda #1
 	sta oam + (20 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000001
 	sta oam + (20* 4) + 2 ; set atttibutes

	lda #232
 	sta oam + (21 * 4) ; set Y
	lda #150
 	sta oam + (21 * 4) + 3 ; set X
	lda #1
 	sta oam + (21 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000001
 	sta oam + (21 * 4) + 2 ; set atttibutes

	lda #232
 	sta oam + (22 * 4) ; set Y
	lda #175
 	sta oam + (22* 4) + 3 ; set X
	lda #1
 	sta oam + (22 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000001
 	sta oam + (22 * 4) + 2 ; set atttibutes

	lda #232
 	sta oam + (23 * 4) ; set Y
	lda #75
 	sta oam + (23 * 4) + 3 ; set X
	lda #1
 	sta oam + (23 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000001
 	sta oam + (23 * 4) + 2 ; set atttibutes

	lda #232
 	sta oam + (23 * 4) ; set Y
	lda #75
 	sta oam + (23 * 4) + 3 ; set X
	lda #1
 	sta oam + (23 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000001
 	sta oam + (23 * 4) + 2 ; set atttibutes

	lda #232
 	sta oam + (24 * 4) ; set Y
	lda #50
 	sta oam + (24 * 4) + 3 ; set X
	lda #1
 	sta oam + (24 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000001
 	sta oam + (24 * 4) + 2 ; set atttibutes

	lda #232
 	sta oam + (25 * 4) ; set Y
	lda #200
 	sta oam + (25 * 4) + 3 ; set X
	lda #1
 	sta oam + (25 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000001
 	sta oam + (25 * 4) + 2 ; set atttibutes

;Place second row of spectators
	lda #224
 	sta oam + (26 * 4) ; set Y
	lda #37
 	sta oam + (26 * 4) + 3 ; set X
	lda #1
 	sta oam + (26 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000000
 	sta oam + (26 * 4) + 2 ; set atttibutes

	lda #224
 	sta oam + (27 * 4) ; set Y
	lda #87
 	sta oam + (27 * 4) + 3 ; set X
	lda #1
 	sta oam + (27 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000000
 	sta oam + (27 * 4) + 2 ; set atttibutes

	lda #224
 	sta oam + (28 * 4) ; set Y
	lda #137
 	sta oam + (28 * 4) + 3 ; set X
	lda #1
 	sta oam + (28 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000000
 	sta oam + (28 * 4) + 2 ; set atttibutes

	lda #224
 	sta oam + (29 * 4) ; set Y
	lda #187
 	sta oam + (29 * 4) + 3 ; set X
	lda #1
 	sta oam + (29 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000000
 	sta oam + (29 * 4) + 2 ; set atttibutes

	lda #224
 	sta oam + (30 * 4) ; set Y
	lda #62
 	sta oam + (30 * 4) + 3 ; set X
	lda #1
 	sta oam + (30 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000001
 	sta oam + (30 * 4) + 2 ; set atttibutes

	lda #224
 	sta oam + (31 * 4) ; set Y
	lda #112
 	sta oam + (31 * 4) + 3 ; set X
	lda #1
 	sta oam + (31 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000001
 	sta oam + (31 * 4) + 2 ; set atttibutes

	lda #224
 	sta oam + (32 * 4) ; set Y
	lda #162
 	sta oam + (32 * 4) + 3 ; set X
	lda #1
 	sta oam + (32 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000001
 	sta oam + (32 * 4) + 2 ; set atttibutes

	lda #224
 	sta oam + (33 * 4) ; set Y
	lda #212
 	sta oam + (33 * 4) + 3 ; set X
	lda #43
 	sta oam + (33 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000001
 	sta oam + (33 * 4) + 2 ; set atttibutes
jmp mainloop_single

multi_setup:
jsr display_game_screen
; place our middle bar bat sprite on the screen
 	lda #118
 	sta oam  ; set Y
 	lda #30
 	sta oam  + 3 ; set X
 	lda #6
	sta oam + 1
	lda #0
	sta oam + 2

	; place our top sprite on the screen
 	lda #110
 	sta oam +4  ; set Y
 	lda #30
 	sta oam  +4 + 3 ; set X
 	lda #7
	sta oam + 4 + 1
	lda #0
	sta oam + 4 + 2

	; place our bottom sprite on the screen
 	lda #134
 	sta oam +(2*4)  ; set Y
 	lda #30
 	sta oam  +(2*4) + 3 ; set X
 	lda #7
	sta oam +(2*4)+ 1
	lda #%10000000
	sta oam +(2*4) + 2

	; place our middel bar sprite on the screen
 	lda #126
 	sta oam +(3*4)  ; set Y
 	lda #30
 	sta oam  +(3*4) + 3 ; set X
 	lda #6
	sta oam +(3*4)+ 1
	lda #0
	sta oam +(3*4) + 2

	; place our player sprite on the screen
 	lda #126
 	sta oam +(10*4)  ; set Y
 	lda #23
 	sta oam  +(10*4) + 3 ; set X
 	lda #1
	sta oam +(10*4)+ 1
	lda #0
	sta oam +(10*4) + 2


	;Right Sprite

	; place our right middle bat sprite on the screen
 	lda #118
 	sta oam+(4*4)  ; set Y
 	lda # 256 - 30
 	sta oam+(4*4)  + 3 ; set X
 	lda #6
	sta oam+(4*4) + 1
	lda #%01000001
	sta oam+(4*4) + 2

	; place our right top sprite on the screen
 	lda #110
 	sta oam + (5*4)  ; set Y
 	lda #256 - 30
 	sta oam + (5*4) + 3 ; set X
 	lda #7
	sta oam +(5*4) + 1
	lda #%01000001
	sta oam + (5*4) + 2

	; place our right bottom sprite on the screen
 	lda #134
 	sta oam +(6*4)  ; set Y
 	lda #256 - 30
 	sta oam  +(6*4) + 3 ; set X
 	lda #7
	sta oam +(6*4)+ 1
	lda #%11000001
	sta oam +(6*4) + 2

	; place our right middle sprite on the screen
 	lda #126
 	sta oam +(7*4)  ; set Y
 	lda #256 - 30
 	sta oam  +(7*4) + 3 ; set X
 	lda #6
	sta oam +(7*4)+ 1
	lda #%01000001
	sta oam + (7*4) + 2

	; place our right player sprite on the screen
 	lda #126
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
 	sta oam + (8 * 4) + 1 ; set patter + (1 * 4)n
 	lda #2
 	sta oam + (8 * 4) + 2 ; set atttibutes

 	; set the ball velocity
 	lda #1
 	sta d_x
	lda #0
 	sta d_y

;place spectator sprite on screen;
	lda #215
 	sta oam + (11 * 4) ; set Y
	lda #100
 	sta oam + (11 * 4) + 3 ; set X
	lda #43
 	sta oam + (11 * 4) + 1 ; set patter + (1 * 4)n
 	lda #0
 	sta oam + (11 * 4) + 2 ; set atttibutes

	lda #215
 	sta oam + (12 * 4) ; set Y
	lda #125
 	sta oam + (12 * 4) + 3 ; set X
	lda #1
 	sta oam + (12 * 4) + 1 ; set patter + (1 * 4)n
 	lda #0
 	sta oam + (12 * 4) + 2 ; set atttibutes

	lda #215
 	sta oam + (13 * 4) ; set Y
	lda #150
 	sta oam + (13 * 4) + 3 ; set X
	lda #1
 	sta oam + (13 * 4) + 1 ; set patter + (1 * 4)n
 	lda #0
 	sta oam + (13 * 4) + 2 ; set atttibutes

	lda #215
 	sta oam + (14 * 4) ; set Y
	lda #175
 	sta oam + (14 * 4) + 3 ; set X
	lda #1
 	sta oam + (14 * 4) + 1 ; set patter + (1 * 4)n
 	lda #0
 	sta oam + (14 * 4) + 2 ; set atttibutes

	lda #215
 	sta oam + (15 * 4) ; set Y
	lda #75
 	sta oam + (15 * 4) + 3 ; set X
	lda #1
 	sta oam + (15 * 4) + 1 ; set patter + (1 * 4)n
 	lda #0
 	sta oam + (15 * 4) + 2 ; set atttibutes


	lda #215
 	sta oam + (17 * 4) ; set Y
	lda #50
 	sta oam + (17 * 4) + 3 ; set X
	lda #1
 	sta oam + (17 * 4) + 1 ; set patter + (1 * 4)n
 	lda #0
 	sta oam + (17 * 4) + 2 ; set atttibutes

	lda #215
 	sta oam + (18 * 4) ; set Y
	lda #200
 	sta oam + (18 * 4) + 3 ; set X
	lda #1
 	sta oam + (18 * 4) + 1 ; set patter + (1 * 4)n
 	lda #0
 	sta oam + (18 * 4) + 2 ; set atttibutes

	;bottom row of spectators

	lda #232
 	sta oam + (19 * 4) ; set Y
	lda #100
 	sta oam + (19 * 4) + 3 ; set X
	lda #1
 	sta oam + (19 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000001
 	sta oam + (19 * 4) + 2 ; set atttibutes

	lda #232
 	sta oam + (20 * 4) ; set Y
	lda #125
 	sta oam + (20 * 4) + 3 ; set X
	lda #1
 	sta oam + (20 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000001
 	sta oam + (20* 4) + 2 ; set atttibutes

	lda #232
 	sta oam + (21 * 4) ; set Y
	lda #150
 	sta oam + (21 * 4) + 3 ; set X
	lda #1
 	sta oam + (21 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000001
 	sta oam + (21 * 4) + 2 ; set atttibutes

	lda #232
 	sta oam + (22 * 4) ; set Y
	lda #175
 	sta oam + (22* 4) + 3 ; set X
	lda #1
 	sta oam + (22 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000001
 	sta oam + (22 * 4) + 2 ; set atttibutes

	lda #232
 	sta oam + (23 * 4) ; set Y
	lda #75
 	sta oam + (23 * 4) + 3 ; set X
	lda #1
 	sta oam + (23 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000001
 	sta oam + (23 * 4) + 2 ; set atttibutes

	lda #232
 	sta oam + (23 * 4) ; set Y
	lda #75
 	sta oam + (23 * 4) + 3 ; set X
	lda #1
 	sta oam + (23 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000001
 	sta oam + (23 * 4) + 2 ; set atttibutes

	lda #232
 	sta oam + (24 * 4) ; set Y
	lda #50
 	sta oam + (24 * 4) + 3 ; set X
	lda #1
 	sta oam + (24 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000001
 	sta oam + (24 * 4) + 2 ; set atttibutes

	lda #232
 	sta oam + (25 * 4) ; set Y
	lda #200
 	sta oam + (25 * 4) + 3 ; set X
	lda #1
 	sta oam + (25 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000001
 	sta oam + (25 * 4) + 2 ; set atttibutes

;Place second row of spectators
	lda #224
 	sta oam + (26 * 4) ; set Y
	lda #37
 	sta oam + (26 * 4) + 3 ; set X
	lda #1
 	sta oam + (26 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000000
 	sta oam + (26 * 4) + 2 ; set atttibutes

	lda #224
 	sta oam + (27 * 4) ; set Y
	lda #87
 	sta oam + (27 * 4) + 3 ; set X
	lda #1
 	sta oam + (27 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000000
 	sta oam + (27 * 4) + 2 ; set atttibutes

	lda #224
 	sta oam + (28 * 4) ; set Y
	lda #137
 	sta oam + (28 * 4) + 3 ; set X
	lda #1
 	sta oam + (28 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000000
 	sta oam + (28 * 4) + 2 ; set atttibutes

	lda #224
 	sta oam + (29 * 4) ; set Y
	lda #187
 	sta oam + (29 * 4) + 3 ; set X
	lda #1
 	sta oam + (29 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000000
 	sta oam + (29 * 4) + 2 ; set atttibutes

	lda #224
 	sta oam + (30 * 4) ; set Y
	lda #62
 	sta oam + (30 * 4) + 3 ; set X
	lda #1
 	sta oam + (30 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000001
 	sta oam + (30 * 4) + 2 ; set atttibutes

	lda #224
 	sta oam + (31 * 4) ; set Y
	lda #112
 	sta oam + (31 * 4) + 3 ; set X
	lda #1
 	sta oam + (31 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000001
 	sta oam + (31 * 4) + 2 ; set atttibutes

	lda #224
 	sta oam + (32 * 4) ; set Y
	lda #162
 	sta oam + (32 * 4) + 3 ; set X
	lda #1
 	sta oam + (32 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000001
 	sta oam + (32 * 4) + 2 ; set atttibutes

	lda #224
 	sta oam + (33 * 4) ; set Y
	lda #212
 	sta oam + (33 * 4) + 3 ; set X
	lda #43
 	sta oam + (33 * 4) + 1 ; set patter + (1 * 4)n
 	lda #%00000001
 	sta oam + (33 * 4) + 2 ; set atttibutes
jmp mainloop

mainloop:
 	
 	; ball animation
 	clc
	inc timer
    lda timer
    cmp #255 ;determens speed of animation
    bne skip_reset
    lda #00
    sta timer

    inc animbyte
    lda animbyte
    cmp #06
    bne skip_reset
    lda #03
    sta animbyte
    skip_reset:

    lda #124

     lda animbyte
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
 		cmp #24
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
 		cmp #198
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
 	lda gamepad
	and #PAD_START
	beq NOT_PAUSE
	lda #0
	jsr wait_frame
	jsr wait_frame
	jsr wait_frame
	jsr wait_frame
	jsr wait_frame
	jsr wait_frame
pause_loop:
	jsr wait_frame
	jsr gamepad_poll
	lda gamepad
	and #PAD_START
	beq pause_loop
	jsr wait_frame
	jsr wait_frame
	jsr wait_frame
	jsr wait_frame
	jsr wait_frame
	jsr wait_frame

	jmp NOT_PAUSE
	
NOT_PAUSE:

 ; read the gamepad
 	jsr gamepad_poll_2
 	; now move the bat if left or right pressed
 	lda gamepad_2
 	and #PAD_U
 	beq NOT_GAMEPAD_UP_2
 		; gamepad has been pressed left
 		lda oam+(5*4) ; get current Y
 		cmp #24
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
 		cmp #198
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
;  	lda gamepad_2
; 	and #PAD_START
; 	beq NOT_PAUSE_2
; 	lda #0
; 	jsr wait_frame
; 	jsr wait_frame
; 	jsr wait_frame
; 	jsr wait_frame
; 	jsr wait_frame
; 	jsr wait_frame
	
; pause_loop_2:
; 	jsr wait_frame
	
; 	jsr gamepad_poll_2
; 	lda gamepad_2
; 	and #PAD_START
; 	beq pause_loop_2
; 	jsr wait_frame
; 	jsr wait_frame
; 	jsr wait_frame
; 	jsr wait_frame
; 	jsr wait_frame
; 	jsr wait_frame
; 	jmp NOT_PAUSE_2
	
; NOT_PAUSE_2:

	lda oam + (8 * 4) + 0
	clc
	adc d_y
	sta oam + (8 * 4) + 0
	cmp #24
	bne NOT_HITTOP
		lda #1
		sta d_y
		lda #FAMISTUDIO_SFX_CH0
    	sta sfx_channel

    	lda #2 ;sound: wall hit
    	jsr play_sfx
 NOT_HITTOP:
 	lda oam + (8 * 4) + 0
 	cmp #198 ; have we hit the bottom border
 	bne NOT_HITBOTTOM
 		lda #$FF ; reverse direction (-1)
 		sta d_y
		lda #FAMISTUDIO_SFX_CH0
		sta sfx_channel

    	lda #2 ;sound: wall hit
    	jsr play_sfx
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
		lda #FAMISTUDIO_SFX_CH0
    sta sfx_channel

    lda #3 ;sound: wall hit
    jsr play_sfx
 NOT_HITLEFT:
 	lda oam + (8 * 4) + 3
 	cmp #248 ; have we hit the right border
 	bne NOT_HITRIGHT
		jsr increment_ScorePlayer1
 		lda #$FF ; reverse direction (-1)
 		sta d_x
		lda #FAMISTUDIO_SFX_CH0
    sta sfx_channel

    lda #3 ;sound: wall hit
    jsr play_sfx
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

	;sound play
    lda #FAMISTUDIO_SFX_CH0
    sta sfx_channel

    lda #0
    jsr play_sfx

	lda #$FF
	sta d_y
	;dec d_y
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

	;sound play
    lda #FAMISTUDIO_SFX_CH0
    sta sfx_channel

    lda #0
    jsr play_sfx

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

	;sound play
    lda #FAMISTUDIO_SFX_CH0
    sta sfx_channel

    lda #0
    jsr play_sfx

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

	;sound play
    lda #FAMISTUDIO_SFX_CH0
    sta sfx_channel

    lda #0
    jsr play_sfx

	lda #1
	sta d_y
	;inc d_y
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

	;sound play
    lda #FAMISTUDIO_SFX_CH0
    sta sfx_channel

    lda #1
    jsr play_sfx

	lda #$FF
	sta d_y
	;dec d_y
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

	;sound play
    lda #FAMISTUDIO_SFX_CH0
    sta sfx_channel

    lda #1
    jsr play_sfx

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

	;sound play
    lda #FAMISTUDIO_SFX_CH0
    sta sfx_channel

    lda #1
    jsr play_sfx

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

	;sound play
    lda #FAMISTUDIO_SFX_CH0
    sta sfx_channel

    lda #1
    jsr play_sfx

	lda #1
	sta d_y
	;inc d_y
	lda #$FF ; reverse direction
	sta d_x
	jmp end_of_right_collision
end_of_right_collision:


spectator_look_at:
	lda oam + (8 * 4) + 3
	cmp #122
	bpl looking_right

	;lda d_x
	;cmp #1
	;beq looking_right
	;lda d_x
	;cmp #1
	;beq looking_right
	
looking_left:


	lda #%01000000
	sta oam + (11*4) + 2
	sta oam + (12*4) + 2
	sta oam + (13*4) + 2
	sta oam + (14*4) + 2
	sta oam + (15*4) + 2
	sta oam + (16*4) + 2
	sta oam + (17*4) + 2
	sta oam + (18*4) + 2
	sta oam + (26*4) + 2
	sta oam + (27*4) + 2
	sta oam + (28*4) + 2
	sta oam + (29*4) + 2
	lda #%01000001
	sta oam + (19*4) + 2
	sta oam + (20*4) + 2
	sta oam + (21*4) + 2
	sta oam + (22*4) + 2
	sta oam + (23*4) + 2
	sta oam + (24*4) + 2
	sta oam + (25*4) + 2
	sta oam + (30*4) + 2
	sta oam + (31*4) + 2
	sta oam + (32*4) + 2
	sta oam + (33*4) + 2

	jmp end_of_look

	
looking_right:
	lda #%00000000
	sta oam + (11*4) + 2
	sta oam + (12*4) + 2
	sta oam + (13*4) + 2
	sta oam + (14*4) + 2
	sta oam + (15*4) + 2
	sta oam + (16*4) + 2
	sta oam + (17*4) + 2
	sta oam + (18*4) + 2
	sta oam + (26*4) + 2
	sta oam + (27*4) + 2
	sta oam + (28*4) + 2
	sta oam + (29*4) + 2

	lda #%00000001
	sta oam + (19*4) + 2
	sta oam + (20*4) + 2
	sta oam + (21*4) + 2
	sta oam + (22*4) + 2
	sta oam + (23*4) + 2
	sta oam + (24*4) + 2
	sta oam + (25*4) + 2
	sta oam + (30*4) + 2
	sta oam + (31*4) + 2
	sta oam + (32*4) + 2
	sta oam + (33*4) + 2
	
end_of_look:

 	 	lda #5
	cmp player1_score
	bne NO_LEFT_WIN
		jmp win_screen_multi_left
NO_LEFT_WIN:

	lda #5
	cmp player2_score
	bne NO_WINNER
		jmp win_screen_multi_right


NO_WINNER:

	jsr famistudio_update

 ; ensure our changes are rendered
 	lda #1
 	sta nmi_ready
 	jmp mainloop

win_screen_multi_left:
jsr offscreen_sprites

	jsr ppu_off ; Wait for the screen to be drawn and then turn off drawing
 	jsr clear_nametable ; Clear the 1st name table

	;P
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 9)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 10)
	ldy #0
	lda #$37 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8* 32 + 11)
	ldy #0
	lda #$2C ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 12)
	ldy #0
	lda #$44 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 13)
	ldy #0
	lda #$30 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 14)
	ldy #0
	lda #$3D ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 16)
	ldy #0
	lda #$21 ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 18)
	ldy #0
	lda #$42 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 19)
	ldy #0
	lda #$35 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 20)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 21)
	ldy #0
	lda #$3E ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 11)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 12)
	ldy #0
	lda #$3D ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 13)
	ldy #0
	lda #$30 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 14)
	ldy #0
	lda #$3E ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 15)
	ldy #0
	lda #$3E ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 17)
	ldy #0
	lda #$3E ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 18)
	ldy #0
	lda #$3F ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 19)
	ldy #0
	lda #$2C ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 20)
	ldy #0
	lda #$3D ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 21)
	ldy #0
	lda #$3F ; tile number to repeat
	sta PPU_VRAM_IO


	jsr ppu_update	

jmp win_loop

win_screen_multi_right:

jsr offscreen_sprites


jsr ppu_off ; Wait for the screen to be drawn and then turn off drawing
 	jsr clear_nametable ; Clear the 1st name table

	;P
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 9)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 10)
	ldy #0
	lda #$37 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8* 32 + 11)
	ldy #0
	lda #$2C ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 12)
	ldy #0
	lda #$44 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 13)
	ldy #0
	lda #$30 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 14)
	ldy #0
	lda #$3D ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 16)
	ldy #0
	lda #$22 ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 18)
	ldy #0
	lda #$42 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 19)
	ldy #0
	lda #$35 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 20)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 21)
	ldy #0
	lda #$3E ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 11)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 12)
	ldy #0
	lda #$3D ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 13)
	ldy #0
	lda #$30 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 14)
	ldy #0
	lda #$3E ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 15)
	ldy #0
	lda #$3E ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 17)
	ldy #0
	lda #$3E ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 18)
	ldy #0
	lda #$3F ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 19)
	ldy #0
	lda #$2C ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 20)
	ldy #0
	lda #$3D ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 21)
	ldy #0
	lda #$3F ; tile number to repeat
	sta PPU_VRAM_IO


	jsr ppu_update
	jmp win_loop

win_screen:
jsr offscreen_sprites
win_loop:
lda 0
sta player1_score
sta player2_score
jsr gamepad_poll
 	lda gamepad
 	and #PAD_START
 	beq NOT_RESET
		jmp reset
NOT_RESET:

jsr famistudio_update

jmp win_loop	

mainloop_single: ;THIS IS THE CODE FOR SINGLE PLAYER PONG, I MADE THIS TEXT EXTRA LONG SO I CAN EASILIY FIND THE BEGINING OF THIS CODE, I DONT KNOW WHAT ELSE TO SAY SO I JUST YAP
 	
 	; ball animation
 	clc
	inc timer
    lda timer
    cmp #255 ;determens speed of animation
    bne skip_reset_single
    lda #00
    sta timer

    inc animbyte
    lda animbyte
    cmp #06
    bne skip_reset_single
    lda #03
    sta animbyte
    skip_reset_single:

    lda #124

     lda animbyte
     sta oam + (8 * 4) + 1 ; set patter + (1 * 4)n
     lda #2
     sta oam + (8 * 4) + 2 ; set atttibutes

 ; skip reading controls if and change has not been drawn
 	lda nmi_ready
 	cmp #0
 	bne mainloop_single
 ; read the gamepad
 	jsr gamepad_poll
 	; now move the bat if left or right pressed
 	lda gamepad
 	and #PAD_U
 	beq NOT_GAMEPAD_UP_single
 		; gamepad has been pressed left
 		lda oam+(1*4) ; get current Y
 		cmp #24
 		beq NOT_GAMEPAD_UP_single
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
 NOT_GAMEPAD_UP_single:
 	lda gamepad
 	and #PAD_D
 	beq NOT_GAMEPAD_DOWN_single
 		; gamepad has been pressed right
 		lda oam + (2*4) ; get current Y
 		cmp #198
 		beq NOT_GAMEPAD_DOWN_single
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
 NOT_GAMEPAD_DOWN_single:

	lda gamepad
	and #PAD_START
	beq NOT_PAUSE_single
	lda #0
	jsr wait_frame
	jsr wait_frame
	jsr wait_frame
	jsr wait_frame
	jsr wait_frame

pause_loop_single:
	jsr wait_frame
	
	jsr gamepad_poll
	lda gamepad
	and #PAD_START
	beq pause_loop_single
	jsr wait_frame
	jsr wait_frame
	jsr wait_frame
	jsr wait_frame
	jsr wait_frame

	jmp NOT_PAUSE_single

NOT_PAUSE_single:

 ; read the gamepad
 	jsr gamepad_poll_2
 	; now move the bat if left or right pressed
 	lda gamepad
 	and #PAD_U
 	beq NOT_GAMEPAD_UP_2_single
 		; gamepad has been pressed left
 		lda oam+(5*4) ; get current Y
 		cmp #24
 		beq NOT_GAMEPAD_UP_2_single
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
 NOT_GAMEPAD_UP_2_single:
 	lda gamepad
 	and #PAD_D
 	beq NOT_GAMEPAD_DOWN_2_single
 		; gamepad has been pressed right
 		lda oam + (6*4) ; get current Y
 		cmp #198
 		beq NOT_GAMEPAD_DOWN_2_single
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
 NOT_GAMEPAD_DOWN_2_single:

	lda oam + (8 * 4) + 0
	clc
	adc d_y
	sta oam + (8 * 4) + 0
	cmp #24
	bne NOT_HITTOP_single
		lda #1
		sta d_y
		lda #FAMISTUDIO_SFX_CH0
   		 sta sfx_channel

    	lda #2 ;sound: wall hit
    	jsr play_sfx
 NOT_HITTOP_single:
 	lda oam + (8 * 4) + 0
 	cmp #198 ; have we hit the bottom border
 	bne NOT_HITBOTTOM_single
 		lda #$FF ; reverse direction (-1)
 		sta d_y
		lda #FAMISTUDIO_SFX_CH0
    	sta sfx_channel

    	lda #2 ;sound: wall hit
    	jsr play_sfx
 NOT_HITBOTTOM_single:
 	lda oam + (8 * 4) + 3 ; get the current x
 	clc
 	adc d_x	; add the X velocity
 	sta oam + (8 * 4) + 3
 	cmp #0 ; have we hit the left border
 	bne NOT_HITLEFT_single
		jsr increment_ScorePlayer2
 		lda #1 ; reverse direction
 		sta d_x
		lda #FAMISTUDIO_SFX_CH0
    	sta sfx_channel

    	lda #3 ;sound: wall hit
    	jsr play_sfx
 NOT_HITLEFT_single:
 	lda oam + (8 * 4) + 3
 	cmp #248 ; have we hit the right border
 	bne NOT_HITRIGHT_single
		jsr increment_ScorePlayer1
 		lda #$FF ; reverse direction (-1)
 		sta d_x
		lda #FAMISTUDIO_SFX_CH0
    	sta sfx_channel

    	lda #3 ;sound: wall hit
    	jsr play_sfx
 NOT_HITRIGHT_single:

 collision_detection_single:
	;storing the ball information for collision detection
 	lda oam + (8*4)+3
	sta cx1

	lda oam + (8*4)
	sta cy1

	lda #6
	sta ch1
	sta cw1

TOP_HIT_single:
	;storing top sprite information for collision detection
	lda oam + (1*4)+3
	sta cx2

	lda oam + (1*4)
	sta cy2

	lda #6
	sta ch2
	sta cw2

	jsr collision_test

	bcc MIDDLE_HIT_single

	;sound play
    lda #FAMISTUDIO_SFX_CH0
    sta sfx_channel

    lda #0
    jsr play_sfx

	lda #$FF
	sta d_y
	;dec d_y
	lda #1 ; reverse direction
	sta d_x
	jmp end_of_left_collision_single


 MIDDLE_HIT_single:
 ;storing middle top sprite information for collision detection
	lda oam + (0*4)+3
	sta cx2

	lda oam + (0*4)
	sta cy2

	lda #6
	sta ch2
	sta cw2

	jsr collision_test
	bcc MIDDLE_SECOND_HIT_single

	;sound play
    lda #FAMISTUDIO_SFX_CH0
    sta sfx_channel

    lda #0
    jsr play_sfx

	lda #0
	sta d_y
	lda #2 ; reverse direction
	sta d_x
	jmp end_of_left_collision_single
MIDDLE_SECOND_HIT_single:
;storing middle bottom sprite information for collision detection
	lda oam + (3*4)+3
	sta cx2

	lda oam + (3*4)
	sta cy2

	lda #6
	sta ch2
	sta cw2

	jsr collision_test
	bcc BOTTOM_HIT_single

	;sound play
    lda #FAMISTUDIO_SFX_CH0
    sta sfx_channel

    lda #0
    jsr play_sfx

	lda #0
	sta d_y
	lda #2 ; reverse direction
	sta d_x
	jmp end_of_left_collision_single
BOTTOM_HIT_single:
;storing bottom sprite information for collision detection
lda oam + (2*4)+3
	sta cx2

	lda oam + (2*4)
	sta cy2

	lda #6
	sta ch2
	sta cw2

	jsr collision_test
	bcc end_of_left_collision_single

	;sound play
    lda #FAMISTUDIO_SFX_CH0
    sta sfx_channel

    lda #0
    jsr play_sfx

	lda #1
	sta d_y
	;inc d_y
	lda #1 ; reverse direction
	sta d_x
	jmp end_of_left_collision_single


end_of_left_collision_single:
TOP_HIT_RIGHT_single:
	;storing top right sprite information for collision detection
	lda oam + (5*4)+3
	sta cx2

	lda oam + (5*4)
	sta cy2

	lda #6
	sta ch2
	sta cw2

	jsr collision_test
	bcc MIDDLE_HIT_RIGHT_single

	;sound play
    lda #FAMISTUDIO_SFX_CH0
    sta sfx_channel

    lda #1
    jsr play_sfx

	lda #$FF
	sta d_y
	;dec d_y
	lda #$FF ; reverse direction
	sta d_x
	jmp end_of_right_collision_single
 MIDDLE_HIT_RIGHT_single:
 ;storing middle top righ sprite information for collision detection
	lda oam + (4*4)+3
	sta cx2

	lda oam + (4*4)
	sta cy2

	lda #6
	sta ch2
	sta cw2

	jsr collision_test
	bcc MIDDLE_SECOND_HIT_RIGHT_single

	;sound play
    lda #FAMISTUDIO_SFX_CH0
    sta sfx_channel

    lda #1
    jsr play_sfx

	lda #0
	sta d_y
	lda #$FE ; reverse direction
	sta d_x
	jmp end_of_right_collision_single
MIDDLE_SECOND_HIT_RIGHT_single:
;storing middle bottom right sprite information for collision detection
	lda oam + (7*4)+3
	sta cx2

	lda oam + (7*4)
	sta cy2

	lda #6
	sta ch2
	sta cw2

	jsr collision_test
	bcc BOTTOM_HIT_RIGHT_single

	;sound play
    lda #FAMISTUDIO_SFX_CH0
    sta sfx_channel

    lda #1
    jsr play_sfx

	lda #0
	sta d_y
	lda #$FE ; reverse direction
	sta d_x
	jmp end_of_right_collision_single
BOTTOM_HIT_RIGHT_single:
;storing bottom right sprite information for collision detection
lda oam + (6*4)+3
	sta cx2

	lda oam + (6*4)
	sta cy2

	lda #6
	sta ch2
	sta cw2

	jsr collision_test
	bcc end_of_right_collision_single

	;sound play
    lda #FAMISTUDIO_SFX_CH0
    sta sfx_channel

    lda #1
    jsr play_sfx

	lda #1
	sta d_y
	;inc d_y
	lda #$FF ; reverse direction
	sta d_x
	jmp end_of_right_collision_single
end_of_right_collision_single:


spectator_look_at_single:
	lda oam + (8 * 4) + 3
	cmp #122
	bpl looking_right_single

	;lda d_x
	;cmp #1
	;beq looking_right
	;lda d_x
	;cmp #1
	;beq looking_right
	
looking_left_single:


	lda #%01000000
	sta oam + (11*4) + 2
	sta oam + (12*4) + 2
	sta oam + (13*4) + 2
	sta oam + (14*4) + 2
	sta oam + (15*4) + 2
	sta oam + (16*4) + 2
	sta oam + (17*4) + 2
	sta oam + (18*4) + 2
	sta oam + (26*4) + 2
	sta oam + (27*4) + 2
	sta oam + (28*4) + 2
	sta oam + (29*4) + 2
	lda #%01000001
	sta oam + (19*4) + 2
	sta oam + (20*4) + 2
	sta oam + (21*4) + 2
	sta oam + (22*4) + 2
	sta oam + (23*4) + 2
	sta oam + (24*4) + 2
	sta oam + (25*4) + 2
	sta oam + (30*4) + 2
	sta oam + (31*4) + 2
	sta oam + (32*4) + 2
	sta oam + (33*4) + 2

	jmp end_of_look_single

	
looking_right_single:
	lda #%00000000
	sta oam + (11*4) + 2
	sta oam + (12*4) + 2
	sta oam + (13*4) + 2
	sta oam + (14*4) + 2
	sta oam + (15*4) + 2
	sta oam + (16*4) + 2
	sta oam + (17*4) + 2
	sta oam + (18*4) + 2
	sta oam + (26*4) + 2
	sta oam + (27*4) + 2
	sta oam + (28*4) + 2
	sta oam + (29*4) + 2

	lda #%00000001
	sta oam + (19*4) + 2
	sta oam + (20*4) + 2
	sta oam + (21*4) + 2
	sta oam + (22*4) + 2
	sta oam + (23*4) + 2
	sta oam + (24*4) + 2
	sta oam + (25*4) + 2
	sta oam + (30*4) + 2
	sta oam + (31*4) + 2
	sta oam + (32*4) + 2
	sta oam + (33*4) + 2
	
end_of_look_single:

 	lda #5
	cmp player1_score
	bne NO_LEFT_WIN_MULTI
		jmp win_screen_single_left
NO_LEFT_WIN_MULTI:

	lda #5
	cmp player2_score
	bne NO_WINNER_MULTI
		jmp win_screen_single_right


NO_WINNER_MULTI:
	jsr famistudio_update

 ; ensure our changes are rendered
 	lda #1
 	sta nmi_ready
 	jmp mainloop_single

win_screen_single_left:
jsr offscreen_sprites

	jsr ppu_off ; Wait for the screen to be drawn and then turn off drawing
 	jsr clear_nametable ; Clear the 1st name table

	;P
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 9)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 10)
	ldy #0
	lda #$37 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8* 32 + 11)
	ldy #0
	lda #$2C ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 12)
	ldy #0
	lda #$44 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 13)
	ldy #0
	lda #$30 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 14)
	ldy #0
	lda #$3D ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 16)
	ldy #0
	lda #$21 ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 18)
	ldy #0
	lda #$42 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 19)
	ldy #0
	lda #$35 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 20)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 21)
	ldy #0
	lda #$3E ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 11)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 12)
	ldy #0
	lda #$3D ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 13)
	ldy #0
	lda #$30 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 14)
	ldy #0
	lda #$3E ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 15)
	ldy #0
	lda #$3E ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 17)
	ldy #0
	lda #$3E ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 18)
	ldy #0
	lda #$3F ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 19)
	ldy #0
	lda #$2C ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 20)
	ldy #0
	lda #$3D ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 21)
	ldy #0
	lda #$3F ; tile number to repeat
	sta PPU_VRAM_IO


	jsr ppu_update	

jmp win_loop_single

win_screen_single_right:

jsr offscreen_sprites


jsr ppu_off ; Wait for the screen to be drawn and then turn off drawing
 	jsr clear_nametable ; Clear the 1st name table

	;P
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 9)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 10)
	ldy #0
	lda #$37 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8* 32 + 11)
	ldy #0
	lda #$2C ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 12)
	ldy #0
	lda #$44 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 13)
	ldy #0
	lda #$30 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 14)
	ldy #0
	lda #$3D ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 16)
	ldy #0
	lda #$22 ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 18)
	ldy #0
	lda #$42 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 19)
	ldy #0
	lda #$35 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 20)
	ldy #0
	lda #$39 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 21)
	ldy #0
	lda #$3E ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 11)
	ldy #0
	lda #$3B ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 12)
	ldy #0
	lda #$3D ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 13)
	ldy #0
	lda #$30 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 14)
	ldy #0
	lda #$3E ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 15)
	ldy #0
	lda #$3E ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 17)
	ldy #0
	lda #$3E ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 18)
	ldy #0
	lda #$3F ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 19)
	ldy #0
	lda #$2C ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 20)
	ldy #0
	lda #$3D ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 21)
	ldy #0
	lda #$3F ; tile number to repeat
	sta PPU_VRAM_IO


	jsr ppu_update
	jmp win_loop_single
win_loop_single:
lda 0
sta player1_score
sta player2_score
jsr gamepad_poll
 	lda gamepad
 	and #PAD_START
 	beq NOT_RESET_single
		jmp reset
NOT_RESET_single:

jsr famistudio_update

jmp win_loop

offscreen_sprites:
	lda #255
 	sta oam  ; set Y
 	sta oam  + 3 ; set X

	; place our top sprite on the screen
 	lda #255
 	sta oam +4  ; set Y
 	sta oam  +4 + 3 ; set X

	; place our bottom sprite on the screen
 	lda #255
 	sta oam +(2*4)  ; set Y
 	sta oam  +(2*4) + 3 ; set X


	; place our middel bar sprite on the screen
 	lda #255
 	sta oam +(3*4)  ; set Y
 	sta oam  +(3*4) + 3 ; set X


	; place our player sprite on the screen
 	lda #255
 	sta oam +(10*4)  ; set Y
 	sta oam  +(10*4) + 3 ; set X


	;Right Sprite

	; place our right middle bat sprite on the screen
 	lda #255
 	sta oam+(4*4)  ; set Y
 	sta oam+(4*4)  + 3 ; set X


	; place our right top sprite on the screen
 	lda #255
 	sta oam + (5*4)  ; set Y
 	sta oam + (5*4) + 3 ; set X


	; place our right bottom sprite on the screen
 	lda #255
 	sta oam +(6*4)  ; set Y
 	sta oam  +(6*4) + 3 ; set X
 

	; place our right middle sprite on the screen
 	lda #255
 	sta oam +(7*4)  ; set Y
 	sta oam  +(7*4) + 3 ; set X

	; place our right player sprite on the screen
 	lda #255
 	sta oam +(9*4)  ; set Y
 	sta oam  +(9*4) + 3 ; set X
 
; place ball sprite on the screen

 	lda #255
 	sta oam + (8 * 4) ; set Y
 	sta oam + (8 * 4) + 3 ; set X


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

title_attrites:
.byte %00000101,%00000101,%00000101,%00000101
.byte %00000101,%00000101,%00000101,%00000101

 .proc update_score
 	jsr ppu_off ; Wait for the screen to be drawn and then turn off drawing

	jsr display_scores

	jsr ppu_update
 	rts
 .endproc

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

; .segment "RODATA"
; ; put the data in our data segment of the ROM
; game_screen_mountain:
; .byte 001,002,003,004,001,002,003,004,001,002,003,004,001,002,003,004
; .byte 001,002,003,004,001,002,003,004,001,002,003,004,001,002,003,004
; game_screen_scoreline:
; .byte "SCORE 0000000"

.segment "CODE"
 .proc display_game_screen
	jsr ppu_off ; Wait for the screen to be drawn and then turn off drawing

 	jsr clear_nametable ; Clear the 1st name table

	; draw court

	; Top & Bottom
 	vram_set_address (NAME_TABLE_0_ADDRESS + 3 * 32)
	ldy #0
	lda #$14 ; tile number to repeat
 loop2:
 	sta PPU_VRAM_IO
	iny
 	cpy #32
 	bne loop2

	vram_set_address (NAME_TABLE_0_ADDRESS + 25 * 32)
	ldy #0
	lda #$15 ; tile number to repeat
 loop3:
 	sta PPU_VRAM_IO
	iny
 	cpy #32
 	bne loop3



	; Left & Right
	vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32)
	ldy #0
	lda #$12 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32)
	ldy #0
	lda #$12 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 6 * 32)
	ldy #0
	lda #$12 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 7 * 32)
	ldy #0
	lda #$12 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32)
	ldy #0
	lda #$12 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 9 * 32)
	ldy #0
	lda #$12 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 10 * 32)
	ldy #0
	lda #$12 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 11 * 32)
	ldy #0
	lda #$12 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 12 * 32)
	ldy #0
	lda #$12 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 13 * 32)
	ldy #0
	lda #$12 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32)
	ldy #0
	lda #$12 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 15 * 32)
	ldy #0
	lda #$12 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 16 * 32)
	ldy #0
	lda #$12 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 17 * 32)
	ldy #0
	lda #$12 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 18 * 32)
	ldy #0
	lda #$12 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 19 * 32)
	ldy #0
	lda #$12 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 20 * 32)
	ldy #0
	lda #$12 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 21 * 32)
	ldy #0
	lda #$12 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 22 * 32)
	ldy #0
	lda #$12 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 23 * 32)
	ldy #0
	lda #$12 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 24 * 32)
	ldy #0
	lda #$12 ; tile number to repeat
	sta PPU_VRAM_IO
	; vram_set_address (NAME_TABLE_0_ADDRESS + 25 * 32)
	; ldy #0
	; lda #$12 ; tile number to repeat
	; sta PPU_VRAM_IO


	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 - 1)
	ldy #0
	lda #$13 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 6 * 32 - 1)
	ldy #0
	lda #$13 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 7 * 32 - 1)
	ldy #0
	lda #$13 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 - 1)
	ldy #0
	lda #$13 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 9 * 32 - 1)
	ldy #0
	lda #$13 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 10 * 32 - 1)
	ldy #0
	lda #$13 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 11 * 32 - 1)
	ldy #0
	lda #$13 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 12 * 32 - 1)
	ldy #0
	lda #$13 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 13 * 32 - 1)
	ldy #0
	lda #$13 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 - 1)
	ldy #0
	lda #$13 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 15 * 32 - 1)
	ldy #0
	lda #$13 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 16 * 32 - 1)
	ldy #0
	lda #$13 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 17 * 32 - 1)
	ldy #0
	lda #$13 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 18 * 32 - 1)
	ldy #0
	lda #$13 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 19 * 32 - 1)
	ldy #0
	lda #$13 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 20 * 32 - 1)
	ldy #0
	lda #$13 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 21 * 32 - 1)
	ldy #0
	lda #$13 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 22 * 32 - 1)
	ldy #0
	lda #$13 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 23 * 32 - 1)
	ldy #0
	lda #$13 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 24 * 32 - 1)
	ldy #0
	lda #$13 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 25 * 32 - 1)
	ldy #0
	lda #$13 ; tile number to repeat
	sta PPU_VRAM_IO
	; vram_set_address (NAME_TABLE_0_ADDRESS + 26 * 32 - 1)
	; ldy #0
	; lda #$13 ; tile number to repeat
	; sta PPU_VRAM_IO

	; draw corners
	vram_set_address (NAME_TABLE_0_ADDRESS + 3 * 32)
	ldy #0
	lda #$08 ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 -1)
	ldy #0
	lda #$0B ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 25 * 32)
	ldy #0
	lda #$09 ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 26 * 32 -1)
	ldy #0
	lda #$0A ; tile number to repeat
	sta PPU_VRAM_IO


	; center
	vram_set_address (NAME_TABLE_0_ADDRESS + 3 * 32 + 15)
	ldy #0
	lda #$0C ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 3 * 32 + 16)
	ldy #0
	lda #$0D ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 25 * 32 + 15)
	ldy #0
	lda #$0E ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 25 * 32 + 16)
	ldy #0
	lda #$0F ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 + 15)
	ldy #0
	lda #$10 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 + 16)
	ldy #0
	lda #$11 ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 7 * 32 + 15)
	ldy #0
	lda #$10 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 7 * 32 + 16)
	ldy #0
	lda #$11 ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 9 * 32 + 15)
	ldy #0
	lda #$10 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 9 * 32 + 16)
	ldy #0
	lda #$11 ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 11 * 32 + 15)
	ldy #0
	lda #$10 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 11 * 32 + 16)
	ldy #0
	lda #$11 ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 13 * 32 + 15)
	ldy #0
	lda #$10 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 13 * 32 + 16)
	ldy #0
	lda #$11 ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 15 * 32 + 15)
	ldy #0
	lda #$10 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 15 * 32 + 16)
	ldy #0
	lda #$11 ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 17 * 32 + 15)
	ldy #0
	lda #$10 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 17 * 32 + 16)
	ldy #0
	lda #$11 ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 19 * 32 + 15)
	ldy #0
	lda #$10 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 19 * 32 + 16)
	ldy #0
	lda #$11 ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 21 * 32 + 15)
	ldy #0
	lda #$10 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 21 * 32 + 16)
	ldy #0
	lda #$11 ; tile number to repeat
	sta PPU_VRAM_IO

	vram_set_address (NAME_TABLE_0_ADDRESS + 23 * 32 + 15)
	ldy #0
	lda #$10 ; tile number to repeat
	sta PPU_VRAM_IO
	vram_set_address (NAME_TABLE_0_ADDRESS + 23 * 32 + 16)
	ldy #0
	lda #$11 ; tile number to repeat
	sta PPU_VRAM_IO

	jsr display_scores

	;jsr draw_court

 	jsr ppu_update ; Wait until the screen has been drawn
 	rts
 .endproc

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