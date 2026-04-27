/*
 * relu_32.c — ReLU over a 32-element array using custom RELU instruction.
 *
 * x[i] = i - 16   (range -16..+15)
 * y[i] = max(x[i], 0)
 *
 * Expected y: {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15}
 *   (first 16 entries clamped to 0, last 16 entries pass through)
 *
 * Uses relu_custom() from custom_ops.S (RELU instruction).
 * Compile:  tools\build.bat tests\relu_32.c
 */

#include "../tools/custom_ops.h"
#include "validate.h"

#define N 32

int x[N] = {
    -16,-15,-14,-13,-12,-11,-10,-9,
     -8, -7, -6, -5, -4, -3, -2,-1,
      0,  1,  2,  3,  4,  5,  6, 7,
      8,  9, 10, 11, 12, 13, 14,15
};

int y[N];

int main(void) {
    int i;
    for (i = 0; i < N; i++)
        y[i] = relu_custom(x[i]);
    validate_write(BENCH_ID_RELU_32, y, N);
    return 0;
}
