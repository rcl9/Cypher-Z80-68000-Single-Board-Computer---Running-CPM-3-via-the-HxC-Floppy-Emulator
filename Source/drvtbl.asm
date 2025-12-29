	public @dtbl
	extrn fdsd0,fdsd1,fdsd2,fdsd3		; floppy disks
	extrn rxdph				; ram disk
	extrn hxdph0,hxdph1			; hard disks

	cseg

@dtbl
	dw fdsd0,fdsd1			; drives A-B are 8" floppies
	dw fdsd2			; C drive is 5" floppy Pied Piper
;	dw fdsd3			; D drive is 5" floppy Morrow
	dw 0				; disable drive D for now
	dw rxdph			; drive E is the ram disk
	dw hxdph0,hxdph1		; drive F-G are hard disks
	dw 0,0,0,0,0,0,0,0,0		; drives H-P are non-existant
	end
