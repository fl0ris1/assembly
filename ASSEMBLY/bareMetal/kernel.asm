[org 0x1000]

;rep is for stos/lods. loop is for the rest

; ---------- VIDEO CONSTANTS ----------
VID_MEM equ 0xb800
COL_MAIN equ 0x1f ;white on blue (main desktop). 1f in binary is 00011111 lower 4 bits are foreground, the 3 higher are the background and the highest one is blinking.
COL_HEADER equ 0x70 ;black on light gray (header)
COL_ERROR equ 0x4f ;white text on red background


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

	mov bx, 0 ;initialize the buffer pointer

	jmp login_screen

login_screen:
	mov bx, 0 ;reset buffer

	mov si, msg_login_prompt ;login prompt
	call print_string

get_username_loop:
	mov ah, 0x00 ;wait for key
	int 0x16

	cmp al, 0x0d ;checks if enter pressed (submission)
	je check_username

	cmp al, 0x08
	je .handle_backspace ;handle backspace

	cmp bx, 64 ;buffer limit
	je get_username_loop

	mov ah, 0x0e ;echo character and store it
	int 0x10
	mov [buffer + bx], al
	inc bx
	jmp get_username_loop

.handle_backspace:
	cmp bx, 0
	je get_username_loop

	dec bx
	mov ah, 0x0e
	mov al, 0x08 ;move cursor one spot to the left
	int 0x10
	mov al, ' ' ;print a space
	int 0x10
	mov al, 0x08 ;move cursor one spot to the left
	int 0x10
	jmp get_username_loop

check_username:
	mov byte [buffer + bx], 0 ;null-terminate the input

	mov ah, 0x0e ;new line for visual cleanliness
	mov al, 0x0d
	int 0x10
	mov al, 0x0a
	int 0x10

	mov si, buffer ;compare input with username
	mov di, auth_username
	call strcmp
	je ask_password ;jump to ask_password if usernames match

	mov si, msg_denied ;print message denied if usernames do not match
	call print_string

	mov ah, 0x0e ;print new line
	mov al, 0x0d
	int 0x10
	mov al, 0x0a
	int 0x10

	jmp login_screen ;try again

ask_password:
	mov bx, 0 ;reset the buffer for new input

	mov si, msg_pass_prompt ;print password prompt
	call print_string

get_password_loop:
	mov ah, 0x00 ;wait for key
	int 0x16

	cmp al, 0x0d ;handle enter (submission)
	je check_password

	cmp al, 0x08 ;handle backspace
	je .handle_backspace_pw

	cmp bx, 64 ;check if buffer full
	je get_password_loop

	mov [buffer + bx], al

	mov ah, 0x0e ;echo the character
	mov al, '*'
	int 0x10

	inc bx
	jmp get_password_loop

.handle_backspace_pw:
	cmp bx, 0
	je get_password_loop

	dec bx
	mov ah, 0x0e
	mov al, 0x08
	int 0x10

	mov al, ' '
	int 0x10

	mov al, 0x08
	int 0x10

	jmp get_password_loop

check_password:
	mov byte [buffer + bx], 0 ;null terminate the input

	mov ah, 0x0e
	mov al, 0x0d ;new line
	int 0x10
	mov al, 0x0a
	int 0x10

	mov si, buffer
	mov di, auth_password
	call strcmp ;compare input with password
	je login_success

	mov si, msg_denied ;print message denied
	call print_string

	mov ah, 0x0e ;new line
	mov al, 0x0d
	int 0x10
	mov al, 0x0a
	int 0x10

	jmp login_screen ;jump to login screen

login_success:
	mov si, msg_welcome ;print welcome message
	call print_string
	
	call sleep_1s

	call draw_loading_screen

	call sleep_1s ;wait 1 second

	call draw_desktop_ui

	mov ax, 440
	call sound_on

	jmp reset_prompt

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

	mov [buffer + bx], al ;stores key pressed into buffer adress + bx
	inc bx

	jmp main_loop

buffer_full:
	;dont store character
	mov ah, 0x0e
	mov al, 0x07 ;bell hex code
	int 0x10

	jmp main_loop

; ---------- LIBRARY SECTION ----------

handle_enter:
	mov byte [buffer+bx], 0 ;adds a null terminator to the end of the command

	mov ah, 0x0e
	mov al, 0x0d ;carriage return (returns to the beginning of the line)
	int 0x10

	mov ah, 0x03 ;until jge .scroll and .scroll unoriginal
	int 0x10
	cmp dh, 23
	jge .scroll

	mov ah, 0x0e
	mov al, 0x0a ;line feed (new line)
	int 0x10

	jmp process_command ;handoff to the dispatcher

.scroll:
	call scroll_workspace
	jmp process_command

process_command:
	;Handle Empty Input

	mov al, [buffer]
	cmp al, 0 ;checks if buffer is empty
	je reset_prompt

	;Check For 'help'

	mov si, buffer ;si points to user input
	mov di, cmd_help ;di points to 'help' string
	call strcmp ;compare si with di
	je execute_help ;jump to execute_help if equal

	;Check For 'reboot'

	mov si, buffer
	mov di, cmd_reboot
	call strcmp
	je execute_reboot

	;Check For 'time'

	mov si, buffer
	mov di, cmd_time
	call strcmp
	je execute_time

	;Check For 'cls

	mov si, buffer
	mov di, cmd_cls
	call strcmp
	je execute_cls

	;Check For 'reset'

	mov si, buffer
	mov di, cmd_reset
	call strcmp
	je reset_shell
	
	;Fallback: Unkown Command
	jmp unkown_command

reset_prompt:
	mov si, prompt
	mov bl, COL_MAIN
	call print_string_attr
	mov bx, 0 ;clear index. sets the index of the buffer back to the beginning

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

print_bcd:
	;input: al = bcd encoded value
	;output: prints two ascii digits to the screen

	;tens
	push ax

	and al, 0xf0 ;set the low 4 bits to 0
	shr al,4 ;shift bits of al to the right by 4
	add al, '0' ;convert to ascii

	mov ah, 0x0e
	int 0x10

	;ones
	pop ax

	and al, 0x0f
	add al, '0'

	mov ah, 0x0e
	int 0x10

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

get_rtc_register:
	; INPUT: AL = Register Index To Read
	; OUTPUT; AL = Value To Read From RTC

	out 0x70, al ;write index to adress port. send value in al to cmos chip
	in al, 0x71 ;read the data from the data port. puts value into al
	ret

sleep_1s:
	;input: none (hardcoded to 1 second)
	;output: none (waits and returns)
	;1,000,000 microseconds = 0x000F4240 hex = 1 second.

	mov ah, 0x86 ;opcode for wait
	mov cx, 0xF ;top half of 0x000F4240
	mov dx, 0x4240 ;bottom half of 0x000F4240
	int 0x15

	ret

sleep_tick:
	push cx
	push dx
	push ax

	mov ah, 0x86 ;wait function
	mov cx, 1 ;100,000 micro seconds in hex = 168a0. CX holds the high word, dx holds the low hold (first 2 bytes)
	mov dx, 0x86a0
	int 0x15

	pop ax
	pop dx
	pop cx

	ret

video_init_blue:
	;input: none
	;output: clears screen to blue background

	push ax
	push cx
	push di ;destination index
	push es ;extra segment

	mov ax, VID_MEM
	mov es, ax ;points es to video memory, which we will manipulate

	xor di, di ;sets destination index to 0

	mov ah, COL_MAIN ;moves main color into ah
	mov al, ' '

	;set counter, 80 columns x 25 rows = 2000 words (1 word = 2 bytes. The 2 bytes are the attributes and the character)
	mov cx, 2000

	rep stosw ;write ax to [es:di] 2 thousand times. stosw stores a word (2 bytes that are attribute and character) in memory

	mov ah, 0x02 ;set cursor position
	mov bh, 0 ;page 0
	mov dh, 1 ;row 0 1
	mov dl, 0 ;column 0
	int 0x10

	pop es ;!!ES IS USED FOR ACCESSING VARIABLES, RESTORE AFTER POPPING!!
	pop di
	pop cx
	pop ax

	ret

draw_header:
	push es
	push di
	push ax
	push cx
	push si

	mov ax, VID_MEM
	mov es, ax

	xor di, di ;set di to 0
	mov ah, COL_HEADER ;color of header
	mov al, ' '
	mov cx, 80 ;write ax to [es:di] 80 times
	rep stosw

	;memory offset = (row * 80 + column) * 2. Times 2 because character and attribute takes up 2 bytes (1 word)
	;text starts at top row column 1 (2nd column). (0 * 80 + 1) * 2

	mov di, 2 ;memory offset
	mov si, os_title

.title_loop:
	lodsb ;load byte from [ds:si] into al, then increments si
	cmp al, 0
	je .done

	mov ah, COL_HEADER
	mov [es:di], ax ;write character and attribute to video memory

	add di, 2 ;change offset by 2 (2 character and attribute stored)
	jmp .title_loop

.done:
	pop si
	pop cx
	pop ax
	pop di
	pop es
	ret

draw_footer:
	push es
	push di
	push ax
	push cx
	push si

	mov ax, VID_MEM
	mov es, ax

	mov di, 3840 ;(24 * 80) * 2

	mov ah, COL_HEADER
	mov al, ' '
	mov cx, 80 ;whole last row
	rep stosw

	mov di, 3842 ; extra 2 spaces from last row
	mov si, os_footer

.footer_loop:
	lodsb ;loads byte from [ds:si] into al
	cmp al, 0
	je .done

	mov ah, COL_HEADER
	mov [es:di], ax
	add di, 2
	jmp .footer_loop

.done:
	pop si
	pop cx
	pop ax
	pop di
	pop es
	ret


draw_desktop_ui:
	call video_init_blue
	call draw_header
	call draw_footer
	ret

print_string_attr:
	;input: SI = adress of string
	;	BL = color attribute

	push ax
	push bx
	push cx
	push dx
	push di
	push es

	mov ax, VID_MEM
	mov es, ax ;setup video memory

.loop:
	mov al, [si] ;load character
	cmp al, 0 ;check if null terminator
	je .done

	cmp al, 0x0d ;carriage return
	je .handle_cr
	cmp al, 0x0a ;line feed
	je .handle_lf

	mov ah, 0x03 ;get cursor position
	mov bh, 0
	int 0x10 ;returns dh = row, dl = column

	xor ch, ch
	mov ch, dh ;move row into ch
	mov ax, 80
	mul ch ;calculate meomry offset

	xor ch, ch
	mov cl, dl
	add ax, cx
	mov di, ax ;move ax into di
	shl di, 1 ;multipy di by 2 (2 bytes per cell)

	mov al, [si] ;again, because al was changed by mul
	mov ah, bl ;move attribute into ah
	mov [es:di], ax ;move attribute and character into video memory

	inc dl
	cmp dl, 80 ;check if cursor hit right edge
	jl .update_cursor

	;line wrap 
	mov dl, 0 ;set column to 0 (left edge)
	cmp dh, 23
	jge .do_scroll

	inc dh ;change cursor position one row down
	jmp .update_cursor 

.update_cursor:
	mov ah, 0x02 ;set cursor position
	mov bh, 0
	int 0x10

	inc si ;next character
	jmp .loop

.handle_cr:
	mov ah, 0x03 ;get cursor positition
	mov bh, 0
	int 0x10
	mov dl, 0 ;set column to 0 (left edge)
	mov ah, 0x02
	int 0x10 ;update cursor position

	inc si ;next character
	jmp .loop

.handle_lf:
	mov ah, 0x03 ;get cursor position
	int 0x10
	
	cmp dh, 23 ;compare row to 23 23
	jge .do_scroll ;jump if greater than or equal jge

	inc dh ;change cursor position one row down

	jmp .set_cursor

.do_scroll:
	call scroll_workspace ;cursor stays on 23 so we dont change dh (row)
	jmp .set_cursor ;update cursor position

.set_cursor:
	mov ah, 0x02 ;update cursor position
	mov bh, 0
	int 0x10

	inc si ;next character
	jmp .loop

.done:
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret

scroll_workspace:
	push ax
	push bx
	push cx
	push dx

	mov ah, 0x06 ;scroll active page up
	mov al, 1 ;scroll up by one line
	mov bh, COL_MAIN

	mov ch, 1 ;cx = row and column of upper left corner
	mov cl, 0
	mov dh, 23 ;dx = row and column of lower right corner
	mov dl, 79

	int 0x10

	pop dx
	pop cx
	pop bx
	pop ax
	ret

draw_loading_screen:
	mov ah, 0x02 ;set cursor postition
	mov bh, 0x00 ;page 0
	mov dh, 13 ;row
	mov dl, 24 ;column
	int 0x10

	mov si, msg_loading
	mov bl, 0x0f ;white text on black background 7
	call print_string_attr

	mov ah, 0x02 ;#inc dh 
	mov bh, 0x00
	mov dh, 12 ;move cursor 1 row down##NOW UP SHOULD BE DOWN
	mov dl, 24
	int 0x10

	mov cx, 25 ;length of the bar (20 blocks)

.bar_loop:
	push cx
	
	mov ah, 0x09 ;write char/attribute at current position
	mov al, 0xDB ;full block character
	mov bh, 0x00 ;page 0
	mov bl, 0x0f ;light green text on blue background (0001 1010) 7
	mov cx, 1 ;print 1 character
	int 0x10
	
	mov ah, 0x03 ;get cursor position
	int 0x10
	inc dl ;increase column (1 to the right)
	mov ah, 0x02 ;set cursor position
	int 0x10

	call sleep_tick ;wait 0,1 seconds

	pop cx ;restore loop counter
	loop .bar_loop ;decrement cx and jump to .bar_loop

	mov ah, 0x03 ;get cursor position
	int 0x10
	dec dl ;mov cursor 1 column back
	mov ah, 0x02
	int 0x10

	ret
	
move_cursor:
	push ax
	push bx

	mov ah, 0x02 ;set cursor position
	mov bh, 0 ;page 0
	int 0x10

	pop bx
	pop ax
	
	ret

sound_on:
	push ax
	push bx
	push cx
	push dx

	;1. store desired frequency inside bx
	mov bx, ax 
	

	;2. load the fixed base clock into DX:AX. 
	;1,193,180 hz is the base frequency (1234dc in hex). You divide this by desired frequency and send it to channel 2 port 0x42
	mov dx, 0x0012 ;high 16 bits
	mov ax, 0x34dc ;low 16 bits

	;3. calculate the divisor
	div bx ;divide the base frequency by desired frequency

	mov bx, ax ;move quotient into bx
	
	;4. configure PIT (channel 2, mode 3, binary)
	mov al, 0xb6 ;10110110. Bits 7-6 select channel 2. Bits 5-4: read and write. First low byte, then high byte.
				;Bits 3-1: mode 3, square wave generator. Bit 0: 16-bit binary mode (not BCD)

	out 0x43, al ;send to command port

	;5. send low byte
	mov ax, bx ;move quotient into ax
	out 0x43, al ;send lower byte of quotient

	;5b. send high byte
	mov al, bh
	out 0x43, al

	;6. enable the speaker (port 0x61)
	in al, 0x61 ;read current state
	or al, 0x03 ;force the bottom 2 bits to be on (for example: 10010000 or 0x03 (00000011) -> 10010011)
	out 0x61, al ;write back to the port 

	pop dx
	pop cx
	pop bx
	pop ax
	ret
	

; ---------- COMMAND LIBRARY ----------

execute_time:

	mov al, 0x04 ;register 0x04 holds hours
	call get_rtc_register ;read and print hours
	call print_bcd

	mov ah, 0x0e
	mov al, ':' ;print a ':'
	int 0x10

	mov al, 0x02 ;register 0x02 holds minutes
	call get_rtc_register ;read and print minutes
	call print_bcd

	;mov ah, 0x0e
	;mov al, 0x0d
	;int 0x10
	
	;mov al, 0x0a
	;int 0x10

	mov si, new_line
	mov bl, COL_MAIN
	call print_string_attr

	jmp reset_prompt

execute_help:
	mov si, msg_help
	call print_string

	;mov ah, 0x0e
	;mov al, 0x0d ;carrier return
	;int 0x10

	;mov al, 0x0a ;line feed
	;int 0x10

	mov si, new_line
	mov bl, COL_MAIN
	call print_string_attr


	jmp reset_prompt

execute_reboot:
	mov si, msg_reboot
	call print_string ;print msg_reboot

	;mov ah, 0x0e ;new line
	;mov al, 0x0d
	;int 0x10	

	;mov al, 0x0a
	;int 0x10

	mov si, new_line
	mov bl, COL_MAIN
	call print_string_attr

	call sleep_1s ;wait 3 seconds
	call sleep_1s
	call sleep_1s

	jmp 0xFFFF:0x0000 ;adress of BIOS reset vector

execute_cls:
	push es
	push di
	push ax
	push cx

	mov ax, VID_MEM
	mov es, ax

	mov di, 160 ;starting points of row 1 (80*2)
	mov ah, COL_MAIN ;character attributes
	mov al, ' ' ;space character

	mov cx, 1840 ;23 rows * 80 columns

	rep stosw ;stores ax value (2 bytes) into [ES:DI] and increase di by 2 (2 bytes) for cx times

	mov dh, 1
	mov dl, 0
	call move_cursor

	pop cx
	pop ax
	pop di
	pop es

	jmp reset_prompt

reset_shell:
	call draw_desktop_ui

	mov dh, 1
	mov dl, 0
	call move_cursor

	jmp reset_prompt

unkown_command:
	mov si, msg_unknown ;prints unkown command message
	mov bl, COL_ERROR
	call print_string_attr

	mov si, buffer ;prints buffer (command that is not recognised)
	call print_string_attr

	;mov ah, 0x0e
	;mov al, 0x0d ;return carrier
	;int 0x10

	;mov al, 0x0a ;line feed
	;int 0x10

	mov si, new_line
	mov bl, COL_MAIN
	call print_string_attr

	jmp reset_prompt

; ---------- VARIABLES ----------
new_line: db 0x0d, 0x0a, 0

buffer: times 64 db 0

cmd_help: db 'help', 0
msg_help: db 'Commands: help, reboot', 0
cmd_reboot: db 'reboot', 0
msg_reboot: db 'System Restarting in 3 Seconds...', 0
msg_unknown: db 'Unknown Command: ', 0
cmd_time: db 'time', 0
cmd_cls: db 'cls', 0
cmd_reset: db 'reset', 0

prompt: db 'root@maioloOS:~$ ', 0

; ---------- AUTHENTICATION DATA ----------

; The 'Golden Truth'
auth_username: db 'root', 0
auth_password: db '1234', 0

;UI prompts
msg_login_prompt: db 'Login: ', 0
msg_pass_prompt: db 'Password: ', 0
msg_denied: db 'Access Denied.', 0
msg_welcome: db 'Welcome, Administrator.', 0
msg_loading: db 'Loading System Modules...', 0
; ---------- UI STRINGS ----------

os_title: db 'MaioloOS v1.0', 0
os_footer: db 'F1: Help   F2: Clear   F3: Time', 0

