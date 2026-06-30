# Reference: Large/detailed SRU — rocblas 7.1.0 → 7.1.1

Use this as a model when there are multiple named upstream fixes with
identifiable symptoms, code paths, and per-fix regression risk.

---

## SRU ##

[ Impact ]

    rocblas 7.1.1 (librocblas5) fixes two correctness/performance regressions
    introduced in ROCm 7.0/7.1.0 on GPU compute workloads, and corrects several
    API implementation bugs:

    1. fp16/bf16 GEMV precision regression on MI200 (SWDEV-560127) — A ROCm 7.0
       optimisation incorrectly allowed half/bf16 input with fp32 output gemm_ex
       calls to use the 16-bit GEMV kernel. Because the 16-bit kernel performs
       accumulation in 16-bit arithmetic, cumulative rounding errors caused
       numerically incorrect results for any workload using
         hpa_half_in_single_out or hpa_bf16_in_single_out precision
       with rocblas_gemm_ex on gfx90a (MI200) and gfx942 targets.
       Fix: operands are now explicitly cast to the execution type (Tex) before
       multiplication inside rocblas_gemvt_kernel_calc and
       rocblas_gemvt_reduce_kernel_calc, restoring 32-bit precision.

    2. rocHPL multi-GPU performance regression from stream-order allocation
       default (SWDEV-558744) — ROCm 7.1.0 made hipMallocAsync/hipFreeAsync
       (stream-order allocation) the default memory scheme for rocBLAS handles.
       This caused 15%–47% throughput drops in rocHPL-MxP on 2-, 4-, and 8-GPU
       configurations. Stream-order allocation is now opt-in again via the
       environment variable ROCBLAS_STREAM_ORDER_ALLOC; the default reverts to
       hipMalloc/hipFree. This behaviour change is documented in the 7.1.1
       CHANGELOG entry. HIP graph capture (beta feature) now explicitly enables
       stream-order allocation internally for the duration of the capture window
       (client_utility.cpp), so it continues to work correctly when
       ROCBLAS_STREAM_ORDER_ALLOC is not set.

    3. rocblas_is_user_managing_device_memory was broken — In 7.1.0 the function
       body was hardcoded to `return false` regardless of handle state. It now
       correctly inspects device_memory_owner. Applications that relied on this
       function to detect user-managed memory were silently getting wrong results.

    4. rocblas_set_device_memory_size was a near-no-op — In 7.1.0 the function
       returned success without performing any allocation. It now actually
       allocates the requested size via hipMalloc and marks the handle as
       user_managed. A new "user_managed" ownership state is introduced alongside
       the existing "user_owned" (rocblas_set_workspace) scheme, with a
       ROCBLAS_REALLOC_ON_DEMAND=1 compile-time flag enabling on-demand
       reallocation for the rocblas_managed path.

    5. Deprecation message cleanup — rocblas_set_device_memory_size and
       rocblas_is_user_managing_device_memory had "[Do not use]" removed from
       their deprecation strings, signalling these APIs are being rehabilitated
       rather than removed.

    The 7.1.1 release also carries a documentation-only fix (logging environment
    variable include path and reference link corrections) with no runtime impact.

    Packaging fixes included in this upload (no user-visible behaviour change
    once installed; they only restore working build/test plumbing):

    a. Tensile kernel install path / runtime lookup mismatch — d/rules pinned
       the Tensile data install dir to a hardcoded internal version (5.1.0)
       while the runtime patch (move-tensile-library-into-versioned-subdir)
       derived its lookup path from upstream's ROCBLAS_VERSION_* macros.
       Upstream bumped VERSION_STRING from 5.1.0 to 5.1.1 in 7.1.1, so the
       install path and the runtime lookup path would drift apart on this
       upload. Symptom would be rocblas-test (and any consumer of librocblas)
       aborting at startup with
         "Cannot read /usr/lib/<multiarch>/rocblas/library/
          TensileLibrary.dat".
       Fix: install kernels at the unversioned
       /usr/lib/<multiarch>/rocblas/library so the runtime finds them via
       upstream's natural fallback path, drop the versioned-subdir patch
       entirely, and update the install/not-installed/lintian-override
       globs to match. This removes the version coupling that caused the
       drift in the first place.
    b. Build-time test could not find rocblas_gtest.data —
       Enable-changing-directory-for-test-data.patch had hard-replaced
       upstream's "look next to the test binary" lookup with a hardcoded
       INSTALL_TEST_DATA_DIR. dh_auto_test runs before dh_auto_install, so
       the file is not yet at the install path. Fix: prefer the install
       path, fall back to rocblas_exepath() when the file is not present
       there. Post-install behaviour is unchanged.
    c. d/rules: BUILD_CLIENTS_TESTS expansion emitted "ON ON" when both
       FEATURE_CHECK and FEATURE_INSTTEST were ON, which CMake parsed as a
       stray extra source path. Replaced $(or $(filter ON,...),OFF) with
       $(if ...) so the variable always expands to a single token.

    Items (b) and (c) only manifest when building on a host with /dev/kfd
    accessible (i.e. with an AMD GPU present). Launchpad's amd64 builders
    have no GPU, so override_dh_auto_test-arch is skipped there and the
    bugs were latent. They were uncovered while validating this upload on
    a gfx1151 (Strix Halo) developer machine.

    Reverse dependencies: librocblas-dev, libtorch-rocm-2.9,
    librocwmma-tests-validate, librocsolver0-tests, librocsolver0-bench,
    librocsolver0, librocblas5-tests, librocblas5-bench, libggml0-backend-hip,
    libmiopen1-tests, libmiopen1, libhipsolver1, libhipblas3.

  [ Test Plan ]

    1. Build:
       - sbuild or dpkg-buildpackage the package successfully.
       - Verify dpkg --compare-versions shows the new version is greater.
       - Run dpkg-gensymbols and confirm no symbols are added/removed/changed
         (the .symbols file should remain identical — SONAME remains
         librocblas.so.5).
       - On a host with an AMD GPU available (/dev/kfd readable), confirm
         override_dh_auto_test-arch runs the rocblas-test suite to
         completion. Locally verified on gfx1151 (Radeon 8060S / Strix
         Halo): 211778 tests across 196 suites, all PASSED.
    2. Installability:
       - apt install librocblas5.
       - Confirm reverse dependencies remain installable without rebuild.
       - Verify the Tensile data is at
           /usr/lib/x86_64-linux-gnu/rocblas/library/
         (no version subdirectory) and that
           dpkg -L librocblas5 | grep TensileLibrary
         lists the per-architecture .dat files.
    3. Run autopkgtest (librocblas5-tests) on a GPU-equipped testbed and
       confirm it passes. Output:

[ SKIPPED ] 4909 tests.
[ PASSED ] 1205568 tests.
[ FAILED ] 0 tests.
rocBLAS version: 5.1.1.07564667-dirty
rocBLAS-commit-hash:
Tensile-commit-hash:
hipBLASLt: N/A, as rocBLAS was built without hipBLASLt
command line: /usr/libexec/rocm/librocblas5-tests/rocblas-test
autopkgtest [18:26:12]: test librocblas5-tests: -----------------------]
autopkgtest [18:26:13]: test librocblas5-tests: - - - - - - - - - - results - - - - - - - - - -
librocblas5-tests PASS
autopkgtest [18:26:14]: @@@@@@@@@@@@@@@@@@@@ summary
librocblas5-tests PASS
2026-05-02 18:26:18 - Autopkg tests ended for rocblas.
Tests took: 1h 51m 59s.

  [ Where problems could occur ]

    1. Applications relying on stream-order allocation being the default
       (low risk, correctness neutral): Any application that depended on the
       ROCm 7.1.0 behaviour where rocBLAS_managed implicitly used
       hipMallocAsync may now observe different memory allocation timing.
       In practice this only matters for HIP graph capture, which the library
       now handles internally. Symptom: none expected for well-behaved apps;
       a graph capture that manually assumed stream-order alloc was active
       without the env var may need updating.
    2. rocblas_set_device_memory_size now triggers allocation (low risk):
       Applications that called this function expecting a no-op will now
       trigger a hipMalloc. Symptom: slightly higher memory usage at handle
       creation if the application calls rocblas_set_device_memory_size with
       a non-zero size before it is needed.
    3. rocblas_is_user_managing_device_memory returning true where it
       previously always returned false (low risk): Any application that
       worked around the broken return value by never checking it will be
       unaffected. Applications that did check it and coded logic around
       "always false" may behave differently. Symptom: unexpected branch
       taken in application code that queries memory ownership.
    4. GEMV precision fix kernel path change (very low risk): The explicit
       Tex() cast changes the instruction sequence in the GEMV transposed
       kernel. On architectures other than gfx90a/gfx942 the cast is a
       no-op so no behaviour change is expected. Symptom: none expected;
       a pre_checkin test failure would be the indicator.

  [ Other Info ]

   * No ABI/API breakage: the debian/librocblas5.symbols file is identical
     between 7.1.0 and 7.1.1. No symbols were added, removed, or changed.
     The SONAME remains librocblas.so.5.
   * Minor: example_solver_rocblas.cpp copyright year reverted 2025→2024 as
     a cherry-pick artefact; no functional impact.
   * Upstream comparison (rocBLAS changes):
     https://github.com/ROCm/rocblas/compare/rocm-7.1.0...rocm-7.1.1
   * Tensile: no changes between rocm-7.1.0 and rocm-7.1.1.
     https://github.com/ROCm/Tensile/compare/rocm-7.1.0...rocm-7.1.1
