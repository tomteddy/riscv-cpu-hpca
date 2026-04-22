/*
 * matmul_8x8.c — 8×8 signed integer matrix multiply using custom MUL.
 *
 * A[i][j] = 1           (all ones)
 * B[i][j] = j + 1       (column j filled with j+1)
 * C[i][j] = Σ_{k=0}^{7} A[i][k] * B[k][j] = 8 * (j+1)
 *
 * Expected C:  col0=8, col1=16, col2=24, col3=32,
 *              col4=40, col5=48, col6=56, col7=64
 *   (same for every row)
 *
 * Uses mul_custom() from custom_ops.S (MUL instruction).
 * Compile:  tools\build.bat tests\matmul_8x8.c
 */

#include "../tools/custom_ops.h"

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

int main(void) {
    int i, j, k;
    for (i = 0; i < N; i++) {
        for (j = 0; j < N; j++) {
            int sum = 0;
            for (k = 0; k < N; k++)
                sum += mul_custom(A[i][k], B[k][j]);
            C[i][j] = sum;
        }
    }
    return 0;
}
