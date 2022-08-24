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

# 'portable' memcmp; uses sse2, so should work on all/any amd64

.intel_syntax noprefix

#ifndef MEMCMP
#define MEMCMP fancy_memcmp_sse2
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

mov	rax, [rdi]
mov	rsi, [rsi]
bswap	rax
bswap	rsi

mov	r8, -1

lea	rcx, [8*rdx - 64]
neg	rcx

xor	edx, edx

shl	r8, cl
and	rax, r8
and	rsi, r8
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
mov	rax, [rdi]
bswap	rax

# ecx shifts off the dummy bits.  Do this after the load, so as to get it
# started asap.  uica says this has less throughput, but we could be on the
# critical path, and this hides latency better
# (I feel like there should be a way to do this with fewer ops that involves a
# negative ecx--taking advantage of the masking--but idk)
lea	rcx, [rdx*8-64]
neg	ecx

shr	rax, cl  #no shlx yet :\

.Lpostrdi:
lea	r8, [rsi + rdx]
lea	r9, [rsi + 7]
xor	r9, r8
test	r9, PAGESZ
jnz	.Lfixrsi

mov	rsi, [rsi]
bswap	rsi
shr	rsi, cl

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
mov	rdi, [rdi + rdx - 8]
bswap	rdi
#mov	ecx, 64
#shl	edx, 3    #2^3 = 8 bits
#sub	ecx, edx
lea	rcx, [rdx*8-64]
neg	ecx
shl	rdi, cl
shr	rdi, cl
jmp	.Lpostrdi

.Lfixrsi:
mov	rsi, [rdi + rdx - 8]
bswap	rsi
shl	rsi, cl
shr	rsi, cl
jmp	.Lpostrsi

.section .text
.Labove8:
cmp	rdx, 16
ja	.Labove16
mov	r8, [rdi + rdx - 8]
mov	r9, [rsi + rdx - 8]
mov	rax, [rdi]
mov	rsi, [rsi]
bswap	r8
bswap	r9
bswap	rax
bswap	rsi
xor	edx, edx
cmp	r8, r9
sbb	rax, rsi
seta	dl
sar	rax, 63
or	eax, edx
ret

.Labove16:
