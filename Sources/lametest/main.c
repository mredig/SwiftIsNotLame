#include <stdio.h>
#include "lame.h"

int main() {
	printf("test\n\n");

	lame_global_flags *gfp;
	gfp = lame_init();

	return 0;
}
