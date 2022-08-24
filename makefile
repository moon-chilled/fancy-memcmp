CFLAGS := -g
O := memcmp-avx512.o memcmp-avx2.o memcmp-sse2.o test.o
default: test
	
test: $(O)

memcmp-sse2.o: ASFLAGS += -DMEMCMPU=fancy_memcmp_unsafe_sse2
memcmp-avx2.o: ASFLAGS += -DMEMCMPU=fancy_memcmp_unsafe_avx2
memcmp-avx512.o: ASFLAGS += -DMEMCMPU=fancy_memcmp_unsafe_avx512

dotest: test
	./test

clean:
	rm -f test $(O)
