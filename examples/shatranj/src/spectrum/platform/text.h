#ifndef NETCHESSZX_SPECTRUM_TEXT_H
#define NETCHESSZX_SPECTRUM_TEXT_H

#include <stdint.h>

#ifndef NETCHESSZX_CALLEE
#ifdef NETCHESSZX_SDCC_IY
#define NETCHESSZX_CALLEE __z88dk_callee
#else
#define NETCHESSZX_CALLEE
#endif
#endif

char *spectrum_append_text(char *dst, const char *src) NETCHESSZX_CALLEE;
char *spectrum_append_u16(char *dst, uint16_t value) NETCHESSZX_CALLEE;

#endif
