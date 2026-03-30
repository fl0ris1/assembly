[org 0x1000]

start:
	;print k for kernel

	mov ah, 0x0e
	mov al, 'K'
	int 0x10

	jmp $
