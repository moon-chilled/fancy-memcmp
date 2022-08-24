.intel_syntax noprefix

#ifndef MEMCMP
#define MEMCMP fancy_memcmp_avx512
#endif
#ifndef MEMCMPU
#define MEMCMPU fancy_memcmp_unsafe_avx512
#endif

.globl MEMCMP, MEMCMPU
.type MEMCMP, @function
.type MEMCMPU, @function
.p2align 4

# rdi, rsi: strings
# rdx: count
# note: MEMCMPU must come before MEMCMP, to ensure the conditional jump is a forward one
MEMCMPU:
cmp	rdx, 64
ja	.Labove64

mov		rcx, -1
bzhi		rcx, rcx, rdx
kmovq		k3, rcx
vmovdqu8	zmm0, [rdi]
vmovdqu8	zmm1, [rsi]
vpcmpnleub	k1{k3}, zmm0, zmm1 #could also be nlt; or le/lt and commute
vpcmpnleub	k2{k3}, zmm1, zmm0
kmovq		rcx, k1
kmovq		rax, k2
tzcnt		rcx, rcx
tzcnt		rax, rax
sub		eax, ecx

#vzeroupper
ret

.p2align 4
# rdi, rsi: strings
# rdx: count
MEMCMP:
cmp	rdx, 64
ja	.Labove64

mov		rcx, -1
bzhi		rcx, rcx, rdx
kmovq		k1, rcx
vmovdqu8	zmm0{k1}, [rdi]
vmovdqu8	zmm1{k1}, [rsi]
.Lcmp64:
vpcmpnleub	k1, zmm0, zmm1 #could also be nlt; or le/lt and commute
vpcmpnleub	k2, zmm1, zmm0
kmovq		rcx, k1
kmovq		rax, k2
tzcnt		rcx, rcx
tzcnt		rax, rax
sub		eax, ecx

#vzeroupper
ret

.Labove64: #could make this the loop body, but overwhelmingly likely that the first 64 bytes are different even if the string is >64 bytes, so spare no cycles here
vmovdqu8	zmm0, [rdi]
vmovdqu8	zmm1, [rsi]
vpcmpequb	k3, zmm0, zmm1
ktestq		k3, k3
jnz		.Lcmp64

mov		rcx, 128 #64 bytes _above_ current index; check if it passed rdx
cmp		rcx, rdx
jae		.tail
.Lloop:
vmovdqu8	zmm0, [rdi + rcx - 64]
vmovdqu8	zmm1, [rsi + rcx - 64]
vpcmpnequb	k3, zmm0, zmm1
ktestq		k3, k3
jnz		.Lcmp64
add		rcx, 64
cmp		rcx, rdx
jb		.Lloop

.tail:
lea		rdi, [rdi + rdx - 64]
vmovdqu8	zmm0, [rdi]
lea		rsi, [rsi + rdx - 64]
vmovdqu8	zmm0, [rsi]
jmp		.Lcmp64
