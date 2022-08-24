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

.extern memcmp

# rdi, rsi: strings
# rdx: count
# note: MEMCMPU must come before MEMCMP, to ensure the conditional jump is a forward one
.p2align 4
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

.p2align 4
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
