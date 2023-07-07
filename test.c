#include <string.h>
#include <assert.h>

int sgn(int y) { return y > 0 ? 1 : y >> 31; }

void test(int (*mmemcmp)(const void*, const void*, size_t)) {
	char as[][5] = {
		"cefhQ",
		"cefhR",
		"befi",
		"defg" };
	for (int i = 1; i < sizeof(as)/sizeof(as[0]); i++) {
		for (int j = 0; j <= i; j++) {
			assert(sgn(memcmp(as[i], as[j], 4)) == sgn(mmemcmp(as[i], as[j], 4)));
			assert(sgn(memcmp(as[i], as[j], 3)) == sgn(mmemcmp(as[i], as[j], 3)));
			assert(sgn(memcmp(as[j], as[i], 4)) == sgn(mmemcmp(as[j], as[i], 4)));
			assert(sgn(memcmp(as[j], as[i], 3)) == sgn(mmemcmp(as[j], as[i], 3)));
			assert(sgn(memcmp(as[i], as[i], 4)) == sgn(mmemcmp(as[i], as[i], 4)));
			assert(sgn(memcmp(as[j], as[j], 3)) == sgn(mmemcmp(as[j], as[j], 3)));
		}
	}
}

typedef int MEMCMP(const void*, const void*, size_t);
MEMCMP fancy_memcmp_avx512, fancy_memcmp_avx2_intel, fancy_memcmp_avx2_amd, fancy_memcmp_sse2;

int main() {
	test(fancy_memcmp_avx512);
	test(fancy_memcmp_avx2_intel);
	test(fancy_memcmp_avx2_amd);
	test(fancy_memcmp_sse2);
}
