/*
 * grad_descent.c — Fixed-point linear regression via gradient descent.
 *
 * Problem: fit w[4] to minimise ||X*w - y||^2
 *   X : 8×4 feature matrix  (fixed-point, scale 1 = 256)
 *   y : 8-element label vector
 *   w : 4-element weight vector (updated each iteration)
 *
 * Fixed-point convention: all values are integers; real value = int/256.
 * Learning rate lr = 1 (in fixed-point: step = grad >> LR_SHIFT).
 *
 * Algorithm (10 iterations):
 *   for iter in 0..9:
 *     for i in 0..7:
 *       pred[i] = mac3(0, X[i][0],w[0]) + ... + mac3(...,X[i][3],w[3])
 *       err[i]  = pred[i] - y[i]
 *     for j in 0..3:
 *       grad = mac3(0, X[0][j],err[0]) + ... + mac3(...,X[7][j],err[7])
 *       w[j] -= grad >> LR_SHIFT   (fixed-point weight update)
 *
 * MAC count per iteration:
 *   Prediction: 8 rows × 4 MACs = 32 MACs
 *   Gradient  : 4 cols × 8 MACs = 32 MACs
 *   Total per iter: 64 MACs × 10 iters = 640 MACs
 *
 * Uses mac3_custom(acc, a, b) = acc + a*b  (3-operand MAC, Phase 4).
 * Compile:  tools\build.bat tests\grad_descent.c
 */

#include "../tools/custom_ops.h"

#define ROWS 8
#define COLS 4
#define ITERS 10
#define LR_SHIFT 8      /* divide gradient by 256 per step */

/* Feature matrix X[8][4] — small integer values for bounded fixed-point */
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

/* Labels y[8] */
int y[ROWS] = { 5, 4, 5, 6, 6, 6, 5, 5 };

/* Weights w[4] — initialised to 1 each */
int w[COLS] = { 1, 1, 1, 1 };

/* Scratch buffers */
int pred[ROWS];
int err[ROWS];
int grad[COLS];

int main(void) {
    int iter, i, j;

    for (iter = 0; iter < ITERS; iter++) {

        /* ---- Forward pass: pred[i] = X[i] . w ---- */
        for (i = 0; i < ROWS; i++) {
            int p = 0;
            p = mac3_custom(p, X[i][0], w[0]);
            p = mac3_custom(p, X[i][1], w[1]);
            p = mac3_custom(p, X[i][2], w[2]);
            p = mac3_custom(p, X[i][3], w[3]);
            pred[i] = p;
            err[i]  = p - y[i];
        }

        /* ---- Gradient: grad[j] = X[:,j] . err ---- */
        for (j = 0; j < COLS; j++) {
            int g = 0;
            g = mac3_custom(g, X[0][j], err[0]);
            g = mac3_custom(g, X[1][j], err[1]);
            g = mac3_custom(g, X[2][j], err[2]);
            g = mac3_custom(g, X[3][j], err[3]);
            g = mac3_custom(g, X[4][j], err[4]);
            g = mac3_custom(g, X[5][j], err[5]);
            g = mac3_custom(g, X[6][j], err[6]);
            g = mac3_custom(g, X[7][j], err[7]);
            grad[j] = g;
        }

        /* ---- Weight update: w[j] -= grad[j] >> LR_SHIFT ---- */
        for (j = 0; j < COLS; j++)
            w[j] -= (grad[j] >> LR_SHIFT);
    }

    return 0;
}
