/*
 * dotprod_16.c — dot product of two 16-element vectors using custom MUL.
 *
 * A[i] = i + 1   (1..16)
 * B[i] = i + 1   (1..16)
 * dot  = Σ_{i=0}^{15} A[i]*B[i] = Σ_{i=1}^{16} i^2 = 1496
 *
 * Note on MAC: the MAC instruction computes rd = rs1 + rs1*rs2, which is
 * not a classic FMA. A dot product needs acc += A[i]*B[i], so we use
 * mul_custom() for the multiply and accumulate into a scalar.
 *
 * Uses mul_custom() from custom_ops.S (MUL instruction).
 * Compile:  tools\build.bat tests\dotprod_16.c
 */

#include "../tools/custom_ops.h"

#define N 16

int A[N] = { 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16 };
int B[N] = { 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16 };

int result;

int main(void) {
    int i;
    int dot = 0;
    for (i = 0; i < N; i++)
        dot += mul_custom(A[i], B[i]);
    result = dot;   /* store so compiler can't eliminate loop */
    return 0;
}
