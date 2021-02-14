# SwiftIsNotLame

### Creation of this package
1. Package.swift set up for a c library
1. download lame source code.
1. (unsure if necessary) - 
	1. in `include/libmp3lame.sym` delete the `lame_init_old` line 
	1. run `./configure --disable-dependency-tracking --disable-debug --enable-nasm`
	1. run `make`
	1. if these steps arent necessary, they at least seem to allow the xcodeproj file in `macosx` folder work
1. copy `lame.h` from lame source `include` to `Sources/lame/include`
1. copy contents of `libmp3lame` from lame source to `Sources/lame`	
	1. delete `i386`, `depcomp`, and files that match `*.rc`, `*.ico`, `*.o`, `*.lo`, and  `Makefile*`
	1. in the `vector` folder also delete `Makefile*`
1. create `Sources/lame/lame.h` and enter:

		#include "include/lame.h"
		#include <strings.h>
		#include <stdlib.h>
1. in `util.h` replace `extern ieee754_float32_t fast_log2(ieee754_float32_t x);` with `extern float fast_log2(float x);`
1. in `vector/xmm_quantize_sub.c` insert `../` before the following:
	* `machine.h`
	* `encoder.h`
	* `util.h`
	
			#include "../machine.h"
			#include "../encoder.h"
			#include "../util.h"
	
1. at this point it SHOULD build (save swift package tests you can comment)
