;Evan Buss
;CSC235 
;Dr. Carelli
;12/9/17
;
; Loads a list of olympians into an array of structs
; and prints them out together with the total medal count


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

	jmp PROCESS						; done loading in, start to process buffer

ERROR:
    mov edx,OFFSET ferror			; output error message
	call WriteString				; uses edx 
	call CrLf 
	jmp BYE							;jump to end

PROCESS:
	;load data into structs
	push LINESIZE					;maximum line read size
	push OFFSET buffer				;point to input buffer
	push OFFSET olist				;point to start of struct array	
	Call loadAllOlympians			;populate struct array with data

	;display data to console
	push eax						;push number of olympians read in
	push OFFSET olist				;push start of array of olympian structs
	Call outputAllOlympians			;outout the contents of struct array

BYE:
	call WaitMsg					; wait for user to hit enter
	invoke ExitProcess,0			; bye
main ENDP

; Prompts for a file name and reads contents into a buffer
; Receives:
;	[ebp+8] = (null terminated) prompt string
;	[ebp+12] = pointer to file name string
;	[ebp+16] = max size of file name string
;	[ebp+20] = pointer to buffer array
;	[ebp+24] = max size buffer
; Returns:
;	EAX = number of bytes read, zero on an error
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

;Copies data from input buffer, formats it, 
;	and copies it to designated output 
;Recieves:
;	[ebp+8] = pointer to input BYTE array
;	[ebp+12] = pointer to output BYTE array
;	[ebp+16] = maximum buffer size
;Returns:
;	EAX = pointer to next character in input array
bufferCopy PROC
	push ebp						;save the base pointer
	mov ebp, esp					;base of the stack frame
	sub esp, 4						;create local variable to return eax
	pushad							;push all directories
	
;assign registers to stack elements
	mov eax, [ebp+8]				;eax = pointer to input array	
	mov edi, [ebp+12]				;edi = poiunter to output location
	mov ecx, [ebp+16]				;ecx = max buffer size
	
Copy:
	mov bl, [eax]					;move input character to bl
	cmp bl, CR						;test if char = Return Char
	je Format						;yes? start formatting string
	mov [edi], bl					;otherwise copy to output
	add eax, TYPE BYTE				;next char of input array
	add edi, TYPE BYTE				;next char of output array
	loop Copy						;keep going until Return char found

Format:
	mov bl, NULL					;bl = NULL
	mov [edi], bl					;replace blank char with NULL
	add eax, TYPE BYTE * 2			;increment past line feed
	add edi, TYPE BYTE				;increment output buffer

BYE:
	mov DWORD PTR [ebp-4],eax		;set local position variable = eax
	popad							;pop all directories
	mov eax,DWORD PTR [ebp-4]		;set eax = local variable
	mov esp, ebp					;remove local var from stack
	pop ebp
	ret 12
bufferCopy ENDP


;Receives from loadAllOlympians:    
; [ebp+8] = pointer to the beginning of a struct object  
; [ebp+12] = pointer  be the beginning of information in the buffer for the next athlete  
; [ebp+16] = maximum number of bytes to read in each transfer (pass to bufferCopy).    
;Returns (in eax):  
; Pointer to the next Olympian (athlete) in the buffer  
loadOlympian PROC
	push ebp							;save the base pointer
	mov ebp, esp						;base of the stack frame
	sub esp, 4							;create a local variable
	pushad								;push all registers

;assign registers to stack data
	mov esi, [ebp+8]					;esi = pointer to beginning of struct
	mov eax, [ebp+12]					;eax = pointer to info buffer
	mov ecx, [ebp+16]					;ecx = max # of bytes to transfer
	 
;move athlete to struct
	mov edx, esi						;edx now at the beginning of the struct
	push ecx 							;push max bytes to transfer
	push edx							;push output location
	push eax							;push input location
	Call bufferCopy						;load athlete

;move country to struct
	add edx, OFFSET olympian.country	;edx at country field
	push ecx							;push max bytes to transfer
	push edx							;push output location
	push eax							;push input location
	Call bufferCopy						;load country

;move gender to struct
	mov edx, esi						;edx now at beginning of struct
	add edx, OFFSET olympian.gender		;edx at gender field
	push ecx							;push max bytes to transfer
	push edx							;push output location
	push eax							;push input location
	Call bufferCopy						;load gender

;move gold medals to struct
	push ecx							;push max bytes to transfer
	push [ebp-4]						;push output location
	push eax							;push input location
	Call bufferCopy						;load gold medal to local var

	mov edx, DWORD PTR [ebp-4]			;load string into edx
	mov ecx, 4							;set string length to DWORD
	push eax							;eax is changed, so save it
	call ParseInteger32					;convert string to integer
	mov edx, esi						;edx now at beginning of struct
	add edx, OFFSET olympian.medals		;edx now at first medal field
	mov [edx], eax						;set value of medal to eax
	pop eax								;return eax to previous value

;move silver medals to struct
	push ecx							;push max bytes to transfer
	push [ebp-4]						;push output location
	push eax							;push input location
	Call bufferCopy						;load gold medal to local var

	mov edx, DWORD PTR [ebp-4]			;load string into edx
	mov ecx, 4							;set string length to DWORD
	push eax							;eax is changed, so save it
	call ParseInteger32					;convert string to integer
	mov edx, esi						;edx now at beginning of struct
	add edx, OFFSET olympian.medals[4]	;edx now at first medal field
	mov [edx], eax						;set value of medal to eax
	pop eax								;return eax to previous value

;move bronze medals to struct
	push ecx							;push max bytes to transfer
	push [ebp-4]						;push output location
	push eax							;push input location
	Call bufferCopy						;load gold medal to local var

	mov edx, DWORD PTR [ebp-4]			;load string into edx
	mov ecx, 4							;set string length to DWORD
	push eax							;eax is changed, so save it
	call ParseInteger32					;convert string to integer
	mov edx, esi						;edx now at beginning of struct
	add edx, OFFSET olympian.medals[8]	;edx now at first medal field
	mov [edx], eax						;set value of medal to eax
	pop eax								;return eax to previous value

	mov DWORD PTR [ebp-4], eax			;set local var to eax
	popad								;pop all registers
	mov eax, DWORD PTR [ebp-4]			;set eax to local var
	mov esp, ebp
	pop ebp
	ret 12
loadOlympian ENDP
	
;Calls loadOlympian 5 times and
;	loads each olympian into the array of structs
;Receives from Main:
;	[ebp+8] = pointer to the beginning of the struct array  
;	[ebp+12] = pointer to the start of the buffer containing the data read from the file   
;	[ebp+16] = Maximum number of bytes to read on each line (pass to loadOlympian).    
;Returns:    
;	EAX = Number of Olympians read  
loadAllOlympians PROC
	push ebp
	mov ebp, esp
	sub esp, 4						;local variable for olympian #
	pushad							;save all registers
	mov edi, 0						;start counter at 0	
	
;assign registers to stack data
	mov edx, [ebp+8]				;edx = pointer to struct array
	mov eax, [ebp+12]				;eax = pointer to input buffer
	mov esi, [ebp+16]				;esi = pointer to max bytes to read

	push esi						;size
	push eax						;push input buffer
	push edx						;push struct pointer	
	
;check for asterisk
	mov bl, [eax]					;bl = character at eax
	cmp bl, ASTERISK				;bl == * ?
	je BYE							;yes? Exit

	Call loadOlympian				;load data into struct
	inc edi							;increment counter

L1:
	mov bl, [eax]					;bl = character at eax
	cmp bl, ASTERISK				;bl == *?
	je	BYE							;yes? Exit
	push esi						;push max bytes
	push eax						;push input buffer
	add edx, TYPE olympian			;next struct
	push edx						;push struct pointer
	Call loadOlympian				;load data into struct
	inc edi							;increment counter
	jmp L1							;repeat
	
BYE:
	mov DWORD PTR [ebp-4], edi		;set local position variable = edi
	popad							;pop all directories
	mov eax,DWORD PTR [ebp-4]		;set eax to local variable
	mov esp, ebp
	pop ebp
	ret 12
loadAllOlympians ENDP

;Goes through array of olympian structs calls
;	outputOlympian for each one
;Receives:
;	[ebp+8] = pointer to olympian struct
;	[ebp+12] = number of olympians
;Returns:
;	Nothing
outputAllOlympians PROC
	push ebp
	mov ebp, esp
	pushad							;push all registers
	Call Crlf						;add space
;assign registers to stack data
	mov ecx, [ebp+12]				;set ecx to total number of olympians	
	mov eax, [ebp+8]				;set eax to pointer to olympian struct
	
	push eax						;push pointer to struct
	Call outputOlympian				;display olympian in console
	dec ecx							;decrement counter
L1:
	cmp ecx, 0						;check remaining olympians
	je BYE							;No more? Exit
	add eax, TYPE olympian			;move to next olympian in array
	push eax						;push pointer to struct
	Call outputOlympian				;display olympian in console
	dec ecx							;decrement counter
	jmp L1							;repeat
BYE:
	popad							;restore all registers
	mov esp, ebp
	pop ebp
	ret 8
outputAllOlympians ENDP

;Formats and displays an Olympian struct
;Recieves:
;	[ebp+8] = pointer to beginning of struct object
;Returns:
;	Nothing
outputOlympian PROC
	push ebp
	mov ebp, esp
	pushad
	mov ecx, 0							;set ecx (total count) to 0
	
;output athlete name
	mov edx, OFFSET outname				;move output string to edx
	Call WriteString					;write to console

	mov ebx, [ebp+8]					;set ebx to struct object 
	mov edx, ebx
	Call WriteString
	Call Crlf

;output country
	mov edx, OFFSET outcountry			;move output string to edx
	Call WriteString					;write to console

	mov ebx, [ebp+8]					;set ebx to struct object 
	add ebx, OFFSET olympian.country	;set ebx tp country field
	mov edx, ebx						;mov ebx to edx
	Call WriteString					;write to console
	Call Crlf

;output gender
	mov edx, OFFSET outgender			;move output string to edx
	Call WriteString					;write to console

	mov ebx, [ebp+8]					;set ebx to struct object 
	add ebx, OFFSET olympian.gender
	mov edx, ebx
	Call WriteString
	Call Crlf

;output medals
	mov edx, OFFSET outmedals			;move output string to edx
	Call WriteString					;write to console

	mov ebx, [ebp+8]					;set ebx to struct object 
	add ebx, OFFSET olympian.medals
	mov eax, [ebx]
	Call WriteDec

	mov al, SPACE
	Call WriteChar

	mov ebx, [ebp+8]					;set ebx to struct object 
	add ebx, OFFSET olympian.medals[4]
	mov eax, [ebx]
	Call WriteDec

	mov al, SPACE
	Call WriteChar

	mov ebx, [ebp+8]					;set ebx to struct object	
	add ebx, OFFSET olympian.medals[8]
	mov eax, [ebx]
	Call WriteDec
	Call Crlf

;output medal totals
	mov edx, OFFSET outtotal			;move output string to edx
	Call WriteString					;write to console
	
	mov ebx, [ebp+8]					;set ebx to struct object 
	add ebx, OFFSET olympian.medals		;move ebx to first medal field
	add ecx, [ebx]						;add value to total
	
	
	mov ebx, [ebp+8]					;set ebx to struct object 
	add ebx, OFFSET olympian.medals[4]	;move ebx to second medal field
	add ecx, [ebx]						;add value to total

	mov ebx, [ebp+8]					;set ebx to struct object 
	add ebx, OFFSET olympian.medals[8]	;move ebx to third medal field
	add ecx, [ebx]						;add value to total
	
	mov eax, ecx						;move total to eax
	Call WriteDec						;print total to console

	Call Crlf
	Call Crlf

	popad
	mov esp, ebp
	pop ebp
	ret 4
outputOlympian ENDP

END main