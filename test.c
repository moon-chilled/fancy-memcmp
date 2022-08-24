#include <string.h>
#include <assert.h>

int sgn(int y) { return y > 0 ? 1 : y >> 31; }

void test(int (*mmemcmp)(const void*, const void*, size_t)) {
	char a[] = "cefhQ";
	char q[] = "cefhR";
	char b[] = "befi";
	char c[] = "defg";
	assert(sgn(memcmp(a, a, 4)) == sgn(mmemcmp(a, a, 4)));
	assert(sgn(memcmp(a, q, 4)) == sgn(mmemcmp(a, q, 4)));
	assert(sgn(memcmp(q, a, 4)) == sgn(mmemcmp(q, a, 4)));
	assert(sgn(memcmp(a, c, 4)) == sgn(mmemcmp(a, c, 4)));
	assert(sgn(memcmp(a, b, 4)) == sgn(mmemcmp(a, b, 4)));
	assert(sgn(memcmp(c, a, 4)) == sgn(mmemcmp(c, a, 4)));
	assert(sgn(memcmp(b, a, 4)) == sgn(mmemcmp(b, a, 4)));
}

typedef int MEMCMP(const void*, const void*, size_t);
MEMCMP fancy_memcmp_avx512, fancy_memcmp_unsafe_avx512, fancy_memcmp_avx2, fancy_memcmp_unsafe_avx2, fancy_memcmp_sse2, fancy_memcmp_unsafe_sse2;

int main() {
	test(fancy_memcmp_avx512);
	test(fancy_memcmp_unsafe_avx512);
	test(fancy_memcmp_avx2);
	test(fancy_memcmp_unsafe_avx2);
	test(fancy_memcmp_sse2);
	test(fancy_memcmp_unsafe_sse2);
}
