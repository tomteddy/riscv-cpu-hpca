/*
 * relu_32_nocustom.c — ReLU on 32 elements, plain C (no custom ops).
 *
 * Same algorithm as relu_32.c but uses a plain conditional instead of the
 * RELU custom instruction. Baseline for measuring RELU instruction speedup.
 *
 * Input:  x[i] = i - 16  (values -16..15)
 * Output: y[i] = max(x[i], 0)
 *
 * Compile:  tools\build.bat tests\relu_32_nocustom.c
 */

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
        y[i] = (x[i] & 0x80000000) ? 0 : x[i];  /* branchless ReLU */
    return 0;
}
