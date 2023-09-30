;*****************************************************
;*                                                   *
;*      Sector Deblocking Algorithms for CP/M 2.0    *
;*      Adjusted for Holborn                         *
;*                                                   *
;*****************************************************
;
;				edit #1 :feb-1982  MM
;				     #1 :15031982  HB
; ADDED CONDITIONALS FOR MEMORY DISK #1 :24051982  DM
;				     #2  : 09061982 HB
;	utility macro to compute sector mask
smask	macro	hblk
;;	compute log2(hblk), return @x as result
;;	(2 ** @x = hblk on return)
@y	set	hblk
@x	set	0
;;	count right shifts of @y until = 1
	rept	8
	if	@y = 1
	exitm
	endif
;;	@y is not 1, shift right one position
@y	set	@y shr 1
@x	set	@x + 1
	endm
	endm
FALSE	EQU	0
TRUE	EQU	NOT FALSE
;
;******************************************************
;*                                                   *
;*         CP/M to host disk constants               *
;*                                                   *
;*****************************************************
blksiz	equ	2048		;CP/M allocation size
hstsiz	equ	2048		;host disk sector size
hstspt	equ	4		;host disk sectors/trk
hstblk	equ	hstsiz/128	;CP/M sects/host buff
cpmspt	equ	hstblk * hstspt	;CP/M sectors/track
secmsk	equ	hstblk-1	;sector mask
	smask	hstblk		;compute sector mask
secshf	equ	@x		;log2(hstblk)
;
single	equ	1		;single density
double	equ	0		;double density
denerr	equ	0ddh		;density error
;
;*****************************************************
;*                                                   *
;*        BDOS constants on entry to write           *
;*                                                   *
;*****************************************************
wrall	equ	0		;write to allocated
wrdir	equ	1		;write to directory
wrual	equ	2		;write to unallocated
;
;*****************************************************
;*                                                   *
;*      public and external references               *
;*                                                   *
;*****************************************************
	PUBLIC	SEKDSK
	PUBLIC	SEKTRK
	public	hstact
	public	unacnt
	public	hstwrt
;
; bios entry points
	public	read
	public	write
	public	settrk
	public	setsec
	public	setdma
	PUBLIC	RQUNIT
;
; externals
	extrn	phread	;physical read from disk
	extrn	phwrite	;physical write from disk
	EXTRN	DEFINE
	EXTRN	DENB
	extrn	prmsg
;
	extrn	dpbase
;
	extrn	fdctrk
	extrn	fdcsec
	extrn	fdclen
	extrn	fdcadr
	extrn	fdcden
	extrn	ftrkun
	extrn	ptrkun

; MEMORY DISK EQUATES
VIRTDSK	EQU	'M'-'A'	; LOGICAL NUMBER FOR MEMORY DISK 'M'
;
;*****************************************************
;*                                                   *
;*	The BDOS entry points given below show the   *
;*      code which is relevant to deblocking only.   *
;*                                                   *
;
;
;
 
;
settrk:
	;set track given by registers BC
	mov	h,b
	mov	l,c
	shld	sektrk		;track to seek
	ret
;
setsec:
	;set sector given by register c 
	mov	a,c
	sta	seksec		;sector to seek
	ret
;
setdma:
	;set dma address given by BC

	mov	h,b
	mov	l,c
	shld	dmaadr
 
;
; CHECK DISK
;
	LDA	SEKDSK
	CPI	2	; SINGLE DENSITY
	RZ
	CPI	3	; SINGLE DENSITY
	RZ
	CPI	VIRTDSK
	RZ

	inx	h	; test for flush buffers
	mov	a,l
	ora	h
	rnz		; HL = FFFFH is flush buffers
	lxi	h,hstwrt
	mov	a,m
	mvi	m,0
	ora	a
	rz
	call	writehst	; flush host write if pending
	ora	a
	rz		; return no error
	pop	h
	ret
;
;
;*****************************************************
;*                                                   *
;*	The READ entry point takes the place of      *
;*	the previous BIOS defintion for READ.        *
;*                                                   *
;*****************************************************
read:

	LDA	SEKDSK
	CPI	VIRTDSK
	JZ	MREADSECTOR
	CPI	2		; SINGLE DENSITY
	JZ	READS
	CPI	3		; SINGLE DENSITY
	JZ	READS


	;read the selected CP/M sector
	xra	a
	sta	unacnt
	mvi	a,1
	sta	readop		;read operation
	sta	rsflag		;must read data
	mvi	a,wrual
	sta	wrtype		;treat as unalloc
	jmp	rwoper		;to perform the read
;
;*****************************************************
;*                                                   *
;*	The WRITE entry point takes the place of     *
;*	the previous BIOS defintion for WRITE.       *
;*                                                   *
;*****************************************************
write:

	LDA	SEKDSK
	CPI	VIRTDSK
	JZ	MWRITESECTOR
	CPI	2		; SINGLE DENSITY
	JZ	WRITES
	CPI	3		; SINGLE DENSITY
	JZ	WRITES

	
	;write the selected CP/M sector
	xra	a		;0 to accumulator
	sta	readop		;not a read operation
	mov	a,c		;write type in c
	sta	wrtype
	cpi	wrual		;write unallocated?
	jnz	chkuna		;check for unalloc
;
;	write to unallocated, set parameters
	mvi	a,blksiz/128	;next unalloc recs
	sta	unacnt
	lda	sekdsk		;disk to seek
	sta	unadsk		;unadsk = sekdsk
	lhld	sektrk
	shld	unatrk		;unatrk = sectrk
	lda	seksec
	sta	unasec		;unasec = seksec
;
chkuna:
	;check for write to unallocated sector
	lda	unacnt		;any unalloc remain?
	ora	a
	jz	alloc		;skip if not
;
;	more unallocated records remain
	dcr	a		;unacnt = unacnt-1
	sta	unacnt
	lda	sekdsk		;same disk?
	lxi	h,unadsk
	cmp	m		;sekdsk = unadsk?
	jnz	alloc		;skip if not
;
;	disks are the same
	lxi	h,unatrk
	call	sektrkcmp	;sektrk = unatrk?
	jnz	alloc		;skip if not
;
;	tracks are the same
	lda	seksec		;same sector?
	lxi	h,unasec
	cmp	m		;seksec = unasec?
	jnz	alloc		;skip if not
;
;	match, move to next sector for future ref
	inr	m		;unasec = unasec+1
	mov	a,m		;end of track?
	cpi	cpmspt		;count CP/M sectors
	jc	noovf		;skip if no overflow
;
;	overflow to next track
	mvi	m,0		;unasec = 0
	lhld	unatrk
	inx	h
	shld	unatrk		;unatrk = unatrk+1
;
noovf:
	;match found, mark as unnecessary read
	xra	a		;0 to accumulator
	sta	rsflag		;rsflag = 0
	jmp	rwoper		;to perform the write
;
alloc:
	;not an unallocated record, requires pre-read
	xra	a		;0 to accum
	sta	unacnt		;unacnt = 0
	inr	a		;1 to accum
	sta	rsflag		;rsflag = 1
;
;*****************************************************
;*                                                   *
;*	Common code for READ and WRITE follows       *
;*                                                   *
;*****************************************************
rwoper:
	;enter here to perform the read/write
	xra	a		;zero to accum
	sta	erflag		;no errors (yet)
	lda	seksec		;compute host sector
	rept	secshf
	ora	a		;carry = 0
	rar			;shift right
	endm
	sta	sekhst		;host sector to seek
;
;	active host sector?
	lxi	h,hstact	;host active flag
	mov	a,m
	mvi	m,1		;always becomes 1
	ora	a		;was it already?
	jz	filhst		;fill host if not
;
;	host buffer active, same as seek buffer?
	lda	sekdsk
	lxi	h,hstdsk	;same disk?
	cmp	m		;sekdsk = hstdsk?
	jnz	nomatch
;
;	same disk, same track?
	lxi	h,hsttrk
	call	sektrkcmp	;sektrk = hsttrk?
	jnz	nomatch
;
;	same disk, same track, same buffer?
	lda	sekhst
	lxi	h,hstsec	;sekhst = hstsec?
	cmp	m
	jz	match		;skip if match
;
nomatch:
	;proper disk, but not correct sector
	lda	hstwrt		;host written?
	ora	a
	cnz	writehst	;clear host buff
;
filhst:
	;may have to fill the host buffer
	lda	sekdsk
	sta	hstdsk
	lhld	sektrk
	shld	hsttrk
	lda	sekhst
	sta	hstsec
	lda	rsflag		;need to read?
	ora	a
	cnz	readhst		;yes, if 1
	xra	a		;0 to accum
	sta	hstwrt		;no pending write
;
match:
	;copy data to or from buffer
	lda	seksec		;mask buffer number
	ani	secmsk		;least signif bits
	mov	l,a		;ready to shift
	mvi	h,0		;double count
	rept	7		;shift left 7
	dad	h
	endm
;	hl has relative host buffer address
	lxi	d,hstbuf
	dad	d		;hl = host address
	xchg			;now in DE
	lhld	dmaadr		;get/put CP/M data
	LXI	B,128		; LENGTH OF MOVE
	lda	readop		;which way?
	ora	a
	jnz	rwmove		;skip if read
;
;	write operation, mark and switch direction
	mvi	a,1
	sta	hstwrt		;hstwrt = 1
	xchg			;source/dest swap
;
rwmove:
	;BC initially 128, DE is source, HL is dest
	XCHG			; HL=SOURCE,DE=DESTENATION
;	LDIR
	DB	0EDH,0B0H
;
;
;	data has been moved to/from host buffer
	lda	wrtype		;write type
	cpi	wrdir		;to directory?
	lda	erflag		;in case of errors
	rnz			;no further processing
;
;	clear host buffer for directory write
	ora	a		;errors?
	rnz			;skip if so
	xra	a		;0 to accum
	sta	hstwrt		;buffer written
	call	writehst
	lda	erflag
	ret
;
;*****************************************************
;*                                                   *
;*	Utility subroutine for 16-bit compare        *
;*                                                   *
;*****************************************************
sektrkcmp:
	;HL = .unatrk or .hsttrk, compare with sektrk
	xchg
	lxi	h,sektrk
	ldax	d		;low byte compare
	cmp	m		;same?
	rnz			;return if not
;	low bytes equal, test high 1s
	inx	d
	inx	h
	ldax	d
	cmp	m	;sets flags
	ret
;
;*****************************************************
;*                                                   *
;*	WRITEHST performs the write to               *
;*	the host disk, READHST reads the host        *
;*	disk.(double density)    		     *
;*                                                   *
;*****************************************************
writehst:
	;hstdsk = host disk #, hsttrk = host track #,
	;hstsec = host sect #. write "hstsiz" bytes
	;from hstbuf and return error flag in erflag.
	;return erflag non-zero if error
	call	setvard	;set variables
	call	writed	;write data to disk
	sta	erflag
	ret
;
readhst:
	;hstdsk = host disk #, hsttrk = host track #,
	;hstsec = host sect #. read "hstsiz" bytes
	;into hstbuf and return error flag in erflag.
	call	setvard	;set variables
	call	readd	;read data from disk
	sta	erflag
	ret
;
;*****************************************************
;*                                                   *
;*	Set variables for double density i/o         *
;*                                                   *
;*****************************************************
;
setvard:
	;set variables for physical i/o
	lda	hstdsk	
	STA	RQUNIT
;
	lhld	hsttrk
	shld	fdctrk
;
	lda	hstsec
	add	a
	inr	a
	mov	l,a
	mvi	h,0
	shld	fdcsec
;
	lxi	h,hstbuf
	shld	fdcadr
;
	lxi	h,hstsiz
	shld	fdclen

	ret		;return to caller
;
;*****************************************************
;*                                                   *
;*	WRITES performs the write to                 *
;*	the host disk, READS reads the host          *
;*	disk.(single density)    		     *
;*                                                   *
;*****************************************************
;
writes:
	call	setvars	;set sector length
	call	writed	;write data
	ret

reads:
	call	setvars	;set sector length
	call	readd	;read data
	ret
;
;*****************************************************
;*                                                   *
;*	Set variables for single density i/o         *
;*                                                   *
;*****************************************************
;
setvars:
	lda	sekdsk
	STA	RQUNIT
;
	lhld	sektrk
	shld	fdctrk
;
	lda	seksec
	mov	l,a
	mvi	h,0
	shld	fdcsec
;
	lhld	dmaadr
	shld	fdcadr
;
	lxi	h,128
	shld	fdclen
;
	ret
;
;
;*****************************************************
;*                                                   *
;*	Read and Write data with density check       *
;*                                                   *
;*****************************************************
;
writed:
	call	phwrite	;perform the physical write
	ana	a	;test for errors
	RZ
	CPI	DENERR	; CHECK IF DENSITY ERROR
	RNZ		; RETURN ERROR
	JMP	CHGDEN	; REPORT ERROR
;
readd:
	call	phread	;perform the physical read
	ana	a	;test for errors
	RZ		; RETURN IF NO ERROR
	CPI	DENERR	; CHECK IF IT IS DENSITY ERROR
	RNZ		; RETURN IF ERROR
	JMP	CHGDEN	; REPORT ERROR
;
CHGDEN:
	; DENSITY IS CHANGED
	; REPORT IT
	LXI	H,DENMSG
	CALL	PRMSG
	MVI	A,0FFH	;REPORT ERROR TO BDOS
	RET
DENMSG:	DB	0DH,0AH
	DB	'DENSITY ERROR'
	DB	0DH,0AH
	DB	0		; END OF STRING

;*****************************************************
;*						     *
;*	READ AND WRITE FROM MEMORY DISK		     *
;*						     *
;*****************************************************

PRECM1	EQU	0200H		; PRECOMPUTED OFFSET
PRECM2	EQU	01E0H	
 
SEG0RS	EQU	0EFFH		;RESTORE SEG 0
SEG1RS	EQU	1EFFH		;RESTORE SEG 1
SEG2RS	EQU	2EFFH		;RESTORE SEG 2
 
SEG1RG	EQU	10H
SEG2RG	EQU	20H
 
 

RESTBLK:
	DS	2		; BLOCK TO RESTORE
MDTRK:
	DS	2		; MEMORY DISK TRACK 
SVDSRC:
	DS	2		; SAVED SOURCE ADDRESS
SVDDST:
	DS	2		; SAVED DESTINATION ADDRESS
SVDSTP:
	DS	2		; SAVED STACK POINTER

	DW	0C7C7H,0C7C7H,0C7C7H
	DW	0C7C7H,0C7C7H,0C7C7H
LSTSTK:				; LOCATION OF TEMPORARY STACK FOR
				; MEMORY SWAP
MWRITESECTOR:
	XRA	A		; OPERATION TYPE IN A
	STA	READOP		; 
	JMP	COMCODE

MREADSECTOR:
	MVI	A,1
	STA	READOP		; OPERATION TYPE IN A

COMCODE:
	LDA	DMAADR+1	; DMAADR IN 4 ST 4K BLOCK ?
	CPI	10H
	JNC	NORMAL		; C=0 => NO
	LXI	H,SEG2RS		; BLOCK TO RESTORE
	SHLD	RESTBLK
	LXI	H,PRECM2
	JMP	CALTRK		; CALCULATE TRACK
NORMAL:
	LXI	H,SEG0RS		; BLOCK TO RESTORE
	SHLD	RESTBLK
	LXI	H,PRECM1	; LOAD PRECOMPUTED ADDRESS OFFSET
CALTRK:
	LXI	B,10H		; CALCULATE TRACK ADDRESS
	LDA	SEKTRK		; GET TRACK NUMBER
	ORA	A		; CHECK IF TRACK=0
	JNZ	NXTBLK
	LXI	B,1000H
	DAD	B
	JMP	NXTBL1
NXTBLK:				; CALCULATE TRACK
	DAD	B
	DCR	A
	JNZ	NXTBLK
NXTBL1:
	MOV	A,L
	CMA
	MOV	L,A
	MOV	A,H
	CMA
	ANI	0FH
	MOV	H,A
	SHLD	MDTRK		; STORE COMPUTED VALUE

; CALCULATE SECTOR

	LDA	SEKSEC		; MASK OFF LEAST SIGNIFICANT BITS
	ANI	1FH
	MOV	L,A
	MVI	H,0
	REPT	7
	DAD	H
	ENDM

; HL HAS HOST BUFFER ADDRESS
	XCHG			; NOW IN DE
	LHLD	DMAADR
	XCHG
	LDA	READOP		; WHICH WAY
	ORA	A
	JNZ	VIRMOV		; #0 => READ

; WRITE OPERATION

	XCHG
	JMP	VRFRUS		; ELSE WRITE

; DATA HAS BEEN MOVED TO/FROM HOST
VIRMV1:
	XRA	A		; CLEAR TO INDICATE NO ERRORS
	RET
;			DE = DESTINATION
; DATA MOVE ROUTINE
;			HL = SOURCE
VIRMOV:

	MOV	A,D		; DMA IN LOWEST 4K ?
	CPI	10H
	CC	ADJUST		; C=1 => YES, ADJUST HOSTADDRESS
LABEL3:
	DI
	SHLD	SVDSRC		; SAVE SOURCE ADDRESS
	XCHG
	SHLD	SVDDST		; SAVE DESTINATION ADDRESS
	LXI	H,0
	DAD	SP
	SHLD	SVDSTP		; SAVE STACK ADDRESS
	LXI	SP,LSTSTK
	LXI	H,MDTRK
	CALL	SWIBUF		; SWITCH IN 4K BLOCK
	LHLD	SVDDST		; RESTORE DESTINATION
	XCHG
	LHLD	SVDSRC		; RESTORE SOURCE
	LXI	B,128
;	LDIR
	DB	0EDH,0B0H
	LXI	H,RESTBLK	; RESTORE BLOCK
	CALL	SWIBUF
	LHLD	SVDSTP
	SPHL			; RESTORE PREVIOUS STACK
	EI
	JMP	VIRMV1
;
VRFRUS:
	MOV	A,H		; HOST ADDRESS IN HL
	XCHG
	CPI	10H
	CC	ADJUST
	XCHG
	JMP	LABEL3
;
ADJUST:				; ADJUST HOST ADDRESS
	MOV	A,H
	ADI	SEG2RG
	MOV	H,A
	LDA	MDTRK+1
	ADI	SEG2RG
	STA	MDTRK+1
	RET

SWIBUF:
	MVI	C,0
	MOV	A,M
	INX	H
	MOV	B,M
;	OUT	(C),A
	DB	0EDH,079H
	RET

;
;*****************************************************
;*                                                   *
;*	Uninitialized RAM data area                  *
;*                                                   *
;*****************************************************
;
sekdsk:	ds	1		;seek disk number
sektrk:	ds	2		;seek track number
seksec:	ds	1		;seek sector number
;
hstdsk:	ds	1		;host disk number
hsttrk:	ds	2		;host track number
hstsec:	ds	1		;host sector number
;
sekhst:	ds	1		;seek shr secshf
hstact:	ds	1		;host active flag
hstwrt:	ds	1		;host written flag
;
unacnt:	ds	1		;unalloc rec cnt
unadsk:	ds	1		;last unalloc disk
unatrk:	ds	2		;last unalloc track
unasec:	ds	1		;last unalloc sector
;
RQUNIT	DS	1		;REQUESTED UNIT NUMBER
;
erflag:	ds	1		;error reporting
rsflag:	ds	1		;read sector flag
readop:	ds	1		;1 if read operation
wrtype:	ds	1		;write operation type
dmaadr:	ds	2		;last dma address
hstbuf:	ds	hstsiz		;host buffer
;
	db	0		; force end for hex

	END
