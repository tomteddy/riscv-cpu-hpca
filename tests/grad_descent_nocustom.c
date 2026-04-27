/*
 * grad_descent_nocustom.c — gradient descent, software multiply only.
 *
 * Same algorithm as grad_descent.c but uses sw_mul() instead of mac3_custom.
 * Baseline for measuring MAC custom-op speedup.
 *
 * 640 software multiplies + 640 adds over 10 iterations.
 *
 * Compile:  tools\build.bat tests\grad_descent_nocustom.c
 */

#include "validate.h"

#define ROWS 8
#define COLS 4
#define ITERS 10
#define LR_SHIFT 8

int X[ROWS][COLS] = {
    { 1,  2,  1,  0},
    { 2,  1,  0,  1},
    { 0,  1,  2,  1},
    { 1,  0,  1,  2},
    { 2,  2,  0,  0},
    { 0,  0,  2,  2},
    { 1,  1,  1,  1},
    { 2,  0,  1,  1}
};

int y[ROWS] = { 5, 4, 5, 6, 6, 6, 5, 5 };
int w[COLS] = { 1, 1, 1, 1 };
int pred[ROWS];
int err[ROWS];
int grad[COLS];

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
    int iter, i, j;

    for (iter = 0; iter < ITERS; iter++) {

        for (i = 0; i < ROWS; i++) {
            int p = sw_mul(X[i][0], w[0])
                  + sw_mul(X[i][1], w[1])
                  + sw_mul(X[i][2], w[2])
                  + sw_mul(X[i][3], w[3]);
            pred[i] = p;
            err[i]  = p - y[i];
        }

        for (j = 0; j < COLS; j++) {
            int g = sw_mul(X[0][j], err[0])
                  + sw_mul(X[1][j], err[1])
                  + sw_mul(X[2][j], err[2])
                  + sw_mul(X[3][j], err[3])
                  + sw_mul(X[4][j], err[4])
                  + sw_mul(X[5][j], err[5])
                  + sw_mul(X[6][j], err[6])
                  + sw_mul(X[7][j], err[7]);
            grad[j] = g;
        }

        for (j = 0; j < COLS; j++)
            w[j] -= (grad[j] >> LR_SHIFT);
    }

    validate_write(BENCH_ID_GRAD_DESC_NOCUST, w, COLS);
    return 0;
}
