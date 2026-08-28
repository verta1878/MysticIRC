/*
 * riplib_version.c — Runtime version accessor for RIPlib.
 *
 * The macro definitions live in include/riplib_version.h and are
 * hand-maintained in lockstep with CMakeLists.txt's project() version.
 *
 * Copyright (c) 2026 SimVU (Brad Hawthorne)
 * Licensed under the MIT License.  See LICENSE.
 */

#include "riplib_version.h"

const char *riplib_version_string(void) {
    return RIPLIB_VERSION_STRING;
}
