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
	mov ah, 0x0e
	mov al, '>'
	int 0x10

	mov bx, 0 ;initialize the buffer pointer

main_loop:

	mov ah, 0x00 ;keyboard read
	int 0x16 ;keyboard interrupt. key is stored in al, scan code is stored in ah

	cmp al, 0x0d ;compare al with 0x0d (enter key)
	je handle_enter

	cmp al, 0x08 ;compare al with 0x08 (backspace key)
	je handle_backspace 

	cmp bx, 64 ;checks if buffer is full
	je main_loop

	mov ah, 0x0e
	int 0x10 ;print character in al

	mov [buffer+bx], al ;stores key pressed into buffer adress + bx
	inc bx

	jmp main_loop

handle_enter:
;placeholder
jmp main_loop

handle_backspace:
;placeholder
jmp main_loop

buffer: times 64 db 0
