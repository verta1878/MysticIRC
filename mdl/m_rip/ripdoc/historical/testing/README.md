# Testing Documentation

All test procedures, results, and how-to guides for reproducing tests.

## Test Files

| File | What it tests |
|------|--------------|
| RIP-TEST-RESULTS.md | RIPview pixel comparison (35 runs, 13 test files) |
| MTERM-TEST-RESULTS.md | mterm RIP engine smoke tests |
| COMPILE-TESTS.md | Compilation verification across all units |
| ANSIEDIT-TESTS.md | ansiedit feature testing (planned) |
| PDNET-TESTS.md | PabloDraw protocol testing (planned) |
| SERIAL-TESTS.md | DOS serial/FOSSIL testing (planned) |

## Testing Philosophy

- Code once, test three times
- Document every test so it can be reproduced
- Save test results with dates
- Test on target platform (DOSBox for DOS, Linux for production)
- Verify before adding more features
