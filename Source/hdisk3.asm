	title 'CYPHER hard disk driver for CP/M Plus'
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	h d i s k 3 . a s m
;
;	CP/M Plus (tm) compatible disk controler routine for the CYPHER PC.
;	CP/M Plus is a trade mark of Digital Research, Calif.
;
;	This version for Seagate 1610-3 disk controller
;	and Miniscribe 3425 hard disk configured as two
;	logical 10 meg hard disks.
;
;	NOTE: On my SASI card I do not use an inverted data buss
;	      so all data i/o has to be inverted. But the status
;	      register doesn't have to be inverted.
;
;	2) I use fe80-feff (default dma buffer) to do a software kludge
;	   for read/writing to the hard disk (there was not enough room
;          in the cseg to put all the R/W code, so I do the R/W in the
;	   dseg then block move the data to the correct bank# via this
;	   dma buffer in high memory.
;
;	Version 1	- RCL, integrated hard disk routines for SASI.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

true	equ	-1
false	equ	0

;------------------------------------------------------------------------------
;	Define some equates
;------------------------------------------------------------------------------

MAX$DRIVES	equ	2	; 2 logical hard disks (F and G)

Data$Port	equ	029h
Status$Port	equ	02bh
Reset$Port	equ	02bh
Select$Port	equ	02dh

;------------------------------------------------------------------------------
;	Define some SCSI equates
;------------------------------------------------------------------------------

; Note that the BIT command does not use equates in this file

Req$SCSI	equ	00010000b	; status port definition
Msg$SCSI	equ	00001000b
Busy$SCSI	equ	00000100b
Cmd$SCSI	equ	00000010b
Input$SCSI	equ	00000001b	; 1 = input to host


; SCSI phases: command, (data), status, messsage, done

; command phase (1st phase)
Out$Cmd$SCSI	equ	Req$SCSI + Busy$SCSI + Cmd$SCSI

; data phase in (to host)
In$Data$SCSI	equ	Req$SCSI + Busy$SCSI + Input$SCSI
; data phase out (to controller)
Out$Data$SCSI	equ	Req$SCSI + Busy$SCSI

; status phase (after data phase, if any)
Status$SCSI	equ	Req$SCSI + Busy$SCSI + Cmd$SCSI + Input$SCSI

; command done phase (all phases complete)
Cmd$Done$SCSI	equ	Req$SCSI + Busy$SCSI + Msg$SCSI + Cmd$SCSI + Input$SCSI

Mask$SCSI	equ	00011111b

; ------------------------------------------------------------------------------

    ; Disk controller commands

	dseg

	extrn	local$stack
	extrn	savestack

    ; Disk drive dispatching tables for linked BIOS

	extrn	@dtbl
	public	hxdph0,hxdph1

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
;				  but bc , de, and af are destroyed
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

;
; The controller is set up for a SASI
; hard disk controller  and a four head, 20 Mbyte Winchester
; type drives. There are 17 sectors of 512 bytes per track,
; or 68 logical sectors. The block size is 4096 bytes, or
; 8 physical sectors.
; There are 615 cylinders, with 10k reserved for the system.
; Therefore there are 615 x 4 = 2460 tracks per drive, or
; 5227.5 blocks.

; The 22 megs is split into two logical drives, each with 11 megs.


	dseg

    ; Extended Disk Parameter Headers (XPDHs)

	dw hd$write
	dw hd$read
	dw hd1$login
	dw hd$init
	db 0				; hard disk drive #0
	db 01000010b			; disk format (unused) byte
hxdph0	dw 0000				; no sector translation
	db 0,0,0,0,0,0,0,0,0		; 72 bits of scratch
	db 0				; media flag
	dw hdpb0
	dw 0				; permanently mounted
	dw 0FFFEh			; alv
	dw 0FFFEh			; dirbcb
	dw 0FFFEh			; dtabcb
	dw 0FFFEh			; hash
	db 0				; h bank

	dw hd$write
	dw hd$read
	dw hd1$login
	dw hd$init
	db 0				; hard disk drive #0 still
	db 01000010b			; disk format (unused)
hxdph1	dw 0000				; no sector translation
	db 0,0,0,0,0,0,0,0,0		; 72 bits of scratch
	db 0				; media flag
	dw hdpb1
	dw 0				; permanently mounted
	dw 0FFFEh			; alv
	dw 0FFFEh			; dirbcb
	dw 0FFFEh			; dtabcb
	dw 0FFFEh			; hash
	db 0				; h bank


;------------------------------------------------------------------------------
;	Drive Tables
;------------------------------------------------------------------------------
;
;   The Drive tables follow$  They constist of a 16 byte table for each
;   active drive$  The table format is
;	+00  \
;	...  +--8 byte Drive characteristic
;	+07  /
;	+08	Step rate
;	+09	Drive number (00h = drive 0, 20h = drive 1)
;	+10	Controller Selection byte
;	+11	Sector Size (1=256, 2=512)
;	+12 \
;	...  +--4 bytes unused
;	+15 /
;

Drive$Table

;..let's define Drive 0 here


	; Miniscribe 3425 drive characteristics
	db	high 615	; # of cylinders
	db	low 615
	db	4		; # of heads
	db	high 615	; Reduced current cylinder
	db	low 615
	db	high 128	; Write precomp cylinder
	db	low 128
	db	8		; 8 bits ECC burst correction
	db	7		; step option - 40us buffered step


	db	0		; this is drive #0 to that controller (cur$drive)
	db	0		; controller selector byte (cur$control)
	db	2		; 512 bytes/sector
	db	0,0,0,0		; ..unused table entries


;------------------------------------------------------------------------------
;	Disk parameter block
;------------------------------------------------------------------------------

	cseg	; disk parameter block goes in common memory

; 21,411,840 = 615 tracks * 17 sect/track * 512 bytes/sec * 4 heads

;
; System: 	2$5 blocks  = 10,240 bytes
; Drive F:	2612 blocks = 10,698,752 bytes -+ total 21,401,600
; Drive G:	2613 blocks = 10,702,848 bytes -+
;
; Total blocks = 5227.5 = 21,411,840 bytes


hdpb0	dw 	4		; spt - 4 logical sectors per track
				; (1 physical sec/trk)
	db 	5,31,1		; bsh, blm, exm
	dw 	2611		; dsm - 10,698,752 bytes
	dw	2047		; 2047 + 1  dir entries allocated
	db	11111111b	; ..allocation map for dir
	db	11111111b	; ...2048 entries = 2048*32/4096 = 16 bits
	dw 	8000h		; cks - permanent drive
	dw 	20		; off - track offset (10k*1024/512)
				;     - 2.5 blocks
	db 	2,3		; psh, phm

hdpb1	dw 	4		; spt - 4 logical sectors per track
	db 	5,31,1		; bsh, blm, exm
	dw 	2612		; dsm - 10,702,848 bytes
	dw	2047		; 2047 + 1  dir entries allocated
	db	11111111b	; ..allocation map for dir
	db	11111111b	; ...2048 entries = 2048*32/4096 = 16 bits
	dw 	8000h		; cks - permanent drive
	dw 	20916		; off - track offset = 20 + 2612*4096/512
	db 	2,3		; psh, phm

	dseg
;
; The format of the format byte is...
;	76543210
;	||||||xx -- sector size, 00 = 128, 01 = 256, 10 = 512, 11 = 1024
;	|||||x	 -- 0 = single side,    1 = double side
;	||||x	 -- 0 = single density, 1 = double density
;	xxxx	 -- disk type:	0000 = 8" floppy, 77 tracks
;				0001 = 5" floppy, 40 tracks
;				0010 = 5" floppy, 80 tracks
;				0100 = hard disk
;

    ; Disk I/O routines for standardized BIOS interface

; Initialization entry point - called for first time initialization

hd$init	mvi	a,0
	sta	cur$control	; select controller # 0
	call	reset		; reset the controller card

; Try to select card and try ram diagnostic test

cardok	mvi	a,0e0h		; ram diagnostic command
	call	task1
	jrnz	nocontr		; oops, no card there
	call	getstat
	ora	a
	jrz	ramok
	call	report
	ret

ramok	mvi	a,0e4h		; controller diagnostic command
	call	task1
	jrnz	nocontr
	call	getstat
	ora	a
	rz
	call	report
	ret

hd$null
	ret

; no sasi card, send error msg

nocontr lxi	h,nocard	; tell no card found
	jmp	?pmsg

; This entry is called when a logical drive is about to
; be logged into for the purpose of density determination$
; It may adjust the parameters contained in the disk
; parameter header pointed at by <DE>

hd1$login
	xchg 			; Start by saving the dph pointer$
	shld 	hd$dphp
	mvi	c,0		; select drive 0
	call	Sendchar	; and select the drive
	ora	a
	rz
	jmp	prterr

;hd2$login
;	xchg 			; Start by saving the dph pointer$
;	shld 	hd$dphp
;	mvi	c,1		; select drive 1
;	call	Sendchar	; and select the drive
;	ora	a
;	rz

prterr	lxi	h,select$msg	; print error message
	call	?pmsg
	lda 	@rdrv
	mvi 	h,0
	mov 	l,a
	call 	?pdec
	lxi	h,crlf
	call	?pmsg
	mvi	a,1
	ora	a
	ret

; disk READ and WRITE entry points$

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


;------------------------------------------------------------------------------
;	Read
;------------------------------------------------------------------------------

;
;   Read a sector from the hard disk.
;   SendChar *MUST* have been called previously
;
;   OUTPUTS:
;	A   = error code
;		0 = no error

hd$read
	xchg
	shld 	hd$dphp			; save dph pointer
	mvi	b,0			; set retry flag active
	mvi	c,0
	lded	@trk			; since we are using 1 physical sector/track, then the
					; track number actually is the logical block address
	call	setup$rw		; setup the task block

;	mvi	a,0eh
;	call	debug		; ###

	mvi	a,8			; the read command
	call	taskout

;	mvi	a,0fh
;	call	debug		; ####

	mvi	e,4			; input four blocks of 128 bytes
	lhld 	@dma			; pick up the dma address

;	mvi	a,10h
;	call	debug		; ###

read2	push	d			; save count
	lxi	d,0fe80h		; point to default dma buffer in monitor
	mvi	b,128			; read 128 characters only

read1	in	Status$Port		; get SCSI status
	cma
	ani	Mask$SCSI

	cpi	Status$SCSI		; *** take out ###
	jrnz	notpre
	lxi	h,prema
	call	?pmsg
	jr	pre

prema	db	'Unexpected End of Sector',cr,lf,0

notpre	cpi	In$Data$SCSI		; wait until data appears
	jnz	read1

	in	Data$port		; get next character
	cma
	stax	d			; put character away in temp. dma buffer
	inx	d

;	mvi	a,11h
;	call	debug		; ###

	dcr	b			; dec # of characters to get this block
	jnz	read1			; get rest for this block

;	mvi	a,12h
;	call	debug		; ###

pre	mvi	c,0
	call	blockmv			; go move to correct bank #

;	mvi	a,13h
;	call	debug		; ###

	pop	d
	dcr	e
	jrnz	read2			; go read next block

;	mvi	a,14h
;	call	debug		; ###

	call	getstat

;	push	psw
;	mvi	a,15h
;	call	debug		; ####
;	pop	psw

	ora	a
	rz
	jmp	report		; report error condition

; ---------------------------------------------------------------------------
; BLOCKMV:	block move 128 bytes from FE00 to another bank
; ---------------------------------------------------------------------------
;
; Inputs:  hl    = destination address
;          @dbnk = destination bank number

	cseg

blockmv
	push	b
	push	d
	lda	@dbnk			; switch in the dest. bank
	call	?bank

	lxi	d,0fe80h		; point to monitor's default dma buffer
	mvi	b,128			; move 128 bytes
	mov	a,c			; see if read or write from the buffer
	cpi	00			; 00 = buffer->dma, 01 = dma -> buffer
	jz	bufdma

; transfer from memory to default dma buffer

dmabuf	mov	a,m			; pick up dma memory
	stax	d			; and store it in default buffer
	inx	h
	inx	d
	djnz	dmabuf			; loop for all data
	jr	bk2

bufdma	ldax	d			; get from default dma buffer
	mov	m,a			; and store it away in dma memory
	inx	h
	inx	d
	djnz	bufdma			; loop for all data

bk2	call	?bank0			; bring back the original bank
	pop	d
	pop	b
bk1	ret

	dseg

;------------------------------------------------------------------------------
;	Write::  write the buffer to the disk
;------------------------------------------------------------------------------
;
;   Write a sector to the hard disk$
;   SendChar *MUST* have been called previously
;
;   OUTPUTS:
;	A   = error code
;		0 = no error
;

hd$write
	xchg
	shld 	hd$dphp			; save dph pointer
	mvi	b,0			; set retry flag active
	mvi	c,0
	lded	@trk			; since we are using 1 physical sector/track, then
					; track number actually is the logical block address
	call	setup$rw		; set up task block for the write
	mvi	a,0ah			; write command
	call	taskout			; send out the task

	call	reqwait			; wait for a request
	mvi	e,4			; write four blocks of 128 bytes
	lhld 	@dma			; pick up the dma address

write2	push	d			; save count
	lxi	d,0fe80h		; point to default dma buffer in monitor
	mvi	b,080h			; read 128 characters only
	mvi	c,1
	call	blockmv			; go next next block

write1	in	Status$Port		; get SCSI status
	cma
	ani	Mask$SCSI
	cpi	Out$Data$SCSI		; wait until data appears
	jnz	write1

	ldax	d			; get inverted character from default dma buffer
	cma
	out	Data$port		; send out next character
	inx	d
	djnz	write1
	pop	d
	dcr	e
	jrnz	write2			; go write next block

	call	getstat			; check for errors
	ora	a
	rz				; no errors, return
	jmp	report			; report error condition

;------------------------------------------------------------------------------
;	Sendchar
;------------------------------------------------------------------------------
;
Sendchar
;
;  Send the drive characteristic table to the controller
;
;  INPUTS:
;	C  = drive number to select (0 = drive 0)
;
;  OUTPUTS:
;	A  = error code
;		0  = no error
;		128= drive # out of range
;		255= controller select failed
;  AFFECTS:
;	AF
;

;	mvi	a,1
;	call	debug	; ####

	mov	a,c
	cpi	max$drives
	mvi	a,128			;set error code
	rnc				;return with error code if >maxdrv

	lda	Send$lastdrv		;check if same as last drive
	cmp	c
	mvi	a,0
	rz				;exit if same drive
	mov	a,c
	sta	Send$temp

	push	b
	push	h
	mov	a,c
	add	a	;*2
	add	a	;*4
	add	a	;*8
	add	a	;*16
	mov	l,a
	mvi	h,0
	lxi	b,Drive$Table
	dad	b			;now find the proper table to use
	shld	Cur$Table

	lxi	b,0008			;offset to step rate
	dad	b
	mov	a,m
	sta	Cur$Step		;save the step
	inx	h
	mov	a,m
	sta	Cur$Drive		;and the drive
	inx	h
	mov	a,m			;yank the selection byte
	sta	Cur$Control		;..save the selection byte
	inx	h
	mov	a,m
	sta	Cur$Size		;save the sector size as well

	mvi	a,0ch			;send drive char cmd
	call	taskout

	in	status$Port
	bit	2,a			;check for busy
	jnz	Sendchar$ctl$err	; no busy, error then

	mvi	b,8			;8 bytes to send
	lhld	Cur$Table		;get back the drive char table

Sendchar1
	call	reqwait
	mov	a,m
	inx	h
	cma
	out	Data$Port
	djnz	Sendchar1

	call	getstat

Sendchar$Exit

	ora	a
	jnz	send$err
	lda	Send$Temp
	sta	Send$Lastdrv
	xra	a
	jmp	send$exit2

send$err

	push	psw
	xra	a
	dcr	a
	sta	Send$Lastdrv
	call	reset
	pop	psw

send$Exit2

	pop	h
	pop	b
	ret

Sendchar$ctl$err

	mvi	a,255
	pop	h
	pop	b
	ret

;------------------------------------------------------------------------------
;	Utility Routines for Hard Disk
;------------------------------------------------------------------------------

setup$rw

;
;   This routine sets up the task block
;   INPUTS:	b = 2 if no error retry wanted
;		c = MSB block address
;		d = Middle block address
;		e = LSB block address



;   OUTPUTS:
;	(task..Task+05) = set up for proper disk i/o
;   AFFECTS:
;	AF, B
;
	mov	a,c
	ani	00011111b		;mask out invalid addr
	mov	c,a
	lda	Cur$Drive		;get the current drive
	ora	c			;add in the high addr
	sta	task+1			;put it where it belongs
	mov	a,d
	sta	task+2
	mov	a,e
	sta	task+3
	mvi	a,1			;read in 1 block
	sta	task+4
	mov	a,b
	rrc
	rrc
	ani	080h
	mov	b,a
	lda	Cur$Step
	ani	0fh
	ora	b
	sta	task+5
	ret

reqwait
;
;  Wait for the controller to request a command
;
	push	psw
reqwait1
	in	Status$Port
	bit	4,a
	jrnz	reqwait1
	pop	psw
	ret

read$byte
	in	Status$Port
	bit	4,a			; wait for busy to go low
	jrnz	read$byte
	call	reqwait			; wait for a request
	bit	0,a			; internal check, make sure
	jrz	r2			; it is in read mode

	lxi	h,int1
	call	internal$Error

r2	in	Data$Port
	cma
	ret


getstat:
;
;  Get the 2 status bytes that follow the completion of a command
;
;  OUTPUTS:
;	A  = error code
;		0  = no errors
;		xx = error code
;	C  = A
;
;  AFFECTS:
;	AF, C
;

	in	Status$Port
	cma
	ani	Mask$SCSI		;mask out bits
	jz	getstat1		;jump out, if SCSI inactive

;	mvi	a,17h
;	call	debug		; ###


	call	reqwait			;wait for another request
	in	Status$Port
	cma
	ani	Mask$SCSI		; check for:
	cpi	Status$SCSI		;  Sending Status byte
	jrz	g2
	lxi	h,int2
	call	internal$error		; not in status phase, so somethings wrong
g2	call	read$byte		; read in the status byte
	mov	c,a			; save the status byte
	call	reqwait			; wait for another request
	in	Status$Port		; get message status byte
	cma
	ani	Mask$SCSI
	cpi	Cmd$Done$SCSI		; Make sure we are in Message phase
	jrz	g3
	lxi	h,int3
	call	internal$error
g3	call	read$byte		; read  in message phase byte
	ora	a			; internal consistency check
	jrz	g4
	lxi	h,int4
	call	internal$Error 		;..should be 0 if SCSI

g4	bit	1,c			;now check for any errors
	rz				;..no errors, just return

getstat1
	mvi	a,3			;request sense status
	call	taskout			;..send cmd

	call	read$byte		; Get first sense byte
	mov	c,a			; Save error code
	call	read$byte
	call	read$byte
	call	read$byte

	call	read$byte		; get the status byte
	bit	1,a
	jrz	g5
	lxi	h,int5
	call	internal$error		; should not cause any errors

g5	in	Status$Port		; check for message phase
	cma
	ani	Mask$SCSI
	cpi	Cmd$Done$SCSI		;check for cmd done (message phase)
	jrz	g6
	lxi	h,int6
	call	internal$error

g6	call	read$byte		;read the last byte (message byte)
	ora	a
	jrz	g7
	lxi	h,int7
	call	Internal$Error		;internal error if non-zero

g7	mov	a,c			;restore the error byte
	ret

;
;  Send a command to the controller
;	Passed in A register
;
; Returns NZ if error (ie. if card was selected and we tried to select it again)

; Entry point here for HD$INIT, returns error instead of sending Internal Error

Task1	lxi	h,task
	mov	m,a		;save the current command

	call	select
	ora	a
	rnz			;return if there is no controller card

	jr	tk4

; normal entry point here, if get error then report as 'internal error'

Taskout	lxi	h,task
	mov	m,a		;save the current command

	call	select
	ora	a
	jrz	tk4

	lxi	h,int8
	call	internal$error	; report selection error

tk4	lda	Cur$Drive
	inx	h		;bump hl to point to (task + 01)
	db	0cbh,0aeh	; 'res 5,(hl)'
				;first reset the drive bit (=drive 0)
	ora	m		;now A = @(task + 01) or (drive bit)
	mov	m,a		;..put back the masked drive #

	dcx	h		;point to the task at hand
	mvi	b,6
tk1	in	Status$Port
	cma
	ani	Mask$SCSI
	cpi	Out$Cmd$SCSI
	jnz	tk1

	mov	a,m
	cma
	out	Data$Port
	inx	h
	dcr	b
	jrnz	tk1

; now wait for Data phase or Status Phase

tk2	in	(Status$Port)
	cma
	ani	Mask$SCSI
	cpi	In$Data$SCSI
	jrz	ok
	cpi	Out$Data$SCSI
	jrz	ok
	cpi	Status$SCSI	; check for status phase
	jrnz	tk2		; loop until correct phase appears

ok
;	mvi	a,0ch
;	call	debug		; ####

	mvi	a,0
	ora	a		; return ok status
	ret

select
;
;  Select the controller
;
;  INPUTS:
;	@(Cur$Control) = controller number to select
;  OUTPUTS:
;	A = error code
;		0  = no error
;		255= controller timed out
;

	call	waitnbusy		;wait for SCSI to be free
	rnz				;return with error if timed out

select$ok

	lda	Cur$Control		;now get the controller number
	out	Data$Port		;send it to the data port
	out	Select$Port		;..and select the controller
					;...and fall thru to wait for busy

waitbusy
;
;  Wait for a busy signal on the SCSI bus
;
;  OUTPUTS:
;	A  = error code
;		0  = no error
;		255= time-out
;  AFFECTS:
;	AF
;
;
	push	b
	lxi	b,0			;time out constant (=2 millisecs)

wait1busy
	in	Status$Port		;wait for the controller to
	bit	2,a			; be active
	jrz	wait2busy
	dcr	c
	jrnz	wait1busy
	djnz	wait1busy
	pop	b
	xra	a
	dcr	a
	ret


wait2busy
	pop	b
	xra	a
	ret

waitnbusy

;
;  wait till SCSI is not busy
;
	push	b
	lxi	b,0000
waitnbusy1
	in	Status$Port
	bit	2,a
 	jrnz	waitnbusy2
	dcr	c
	jrnz	waitnbusy1
	djnz	waitnbusy1
	xra	a
	dcr	a
	pop	b
	ret

waitnbusy2

	xra	a
	pop	b
	ret

reset
;
;  Reset all devices on the SCSI bus
;

	xra	a
	out	Reset$Port
	ret


; -------------------------------------------------------------

; Convert Controller Error to a message

; Input: A = sense byte error # from controller

; -------------------------------------------------------------

; first pick up the class of the error

report:	push	psw
	lxi	h,dskmsg
	call	?pmsg		; print out opening message
	pop	psw
	push	psw
	ani	70h
	lxi	h,lvl0$err
	cpi	10h
	jrz	sendit
	lxi	h,lvl1$err
	cpi	20h
	jrz	sendit
	lxi	h,lvl2$err
	cpi	30h
	jrz	sendit
	lxi	h,lvl3$err
	cpi	40h
	jrz	sendit
	pop	psw
	lxi	h,noclass
	call	?pmsg
	jr	hd$error

sendit	pop	psw
	ani	0fh
	db	0cbh,027h	; sla a
	mov	e,a
	mvi	d,0
	dad	d		; get address of message
	call	?pmsg
	lxi	h,crlf
	call	?pmsg

hd$error
	mvi 	a,1
	ora 	a
	ret			; return hard error to bdos


;------------------------------------------------------------------------------
;	Severe ERROR Handling routines
;------------------------------------------------------------------------------
;
internal$error
;
;  Arrive here on an internal inconsistency error
;

	push	h		; save routine address message
	lxi	h,int$err
	call	?pmsg
	pop	h		; get routine address message
	call	?pmsg
	lxi	h,pc$msg
	call	?pmsg
	pop	h		; get address
	push	h
	call	?pdec

	lxi	h,sp$msg
	call	?pmsg

	lxi	h,0
	dad	sp
	call	?pdec
	lxi	h,boot$msg
	call	?pmsg
	call	reset		;reset the controller
	mvi	a,1
	jmp	reboot


	cseg
reboot:	out	1		; select tpa bank
	rst	0		; then jump to 0

	dseg

;-------------------------------------------------------------

boot$msg db	cr,lf,'Warm booting CP/M+',cr,lf,lf,0
sp$msg	db	'. SP= ',0
pc$msg	db	', PC= ',0
int$err db	cr,lf,'HDISK3.ASM: Internal Error, Routine Name = ',0

int1	db	'Read$Byte',0
int2	db	'g2',0
int3	db	'g3',0
int4	db	'g4',0
int5	db	'g5',0
int6	db	'g6',0
int7	db	'g7',0
int8	db	'Taskout (selection error)',0

select$msg	db cr,lf,'Error: Could not select HD # ',0

crlf	db	cr,lf,0
notused	db	'Err: Not used message',0

cl0$0  db	'No sense',0
cl0$1  db	'No index signal from HD',0
cl0$2  db	'No seek complete',0
cl0$3  db	'Drive fault',0
cl0$4  db	'Drive not ready',0
cl0$6  db	'No track 0',0
cl0$8  db	'Seek in progress',0

cl1$0  db	'ID Crc error',0
cl1$1  db	'Uncorr. data error',0
cl1$2  db	'ID Addr mark not found',0
cl1$4  db	'Record not found',0
cl1$5  db	'Seek error',0
cl1$8  db	'Corr. data check',0
cl1$9  db	'Bad block found',0
cl1$a  db	'Format error',0
cl1$c  db	'Class 1-c: See manual',0
cl1$d  db	'Class 1-d: See manual',0
cl1$e  db	'Class 1-e: See manual',0
cl1$f  db	'Class 1-f: See manual',0

cl2$0  db	'Invalid cmd',0
cl2$1  db	'Illegal blk addr',0
cl2$2  db	'Illegal f`n or Cur. drive type',0


cl3$0  db	'Controller Ram error',0
cl3$1  db	'Eprom checksum err',0
cl3$2  db	'ECC diagnostic err',0

dskmsg	db	cr,lf,lf,'CP/M+ Hard Disk Error',cr,lf,0
noclass	db	'Int Err: Class of err msg not recognized',cr,lf,0

nocard	db	'No SASI card found',cr,lf,0

lvl0$err
	dw	cl0$0
	dw	cl0$1
	dw	cl0$2
	dw	cl0$3
	dw	cl0$4
	dw	notused
	dw	cl0$6
	dw	notused
	dw	cl0$8

lvl1$err
	dw	cl1$0
	dw	cl1$1
	dw	cl1$2
	dw	notused
	dw	cl1$4
	dw	cl1$5
	dw	notused
	dw	notused
	dw	cl1$8
	dw	cl1$9
	dw	cl1$a
	dw	notused
	dw	cl1$c
	dw	cl1$d
	dw	cl1$e
	dw	cl1$f

lvl2$err
	dw	cl2$0
	dw	cl2$1
	dw	cl2$2

lvl3$err
	dw	cl3$0
	dw	cl3$1
	dw	cl3$2


;------------------------------------------------------------------------------
;	Here is the temporary storage area
;------------------------------------------------------------------------------

Cur$Size		db	01

Cur$control		db	00		; use to be 1

Cur$drive		db	00

Cur$Step		db	00

Cur$table		dw	Drive$table

Send$Temp		db	00

Send$Lastdrv		db	0ffh

Task
			db	0	;command byte
			db	0
			db	0
			db	0
			db	0
			db	0

hd$dphp			dw	0	; disk parameter pointer

;debug	push	d
;	push	b
;	push	h
;	mvi	h,0
;	mov	l,a
;	call	?pdec
;	pop	h
;	pop	b
;	pop	d
;	ret

	end
