#ifndef CUSTOM_OPS_H
#define CUSTOM_OPS_H

/*
 * Wrappers for custom CPU instructions (Phase 3/4).
 * Implemented in custom_ops.S using .word literal encoding.
 *
 *   mul_custom(a, b)  ->  (a * b)[31:0]          signed multiply
 *   mac_custom(a, b)  ->  a + (a * b)             multiply-accumulate
 *   relu_custom(a)    ->  (a < 0) ? 0 : a         rectified linear unit
 *   rdcyc()           ->  cycle_counter            free-running 32-bit counter
 *
 * Link with custom_ops.S:
 *   tools\build.bat already includes it automatically.
 */

extern int mul_custom(int a, int b);
extern int mac_custom(int a, int b);
extern int relu_custom(int a);
extern int rdcyc(void);

#endif /* CUSTOM_OPS_H */
