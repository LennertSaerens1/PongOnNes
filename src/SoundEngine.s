; This file is for the FamiStudio Sound Engine and was generated by FamiStudio


.if FAMISTUDIO_CFG_C_BINDINGS
.export _sounds=sounds
.endif

sounds:
	.word @ntsc
	.word @ntsc
@ntsc:
	.word @sfx_ntsc_pong
	.word @sfx_ntsc_ping
	.word @sfx_ntsc_wall_hit
	.word @sfx_ntsc_goal
	.word @sfx_ntsc_victory

@sfx_ntsc_pong:
	.byte $81,$c4,$82,$01,$80,$3f,$89,$f0,$0a,$00
@sfx_ntsc_ping:
	.byte $81,$1c,$82,$01,$80,$3f,$89,$f0,$0a,$00
@sfx_ntsc_wall_hit:
	.byte $87,$59,$88,$00,$86,$8f,$89,$f0,$0a,$00
@sfx_ntsc_goal:
	.byte $8a,$04,$89,$3f,$1e,$8a,$03,$14,$8a,$04,$1e,$00
@sfx_ntsc_victory:
	.byte $89,$f0,$00

.export sounds