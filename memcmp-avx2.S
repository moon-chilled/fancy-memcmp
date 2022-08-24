.intel_syntax noprefix

#ifndef MEMCMP
#define MEMCMP fancy_memcmp_avx2
#endif
#ifndef MEMCMPU
#define MEMCMPU fancy_memcmp_unsafe_avx2
#endif

.globl MEMCMP, MEMCMPU
.type MEMCMP, @function
.type MEMCMPU, @function
.p2align 4

.extern memcmp

# rdi, rsi: strings
# rdx: count
# note: MEMCMPU must come before MEMCMP, to ensure the conditional jump is a forward one
MEMCMPU:
mov		r8, -1

cmp     	rdx, 32
ja      	.Labove32

# could save a couple of bytes by figuring out how to use one of the first 8 registers in place of r8 
vmovdqu		ymm0, [rdi]
vmovdqu		ymm1, [rsi]
bzhi		r8, r8, rdx
.Lcmp32:
vpcmpgtb	ymm3, ymm1, ymm0
vpcmpgtb	ymm2, ymm0, ymm1
vpmovmskb	rcx, ymm2
vpmovmskb	rax, ymm3
and		rcx, r8
and		rax, r8
tzcnt		rcx, rcx
tzcnt		rax, rax
sub		eax, ecx
ret

.Labove32:
vmovdqu		ymm0, [rdi]
vmovdqu		ymm1, [rsi]
vpcmpeqb	ymm2, ymm0, ymm1
vpmovmskb	eax, ymm2
cmp		eax, 0xffffffff
jne		.Lcmp32
jmp memcmp

MEMCMP:
mov	r8, -1

cmp	rdx, 32
ja	.Lsafeabove32

# conservative page-cross test stolen from glibc
mov	eax, edi
or	eax, esi
and	eax, 4095
cmp	eax, 4064
ja	memcmp

vmovdqu		ymm0, [rdi]
vmovdqu		ymm1, [rsi]
bzhi		r8, r8, rdx
.Lsafecmp32
vpcmpgtb	ymm3, ymm1, ymm0
vpcmpgtb	ymm2, ymm0, ymm1
vpmovmskb	rcx, ymm2
vpmovmskb	rax, ymm3
and		rcx, r8
and		rax, r8
tzcnt		rcx, rcx
tzcnt		rax, rax
sub		eax, ecx
ret

.Lsafeabove32
vmovdqu		ymm0, [rdi]
vmovdqu		ymm1, [rsi]
vpcmpeqb	ymm2, ymm0, ymm1
vpmovmskb	eax, ymm2
cmp		eax, 0xffffffff
jne		.Lsafecmp32
jmp memcmp
