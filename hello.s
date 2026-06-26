	.intel_syntax noprefix
	.text
	.section	.text.strlen,"ax",@progbits
	.globl	strlen
strlen:
	xor	eax, eax
.L2:
	cmp	BYTE PTR [rdi+rax], 0
	je	.L5
	inc	rax
	jmp	.L2
.L5:
	ret
	.section	.text.printf,"ax",@progbits
	.globl	printf
printf:
	push	rbx
	mov	r10, rdi
	lea	rax, [rsp+16]
	mov	QWORD PTR [rsp-40], rsi
	mov	QWORD PTR [rsp-64], rax
	lea	rax, [rsp-48]
	mov	QWORD PTR [rsp-32], rdx
	mov	QWORD PTR [rsp-24], rcx
	mov	QWORD PTR [rsp-8], r9
	mov	DWORD PTR [rsp-72], 8
	mov	QWORD PTR [rsp-56], rax
	mov	QWORD PTR [rsp-16], r8
	xor	r8d, r8d
.L7:
	movsx	rsi, r8d
	add	rsi, r10
	mov	al, BYTE PTR [rsi]
	test	al, al
	je	.L28
	cmp	al, 37
	jne	.L8
	inc	r8d
	movsx	rax, r8d
	mov	al, BYTE PTR [r10+rax]
	cmp	al, 99
	jne	.L9
	mov	edx, DWORD PTR [rsp-72]
	cmp	edx, 47
	ja	.L10
	mov	eax, edx
	add	edx, 8
	add	rax, QWORD PTR [rsp-56]
	mov	DWORD PTR [rsp-72], edx
	jmp	.L11
.L10:
	mov	rax, QWORD PTR [rsp-64]
	lea	rdx, [rax+8]
	mov	QWORD PTR [rsp-64], rdx
.L11:
	mov	eax, DWORD PTR [rax]
	lea	rsi, [rsp-84]
	mov	BYTE PTR [rsp-84], al
	mov	eax, 1
	mov	edi, eax
	jmp	.L27
.L9:
	cmp	al, 100
	jne	.L13
	mov	edx, DWORD PTR [rsp-72]
	cmp	edx, 47
	ja	.L14
	mov	eax, edx
	add	edx, 8
	add	rax, QWORD PTR [rsp-56]
	mov	DWORD PTR [rsp-72], edx
	jmp	.L15
.L14:
	mov	rax, QWORD PTR [rsp-64]
	lea	rdx, [rax+8]
	mov	QWORD PTR [rsp-64], rdx
.L15:
	lea	rsi, [rsp-84]
	mov	eax, DWORD PTR [rax]
	mov	ecx, 10
	mov	rbx, rsi
.L16:
	cdq
	inc	rsi
	idiv	ecx
	add	edx, 48
	mov	BYTE PTR [rsi-1], dl
	test	eax, eax
	jne	.L16
	mov	edi, 1
.L17:
	cmp	rbx, rsi
	jnb	.L12
	dec	rsi
	mov	eax, edi
	mov	edx, 1
#APP
# 10 "/tmp/cib_PquGti.c" 1
	syscall
# 0 "" 2
#NO_APP
	jmp	.L17
.L13:
	cmp	al, 115
	jne	.L12
	mov	edx, DWORD PTR [rsp-72]
	cmp	edx, 47
	ja	.L20
	mov	eax, edx
	add	edx, 8
	add	rax, QWORD PTR [rsp-56]
	mov	DWORD PTR [rsp-72], edx
	jmp	.L21
.L20:
	mov	rax, QWORD PTR [rsp-64]
	lea	rdx, [rax+8]
	mov	QWORD PTR [rsp-64], rdx
.L21:
	mov	rsi, QWORD PTR [rax]
	mov	edi, 1
.L22:
	cmp	BYTE PTR [rsi], 0
	je	.L12
	mov	eax, edi
	mov	edx, 1
#APP
# 10 "/tmp/cib_PquGti.c" 1
	syscall
# 0 "" 2
#NO_APP
	inc	rsi
	jmp	.L22
.L8:
	mov	eax, 1
	mov	edi, 1
.L27:
	mov	edx, 1
#APP
# 10 "/tmp/cib_PquGti.c" 1
	syscall
# 0 "" 2
#NO_APP
.L12:
	inc	r8d
	jmp	.L7
.L28:
	xor	eax, eax
	pop	rbx
	ret
	.section	.text.scanf,"ax",@progbits
	.globl	scanf
scanf:
	mov	BYTE PTR [rsp-1], 0
	mov	r8, rsi
	xor	edi, edi
.L33:
	mov	eax, edi
	lea	rsi, [rsp-1]
	mov	edx, 1
#APP
# 21 "/tmp/cib_PquGti.c" 1
	syscall
# 0 "" 2
#NO_APP
	mov	al, BYTE PTR [rsp-1]
	lea	edx, [rax-9]
	cmp	dl, 1
	jbe	.L33
	cmp	al, 32
	je	.L33
	mov	BYTE PTR [r8], al
	mov	eax, 1
	ret
	.section	.rodata.main.str1.1,"aMS",@progbits,1
.LC0:
	.string	"Hello, World!\n"
	.section	.text.startup.main,"ax",@progbits
	.globl	main
main:
	mov	edi, 1
	mov	esi, OFFSET FLAT:.LC0
	mov	edx, 14
	mov	eax, edi
	syscall
	xor	eax, eax
    mov edi, eax
    mov eax, 60
    syscall


