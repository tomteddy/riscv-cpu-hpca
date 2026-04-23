/*
 * matmul_8x8_nocustom.c — 8×8 matrix multiply, software multiply only.
 *
 * Identical algorithm to matmul_8x8.c but uses a plain C software multiply
 * (compiler emits shift-and-add / __mulsi3) instead of MUL/MAC instructions.
 * Used as the baseline for measuring custom-op speedup.
 *
 * Same data and expected result as matmul_8x8.c:
 *   C[i][j] = 8*(j+1)  for all i.
 *
 * Compile:  tools\build.bat tests\matmul_8x8_nocustom.c
 */

#define N 8

int A[N][N] = {
    {1,1,1,1,1,1,1,1},
    {1,1,1,1,1,1,1,1},
    {1,1,1,1,1,1,1,1},
    {1,1,1,1,1,1,1,1},
    {1,1,1,1,1,1,1,1},
    {1,1,1,1,1,1,1,1},
    {1,1,1,1,1,1,1,1},
    {1,1,1,1,1,1,1,1}
};

int B[N][N] = {
    {1,2,3,4,5,6,7,8},
    {1,2,3,4,5,6,7,8},
    {1,2,3,4,5,6,7,8},
    {1,2,3,4,5,6,7,8},
    {1,2,3,4,5,6,7,8},
    {1,2,3,4,5,6,7,8},
    {1,2,3,4,5,6,7,8},
    {1,2,3,4,5,6,7,8}
};

int C[N][N];

/* Software signed multiply: 32-bit result of a*b using shift-add.
 * Handles negative operands by working on absolute values. */
static int sw_mul(int a, int b) {
    int neg = 0;
    int result = 0;
    int i;
    if (a < 0) { a = -a; neg ^= 1; }
    if (b < 0) { b = -b; neg ^= 1; }
    for (i = 0; i < 32; i++) {
        if (b & 1) result += a;
        a <<= 1;
        b >>= 1;
        if (!b) break;
    }
    return neg ? -result : result;
}

int main(void) {
    int i, j, k;
    for (i = 0; i < N; i++) {
        for (j = 0; j < N; j++) {
            int sum = 0;
            for (k = 0; k < N; k++)
                sum += sw_mul(A[i][k], B[k][j]);
            C[i][j] = sum;
        }
    }
    return 0;
}
