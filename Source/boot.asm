	title 'CYPHER cold boot routine'
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	b o o t . a s m
;
;	CP/M Plus (tm) compatible cold boot initialization routine.
;	CP/M Plus is a registered trade mark by Digital research, Calif.
;
;	Motel Computers Ltd.,
;	174 Betty Ann Dr.,
;	Willowdale, Canada
;
;	Version 1	- Ian Cunningham  January 1 1985
;		3	- NEC terminal emulator June 85 I.Cunningham
;		3.2	- hard disk driver added
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

true	equ -1
false	equ not true

banked	equ true
copyccp	equ true

	public  savestack
	public	local$stack		; This common mem stack can be used by
					;   other cp/m 3 routines.  Make sure
					;   there will be no conflicts.

	public	?init,?ldccp,?rlccp,?time
	extrn	?pmsg,?conin,?cono
	extrn	@civec,@covec,@aivec,@aovec,@lovec
	extrn 	@cbnk,?bnksl,?stbnk, ?bank, ?bank0,?cur$bank
	extrn	@date,@hour,@min,@sec
	extrn	?xmov,?mov

	maclib z80			; define some z80 op codes
	maclib ports			; define cypher port addresses
	maclib cymonitr			; define cypher monitor entry points

bdos	equ	5

lf	equ	0Ah
cr	equ	0Dh

	if banked
tpa$bank	equ 1
ccp$bank	equ 2
	else
tpa$bank	equ 0
	endif

	dseg	; init done from banked memory

?init:
		; 08000h = CONSOL: cypher monitor console device
		; 04000h = RS232A: serial interface A
		; 02000h = RS232B: serial interface B
		; 01000h = NECGRA: NEC graphics terminal emulator
		; 00800h = CEN:    parallel printer output (expansion 8255)
		; 00400h = null:
		; 00200h = null:
		; 00100h = null:

	lxi h,08000h ! shld @covec ! shld @civec	; console device
	lxi h,00800h ! shld @lovec			; Centronics printer
	lxi h,04000h ! shld @aivec ! shld @aovec	; serial A and NEC
	lxi h,init$table
	call out$blocks				; set up misc hardware
	lxi h,signon$msg ! call ?pmsg		; print signon message
	ret	

out$blocks:
	mov a,m ! ora a ! rz ! mov b,a
	inx h ! mov c,m ! inx h
	outir
	jmp out$blocks


	cseg	; boot loading must be done from resident memory
	
    ;	This version of the boot loader loads the CCP from a file
    ;	called CCP.COM on the system drive (A:).

?ldccp:
    ; First time, load the CCP.COM file into TPA
	xra a ! sta ccp$fcb+15		; zero extent
	mov h,a				; zero HL
	mov l,a
	shld fcb$nr		; start at beginning of file
	lxi d,ccp$fcb ! call open	; open file containing CCP
	inr a ! jrz no$CCP		; error if no file...
	lxi d,0100h ! call setdma	; start of TPA
	lxi d,128 ! call setmulti	; allow up to 16k bytes
	lxi d,ccp$fcb ! call read	; load the thing
					; now,
	if copyccp
						; copy CCP to bank 2 for reloading
		mvi a,32			; copy 32 128-byte sectors (4k)
		lxi d,0100h ! lxi h,0000h	; starting at 0100h to 0000h

ld$1		push psw
		mvi c,tpa$bank ! mvi b,ccp$bank	; prep source and dest bank
		call ?xmov			; prepare for extended move
		lxi b,128			; move 128 bytes at a time
		call ?mov			; move block
		pop psw ! dcr a ! jrnz ld$1	; loop until 32 sectors moved
	endif
	ret

no$CCP:			; here if we couldn't find the file
	lxi h,ccp$msg ! call ?pmsg	; report this...
	jmp m$cold			; and return to the monitor

?rlccp:
	if copyccp
		mvi a,32			; copy 32 128-byte sectors (4k)
		lxi d,0000h ! lxi h,0100h	; start at 0100h to 0100h
rl$1		push psw
		mvi c,ccp$bank ! mvi b,tpa$bank	; prep source and dest banks
		call ?xmov			; prepare for extended move
		lxi b,128			; move 128 bytes at a time
		call ?mov
		pop psw ! dcr a ! jrnz rl$1	; loop until 32 sectors moved
		ret
	else
		jmp ?ldccp
	endif
	
    ; External clock.
?time:	push h ! push d				; save <hl> and <de>
	sspd savestack
	lxi sp,local$stack			; use local stack
	call ?bank0			; switch in bank 0
	jmp btime

timeret	call ?cur$bank			; restore current bank
	lspd savestack				; restore stack
	pop d ! pop h				; restore <hl> and <de>
	ret

	dseg
btime
	mov a,c
	cpi 0 ! jz ?time$get		; get time and date, put in SCB

?time$set:
	mvi a,0Ah ! out p$rtc$address	; init clock register A
	mvi a,2Ah ! out p$rtc$data	; 32.768kHz, 64Hz SQW
	mvi a,0Bh ! out p$rtc$address	; init clock register B
	mvi a,80h ! out p$rtc$data	; disable updates

	mvi a,00h ! out p$rtc$address	; set clock
	lda @sec  ! call bcdtobin ! out p$rtc$data
	mvi a,02h ! out p$rtc$address
	lda @min  ! call bcdtobin ! out p$rtc$data
	mvi a,04h ! out p$rtc$address
	lda @hour ! call bcdtobin ! out p$rtc$data

	mvi a,28 ! sta monthtable+1	; init February entry in month table
	lhld @date			; get days since Jan 0 1978 (binary)
	dcx h				; want days - 1
	lxi d,-365
	mvi b,78			; init year
times1	ora a ! dad d			; subtract 365 days
	mov a,b ! ani 03h
	cpi 00h ! jnz times7		; leap year? (jump if no)
	dcx h				;    yes, decrement days by 1
times7	mov a,h ! ora a ! jm times2	; exit if days < 0 now
	inr b				; else increment binary year counter
	jmp times1			; and loop again
times2	lxi d,365			; standard year has 365 days
	mov a,b ! ani 03h		; leap year?
	cpi 00h ! jnz times6
	lxi d,366			;    yes, leap year has 366 days
	mvi a,29 ! sta monthtable+1	;    and update Feb month table entry
times6	ora a ! dad d			; no, backup days by one year
	mvi a,9 ! out p$rtc$address	; and update clock year register
	mov a,b ! out p$rtc$data

	mov b,h ! mov c,l		; <bc> = days since Jan 0 of cur yr - 1
	mvi e,1				; init months counter
	lxi h,monthtable
times3	mov d,m				; get days in month
	mov a,c ! sub d ! mov c,a
	mov a,b ! sbi 0 ! mov b,a	; subtract it
	jm times4			; exit when <bc> (days) is neg
	inr e				; increment months counter
	inx h				; and table pointer
	jmp times3
times4	mov a,c ! add d ! mov c,a
	mov a,b ! aci 0 ! mov b,a	; add back month
	inr c				; <c> = date, <e> = month
	mvi a,8 ! out p$rtc$address	; and update clock month register
	mov a,e ! out p$rtc$data
	mvi a,7 ! out p$rtc$address	; and update clock date register
	mov a,c ! out p$rtc$data

	mvi a,0Bh ! out p$rtc$address	; enable clock register B
	mvi a,0Fh ! out p$rtc$data	; SQWE, binary mode, 24hr mode, DSE
	jmp timeret

?time$get:
	mvi c,255
timeg1	mvi a,0Ah ! out p$rtc$address	; check clock register A
	in p$rtc$data
	ani 10000000h ! jz timeg2	; wait until UIP (update in prog) = 0
	dcr c ! jnz timeg1		;   a maximum of 255 checks

timeg2	mvi a,0 ! out p$rtc$address
	in p$rtc$data ! call bintobcd ! sta @sec
	mvi a,2 ! out p$rtc$address
	in p$rtc$data ! call bintobcd ! sta @min
	mvi a,4 ! out p$rtc$address
	in p$rtc$data ! call bintobcd ! sta @hour
	mvi a,7 ! out p$rtc$address
	in p$rtc$data ! sta date
	mvi a,8 ! out p$rtc$address
	in p$rtc$data ! sta month
	mvi a,9 ! out p$rtc$address
	in p$rtc$data ! sta year

	mvi a,28 ! sta monthtable+1	; init February entry in month table
	lxi h,0				; <hl> = days since Jan 0 1978
	lxi d,365			; <de> = days per year
	mvi c,1				; binary year counter for leap yr calc
	lda year ! sui 78		; count years from 1978
timeg3	cpi 0 ! jz timeg4		; loop until up to current year
	ora a ! dad d ! inr c		; increment days by 365, years by 1
	dcr a ! jmp timeg3		; and loop again
timeg4	mov a,c				; Get year.  Bits 0,1 = 11 if a leap yr
	ani 03h ! cpi 03h ! jnz timeg7	; jump if this is not a leap year
	mvi a,29 ! sta monthtable+1	; update February entry
timeg7	srlr c
	srlr c				; divide years by 4
	mvi b,0 ! ora a ! dad b		; add to # of days, <hl> = days to Jan 0
					;   in current year
	mov b,h ! mov c,l		; <bc> = days to Jan 0 in current year
	lxi h,monthtable
	
	lda month			; get month
timeg5	dcr a ! jz timeg6		; leave loop when months added
	mov e,a ! mov a,m		; get days in month
	add c ! mov c,a
	mov a,b ! aci 0 ! mov b,a	; add to days in <bc>
	inx h ! mov a,e ! jmp timeg5
timeg6	lda date
	mvi h,0 ! mov l,a ! dad b	; add date to days
	shld @date
	jmp timeret

bintobcd
	mov c,a				; save binary byte
	mvi b,0
bin2	sui 10 ! jm bin3
	inr b ! jmp bin2
bin3	adi 10
	slar b
	slar b
	slar b
	slar b
	add b
	ret				; return with bcd value in <a>
bcdtobin
	mov c,a				; save bcd byte
	ani 0Fh				; ls nibble into <a>
	srlr c				; move ms nibble into ls nibble in <c>
	srlr c
	srlr c
	srlr c
	jz bcdret			; if zero, we are finished
	mvi b,10
bcd2	add b ! dcr c ! jnz bcd2
bcdret	ret				; return with binary value in <a>

monthtable
	db 31,28,31,30,31,30,31,31,30,31,30,31	; days per month
date	ds 1				; temp loc for clock data
month	ds 1
year	ds 1

	cseg
	; CP/M BDOS Function Interfaces

open:
	mvi c,15 ! jr nbdos		; open file control block
setdma:
	mvi c,26 ! jr nbdos		; set data transfer address
setmulti:
	mvi c,44 ! jr nbdos		; set record count
read:	mvi c,20 			; read records
nbdos:	jmp bdos		

	dseg
signon$msg	db cr,lf,'CP/M Plus - Custom BIOS Ver 3.22 (C) 1985,2017.'
		db cr,lf,lf,'A,B = Cypher/Sorcerer 8"'
		db cr,lf,'C   = 80 track Pied Piper'
		db cr,lf,'D   = (40 track Morrow) - disabled'
		db cr,lf,'E   = Ram disk'
		db cr,lf,'F   = 11 Meg HD'
		db cr,lf,'G   = 11 Meg HD'
		db cr,lf,0
	cseg
ccp$msg		db 'CCP.COM?',0

ccp$fcb		db 0,'CCP     ','COM',0,0,0,0
		ds 16
fcb$nr		db 0,0,0

	dseg
init$table
	; serial channel A
	db 8,p$sio$controlA		; send 8 bytes to serial A
	db 0,18h			; channel reset
	db 4,01000100b			; x16, 1 stop bit, no parity
	db 3,11000001b			; Rx 8 bits, enabled
	db 5,11101010b			; DTR on, Tx 8 bits, enabled, CRC
	db 0				; end of init$table

	cseg
savestack	ds 2
		ds 12
local$stack	equ $
	end

