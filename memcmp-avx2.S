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

# memcmp with avx2, bmi, movbe, etc.

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

.p2align 4
MEMCMPU:
cmp	rdx, 8
ja	.Labove8
test	edx, edx #need this because of braindead x86 shifts
jz	.Lunsafe_ret

MOVBE	rax, [rdi]
MOVBE	rsi, [rsi]
BSWAP	(rax)
BSWAP	(rsi)

lea	rcx, [8*rdx - 64]
neg	rcx

xor	edx, edx

SHR	(rax)
SHR	(rsi)
sub	rax,rsi
seta	dl
sar	rax, 63
or	eax, edx
.Lunsafe_ret:
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
test	edx, edx #need this because of braindead x86 shifts
jz	.Lret

lea	r8, [rdi + rdx]
lea	r9, [rdi + 7]
xor	r9, r8
test	r9, PAGESZ  #shr+jc would use a shorter immediate, but not fuse
jnz	.Lfixrdi
movbe	rax, [rdi] #just use regular movbe here

# ecx shifts off the dummy bits.  Do this after the load, so as to get it
# started asap.  uica says this has less throughput, but we could be on the
# critical path, and this hides latency better
# (I feel like there should be a way to do this with fewer ops that involves a
# negative ecx--taking advantage of the masking--but idk)
lea	rcx, [rdx*8-64]
neg	ecx

SHR	(rax)

.Lpostrdi:
lea	r8, [rsi + rdx]
lea	r9, [rsi + 7]
xor	r9, r8
test	r9, PAGESZ
jnz	.Lfixrsi

movbe	rsi, [rsi] #ditto
SHR	(rsi)

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
lea	rcx, [rdx*8-64]
neg	ecx
SHL	(rdi)
SHR	(rdi)
jmp	.Lpostrdi

.Lfixrsi:
movbe	rsi, [rdi + rdx - 8]
SHL	(rsi)
SHR	(rsi)
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
