/*
 * riplib_version.h — Compile-time and runtime version identification for RIPlib.
 *
 * Consumers can rely on the RIPLIB_VERSION_* macros for conditional
 * compilation against specific RIPlib versions, and on the runtime
 * accessor `riplib_version_string()` for runtime version logging.
 *
 * RIPLIB_VERSION_INT exposes a packed integer (major * 10000 + minor * 100
 * + patch) for ordered comparisons:
 *   #if RIPLIB_VERSION_INT >= 20000
 *       // code that requires v2.0.0 or newer
 *   #endif
 *
 * NOTE: these macros are hand-maintained.  At release time they MUST be
 * updated in lockstep with the `project(... VERSION ...)` line in the
 * top-level CMakeLists.txt.  The CMake build asserts they match at
 * configure time and fails loudly on mismatch.
 *
 * Copyright (c) 2026 SimVU (Brad Hawthorne)
 * Licensed under the MIT License.  See LICENSE.
 */

#pragma once

#define RIPLIB_VERSION_MAJOR  2
#define RIPLIB_VERSION_MINOR  0
#define RIPLIB_VERSION_PATCH  1

#define RIPLIB_VERSION_STRING "2.0.1"

#define RIPLIB_VERSION_INT \
    (RIPLIB_VERSION_MAJOR * 10000 + RIPLIB_VERSION_MINOR * 100 + RIPLIB_VERSION_PATCH)

/* Runtime accessor — returns the same literal as RIPLIB_VERSION_STRING.
 * Useful when the consuming application links against a different RIPlib
 * build than it was compiled with (e.g. shared-library scenarios), and as
 * a generic "what version is this?" reflection hook for diagnostics. */
#ifdef __cplusplus
extern "C" {
#endif

const char *riplib_version_string(void);

#ifdef __cplusplus
}
#endif
