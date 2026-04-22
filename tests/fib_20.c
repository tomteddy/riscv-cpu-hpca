/*
 * fib_20.c — iterative Fibonacci, fib(20) = 6765.
 *
 * Branch-heavy workload — good for stressing the BTB predictor.
 * The inner loop has a predictable backward branch that the BTB
 * should learn quickly, reducing mispredict penalty after warmup.
 *
 * No custom instructions; uses only RV32I base ISA.
 * Result stored in a global so the compiler cannot eliminate the loop.
 *
 * Compile:  tools\build.bat tests\fib_20.c
 */

int fib_result;

int main(void) {
    int n = 20;
    int a = 0, b = 1, i, tmp;
    for (i = 0; i < n; i++) {
        tmp = a + b;
        a = b;
        b = tmp;
    }
    fib_result = a;   /* fib(20) = 6765 */
    return 0;
}
