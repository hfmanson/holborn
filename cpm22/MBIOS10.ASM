;
; FILE : MBIOS10.ASM
;
;
;****** NUMBER OF HARD DISKS *****
;******  LOGICAL DISKS ******
;
TYPE1	EQU	10	; NO HARD DISKS
TYPE2	EQU	20	; 1 HARD DISK
TYPE3	EQU	30	; 2 HARD DISKS
TYPE4	EQU	40	; 3 HARD DISKS
TYPE5	EQU	50	; 4 HARD DISKS
;
TYPE	EQU	TYPE1
;
;******  PHYSICAL HARD DISKS ******
;
NHDSK	EQU	1
;
 

SUBTYP	EQU	3	; RELEASE NUMBER OF BIOS
;

;
;
;

;	Holborn I/O Drivers for CP/M 2.2
;
;	February, 1982
;	HB	10031982
;	ADDED CODE FOR MEMORYDISK
;	DM	240582
;	HB	08061982	HARD DISK
;       HB	08031983		5.25 " 1.25 MB

vers	equ	22	;version 2.2
;
;	Copyright (c) 1980
;	Digital Research
;	Box 579, Pacific Grove
;	California, 93950
;
;
true	equ	0ffffh	;value of "true"
false	equ	not true	;"false"
test	equ	TRUE	;true if test bios
prmldr	equ	true
drivbs	equ	false	;false if drive b double density
HDISK	EQU	FALSE
single	equ	1
double	equ	0
PARALL	EQU	0	; PARALLEL DEVICE
SERIEB	EQU	2	; SERIE DEVICE BŠSERIEA	EQU	2	; SERIE DEVICE A
;
RS232	EQU	0
XONOFF	EQU	1
HANDSK	EQU	2
RATE1	EQU	0
RATE2	EQU	1
RATE3	EQU	2
CTSVAL	EQU	20H	;CLEAR TO SEND
DTRVAL	EQU	08H	;DATA  TERMINAL READY
;
cpml	equ	1600H	;length (in bytes) of cpm system
nsects	equ	cpml/128	;number of sectors to load
offset	equ	2	;number of disk tracks used by cp/m
cdisk	equ	0004h	;address of last logged disk on warm start
 buff	equ	0080h	;default buffer address
retry	equ	10	;max retries on disk i/o before error
;
;	perform following functions
;	boot	cold start
;	wboot	warm start (save i/o byte)
;
;	jump vector for indiviual routines
bios:	jmp	boot
wboote:	jmp	wboot
	jmp	const
	jmp	conin
	jmp	conout
	jmp	list
	jmp	punch
	jmp	reader
	jmp	home
	jmp	seldsk
	jmp	settrk
	jmp	setsec
	jmp	setdma
	jmp	read
	jmp	write
	jmp	listst	;list status
	jmp	sectran
;
	JMP	DEFINE	; RETURNS ADDRESS OF MODE FLAGS
;
	maclib	diskdef	;load the disc definition table
;
NUMDSK	SET	5	; 2 DOUBLE,2 SINGLE +1 MEMORY DISK
NUMDSK	SET	NUMDSK+(TYPE/10-1)
;
	DISKS	NUMDSK
;
;
	; double density def for drives
;
	diskdef	0,0,63,0,2048,400,256,256,offset
	DISKDEF	1,0Š
;	SINGLE DENSITY DEF FOR DRIVE C AND D

	DISKDEF	2,1,26,6,1024,243,64,64,OFFSET
	DISKDEF 3,2
;
;   MEMORY DISK DEF TABLE
;
	DISKDEF	4,0,31,0,1024,128,32,0,0

;
;  HARD DISK TABLES
;
	IF	TYPE GT 19
	DISKDEF	5,0,63,0,2048,4096,1024,0,OFFSET
	IF	TYPE GT	29
	DISKDEF	6,0,63,0,2048,4096,1024,0,1024+OFFSET
	IF	TYPE GT 39
	DISKDEF	7,0,63,0,2048,4096,1024,0,2048+OFFSET
	IF	TYPE GT 49
	DISKDEF	8,0,63,0,2048,4096,1024,0,0+OFFSET
	IF	TYPE GT 59
	DISKDEF	9,0,63,0,2048,4096,1024,0,0+OFFSET
	ENDIF
	ENDIF
	ENDIF
	ENDIF
	ENDIF

;
;
; DISK PARAMETER BASE TABEL
;
BASETB:
	DW	DPE0	;A
	DW	DPE1	;B
	DW	DPE2	;C
	DW	DPE3	;D
	IF	TYPE GT 19
	DW	DPE5	;E
	ELSE
	DW	0	;E
	ENDIF
	IF	TYPE GT 29
	DW	DPE6	;F
	ELSE
	DW	0	;F
	ENDIF
	IF	TYPE GT 39
	DW	DPE7	;G
	ELSE
	DW	0	;G
	ENDIF
	IF	TYPE GT 49
	DW	DPE8	;HŠ	ELSE
	DW	0	;H
	ENDIF
	IF	TYPE GT 59
	DW	DPE9	;I
	ELSE
 	DW	0	;I
	ENDIF
	DW	0	;J
	DW	0	;K
	DW	0	;L
	DW	DPE4	;M
	DW	0	;N
	DW	0	;O
	DW	0	;P
 
;
; PHYSICAL HARD DISKS DRIVE NUMBERS
;
HDRVTB:
	DB	0	; FOR UNIT E
	DB	0	;          F
	DB	0	;          G
	DB	0	;          H
;
 
;
;	MODE FLAGS, 
;		DENSITY FOR DRIVE B
;		LIST DEVICE FLAG
;		PROTOCOL
;
MODFLG:
DENB:	DB	DOUBLE
LSTFLG:	DB	PARALL
PROTOC:	DB	RS232
DIVIDE:	DB	RATE1
PRTAIN:	DW	SINITA
PRTBIN:	DW	SINITB
HNDMSK:	DB	CTSVAL
DPDEF:	DW	BASETB
HDDEF:	DW	HDSKDF
COLDFL:	DB	0AAH	; COLD BOOT
	IF	TYPE GT 19
HDAVBL:	DB	NHDSK	; NUMBER OF PHYSICAL HARD DISKS
	ELSE
HDAVBL:	DB	0	; NO HARD DISK
	ENDIF
HDUNTB:	DW	HDRVTB	; UNIT TABLE OF PHYSICAL HARD DISKS
LGHDSK:	DB	TYPE
STAINT:	DW	EXTINT
MSGPTR:	DW	MSGID
;
;
Š;	endef occurs at end of assembly
;
;	end of controller - independent code, the remaining subroutines
;	are tailored to the particular operating environment, and must
;	be in separate modules.
;
	extrn	const
	extrn	conin
	extrn	conout
	extrn	list
	extrn	punch
	extrn	reader
	extrn	home
	extrn	seldsk
	extrn	settrk
	extrn	setsec
	extrn	setdma
	extrn	read
	extrn	write
	extrn	listst

	extrn	pinit
	EXTRN	SINITA
	EXTRN	SINITB
	extrn	phread

	EXTRN	FHINIT	; FLOPPY AND HARD DISK INIT
	extrn	fdcden
	extrn	fdcadr
 	extrn	fdclen
	extrn	fdctrk
	extrn	fdcsec

	extrn	hstact	;blocking-deblocking externals
	extrn	hstwrt
	extrn	unacnt
	EXTRN	HDSKDF	; HARD DISK DEF TABLE


	PUBLIC	DEFINE
	PUBLIC	MODFLG	; MODE FLAGS
	PUBLIC	DENB
	PUBLIC	PROTOC
	PUBLIC	DIVIDE
	PUBLIC	LSTFLG	;LIST FLAG
	PUBLIC	COLDFL
	PUBLIC	HNDMSK
	EXTRN	EXTINT

	public	prmsg

	public	dpbase
	public	boot
	PUBLIC	BASETB
	PUBLIC	HDRVTBŠ	PUBLIC	HDAVBL
	PUBLIC	BREAK

;
cr	equ	0dh	;carriage return
lf	equ	0ah	;line feed
;
signon:	;signon message: xxk cp/m vers y.y
	db	cr,lf,lf
	db	'(c) Copyright Digital Research 1979'
	db	cr,lf
	db	'CP/M vers '
	db	vers/10+'0','.',vers mod 10+'0'
	db	cr,lf
	DB	'********* H O L B O R N  S Y S T E M S *********'
	DB	'  [V',TYPE/10+'0',TYPE MOD 10+'0'
	DB	'.',SUBTYP+'0'
MSGID:
	DB	']','                '
	DB	'M125'
	db	cr,lf,0
boot:
	lxi	sp,stack

	CALL	SINITA	; INITIALIZE SERIAL I/O
	call	pinit	; initialise parallel i/o
i
	;print signon message and go to ccp

	lxi	h,signon
	call	prmsg	;print message

 	CALL	FHINIT	; INITIEER FLOPPY,MEMORY AND HARD DISK
;
; RESET COLD BOOT FLAG
;
	MVI	A,0
	STA	COLDFL
 

	if prmldr
	mvi	a,0ffh
	out	1ch	; disable boot prom
	endif

	xra	a	;clear accumulator
	sta	cdisk	;set initially to disk a

	jmp	gocpm	;go to cp/m
;
;
wboot:;	loader on track 0, sector 1, which will be skipped for warm 
;	read cp/m from disk - assuming there is a 128 byte cold start
;	start.
;
	lxi	sp,buff	;using dma - thus 80 thru ff available for stackŠ;
;
	mvi	c,retry	;max retries
	push	b
wboot0:	;enter here on error retries
;
	CALL	FHINIT	; RE-INITIALIZE FLOPPY,INTVECTOREN
;
	XRA	A	; CLEAR ACC.
	STA	COLDFL
;
;
	LXI	H,BIOS
	LXI	D,-CPML	
	DAD	D
	shld	fdcadr
	lxi	b,0	;boot from drive 0
	call	seldsk
	call	home
	lxi	h,0	;start with track 0
	shld	fdctrk
	lxi	h,2	;start reading sector 2
	shld	fdcsec
	lxi	h,cpml	;set length
	shld	fdclen
	MVI	A,DOUBLE	;SET DENSITY
	sta	fdcden
	call	phread	;read data
	ana	a	;test for errors
	jnz	booterr
;
; KILL AUTO BOOT LOAD IF PRESENT
;
	LXI	H,BIOS
	LXI	D,-CPML
	DAD	D
	LXI	D,7		; LENGTH ADDRESS OF CCP LOADER
	DAD	D		; ADDRESS IN HL
	XRA	A		; CLEAR ACCU
	MOV	M,A		; CLEAR IT
;
 
;
;	done with the load, reset default buffer address
gocpm:	;(enter here from cold start boot)

;
;	set default buffer address to 80h
	lxi	b,buff
	call	setdma
;
;	reset monitor entry points
	mvi	a,jmp
	sta	0
 	lxi	h,wbooteŠ	shld	1	;jmp wboot at location 00
	sta	5
	lxi	h,bios
	lxi	d,806h-cpml
	dad	d	; calculate address of bdos
	shld	6	;jmp bdos at location 5
;
;	blocking-deblocking init
	xra	a
	sta	hstact	;host buffer inactive
	sta	hstwrt
	sta	unacnt	;clear unalloc count
;
;	leave iobyte set
;	previously selected disk was b, send parameter to cpm
	lda	cdisk	;last logged disk number
	mov	c,a	;send to ccp to log it in
	ei
	lxi	h,bios
	lxi	d,-cpml
	dad	d	; calculate address of ccp
	pchl		; go to ccp
;
;	error condition occurred, print message and retry
booterr:
	pop	b	;recall counts
	dcr	c
	jz	booter0
;	try again
	push	b
	jmp	wboot0
;
booter0:
;	otherwise too many retries
	lxi	h,bootmsg
	call	prmsg
	JMP	BREAK	; RESTART DEBUGGER
;
bootmsg:
	db	'?boot   ',0
;
sectran:
		;translate sector bc using table at de
	mov	a,d	;test if translation needed
	ora	e
	jz	notran

tran:	mvi	b,0	;double precision sector number in BC
	xchg		;translate table address to HL
	dad	b	;translate(sector) address
	mov	l,m	;translated sector number to L
	mvi	h,0	; clear h.o.
	ret
notran:
	mov	l,c	;return sector in hlŠ 	mvi	h,0
	ret
;
DEFINE:			; RETURNS THE ADDRESS OF MODE FLAGS
	LXI	H,MODFLG
	RET
 
;
;
;	utility subroutines
prmsg:	;print message at h,l to 0
	mov	a,m
	ora	a	;zero?
	rz
;	more to print
	push	h
	mov	c,a
	call	conout
	pop	h
	inx	h
	jmp	prmsg
;
acc:	ds	1
break:
	sta	acc	; save acc
	mvi	a,0
	out	1ch	; enable debugger
	jmp	0	; breakpoint addr.
;
;
;	define ram areas for bdos operation

	endef
	ds	40
stack	equ	$	; stack for boot	
	DB	0
       	end
