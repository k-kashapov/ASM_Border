.model tiny
.code
org 100h

locals @@

VIDEOBASE	equ 0B800h					; video sector
CMD_IN		equ 80h						; cmd arguments ptr
CMD_CHARS	equ 84h						; cmd char set for borders
WHT_GRN		equ 2Fh						; white on green

										; top-left corner of the border:
TLX			equ 37d						; X pos
TLY			equ 5d						; Y pos
TOPLEFT 	equ (80d * TLY + TLX) * 2d	; relative offset

SCR_WIDTH	equ 160d					; screen width in bytes
BRD_HEIGHT  equ 01h						; border height

GetCH	macro
		xor ah, ah
		int 16h
		endm

_start:
		mov ax, VIDEOBASE			; save videoseg to es
		mov es, ax

		mov bx, CMD_IN				; get cmd args len from cmd line
		xor cx, cx
		mov cl, byte ptr [bx]
		cmp cl, 00h
		jbe @@BRD1					; no args is treated as arg == 1

		mov cl, byte ptr [bx + 02h] ; get argument
		sub cl, '0'					; arg into int
		je @@BRD0					; if arg == 0: get chars from cmd line

		cmp cl, 01h					; arg == 1: set BRD1
		je @@BRD1
		
		mov si, offset BRD2			; arg > 1: set BRD2
		jmp @@Draw

@@BRD0:
		mov si, CMD_CHARS
		jmp @@Draw

@@BRD1:
		mov si, offset BRD1			; set BRD1 chars as borders

;----------------------------------------------
; Draws a rectangle box
; Regs:
;	AH - Color
;	AL - Symbol
;	BX - Row iterator
;	CH - Height
;	CL - Width
;	DL - Saved Width
;	DI - Column iterator
;	SI - Symbols arr
;----------------------------------------------

@@Draw:
		call GetS					; Get str from keybrd, cl = length
		mov ah, WHT_GRN				; save color to ah
		mov dl, cl					; save input length to dl

		mov bx, TopLeft				; set top left corner pos
		mov di, bx					; di moves between columns, bx - rows
		call DrawLine				; Top border

		mov di, bx					; update row/column
		mov ch, BRD_HEIGHT			; reset heigth
		mov cl, dl					; reset width
		call DrawEmpty

		mov di, bx					; update row/column
		mov cl, dl					; reset width
		call DrawStr

		mov di, bx					; update row/column
		mov ch, BRD_HEIGHT			; reset heigth
		mov cl, dl					; reset width
		call DrawEmpty

		add si, 03d					; after finished, change chars to the next line

		mov di, bx					; update row/column
		mov cl, dl					; reset width
		call DrawLine				; Bottom border

@@End:
		GetCH
		mov ax, 4C00h			; terminate program
		int 21h

;##############################################
; Draws a line of the screen
;
; Entry: 
;	AH - Color of the line
;	CL - Length of the line
; 	SI - addr of 3-byte line style array
;	DI - addr of start of line
;
; Note:
;	ES = videoseg addr (0b800h)
;	BX += number of empty lines * width of the line
; Exit:  None
; Destr: AX
;##############################################

DrawLine 	proc
							; UL corner
		lodsb				; ld byte from [si] to al
		stosw				; mov al to es:[di]

		jcxz @@Ret
		lodsb				; U prt

@@Loop:
		stosw				; repeat stosw while cl > 0
		dec cl
		ja @@Loop

		lodsb				; TR corner
		stosw

@@Ret:
		add bx, SCR_WIDTH	; bx = rows offset
		ret
		endp

;##############################################
; Get buffered input form keyboard
; Expects:
; 	INBYTES - static array of N bytes, first byte is array len
; Returns:
;	CL - input length
;	INBYTES[2:] - string
; Destr:
;	AH, DX, CX
;##############################################

GetS	proc	
		mov ah, 0Ah						; get buffered input
		mov dx, offset INBYTES			; buffer ptr
		int 21h

		xor cx, cx
		mov cl, byte ptr INBYTES + 1	; save input len to cl
		add cl, 2						; make neat spaces on the left and right
		ret
endp

;##############################################
; Draws several empty lines of the border
;
; Expects:
;	AH - Color of the line
;	CL - Width of the line
;	CH - Height of the line
; 	SI - addr of 3-byte line style array
;	DI - addr of start of line
;	const BRD_HEIGHT - number of empty lines
; Note:
;	ES = videoseg addr (0b800h)
;	BX += number of empty lines * width of the line
; Returns:
;	None
; Destr:
;	CX, DX
;##############################################

DrawEmpty proc
		mov dx, cx						; save cx value
@@Empty:
		call DrawLine					; draw empty
		sub si, 03d						; reset si to initial val

		mov di, bx						; increment row
		mov cl, dl						; reset width counter

		dec ch							; check if height is enough
		ja @@Empty

		ret
endp

;##############################################
; Draws str from buffered input to the video RAM
; Expects:
;	AH - Color
;	CL - Width
;	DI - Addr to draw to
;	SI - Addr of 3-byte char array
;	INBYTES - Buffered input
; Note:
;	ES = videoseg addr (0b800h)
;##############################################

DrawStr proc
		lodsb						; load from [si] to al
		stosw						; draw border
		
		push si						; save si (pointing at the middle elem) to the stack
		
		lodsb
		stosw						; draw empty space

		sub cl, 02h
		mov si, offset INBYTES + 2

@@PutC:
		lodsb						; load from array to al
		stosw						; print input str to video RAM
		dec cl
		ja @@PutC

		pop si						; return si value

		lodsb						; draw empty space
		stosw

		lodsb						; draw border
		stosw

		sub si, 03h					; return si to the initial char set
		add bx, SCR_WIDTH			; iterate row

		ret
endp

.data

INBYTES db 10h, 10h dup(0)											; input buffer
BRD1	db 0DAh, 0C4h, 0BFh, 0B3h, 0B1h, 0B3h, 0C0h, 0C4h, 0D9h		; std border 1 symbols
BRD2	db 0C9h, 0CDh, 0BBh, 0BAh, 0B0h, 0BAh, 0C8h, 0CDh, 0BCh		; std border 2 symbols

DataEND:
end _start