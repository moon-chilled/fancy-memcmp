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

# memcmp with avx2, bmi2, movbe (only on amd)

.intel_syntax noprefix

#ifndef MEMCMP
#define MEMCMP fancy_memcmp_avx2
#endif
#ifndef VZEROUPPER
#define VZEROUPPER vzeroupper
#endif

# on amd, movbe is free, so we use it to perform a byteswapped load
# on intel, however, movbe is an extra op over a straight load, so we prefer to load and bswap separately
# similarly, shr x,cl is expensive on intel compared with shrx x,y,z--amd has a smaller but still apparently real penalty--but future hardware may eliminate the penalty, and shr x,cl is preferrable on account of being smaller
#ifdef MEMCMP_AMD
# define MOVBE movbe
# define BSWAP(y)
# define SHR(y) shrx y, y, rcx
# define SHL(y) shlx y, y, rcx
#else
# define MOVBE mov
# define BSWAP(y) bswap y
# define SHR(y) shrx y, y, rcx
# define SHL(y) shlx y, y, rcx
#endif

.globl MEMCMP
.type MEMCMP, @function

#ifdef MEMCMPU
.globl MEMCMPU
.type MEMCMPU, @function

.p2align 4,0xcc
MEMCMPU:
cmp	rdx, 32
ja	.Labove32

vmovdqu		ymm0, [rdi]
vmovdqu		ymm1, [rsi]

shl		edx, 3

# ymm0 = min(ymm0,ymm1) where ymm0 <= ymm1 (in an unsigned way!)
vpminub		ymm2, ymm0, ymm1
vpcmpeqb	ymm0, ymm0, ymm2
vpcmpeqb	ymm1, ymm1, ymm2
vpmovmskb	eax, ymm0
vpmovmskb	ecx, ymm1
not		eax
not		ecx
bzhi		eax, eax, edx
bzhi		ecx, ecx, edx
tzcnt		eax, eax
tzcnt		ecx, ecx
sub		eax, ecx

VZEROUPPER
ret
#endif

#define LGPAGESZ 12
#define PAGESZ (1<<LGPAGESZ)

# Branchless strategy for <8-byte compares:
# We were asked to read rdx bytes from x (for values of x in {rdi rsi}), but we
# actually want to read 8 bytes starting from x and shift off the extraneous ones.
# Is that a problem?  If x is near the end of a page, and x+rdx is also near
# the end of that page, but x+7 is in the next page, then we read from the next
# page when we shouldn't.  But if x+rdx crosses a page, then we don't care.  So
# what we have to check is whether x+rdx and x+7 are in different pages, which
# is equivalent to checking if they differ in the LGPAGESZth bit.
# If they do so differ, then we can instead read 8 bytes from x+rdx-8, and shift
# the other way around.

# rdi, rsi: strings
# rdx: length
.p2align 4,0xcc
MEMCMP:
cmp	rdx, 8
jae	.Labove8
test	edx, edx
jz	.Lret

lea	r8, [rdi + rdx]
lea	r9, [rdi + 7]
xor	r9, r8
test	r9, PAGESZ  #shr+jc would use a shorter immediate, but not fuse
jnz	.Lfixrdi
mov	rax, [rdi] #just use regular mov here

# shifts off the dummy bits
lea	ecx, [edx * 8]
bzhi	rax, rax, rcx
bswap	rax

.Lpostrdi:
lea	r8, [rsi + rdx]
lea	r9, [rsi + 7]
xor	r9, r8
test	r9, PAGESZ
jnz	.Lfixrsi

bzhi	rsi, [rsi], rcx
bswap	rsi

.Lpostrsi:
xor	edx, edx
sub	rax, rsi
seta	dl
sar	rax, 63
or	eax, edx
.Lret:
ret

.section .text.cold,"ax" #good idea or no?
.Lfixrdi:
movbe	rdi, [rdi + rdx - 8]
mov	ecx, edx
shl	ecx, 3
bzhi	rdi, rdi, rcx
jmp	.Lpostrdi

.Lfixrsi:
movbe	rsi, [rdi + rdx - 8]
bzhi	rsi, rsi, rcx
jmp	.Lpostrsi

.section .text
.Labove8:
cmp	rdx, 16
ja	.Labove16
MOVBE	r8, [rdi + rdx - 8]
MOVBE	r9, [rsi + rdx - 8]
BSWAP	(r8)
BSWAP	(r9)
MOVBE	rax, [rdi]
MOVBE	rsi, [rsi]
BSWAP	(rax)
BSWAP	(rsi)
xor	edx, edx
cmp	r8, r9
sbb	rax, rsi
seta	dl
sar	rax, 63
or	eax, edx
ret

.Labove16:
