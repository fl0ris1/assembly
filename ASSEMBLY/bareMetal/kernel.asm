[org 0x1000]

start:
	xor ax, ax ;explicitly set the segment registers
	mov ds, ax
	mov es, ax
	mov fs, ax ;segments for 386+ processors
	mov gs, ax

	;initialize the stack
	cli ;disable hardware interrupts
	mov ss, ax ;sets stack segment to 0
	mov sp, 0xFFF0 ;sets stack pointer to adress 0xFFF0
	sti ;enables hardware interrupts

	;print the character '>'
	mov si, prompt
	call print_string

	mov bx, 0 ;initialize the buffer pointer

	jmp main_loop

main_loop:
	mov ah, 0x00 ;keyboard read
	int 0x16 ;keyboard interrupt. key is stored in al, scan code is stored in ah

	cmp al, 0x0d ;compare al with 0x0d (enter key)
	je handle_enter

	cmp al, 0x08 ;compare al with 0x08 (backspace key)
	je handle_backspace

	cmp bx, 64 ;checks if buffer is full
	je buffer_full ;jumps to buffer_full if buffer is full

	mov ah, 0x0e
	int 0x10 ;print character in al

	mov [buffer+bx], al ;stores key pressed into buffer adress + bx
	inc bx

	jmp main_loop

buffer_full:
	;dont store character
	mov ah, 0x0e
	mov al, 0x07 ;bell hex code
	int 0x10

	jmp main_loop

handle_enter:
	mov byte [buffer+bx], 0 ;adds a null terminator to the end of the command

	mov ah, 0x0e
	mov al, 0x0d ;carriage return (returns to the beginning of the line)
	int 0x10

	mov al, 0x0a ;line feed (new line)
	int 0x10

	jmp process_command ;handoff to the dispatcher

process_command:
	;1. Handle Empty Input

	mov al, [buffer]
	cmp al, 0 ;checks if buffer is empty
	je reset_prompt

	;2. Check For 'help'

	mov si, buffer ;si points to user input
	mov di, cmd_help ;di points to 'help' string
	call strcmp ;compare si with di
	je execute_help ;jump to execute_help if equal

	;3. Check For Reboot

	mov si, buffer
	mov di, cmd_reboot
	call strcmp
	je execute_reboot

	;4. Fallback: Unkown Command
	jmp unkown_command

reset_prompt:
	mov bx, 0 ;clear index. sets the index of the buffer back to the beginning
	mov si, prompt
	call print_string
	jmp main_loop

handle_backspace:
	cmp bx, 0
	je main_loop ;do nothing if buffer is empty

	dec bx ;mov buffer pointer back by 1
	mov byte [buffer+bx], 0 ;clear the character in memory

	mov ah, 0x0e

	mov al, 0x08 ;move cursor one spot to the left
	int 0x10

	mov al, ' ' ;prints a space
	int 0x10

	mov al, 0x08 ;move cursor one spot to the left
	int 0x10

	jmp main_loop

print_string:
	mov ah, 0x0e

.loop:
	mov al, [si] ;load the character at si into al
	cmp al, 0 ;checks if al is a null terminator
	je .done ;if equal jump to .done

	int 0x10 ;print the character
	inc si ;move to next character at si
	jmp .loop ;loop again

.done:
	ret

strcmp:
	;input: si (source index) = adress of string a, di (destination index) = adress of string b
	;output: sets zero flag if equal, clears it if not

.loop:
	mov al, [si] ;load byte from string a
	mov bl, [di] ;load byte from string b

	cmp al, bl ;compare the 2 bytes
	jne .notequal ;if they are not equal, jump to .notequal

	cmp al, 0
	je .done

	inc si ;move to next byte in string a
	inc di ;move to next byte in string b

	jmp .loop ;next character

.notequal:
	mov al, 1
	cmp al, 0 ;1 != 0 so zero flag will be cleared (set to 0 NOT 1)
	ret

.done:
	xor ax, ax ;xoring a register with itself results in 0, setting the zero flag
	cmp al, 0 ;0 == 0 so zero flag will be set (set to 1 NOT 0)
	ret

; ---------- VARIABLES ----------

buffer: times 64 db 0

cmd_help: db 'help', 0
cmd_reboot: db 'reboot', 0
msg_help: db 'Commands: help, reboot', 0
msg_unknown: db 'Unknown Command: ', 0

prompt: db 'root@maioloOS:~$ ', 0

; ---------- COMMAND LIBRARY ----------

execute_help:
	mov si, msg_help
	call print_string

	mov ah, 0x0e
	mov al, 0x0d ;carrier return
	int 0x10

	mov al, 0x0a ;line feed
	int 0x10

	jmp reset_prompt

execute_reboot:
	jmp 0xFFFF:0x0000 ;adress of BIOS reset vector

unkown_command:
	mov si, msg_unknown ;prints unkown command message
	call print_string

	mov si, buffer ;prints buffer (command that is not recognised
	call print_string

	mov ah, 0x0e
	mov al, 0x0d ;return carrier
	int 0x10
	mov al, 0x0a ;line feed
	int 0x10

	jmp reset_prompt
