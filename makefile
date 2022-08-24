CFLAGS := -g
O := memcmp-avx512.o memcmp-avx2.o test.o
default: test
	
test: $(O)

dotest: test
	./test

clean:
	rm -f test $(O)
