/*
 * dotprod_16_nocustom.c — dot product, software multiply only.
 *
 * Same algorithm as dotprod_16.c but uses sw_mul() instead of MAC.
 * Baseline for measuring custom-op speedup.
 *
 * dot = Σ_{i=0}^{15} A[i]*B[i] = 1496
 *
 * Compile:  tools\build.bat tests\dotprod_16_nocustom.c
 */

#define N 16

int A[N] = { 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16 };
int B[N] = { 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16 };

int result;

static int sw_mul(int a, int b) {
    int neg = 0;
    int r = 0;
    int i;
    if (a < 0) { a = -a; neg ^= 1; }
    if (b < 0) { b = -b; neg ^= 1; }
    for (i = 0; i < 32; i++) {
        if (b & 1) r += a;
        a <<= 1;
        b >>= 1;
        if (!b) break;
    }
    return neg ? -r : r;
}

int main(void) {
    int i;
    int dot = 0;
    for (i = 0; i < N; i++)
        dot += sw_mul(A[i], B[i]);
    result = dot;
    return 0;
}
