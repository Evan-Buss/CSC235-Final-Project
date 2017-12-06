;
; Load a list of olympians into an array of structs
; print them out together with the total medal count
; 
; PLEASE ENTER YOUR NAME:
;

include Irvine32.inc

olympian STRUCT
	athlete BYTE 32 DUP('a')		; 32 bytes	
	country BYTE 32 DUP('c')		; 32
	gender BYTE 'x'					; 1
	ALIGN DWORD						; add 3 bytes
	medals DWORD -1,-1,-1			; gold silver bronze (96)
olympian ENDS						; 164 total

; define some constants for global use
FSIZE = 100							; max file name size
BSIZE = 1000						; buffer size
LINESIZE = 100						; max input line size
CR = 0Dh							; c/r
LF = 0Ah							; line feed
ASTERISK = 2Ah						; asterisk for new entry
NULL = 00h							; null character
SPACE = 20h							; space character
MAXNUM = 5							; number of olympians

.data
filename BYTE FSIZE DUP(?)			; array to hold the file name
buffer BYTE BSIZE DUP(?)			; buffer to hold the file contents
prompt BYTE "Enter a filename: ",0	; prompt for a string
ferror BYTE "Invalid input...",0	; error message

olist olympian <>,<>,<>,<>,<>		; list of 5 olympians

; for output listing
outname    BYTE "Name: ",0
outcountry BYTE "Country: ",0
outgender  BYTE "Gender: ",0
outmedals  BYTE "Medals: ",0
outtotal   BYTE "Total Medals: ",0

.code
main PROC
    ; load the data from a file - push the arguments in reverse order
	push BSIZE						; data buffer size
	push OFFSET buffer				; point to the start of the buffer
	push FSIZE						; file name size
	push OFFSET filename			; point to the start of the string
	push OFFSET prompt				; output the prompt
	call loadFile					; load the buffer
	cmp eax,0						; nothing read, bail out
	jz ERROR

	; file loaded correctly, process and output the data

	jmp DONE						; done processing data, jump to the end

ERROR:
    mov edx,OFFSET ferror			; output error message
	call WriteString				; uses edx 
	call CrLf 

DONE:
	;loadAllOlympians
	;outputAllOlympians
	call WaitMsg					; wait for user to hit enter
	invoke ExitProcess,0			; bye
main ENDP

; prompts for a file name and reads contents into a buffer
; receives:
;	[ebp+8] = (null terminated) prompt string
;	[ebp+12] = pointer to file name string
;	[ebp+16] = max size of file name string
;	[ebp+20] = pointer to buffer array
;	[ebp+24] = max size buffer
; returns:
;	eax = number of bytes read, zero on an error
loadFile PROC
	push ebp						; save the base pointer
	mov ebp,esp						; base of the stack frame
	sub esp,4						; create a local variable for the return value
	pushad							; save all of the registers (lazy)

	; prompt for the file name
    mov edx,[ebp+8]					; output the prompt
	call WriteString				; uses edx  

	; get the file name, open the file
	mov edx,[ebp+12]				; point to the start of the file name string
	mov ecx,[ebp+16]				; max size for file name
	call ReadString					; load the file name (string pointer in edx, max size in ecx)
	call OpenInputFile				; open the file (expects name in edx, max size in ecx)
	mov ebx,eax						; save the file pointer (returned in eax)
	cmp eax,INVALID_HANDLE_VALUE	; check for a valid file pointer 
	je BAD							; bail out on a failure

	; load the buffer with the contents of the file
	mov edx,[ebp+20]				; point to the start of the buffer
	mov ecx,[ebp+24]				; max size of the buffer
	call ReadFromFile				; gets file handle from eax (loaded above)
	mov DWORD PTR [ebp-4],eax		; save the number of bytes in local variable
	mov eax,ebx						; restore the file pointer for closing (saved above)
	call CloseFile					; close the file
	jc BAD							; if carry fag set, it's an error
	jmp OK

BAD:
	call WriteWindowsMsg			; got an error, display it
	mov DWORD PTR [ebp-4],0			; error: set the number of bytes read to zero

OK:									; clean up
	popad							; restore the registers
	mov eax,DWORD PTR [ebp-4]		; save the number of bytes read for return in eax
	mov esp,ebp						; remove local varfrom stack 
	pop ebp
	ret 20
loadFile ENDP
END main