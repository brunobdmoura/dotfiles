# Reference: Small/minimal SRU — hipblas pure version bump

Use this as a model when the upstream change is a pure version bump with
no functional changes — no new fixes, no behaviour changes, no ABI delta.

---

## SRU ##

[ Impact ]

 * This update simply bumps the library version without adding any changes to the source code, which means there is no real impact to be considered.

[ Test Plan ]

 * Due to it simply being a version bump with no changes on the source code, the easiest way to check whether this update actually introduces no breaking changes is to present the result of the autopkgtests for the library:

   ```
   [----------] Global test environment tear-down
   [==========] 47216 tests from 207 test suites ran. (153029 ms total)
   [ PASSED ] 47216 tests.
   hipBLAS version 3.1.0.
   command line: /usr/libexec/rocm/libhipblas3-tests/hipblas-test
   autopkgtest [13:21:25]: test command1: -----------------------]
   autopkgtest [13:21:25]: test command1: - - - - - - - - - - results - - - - - - - - - -
   command1 PASS
   autopkgtest [13:21:26]: @@@@@@@@@@@@@@@@@@@@ summary
   command1 PASS
   2026-05-05 13:21:28 - Autopkg tests ended for hipblas in ppa:bullwinkle team/rocm-exp-21.
   Tests took: 0h 13m 14s. Logs saved in ./hipblas_20260505_130814.log
   ```

[ Where problems could occur ]

 * In this case, due to no changes being added to the source code, the only problems that could occur would be related to eventual LP builders unavailability and general infrastructure issues, but none of them related to the library usage itself.

[ Other Info ]

 * This update is part of the coordinated ROCm stack release to bump all of its parts to version 7.1.1 after their initial 7.1.0 packaging.

 * PPA: https://launchpad.net/~bullwinkle-team/+archive/ubuntu/rocm-exp-21/+packages

 * Upstream version comparison: https://github.com/ROCm/hipblas/compare/rocm-7.1.0...rocm-7.1.1
