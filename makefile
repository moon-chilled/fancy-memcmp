CFLAGS := -g
O := memcmp-avx512.o memcmp-avx2-amd.o memcmp-avx2-intel.o memcmp-sse2.o test.o
default: test
	
test: $(O)
	$(CC) $(LFLAGS) -o $@ $^

memcmp-sse2.o: ASFLAGS += -DMEMCMPU=fancy_memcmp_unsafe_sse2
memcmp-avx2-amd.o: ASFLAGS += -DMEMCMP=fancy_memcmp_avx2_amd -DMEMCMPU=fancy_memcmp_unsafe_avx2_amd -DMEMCMP_AMD
memcmp-avx2-amd.o: memcmp-avx2.S
	$(CC) $(ASFLAGS) -c -o $@ $<
memcmp-avx2-intel.o: ASFLAGS += -DMEMCMP=fancy_memcmp_avx2_intel -DMEMCMPU=fancy_memcmp_unsafe_avx2_intel -DMEMCMP_INTEL
memcmp-avx2-intel.o: memcmp-avx2.S
memcmp-avx2-intel.o: memcmp-avx2.S
	$(CC) $(ASFLAGS) -c -o $@ $<
memcmp-avx512.o: ASFLAGS += -DMEMCMPU=fancy_memcmp_unsafe_avx512

dotest: test
	./test

clean:
	rm -f test $(O)
