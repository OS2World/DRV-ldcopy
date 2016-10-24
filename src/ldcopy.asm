 	PAGE	64,132
	TITLE	LDCOPY - device driver to copy files on startup
	NAME	LDCOPY
	.286
;
; Description:
;	OS/2 device driver for copying files.
; Version:
;	1.1
; Date:
;	April 2003
; Author:
;	Bob Eager
;		rde@tavi.co.uk
;
;	This program is released into the public domain. Please do not
;	change this notice, or try to make money from the program.
;
; History:
;	1.0	Initial version.
;	1.1	Use noncritical init error code to unload completely.
;
; This device driver performs no useful function except at system
; initialisation time. At that time, it copies a file based on its two
; parameters:
;
;	DEVICE=LDCOPY.SYS   <fromfile> <tofile>
;
; The idea is that the DEVICE=LDCOPY.SYS... line will appear before that
; for any driver that needs the relevant file.
;
	.XLIST
	INCLUDE	DEVSYM.INC
	.LIST
;
; Constants
;
STDOUT		EQU	1		; Standard output handle
DCPY_EXISTING	EQU	1		; DosCopy option
;
CR		EQU	0DH		; Carriage return
LF		EQU	0AH		; Linefeed
TAB		EQU	09H		; Tab
BEL		EQU	07H		; Bell!
;
; External references
;
	EXTRN	DosCopy:FAR
	EXTRN	DosWrite:FAR
;
	SUBTTL	Data areas
	PAGE+
;
DGROUP	GROUP	_DATA
;
_DATA	SEGMENT	WORD PUBLIC 'DATA'
;
; Device driver header
;
HEADER	DD	-1			; Link to next device driver
	DW	(DEV_CHAR_DEV OR DEVLEV_1)
					; Device attributes:
					;   character device
					;   function level 001
	DW	OFFSET STRATEGY		; Strategy entry point
	DW	0			; IDC entry point - not used
	DB	'LDCOPY$$'		; Device name
	DB	8 DUP (0)		; Reserved
;
; Filenames
;
SRCA	DB	256 DUP (0)		; Source file
DSTA	DB	256 DUP (0)		; Destination file
;
WLEN	DW	?			; Receives DosWrite length
;
MES1	DB	CR,LF,'LDCOPY: invalid argument on DEVICE= line'
	DB	BEL,BEL,BEL,CR,LF,0
CMES1	DB	'LDCOPY: File ',0
CMES2	DB	' copied to ',0
CMES3	DB	CR,LF,0
CMES4	DB	BEL,BEL,BEL,' NOT copied to ',0
;
_DATA	ENDS
;
	SUBTTL	Main code
	PAGE+
;
_TEXT	SEGMENT	WORD PUBLIC 'CODE'
;
	ASSUME	CS:_TEXT,DS:DGROUP,ES:NOTHING
;
; Strategy entry point; ES:BX points to the request packet
;
; We support only initialise (of course) and deinstall.
; Deinstall allows multiple calls to load this driver, thus allowing
; files to be copied.
; If deinstall were not provided, only the first load would succeed.
;
STRATEGY	PROC	FAR
;
	CMP	ES:[BX].PktCmd,CmdInit	; initialise function?
	JE	STRA10			; j if so
	CMP	ES:[BX].PktCmd,CmdDeInstall
					; deinstall function?
	JNE	STRA05			; j if not - error
	MOV	AX,STDON		; just 'done'
	JMP	SHORT STRA20		; and exit
;
STRA05:	MOV	AX,(STERR OR STDON OR 3); error and done status, unknown command
	JMP	SHORT STRA20		; use common exit code
;
STRA10:	CALL	INIT			; do the initialisation
;
STRA20:	MOV	ES:[BX].PktStatus,AX	; store status in request packet
	RET				; return to system
;
STRATEGY	ENDP
;
	SUBTTL	Initialisation code
	PAGE+
;
; Initialisation code. All of this code is present only during initialisation;
; none of the driver data is used after that time either.
;
	ASSUME	CS:_TEXT,DS:DGROUP,ES:NOTHING
;
INIT	PROC	NEAR
;
	PUSH	BX			; save request packet offset for later
	PUSH	ES			; save request packet segment for later
	PUSH	DS			; save data segment for later
	PUSH	DS			; save it again for ES setting below
;
; Get the arguments; just two strings
;
	MOV	SI,WORD PTR ES:[BX].InitParms
					; offset of INIT arguments
	MOV	DS,WORD PTR ES:[BX].InitParms+2
					; segment of INIT arguments
;
	ASSUME	CS:_TEXT,DS:NOTHING,ES:NOTHING
;
	POP	ES			; copy our DS to ES for copying names
	CLD				; autoincrement
;
INIT01:	LODSB				; skip leading whitespace
	CMP	AL,' '
	JE	INIT01
	CMP	AL,TAB
	JE	INIT01
	DEC	SI			; back to first non-space
;
; Now at start of driver filename (after DEVICE=)
;
INIT02:	LODSB				; skip driver filename
	CMP	AL,' '
	JE	SHORT INIT03		; found next separator
	CMP	AL,TAB
	JE	SHORT INIT03		; found next separator
	CMP	AL,0			; found terminator?
	JE	SHORT INIT30		; j if so - error
	JMP	INIT02			; else keep looking
;
; Now at end of driver filename (after DEVICE=LDCOPY.SYS)
;
INIT03:	LODSB				; strip separating whitespace
	CMP	AL,' '
	JE	INIT03
	CMP	AL,TAB
	JE	INIT03
;
INIT04:	DEC	SI			; back to first non-space, if any
	MOV	DI,OFFSET SRCA		; where to put name; ES already set
;
; We are now at the start of the arguments proper
; (or at the end of the whole line)
;
INIT05:	LODSB				; next byte of filename
	CMP	AL,0			; terminator?
	JE	INIT30			; j if so - error
	CMP	AL,' '			; end?
	JE	INIT06			; j if so
	CMP	AL,TAB			; end?
	JE	INIT06			; j if so
	STOSB				; else store it
	JMP	INIT05			; and keep going
;
INIT06:	XOR	AL,AL			; terminator
	STOSB				; store it
;
; Now at start of whitespace preceding second filename (if any)
;
INIT07:	LODSB				; strip separating whitespace
	CMP	AL,' '
	JE	INIT07
	CMP	AL,TAB
	JE	INIT07
;
	DEC	SI			; back to first non-space, if any
	MOV	DI,OFFSET DSTA		; where to put name
;
; We are now at the start of the second filename...
;
INIT09:	LODSB				; next byte of filename
	OR	AL,AL			; terminator?
	JE	INIT10			; j if so
	CMP	AL,' '			; end?
	JE	INIT10			; j if so
	CMP	AL,TAB			; end?
	JE	INIT10			; j if so
	STOSB				; else store it
	JMP	INIT09			; and keep going
;
INIT10:	CMP	DI,OFFSET DSTA		; check for null filename
	JE	INIT30			; j if so - error
	XOR	AL,AL			; terminator
	STOSB				; store it
;
	POP	DS			; recover register
;
	ASSUME	CS:_TEXT,DS:DGROUP,ES:NOTHING
;
; Now copy the file
;
	MOV	AX,OFFSET DGROUP:SRCA	; source file
	MOV	DX,OFFSET DGROUP:DSTA	; destination file
	CALL	DOCOPY			; copy it
;
INIT20:	POP	ES			; recover registers
	POP	BX
;
	XOR	AX,AX
	MOV	WORD PTR ES:[BX+0EH],AX	; lose code segment
	MOV	WORD PTR ES:[BX+10H],AX	; lose data segment
	MOV	AX,(STERR OR STDON OR 15H)
					; error and done status, noncritical
					; initialisation failure
	RET
;
; Malformed parameters
;
	ASSUME	CS:_TEXT,DS:NOTHING,ES:NOTHING
;
INIT30:	POP	DS			; recover register
;
	ASSUME	CS:_TEXT,DS:DGROUP,ES:NOTHING
;
	MOV	AX,OFFSET MES1		; '..invalid argument'
	CALL	DOSOUT			; output it
	JMP	INIT20			; join exit code
;
INIT	ENDP
;
	SUBTTL	Copy a file
	PAGE+
;
; This routine copies a file
;
; Inputs:
;	AX	- offset of source file name
;	DX	- offset of destination file name
;	DS	- data segment
;
; Outputs:
;	None
;
	ASSUME	CS:_TEXT,DS:DGROUP,ES:NOTHING
;
DOCOPY	PROC	NEAR
;
	PUSH	DX			; save destination offset
	PUSH	AX			; save source offset
	PUSH	DS			; source segment
	PUSH	AX			; source offset
	PUSH	DS			; destination segment
	PUSH	DX			; destination offset
	PUSH	DCPY_EXISTING		; options
	PUSH	0			; DWORD reserved
	PUSH	0
	CALL	DosCopy			; do the copy
	OR	AX,AX			; copied OK?
	JNZ	NOCOPY			; j if not
	MOV	AX,OFFSET CMES1		; 'File '
	CALL	DOSOUT			; output it
	POP	AX			; source filename
	CALL	DOSOUT			; output it
	MOV	AX,OFFSET CMES2		; ' copied to '
	CALL	DOSOUT			; output it
	POP	AX			; destination filename
	CALL	DOSOUT			; output it
	MOV	AX,OFFSET CMES3		; '<CR><LF>'
	CALL	DOSOUT			; output it
;
	RET				; and return

NOCOPY:	MOV	AX,OFFSET CMES1		; 'File '
	CALL	DOSOUT			; output it
	POP	AX			; source filename
	CALL	DOSOUT			; output it
	MOV	AX,OFFSET CMES4		; ' NOT copied to '
	CALL	DOSOUT			; output it
	POP	AX			; destination filename
	CALL	DOSOUT			; output it
	MOV	AX,OFFSET CMES3		; '<CR><LF>'
	CALL	DOSOUT			; output it
;
	RET				; and return
;
DOCOPY	ENDP
;
	SUBTTL	Output message
	PAGE+
;
; Routine to output a string to the screen.
;
; Inputs:
;	AX	- offset of zero terminated message
;	DS	- data segment
;
; Outputs:
;	None
;
	ASSUME	CS:_TEXT,DS:DGROUP,ES:NOTHING
;
DOSOUT	PROC	NEAR
;
	PUSH	ES			; save ES
	PUSH	AX			; save message offset
	PUSH	DS			; copy DS...
	POP	ES			; ...to ES
	MOV	DI,AX			; ES:DI point to message
	XOR	AL,AL			; set AL=0 for scan value
	MOV	CX,100			; just a large value
	REPNZ	SCASB			; scan for zero byte
	POP	AX			; recover message offset
	POP	ES			; recover ES
	SUB	DI,AX			; get size to DI
	DEC	DI			; adjust
	PUSH	STDOUT			; standard output handle
	PUSH	DS			; segment of message
	PUSH	AX			; offset of message
	PUSH	DI			; length of message
	PUSH	DS			; segment for length written
	PUSH	OFFSET DGROUP:WLEN	; offset for length written
	CALL	DosWrite		; write message
;
	RET
;
DOSOUT	ENDP
;
_TEXT	ENDS
;
	END
