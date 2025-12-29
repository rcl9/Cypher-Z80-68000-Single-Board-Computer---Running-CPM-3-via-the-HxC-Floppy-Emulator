	title 'CYPHER floppy disk driver interface to the monitor'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	d i s k i o 3 . a s m
;
;	CP/M Plus (tm) compatible disk controler routine for the CYPHER PC.
;	CP/M Plus is a trade mark of Digital Research, Calif.
;
;	Note that this module assembles very slowly.  Do not be alarmed.
;
;	Motel Computers Ltd.
;	174 Betty Ann Dr.
;	Willowdale, Ontario,
;	Canada M2N 1X6
;
;	Version 1	- I.A. Cunningham  January 1 1985
;		1.1	- physical seek only when required Apr 5 1985
;		1.2	- returns not ready error if not ready
;		1.21	- seeked to track 3 for auto density recognition
;			- waited 250ms after turning on the motor drive
;			- hacked in Pied Piper format
;
; NOTE: 5.25" formats select the size by the track number (odd/
;       even) instead of the sector number. This is used for
;       the Pied Piper and Morrow formats (# of tracks just 
;	doubled in dpb).
;
; BUG: This version only recognizes SD128 or DDDS1024 or DDDS1024
; formats in the login routine
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

true	equ	-1
false	equ	0

den$trk equ	3	; track to seek to for auto density recognition

	dseg

	extrn	local$stack
	extrn	savestack

    ; Disk drive dispatching tables for linked BIOS

	extrn	@dtbl
	public	fdsd0,fdsd1,fdsd2,fdsd3

    ; Variables containing parameters passed by BDOS

	extrn	@adrv,@rdrv
	extrn	@dma,@trk,@sect,@cnt
	extrn	@dbnk,@cbnk

    ; System Control Block variables

	extrn	@ermde		; BDOS error mode

    ; Utility routines in standard BIOS

	extrn	?bank0
	extrn	?bank
	extrn	?wboot		; warm boot vector
	extrn	?pmsg		; print message @<HL> up to 00, save <BC> & <DE>
	extrn	?pdec		; print binary number in <HL> in decimal
	extrn	?pderr		; print BIOS disk error header
	extrn	?conin,?cono	; con in to a, and out from c
	extrn	?const		; get console status

    ; CP/M 3 Disk definition macros

	maclib cpm3		; define macro routines
	maclib z80		; define selected z80 op codes
	maclib ports		; define cypher pc port addresses (z80 mode)
	maclib cymonitr		; define cypher pc monitor entry addresses

    ; common control characters

cr	equ 13
lf	equ 10
bell	equ 7

    ; Extended Disk Parameter Headers (XPDHs)

	dw	fd$write
	dw	fd$read
	dw	fd$login
	dw	fd$init
	db	0			; unit number 0
	db	00h			; disk format type byte for 8" floppy
fdsd0	dph     trans7,cdpb0

	dw	fd$write
	dw	fd$read
	dw	fd$login
	dw	fd$init
	db	1			; unit number 1
	db	00h			; set for 8" floppy
fdsd1	dph	trans7,cdpb1

; Pied Piper hard coded format

	dw	fd$write
	dw	fd$read
	dw	pp$login		; go log in Pied Piper drive
	dw	fd$init
	db	2			; unit number 2
	db	2eh			; 5" floppy, 80 tracks per side
					; DD/DS 512 byte sectors
fdsd2	dph	trans5f,cdpb2

; Morrow 40 track hard coded format (for 40 track drive)

	dw	fd$write
	dw	fd$read
	dw	mor$login		; turn on motor and get density
	dw	fd$init
	db	3			; map D drive to C
	db	1fh			; 5" floppy, Morrow Format
fdsd3	dph	trans7f,cdpb3		; 40 tracks , 1024 b/sec, skew = 3

	cseg
		; disk paramter block goes in common memory
		; These paramter blocks must be bigger in every respect than
		; any other used by each drive.  The auto-density recognition
		; code copies the appropriate parameter block from banked
		; into these locations.  There must be one parameter block for
		; each defined unit number.

cdpb0		dpb 1024,16,77,2048,256,2
cdpb1		dpb 1024,16,77,2048,256,2

; # 2 and 3 are hard coded and are never changed by the login routine

cdpb2		dpb 512, 10,160,2048,256,3 ; Hacked Pied Piper format
cdpb3		dpb 1024, 5, 80,2048,192,2  ; Hacked Morrow 3 format

	dseg
		; These tables are 17 bytes long, and are copied into the
		; cdpb block space when required.  Each drive must have
		; its own unique parameter block.
;
; Eight inch 77 track floppies
;
ss128		dpb 128,26,77,1024,64,2		; single density, single side
sd128		dpb 128,52,77,2048,128,2	; single density, double side
ds128		dpb 128,40,77,2048,128,2	; double density, single side
dd128		dpb 128,80,77,2048,256,2	; double density, double side
ss256		dpb 256,16,77,2048,128,2
sd256		dpb 256,32,77,2048,128,2
ds256		dpb 256,26,77,2048,128,2
dd256		dpb 256,52,77,2048,256,2
ss512		dpb 512,8,77,2048,64,2
sd512		dpb 512,16,77,2048,128,2
ds512		dpb 512,15,77,2048,128,2
dd512		dpb 512,30,77,2048,256,2
ss1024		dpb 1024,4,77,2048,128,2
sd1024		dpb 1024,8,77,2048,256,2
ds1024		dpb 1024,8,77,2048,128,2
dd1024		dpb 1024,16,77,2048,256,2
;
; Five inch 40 track floppies
;
;ss128f40	dpb 128,16,40,1024,64,2
;sd128f40	dpb 128,32,40,1024,64,2
;ds128f40	dpb 128,25,40,1024,64,2
;dd128f40	dpb 128,50,40,1024,64,2
;ss256f40	dpb 256,9,40,1024,64,2
;sd256f40	dpb 256,18,40,1024,64,2
;ds256f40	dpb 256,16,40,1024,64,2
;dd256f40	dpb 256,32,40,2048,128,2
;ss512f40	dpb 512,5,40,1024,64,2
;sd512f40	dpb 512,10,40,1024,64,2
;ds512f40	dpb 512,9,40,1024,64,2
;dd512f40	dpb 512,18,40,2048,128,2
;ss1024f40	dpb 1024,2,40,1024,64,2
;sd1024f40	dpb 1024,4,40,1024,64,2
;ds1024f40	dpb 1024,5,40,1024,64,2
;dd1024f40	dpb 1024,10,40,2048,128,2
;
; Five inch 80 track floppies
;
;ss128f80	dpb 128,16,80,1024,64,2
;sd128f80	dpb 128,32,80,2048,128,2
;ds128f80	dpb 128,25,80,2048,128,2
;dd128f80	dpb 128,50,80,2048,128,2
;ss256f80	dpb 256,9,80,1024,64,2
;sd256f80	dpb 256,18,80,2048,128,2
;ds256f80	dpb 256,16,80,2048,128,2
;dd256f80	dpb 256,32,80,2048,128,2
;ss512f80	dpb 512,5,80,1024,64,2
;sd512f80	dpb 512,10,80,2048,128,2
;ds512f80	dpb 512,9,80,2048,128,2
;dd512f80	dpb 512,18,80,2048,128,2
;ss1024f80	dpb 1024,2,80,1024,64,2
;sd1024f80	dpb 1024,4,80,2048,128,2
;ds1024f80	dpb 1024,5,80,2048,128,2
;dd1024f80	dpb 1024,10,80,2048,128,2

;
;  Table of skewed sector translates for supported disk formats.
;

; 8" skew tables

trans0	skew 26,6,1		; single density, 128 byte sectors
	skew 26,6,27
trans1	skew 40,6,1		; double density, 128 byte sectors
	skew 40,6,41
trans2	skew 16,4,1		; single density, 256 byte sectors
	skew 16,4,17
trans3	skew 26,4,1		; double density, 256 byte sectors
	skew 26,4,27
trans4	skew 8,3,1		; single density, 512 byte sectors
	skew 8,3,9
trans5	skew 15,3,1		; double density, 512 byte sectors
	skew 15,3,16	
trans6	skew 4,2,1		; single density, 1024 byte sectors
	skew 4,2,5
trans7	skew 8,3,1		; double density, 1024 byte sectors
	skew 8,3,9

; 5.25 skew tables

trans0f	skew 16,6,1		; single density, 128 byte sectors
	skew 16,6,17
trans1f	skew 25,6,1		; double density, 128 byte sectors
	skew 25,6,26
trans2f	skew 9,3,1		; single density, 256 byte sectors
	skew 9,3,10
trans3f	skew 16,6,1		; double density, 256 byte sectors
	skew 16,6,17
trans4f	skew 5,2,1		; single density, 512 byte sectors
	skew 5,2,6

;trans5f	skew 9,4,1		; double density, 512 byte sectors
;		skew 9,4,10	

trans5f	skew 10,2,1		; double density, 512 byte sectors
	skew 10,2,11		; Pied Piper format


trans6f	skew 2,1,1		; single density, 1024 byte sectors
	skew 2,1,3

;trans7f	skew 5,2,1		; double density, 1024 byte sectors
;		skew 5,2,6

trans7f skew 5,3,1		; Morrow format 1024 DD
	skew 5,3,6

;
; Table of translate table pointers, dpb pointers and sectors per track
; for the different disk formats supported on the CYPHER PC.
;
; The format byte (times two if a word table) is used as an offset into these
; tables to obtain the appropriate entry.
;
; The format of the format byte is...
;	76543210
;	||||||xx -- sector size, 00 = 128, 01 = 256, 10 = 512, 11 = 1024
;	|||||x	 -- 0 = single side,    1 = double side
;	||||x	 -- 0 = single density, 1 = double density
;	xxxx	 -- disk type:	0000 = 8" floppy, 77 tracks
;				0001 = 5" floppy, 40 tracks
;				0010 = 5" floppy, 80 tracks
;
transtab

; 8" floppy


	dw trans0,trans2,trans4,trans6  ; single density, single side
	dw trans0,trans2,trans4,trans6	; single density, double side
	dw trans1,trans3,trans5,trans7	; double density, single side
	dw trans1,trans3,trans5,trans7	; double density, double side


; 40 track 5.25 floppy

;	dw trans0f,trans2f,trans4f,trans6f	; single density, single side
;	dw trans0f,trans2f,trans4f,trans6f	; single density, double side
;	dw trans1f,trans3f,trans5f,trans7f	; double density, single side
;	dw trans1f,trans3f,trans5f,trans7f	; double density, double side


; 80 track 5.25 floppy

;	dw trans0f,trans2f,trans4f,trans6f	; single density, single side
;	dw trans0f,trans2f,trans4f,trans6f	; single density, double side
;	dw trans1f,trans3f,trans5f,trans7f	; double density, single side
;	dw trans1f,trans3f,trans5f,trans7f	; double density, double side

dphtab

; 8" floppy

	dw ss128,ss256,ss512,ss1024	; single density, single side
	dw sd128,sd256,sd512,sd1024	; single density, double side
	dw ds128,ds256,ds512,ds1024	; double density, single side
	dw dd128,dd256,dd512,dd1024	; double density, double side

; 40 track 5.25 floppy


;	dw ss128f40,ss256f40,ss512f40,ss1024f40	; single density, single side, 5"
;	dw sd128f40,sd256f40,sd512f40,sd1024f40	; single density, double side, 5"
;	dw ds128f40,ds256f40,ds512f40,ds1024f40	; double density, single side, 5"
;	dw dd128f40,dd256f40,dd512f40,dd1024f40	; double density, double side, 5"

; 80 track 5.25 floppy

;	dw ss128f80,ss256f80,ss512f80,ss1024f80	; single density, single side, 5"
;	dw sd128f80,sd256f80,sd512f80,sd1024f80	; single density, double side, 5"
;	dw ds128f80,ds256f80,ds512f80,ds1024f80	; double density, single side, 5"
;	dw dd128f80,dd256f80,dd512f80,dd1024f80	; double density, double side, 5"

; this is used by selside to determine on which side from
; selected sector resides on (255 = dont care)

sectab	db 255,255,255,255		; single density, single side
	db  26, 16,  8,  4		; single density, double side
	db 255,255,255,255		; double density, single side
	db  40, 26, 15,  8		; double density, double side

;	db 255,255,255,255		; single density, single side, 5"
;	db  16,  9,  5,  2		; single density, double side, 5"
;	db 255,255,255,255		; double density, single side, 5"
;	db  25, 16,  9,  5		; double density, double side, 5"

;	db 255,255,255,255		; single density, single side, 5"
;	db  16,  9,  5,  2		; single density, double side, 5"
;	db 255,255,255,255		; double density, single side, 5"
;	db  25, 16, 9,  5		; double density, double side, 5"

cdpbtab	dw cdpb0,cdpb1,cdpb2,cdpb3

    ; Disk I/O routines for standardized BIOS interface

; Initialization entry point.

	; called for first time initialization.

fd$init:
	mvi a,0FFh		; init previous drive and tracks
	sta pdisk
	sta ptrack
fd$null:
	ret

; This is the login entry point for the Morrow drive

mor$login:
	lxi	h,1024		; 1024 bytes/sector
	jmp	do$login


; This is the entry point for the Pied Piper format

pp$login:
	lxi	h,512

do$login
	push	h		; save sector size
	call	motor$on
	xchg 
	shld 	fd$dphp
	mvi 	a,0FFh 
	sta 	@pdrv		; force a select by the monitor
	sta 	perr
	mvi 	a,5
	sta 	size58		 

	mvi 	c,0 
	call 	m$setside	
	mov 	d,5
	pop	h		; get back sector size
	mvi 	e,2		; use double density
	call 	m$setdens	; this call must come before select
	lda 	@rdrv
	mov 	c,a
	call 	m$select
	ret


; This entry is called when a logical drive is about to
; be logged into for the purpose of density determination.
; It may adjust the parameters contained in the disk
; parameter header pointed at by <DE>


fd$login:

; Start by saving the dph pointer.

	xchg 
	shld 	fd$dphp
	mvi 	a,0FFh 
	sta 	@pdrv		; force a select by the monitor
	sta 	perr
	dcx 	h 
	mov 	a,m		; get format type byte
	ani 	11110000b	; save whether 5" or 8"
	mvi 	a,8 
	jz 	fd$size
	mvi 	a,5

fd$size	sta 	size58		; and record it

	mvi 	c,0 
	call 	m$setside	; use side 0 for density determination
	lda 	size58
	mov 	d,a
	lxi 	h,1024
	mvi 	e,2		; try double density (8")first
	call 	m$setdens	; this call must come before select

	lda 	@rdrv
	mov 	c,a
	call 	m$select

	mvi 	c,1
	in 	p$floppy$status	; check for device ready
	ani 	10000000b 
	cnz 	report		; error if not ready

; Next seek to directory track + 1 to determine density
; (First 2 tracks of Sorcerer disks are SD, remainder are DD)

	mov 	c,den$trk	; move to the proper track
	mvi 	b,m$speed
	call 	m$seek 		; and do the seek

	call 	m$getsad 
	ora 	a		; return <c> = sector size code
	jz 	fd$dou		; if no error must be double density
fd$sing	lda 	size58 
	mov 	d,a
	lxi 	h,128
	mvi 	e,1		; set single density
	call 	m$setdens	; before next select
	lda 	@rdrv 
	mov 	c,a 
	call 	m$select
	call 	m$getsad 
	ora 	a
	mvi 	a,0 
	jz 	fd$log1		; no error, single density
	mvi 	c,0 
	jmp 	fd$log1		; error, assume 128 byte sectors
fd$dou	mvi 	a,00001000b	; set density bit
fd$log1	ora 	c		; mix in sector size code
	ani 	00001011b	; be sure other bits are cleared
	push 	psw
	mvi 	c,1 
	call 	m$setside	; try to read side 1
	call 	m$getsad 
	ora 	a
	mvi 	b,00000000b	; assume single side
	jnz 	fd$log2		; if error from getsad, single side
	mov 	a,e 
	cpi 	1 
	jnz 	fd$log2		;   or if side not 1, single side
	mvi 	b,00000100b	; else set double side bit
fd$log2	pop 	psw 
	ora 	b		; add to format byte
	mov 	b,a
	lhld 	fd$dphp 
	dcx 	h 
	mov 	a,m		; get previous format byte
	ani 	11110000b	; preserve only the disk type bits
	ora 	b 
	mov 	m,a		; save format byte

; Update the translate table pointer in the dph

	mvi 	h,0 
	mov 	l,a 
	dad 	h		; <hl> = twice format byte
	push 	h
	lxi 	b,transtab 
	dad 	b		; point to translate table pointer
	mov 	c,m 
	inx 	h 
	mov 	b,m		; <bc> = translate table entry
	pop 	h
	lxi 	d,dphtab 
	dad 	d		; point to dph table pointer
	mov 	e,m 
	inx 	h 
	mov 	d,m		; <de> = dph table entry
	lhld 	fd$dphp
	mov 	m,c 
	inx 	h 
	mov 	m,b		; update translate table

;
; Copy the appropriate dpb from banked memory to common memory
;

	lhld 	fd$dphp 
	dcx 	h 
	mov 	a,m		; get format byte
	mov 	l,a 
	mvi 	h,0 
	dad 	h		; <hl> = twice format byte
	lxi 	d,dphtab 
	dad 	d
	mov 	a,m 
	inx 	h 
	mov 	h,m 
	mov 	l,a		; <hl> = dpb source address
	push 	h
	lda 	@adrv 
	add 	a
	mov 	c,a 
	mvi 	b,0		; <bc> = twice drive number
	lxi 	h,cdpbtab 
	dad 	b		; point to cdpbtab entry
	mov 	a,m 
	inx 	h 
	mov 	d,m 
	mov 	e,a		; <de> = dpb destination address
	pop 	h
	lxi 	b,17
	ldir			; move dpb into common memory

; only turn off drives if in 8" mode

	lda	size58
	cpi	5
	jz	ext1
	call 	motor$off	; turn off 5.25" if using 8" drive
ext1	ret

	
; disk READ and WRITE entry points.

		; these entries are called with the following arguments:

			; relative drive number in @rdrv (8 bits)
			; absolute drive number in @adrv (8 bits)
			; disk transfer address in @dma (16 bits)
			; disk transfer bank	in @dbnk (8 bits)
			; disk track address	in @trk (16 bits)
			; disk sector address	in @sect (16 bits)
			; pointer to XDPH in <DE>

		; they transfer the appropriate data, perform retries
		; if necessary, then return an error code in <A>


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; s e l n o w	- Do the actual select now.
;

selnow:	lda 	@adrv 
	mov 	c,a		; if @adrv is same as @pdrv,
	lda 	@pdrv 
	cmp 	c 
	rz			; do nothing and return.
	mov 	a,c 
	sta 	@pdrv		; update @pdrv as @adrv
	lhld 	fd$dphp		; <hl> = dphp
	dcx 	h		; point to format byte
	mov 	a,m 
	mov 	c,a
	ani 	1000b		; D3 = 1 if double density
	mvi 	e,1 
	jz 	selsin		; jump if single density
	mvi 	e,2
selsin	mov 	a,c 
	ani 	0011b		; get sectorsize code
	lxi 	h,1024 ! cpi 3 ! jz sel3
	lxi 	h,512  ! cpi 2 ! jz sel3
	lxi 	h,256  ! cpi 1 ! jz sel3
	lxi 	h,128
sel3	mov 	a,c 
	ani 	00110000b	; get 5 or 8"
	mvi 	d,5
	jnz 	sel4
	mvi 	d,8 
	call	motor$off	; turn off 5.25" motor

sel4	call 	m$setdens	; set density  <e>, 5 or 8" <d>, sec size <hl>
	lda 	@rdrv 
	mov 	c,a
	call 	m$select	; do select through monitor
	xra 	a 
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	s e l s i d e
;

selside	lhld 	fd$dphp 
	dcx 	h 
	mov 	a,m	; get <a> = format byte

	ani	30h	; keep 5.25" bits
	jz	notpp	; is it Pied Piper or Morrow format?

; for Pied Piper, select side by the logical track we are accessing

	lda	@trk	; get track number
	ani	1
	mov	c,a
	call	m$setside
	lda	@sect		; get sector number
	sta	psect		; update physical sector
	ret

; normal drives select via the sector number

notpp:	mov	a,m
	mov 	l,a 
	mvi 	h,0	; <hl> = format byte	
	lxi 	d,sectab 
	dad 	d	; point to table entry
	lda 	@sect
	dcr 	a 
	cmp 	m	; (sector - 1) - (num per track)
	jc 	sels0	; read side 0
sels1	inr 	a 
	sub 	m 
	sta 	psect	; calculate physical sector #
	mvi 	c,1 
	call 	m$setside  ; on side 1
	ret
sels0	inr 	a 
	sta 	psect	; calculate physical sector #
	mvi 	c,0 
	call 	m$setside  ; on side 1
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	s e e k
;
seek:	lda 	@adrv
	lxi 	h,pdisk
	cmp 	m 
	mov 	m,a		; update previous drive
	jnz 	pseek		; if new drive force phys seek
	lda 	@trk
	lxi 	h,ptrack
	cmp 	m
	jnz 	pseek		; if new track force phys seek
	ret			; else no physical seek
pseek	lda 	@trk
	lxi 	h,ptrack 
	mov 	m,a		; update previous track
	
	push	h
	lhld 	fd$dphp 
	dcx 	h 
	mov 	a,m		; get <a> = format byte
	ani	030h		; see if Pied Piper or Morrow format
	lda	@trk
	jz	notppp		; no, jump
	
; for Pied Piper, shift right (divide track by 2)

	db	0cbh,03fh	; SRL A

; if 40 track drive, * 2 to map into 96 tpi drive

;	mov	c,a
;	mov	a,m		; get format byte again
;	ani	10h		; 40 track format?
;	jz	notpp2		; 80 track, so jump	
;	mov	a,c
;	db	0cbh,027h	; SLA A

notppp	mov 	c,a 
notpp2	mvi 	b,m$speed
	pop	h
	call 	m$seek 
	ani 	10011000b 
	rz
	mvi 	c,2  
	jmp 	report

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	r e a d
;
fd$read:
	xchg ! shld fd$dphp			; save dph pointer
;	call motor$on
fd$r2	call selnow ! call selside		; select appropriate disk side
	mvi c,3
	in p$floppy$status			; check device is ready
	ani 10000000b ! cnz report
	call seek
	sspd savestack
	lxi sp,local$stack			; use local stack in common mem
	lda psect ! mov c,a ! mvi b,0		; set <bc> = sector
	lda @dbnk				; set <a>  = dma page
	lhld @dma				; set <hl> = dma address
	jmp fd$r3
	cseg
fd$r3	call ?bank				; switch in dma bank
	call m$read				; call read routine in monitor
	push psw				; save returned read status
	call ?bank0				; restore page 0
	jmp fd$r4
	dseg
fd$r4	pop psw					; restore <a> = read status
	lspd savestack				; restore stack
	ani 10011100b
	sta perr				; save as previous error byte
	push psw 
;	call motor$off 
	pop psw
	rz					; check read status result
	mvi c,3 ! call report ! jz fd$r2
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	w r i t e
;
fd$write:
	xchg ! shld fd$dphp			; save dph pointer
;	call motor$on
fd$w2	call selnow ! call selside		; select appropriate disk side
	mvi c,4
	in p$floppy$status			; check device is ready
	ani 10000000b ! cnz report
	call seek
	sspd savestack
	lxi sp,local$stack			; use local stack in common mem
	lda psect ! mov c,a ! mvi b,0		; set <bc> = sector
	lda @dbnk				; set <a>  = dma page
	lhld @dma				; set <hl> = dma address
	jmp fd$w3
	cseg
fd$w3	call ?bank				; switch in dma page
	call m$write				; read physical sector
	push psw				; save returned status byte
	call ?bank0				; switch in page 0
	jmp fd$w4
	dseg
fd$w4	pop psw					; restore <a> = write status
	lspd savestack				; restore stack
	ani 11011100b
	push psw 
;	call motor$off 
	pop psw
	rz					; check write status byte
	mvi c,4 ! call report ! jz fd$w2
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	motor control
;		Turn motor on/off with bit 5 of the ppi 8255 par port.
;		Signal is active low.
;
motor$on
	in p$ppi$dataA
	ani 11011111b
	out p$ppi$dataA

; now wait > 250ms for motor to turn on

	push	h
	push	b

	lxi	b,091a8h	; 

dncnt	lhld	0000		; (16) wait
	dcx	b		; (6) 
	mov	a,c		; (4)
	ora	b		; (4)
	jnz	dncnt		; (10)
	pop	b
	pop	h
	ret

motor$off
	push	psw
	in 	p$ppi$dataA
	ori 	00100000b
	out 	p$ppi$dataA
	pop	psw
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	r e p o r t
;
report:	sta @flags
	mov a,c ! sta @class		; store command class of error
	lda perr ! ani 10011100b
	jnz rep				; cont if previous try was an error too
	pop h				; skip one return level
	mvi a,0FFh ! ret		; else return <a> = FF (force login)
rep:	lda @ermde ! cpi 0FFh ! jz hard$error
	lxi h,dskmsg ! call pmsg ! dcx h
	lda @class ! mov b,a
rep1:	call skip
	djnz rep1			; skip to next '$' in string at hl
	call pmsg			; print string now pointed to by hl
	lxi h,errmsg ! call pmsg	; print 'error  ' after type
	lda @flags ! ral ! jc rep8	; jump if drive-not-ready error
	mov e,a				; put remaining 2793 error bits in e
	lxi h,rwerrs
	lda @class ! cpi 3 ! jnc rep2	; jump if not seek/select of r/w errors
	lxi h,skerrs
rep2:	mvi b,5
	res 0,d
rep4:	slar e
	jnc rep5
	call pmsg
	setb 0,d
	jmp rep6
rep5:	call skip			; skip to next string at hl
	res 0,d
rep6:	djnz rep4			; repeat for all 5 possible errors
	call ?pderr			; print track and sector
hard$error:
	pop h				; skip one level of subroutines
	mvi a,1 ! ora a ! ret		; return hard error to bdos

rep8:	lxi h,rdymsg ! call pmsg	; print disk-not-ready message
	jmp hard$error

skip:	push b
	mvi b,255 ! mvi a,'$'
	ccir
	pop b ! ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	pmsg		- print string pointed to by <hl>
;			- end string with '$'
;			- save bc, de
pmsg:	push b ! push d
pmsg1:	mov a,m ! inx h ! cpi '$' ! jz pmsgr
	mov c,a ! push h ! call ?cono ! pop h
	jmp pmsg1
pmsgr:	pop d ! pop b ! ret

dskmsg:	db	cr,lf,lf,'*** CP/M Plus FLOPPY DISK $'
	db	'SELECT $'
	db	'SEEK $'
	db	'READ $'
	db	'WRITE $'
errmsg:	db	'ERROR ***',cr,lf,'$'
skerrs:	db	'$'
	db	'$'
	db	'   - cannot seek track',cr,lf,'$'
	db	'   - bad sector (cyclic redundancy check error)',cr,lf,'$'
	db	'   - cannot restore drive',cr,lf,'$'
rdymsg:	db	'   - drive is not ready',cr,lf,'$'
rwerrs:	db	'   - drive is write protected',cr,lf,'$'
	db	'   - drive write fault detected',cr,lf,'$'
	db	'   - record not found',cr,lf,'$'
	db	'   - bad sector (cyclic redundancy check error)',cr,lf,'$'
	db	'   - data overrun (lost data)',cr,lf,'$'

@pdrv:	db	0FFh		; previous drive unit number
@flags:	db	0
@class:	db	0
fd$dphp	dw	0		; disk parameter pointer
size58	db	0		; has value 5 or 8 for 5" or 8" floppy size
psect	db	0		; physical sector
perr	db	0		; previous error byte
pdisk	ds	1		; previous disk
ptrack	ds	1		; previous track
	end
