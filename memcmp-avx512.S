# Copyright (c) 2022, Elijah Stone
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# memcmp with avx512

.intel_syntax noprefix

#ifndef MEMCMP
#define MEMCMP fancy_memcmp_avx512
#endif

.globl MEMCMP
.type MEMCMP, @function

# rdi, rsi: strings
# rdx: count
.p2align 4,0xcc
MEMCMP:
cmp	rdx, 64
ja	.Labove64

mov		rcx, -1
bzhi		rcx, rcx, rdx
kmovq		k1, rcx
vmovdqu8	zmm16{k1}{z}, [rdi]
vmovdqu8	zmm17{k1}{z}, [rsi]
.Lcmp64:
vpcmpnleub	k1, zmm16, zmm17 #could also be nlt; or le/lt and commute
vpcmpnleub	k2, zmm17, zmm16
kmovq		rcx, k1
kmovq		rax, k2
tzcnt		rcx, rcx
tzcnt		rax, rax
sub		eax, ecx

ret

.Labove64: #could make this the loop body, but overwhelmingly likely that the first 64 bytes are different even if the string is >64 bytes, so spare no cycles here
vmovdqu8	zmm16, [rdi]
vmovdqu8	zmm17, [rsi]
vpcmpnequb	k3, zmm16, zmm17
ktestq		k3, k3
jnz		.Lcmp64

mov		rcx, 128 #64 bytes _above_ current index; check if it passed rdx
cmp		rcx, rdx
jae		.Ltail
.p2align 4
.Lloop:
vmovdqu8	zmm16, [rdi + rcx - 64]
vmovdqu8	zmm17, [rsi + rcx - 64]
vpcmpnequb	k3, zmm16, zmm17
ktestq		k3, k3
jnz		.Lcmp64
add		rcx, 64
cmp		rcx, rdx
jb		.Lloop

.Ltail:
vmovdqu8	zmm16, [rdi + rdx - 64]
vmovdqu8	zmm17, [rsi + rdx - 64]
jmp		.Lcmp64
