%include 'functions.asm'

SECTION .data
comma db ",",0

SECTION .text
global _start

_start:
mov eax, 1 ;eax/ebx
mov ebx, 7
div ebx

call iprint

mov eax, comma

call sprint

mov eax, 1000000000
mul edx
div ebx

call iprintLF

call quit
