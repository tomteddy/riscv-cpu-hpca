// ============================================================
// smoke_add.c : minimal sanity test for the CPU + toolchain.
//   Computes a = 7 + 11 and stores it at the start of data
//   memory. Testbench checks dmem[0..3] == 0x12 (18 decimal).
// ============================================================

volatile int result;       // forces a store to .data (DMEM)

int main(void) {
    int a = 7;
    int b = 11;
    result = a + b;        // expected: 18 (0x12)
    return 0;
}
