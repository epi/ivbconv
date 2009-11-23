;
	*=$5800
;
; Interlaced pic displayer
; 
; Uses Method 1 - do nothing on non-interlace fields
;
brkflag	= $11
attract	= $4d
ramtop	= $6a 
ztemp1	= $e0
ztemp2	= $e2
ztemp3	= $e4
screen1	= $9c40 ; ***** Temporarily use normal screen RAM *****
vscount	= $04 ; must be zero-page (timing)
sdmctl	= $22f
sdslst	= $230
gprior	= $26f
chbas = $2f4
ichid	= $340
iccom	= $342
icba	= $344
icbl	= $348
icax1	= $34a
icax2	= $34b
;
pal	= $d014
colpf1	= $d017
colpf2	= $d018
colbak	= $d01a
prior	= $d01b
consol	= $d01f
porta	= $d300
pactl	= $d302
dmactl	= $d400
dlistl	= $d402
dlisth	= $d403
hscrol	= $d404
vscrol	= $d405
chbase	= $d409
wsync	= $d40a
vcount	= $d40b
nmien	= $d40e
;
; VBXE stuff
vbxe	= $cb ; Pointer to VBXE page (=$d600 or $d700)
vbxe_bank = $cd ; Current bank in VBXE
;
vb_video_control = $40
vb_xdl_adr	= $41
vb_csel	= $44 ; Color select
vb_psel = $45 ; Palette select
vb_cr	= $46
vb_cg	= $47
vb_cb	= $48 ; RGB registers

vb_memac_b_control = $5d ; Control for old banking scheme
vb_memac_control = $5e ; MEMAC A Control
vb_memac_bank_sel = $5f ; Bank select for MEMAC A

;
; Jump tables
;
	jmp init1
	jmp init_palette
	jmp inc_bank
	jmp setup_interlace
	jmp display_pic
;
	pla ; for BASIC
setup_interlace
	cld
	lda #0
	sta fieldswap
	lda #8
	jsr waitvc
	jsr waitvc ; Wait at least 1 frame
	lda #0
	sta nmien
	ldx #<vblank
	ldy #>vblank
	stx $222
	sty $223
	lda #$40
	sta nmien
	rts
;
waitvc
	cmp vcount
	bne waitvc
	rts
vblank
	lda #0
	sta attract
	lda #$c0
	sta nmien
	jsr doscreen
; Do colours and DList pointer in case Stage 2 is skipped
	ldx #4
vb_setcolours
	lda $2c4,x
	sta $d016,x
	dex
	bpl vb_setcolours
	lda sdslst+1
	sta dlisth
	lda sdslst
	sta dlistl
	ldx #<dli1
	ldy #>dli1
	stx $200
	sty $201
	lda 20
	tax
	and #1
	eor fieldswap
	asl
	asl
	sta choffset ; Chbase offset
	txa
	lsr a
	bcc vblank2
	jmp vblankend
vblank2
	ldy #$88
	lda pal
	cmp #$f ; Are we NTSC ?
	bne not_ntsc
	ldy #$7e
not_ntsc
	tya
	jsr waitvc
	lda #0
	sta $d017
	sta $d018
	sta $d01a
	sta wsync
;	sta porta
	ldy #3
	sta wsync
	sta porta
	sta wsync
; first line of vsync... half line at blanking level, second half at sync level
	nop ; 105
	sty dmactl ; 109
	ldx #7 ; 111
; Refresh cycles 26 30 34 38 42 46 50 54 58
vbwait1
	dex
	bne vbwait1 ; 5*X-1=34=31 (+2 Ref)= 33
	ldx #3 ; 36 (1)
	nop ; 39 (1)
	nop ; 41
	nop ; 44 (1)
	nop ; 47 (1)
	sta dmactl ; 52 (1)
	nop ; 55 (1)
	nop ; 57 
	stx vscount ; 61 (1)
	ldx #7 ; 63
; Refresh cycles 26 30 34 38 42 46 50 54 58
vbloop1
vbwait3
	dex
	bne vbwait3 ; 5*X-1 = 34 = 97, 
	sty dmactl ; 101 get HSync pulses back in normal order
	nop ; 103
	nop ; 105
	nop ; 107
	sta dmactl ; 111
	dec vscount ; 116 = 2
	beq vsyncend ; 4
	ldx #5 ; 6
vbwait2
	dex
	bne vbwait2 ; 5*X-1 = 24 (+ 2 Ref) = 32
	ldx #6 ; 35 (1)
	nop ; 37
	nop ; 40 (1)
	sty dmactl ; 45 (1)
	sta dmactl ; 51 (2)
	nop ; 53
	nop ; 56 (1)
	nop ; 59 (1)
	nop ; 61
	nop ; 63
	nop ; 65
	jmp vbloop1 ; 68 
; Refresh cycles 26 30 34 38 42 46 50 54 58
vsyncend
	lda #1
	jsr waitvc
vblankend
	lda sdmctl
	sta savesdmctl
	lda #$20
	sta sdmctl
	sta dmactl
	lda #$80
	sta wsync
;	sta porta
	.byte 234,234,234,234
	.byte 234,234,234,234
	.byte 234,234,234,234
	jmp $e45f
;
; Switch screen base
;
doscreen
	lda 20
	and #1
	asl a
	asl a
	tax
	ldy #vb_xdl_adr
	lda xdl_table,x
	sta (vbxe),y
	lda xdl_table+1,x
	iny
	sta (vbxe),y
	lda xdl_table+2,x
	iny
	sta (vbxe),y
	rts
; bitmap_table	.word $7000,$8000
fieldswap  .byte 0
choffset   .byte 0
savesdmctl .byte 0
load_count  .byte 2 ; load counter for 4K segments
; mpindex	.byte 0
; message_end_ptr .word 0
; scrollspeed	.byte 0
; message1_fine	.byte 0
	.word 0,0,0,0,0,0,0,0
;
; First DLI - enable normal screen DMA
;
dli1
	pha
	lda #$22
	sta sdmctl
	sta wsync
	sta dmactl
	lda #<dli_last
	sta $200
	lda #>dli_last
	sta $201
	pla
	rti
;
; DLI for bottom of screen - enact Scanline 240 bug
;
dli_last
	pha
	lda #0
	sta wsync
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	sta dmactl
	pla
	rti
;
xdl_table
	.byte 0,0,0,0 ; first xdl at $000000
	.byte 0,2,0,0 ; second xdl at $000200
;
; INIT segment for multipart load of BMPs for VBXE
;
init1
	lda #$40
	sta nmien
	lda #0
	sta colbak
	sta vbxe
	sta vbxe+1 ; Assume no VBXE installed for now
	ldy #$d6
	ldx $d640
	inx
	bne found_d6
	ldx $d740
	inx
	bne found_d7
; Not found - display message and loop
	ldx #<dl_vbnotfound
	ldy #>dl_vbnotfound
	stx sdslst
	sty sdslst+1
vbxe_notfound
	jmp vbxe_notfound
found_d7
	inc foundat_txt
	iny
found_d6
	sty vbxe+1 ; Setup pointer in ZP to VBXE page base
	ldx #<dl_vbfound
	ldy #>dl_vbfound
	stx sdslst
	sty sdslst+1
	ldy #0
	tya
	sta (vbxe),y ; Clear any current VBXE modes
	ldy #vb_memac_b_control
	sta (vbxe),y ; Clear any MEMAC_B access modes
	ldy #vb_memac_control
	lda #$88
	sta (vbxe),y ; Set MEMAC_CONTROL to window at $8000-8FFF, CPU access only
	ldy #vb_memac_bank_sel
	lda #$80
	sta (vbxe),y ; Set window at $000000 in VBXE RAM
	ldx #xdl_length
copyxdl
	lda xdl1,x
	sta $8000,x
	lda xdl2,x
	sta $8200,x
	dex
	bpl copyxdl ; Copy XDLs to VBXE @ $0000 and $0200
	ldy #1
clear_vbxe_ram
	jsr set_vbxe_bank ; Set to bank 2
	lda #0
	tax
clear_vbxe2
	sta $8000,x
	sta $8100,x
	sta $8200,x
	sta $8300,x
	sta $8400,x
	sta $8500,x
	sta $8600,x
	sta $8700,x
	sta $8800,x
	sta $8900,x
	sta $8a00,x
	sta $8b00,x
	sta $8c00,x
	sta $8d00,x
	sta $8e00,x
	sta $8f00,x
	inx
	bne clear_vbxe2
	iny
	cpy #40
	bcc clear_vbxe_ram ; Clear ~ 160K of Video RAM
	rts ; Continue picture load
; 
; INIT segment for Palette setup - palette loaded from $7000-72FF
;
init_palette
	ldy #vb_psel
	lda #1
	sta (vbxe),y ; Set palette 1
	ldy #vb_csel
	lda #0
	sta (vbxe),y ; Select colour 1
	ldx #0
vbxe_setcolours1
	lda $7000,x
	ldy #vb_cr
	sta (vbxe),y ; set Red
	lda $7001,x
	iny
	sta (vbxe),y ; Set Green
	lda $7002,x
	iny
	sta (vbxe),y ; Set Blue
	inx
	inx
	inx
	cpx #2
	bne vbxe_setcolours1
	ldx #0
vbxe_setcolours2
	lda $7102,x
	ldy #vb_cr
	sta (vbxe),y ; Set Red
	lda $7103,x
	iny
	sta (vbxe),y ; G
	lda $7104,x
	iny
	sta (vbxe),y ; B
	inx
	inx
	inx
	cpx #2
	bne vbxe_setcolours2
	ldx #0
vbxe_setcolours3
	lda $7204,x
	ldy #vb_cr
	sta (vbxe),y ; R
	lda $7205,x
	iny
	sta (vbxe),y ; G
	lda $7206,x
	iny
	sta (vbxe),y ; Set Blue
	inx
	inx
	inx
	cpx #2
	bne vbxe_setcolours3
	ldy #2
	sty vbxe_bank
	jsr set_vbxe_bank ; Set to bank 2 for start of bitmap data
	lda #0
	ldy #vb_xdl_adr
	sta (vbxe),y
	iny
	sta (vbxe),y
	iny
	sta (vbxe),y ; Set XDL address to $0000
	lda #7
	ldy #vb_video_control
	sta (vbxe),y ; Set Video Control
	rts
;
; Increment VBXE MEMAC Bank, used during pic load
; 4K segments load at $8000-8FFF into RAMAC window
;
inc_bank
	ldy vbxe_bank
	iny
	sty vbxe_bank
	jsr set_vbxe_bank
	dec load_count
	bne inc_bank_end
	ldx #<dl_main
	ldy #>dl_main
	stx sdslst
	sty sdslst+1
	lda #$d8
	sta colpf1
	lda #8
	jsr waitvc
	lda #7
	jsr waitvc
inc_bank_end
	rts

;
; Set VBXE MEMAC Bank.  Y=bank number
;
set_vbxe_bank
	tya
	pha
	ora #$80
	ldy #vb_memac_bank_sel
	sta (vbxe),y
	pla
	tay
	rts
;
; Display picture
;
display_pic
	ldx #<dl_main
	ldy #>dl_main
	stx sdslst
	sty sdslst+1
	lda #$d8
	sta colpf1
display_pic_wait
	jmp display_pic_wait ; Just loop for now
;
dl_vbnotfound
	.byte $70,$70,$70,$70,$70
	.byte $46
	.word txt_vbnotfound
	.byte $40,6,$41
	.word dl_vbnotfound
txt_vbnotfound
	.sbyte "   vbxe not found   "
	.sbyte "  PRESS RESET       "
dl_vbfound
	.byte $70,$70,$70,$70,$70
	.byte $46
	.word txt_vbfound
	.byte $41
	.word dl_vbfound
txt_vbfound
	.sbyte " VBXE FOUND AT $D640"
foundat_txt = *-3
;
; DList for when picture is displayed
;
dl_main
	.byte 112,112,$f0,112,112 ; DLI1 here
	.byte 112,112,112,112,112
	.byte 112,112,112,112,112
	.byte 112,112,112,112,112
	.byte 112,112,112,112,112
	.byte 112,112,112 ; 28 blank chr rows
	.byte $c2 ; LMS 2
	.word txt_main1
	.byte $cf ; LMS F
	.word blank40
	.byte 0,$41
	.word dl_main
txt_main1
	.sbyte "  320x480i pic by Rybags, November 2009 "
blank40
	.sbyte "                                        "
;
; XDLs here
;
xdl1
	.byte $62 ; overlay, repeat, set overlay adr
	.byte $88 ; set attrib, end XDL
	.byte 239 ; Repeat 239 for 240 pixel screen height
	.byte $00,$20,$00 ; First overlay Field 0 starts @ $02000 in VBXE RAM
	.word 640 ; Step size 640 bytes for interlace
	.byte $11 ; Attrib:  Normal width, use palette 1
	.byte $DF ; Overlay has priority over all except PF1
	.byte 0,0 ; filler
xdl_length = *-xdl1
;
xdl2
	.byte $62 ; overlay, repeat, set overlay adr
	.byte $88 ; set attrib, end XDL
	.byte 239 ; Repeat 239 for 240 pixel screen height
	.byte $40,$21,$00 ; First overlay Field 1 starts @ $02140 in VBXE RAM
	.word 640 ; Step size 640 bytes for interlace
	.byte $11 ; Attrib:  Normal width, use palette 1
	.byte $DF ; Overlay has priority over all except PF1
	.byte 0,0 ; filler
;
