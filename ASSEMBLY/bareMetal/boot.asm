[org 0x7c00]

start:
	cli ;disables system interrupts
	mov [BOOT_DRIVE], dl ;saves boot drive number provided by bios into BOOT_DRIVE variable
	xor ax, ax ;sets ax to 0
	mov ss, ax ;sets stack segment to 0
	mov sp, 0x7c00 ;sets stack pointer to 0x7c00
	mov ds, ax ;sets data segment to 0
	mov es, ax ;sets extra segment to 0
	sti ;enables system interrupts

	mov ah, 0x0e
	mov al, 'M'
	int 0x10

	mov ah, 0x02 ;BIOS read sector function
	mov al, 15 ;read 15 sectors
	mov ch, 0 ;cylinder 0 (first cylinder)
	mov dh, 0 ;which side to read (top)
	mov cl, 2 ;start to read at sector 2 (1 is bootloader)

	xor bx, bx ;sets bx to 0
	mov es, bx ;sets extra segment to 0
	mov bx, 0x1000 ;sets bx to 0x1000 (offset)
	mov dl, [BOOT_DRIVE] ;loads boot drive number into dl

	int 0x13 ;diskette interrupt

	jc disk_error ;check if carry flag is set for general failure

	cmp al, 15 ;check if we read exactly 15 sectors
	jne disk_error ;if al != 15 jump to error

	jmp kernel_load_success

disk_error:
	mov ah, 0xe
	mov al, 'D'
	int 0x10
	jmp $

kernel_load_success:
	jmp 0x0000:0x1000 ;far jump to kernel adress

error:
	mov ah, 0xe ;teletype
	mov al, 'E' ;character to print
	int 0x10 ;video interrupt
	jmp $ ;jumps to the current line in memory, freezing the system

BOOT_DRIVE: db 0 ;sets BOOT_DRIVE variable to 0

times 510 - ($ - $$) db 0
dw 0xAA55 ;magic number
