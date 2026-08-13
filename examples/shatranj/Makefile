CC ?= gcc
CFLAGS ?= -std=c99 -Wall -Wextra -Werror -pedantic -Isrc
BUILD_DIR := build
RELEASE_DIR := release
# Relative path from inside $(BUILD_DIR) back to the repo root; recipes
# cd into $(BUILD_DIR), which may be nested (e.g. build/nex).
empty :=
space := $(empty) $(empty)
BUILD_DIR_UP := $(subst $(space),,$(patsubst %,../,$(subst /, ,$(BUILD_DIR))))
ZCC ?= zcc
Z80ASM ?= z80asm
POWERSHELL ?= pwsh
PYTHON ?= python3
CMAKE ?= cmake
CTEST ?= ctest
MACDEPLOYQT ?= macdeployqt
CODESIGN ?= codesign
DITTO ?= ditto
QTPATHS ?= qtpaths6
ZX_EXTRA_CFLAGS ?=
CLIENT_BUILD ?= auto
CLIENT_CMAKE_BUILD_DIR ?= $(BUILD_DIR)/qt-client
CLIENT_CMAKE_CONFIG ?= Release
CLIENT_CMAKE_ARGS ?=
CLIENT_MSVC_QT_DIR ?= C:\Qt\6.11.0\msvc2022_64
CLIENT_MSVC_GENERATOR ?= Visual Studio 17 2022
CLIENT_MSVC_ARCH ?= x64
CLIENT_MSVC_CONFIG ?= Release
CLIENT_MSVC_DEPLOY_TIMEOUT ?= 120
CLIENT_MSVC_CLEAN_TIMEOUT ?= 30
CLIENT_MAC_APPLICATIONS_DIR ?= /Applications
HOST_UNAME := $(shell uname -s 2>/dev/null || echo unknown)
CLIENT_HOST_IS_WINDOWS := $(if $(filter Windows_NT,$(OS)),1,$(if $(COMSPEC),1,$(if $(ComSpec),1,$(if $(filter MINGW% MSYS% CYGWIN%,$(HOST_UNAME)),1,))))
HOST_GC_CFLAGS := -ffunction-sections -fdata-sections
HOST_GC_LDFLAGS := -Wl,--gc-sections
ifeq ($(HOST_UNAME),Darwin)
HOST_GC_LDFLAGS := -Wl,-dead_strip
endif

PORT ?= 5000
MQTT_HOST ?= broker.hivemq.com
MQTT_PORT ?= 1883
MQTT_CODE ?= DEVROOM
ZX_NAME := SHATRANJ
APP_VERSION := $(strip $(shell cat VERSION))
ZX_ORG := 28672
ASSET_ASM := assets/spectrum/ui_runtime_assets.asm
ABOUT_BOARD := assets/spectrum/about_board.bin
SPECTRUM_SRC := src/spectrum/app/app.c \
                src/spectrum/app/net_runtime.c \
                src/spectrum/config/session.c \
                src/common/chess/move_coords.c \
                src/common/protocol/game_protocol.c \
                src/common/protocol/game_protocol_extra.c \
                src/common/protocol/direct_session_protocol.c \
                src/common/protocol/mqtt_session_protocol.c \
                src/spectrum/session/direct.c \
                src/spectrum/session/event.c \
                src/spectrum/session/mqtt.c \
                src/spectrum/session/outgoing.c \
                src/spectrum/session/ping.c \
                src/spectrum/session/poll.c \
                src/spectrum/platform/platform.c \
                src/spectrum/transport/esp_at.c \
                src/spectrum/transport/keepalive_protocol.c \
                src/spectrum/transport/net.c \
                src/spectrum/transport/mqtt_session_wire.c \
                src/spectrum/transport/mqtt_min.c \
                src/spectrum/board/board.c \
                src/spectrum/board/san.c \
                src/spectrum/saveload/saveload.c \
                src/spectrum/fileui/fileui.c \
                src/spectrum/restore/restore.c \
                src/spectrum/ui/gui.c \
                src/spectrum/overlay/overlay.c
PIECE_ASM := assets/spectrum/chess_pieces_16x16.asm

RULES_TEST := $(BUILD_DIR)/netchesszx_rules_test.exe
RULES_TEST_SRC := src/common/chess/position.c src/common/chess/legal.c \
                  src/common/chess/rules_compact.c tests/rules/test_fen.c
MOVE_COORDS_TEST := $(BUILD_DIR)/netchesszx_move_coords_test.exe
MOVE_COORDS_TEST_SRC := src/common/chess/move_coords.c tests/common/test_move_coords.c
SAVEGAME_WIRE_TEST := $(BUILD_DIR)/netchesszx_savegame_wire_test.exe
SAVEGAME_WIRE_TEST_SRC := src/common/savegame/savegame_wire.c \
                          src/spectrum/overlay/restore_ovl.c \
                          tests/common/test_savegame_wire.c
BOARD_TEST := $(BUILD_DIR)/netchesszx_spectrum_board_test.exe
BOARD_TEST_SRC := src/common/chess/move_coords.c \
                  src/spectrum/board/board.c src/spectrum/board/san.c \
                  src/common/chess/rules_compact.c \
                  src/common/chess/legal.c tests/spectrum/test_board.c
RULES_COMPACT_PERFT_TEST := $(BUILD_DIR)/netchesszx_rules_compact_perft_test.exe
RULES_COMPACT_PERFT_TEST_SRC := src/common/chess/move_coords.c \
                                src/spectrum/board/board.c \
                                src/common/chess/rules_compact.c \
                                tests/spectrum/test_rules_compact_perft.c
MQTT_TEST := $(BUILD_DIR)/netchesszx_mqtt_test.exe
MQTT_TEST_SRC := src/common/mqtt/mqtt.c src/spectrum/transport/mqtt_min.c \
                 tests/net/test_mqtt.c
MQTT_STREAM_TEST := $(BUILD_DIR)/netchesszx_mqtt_stream_test.exe
MQTT_STREAM_TEST_SRC := tests/spectrum/test_mqtt_stream.c
GAME_PROTOCOL_TEST := $(BUILD_DIR)/netchesszx_game_protocol_test.exe
GAME_PROTOCOL_TEST_SRC := src/common/protocol/game_protocol.c \
                           src/common/protocol/game_protocol_extra.c \
                           src/common/protocol/game_protocol_format.c \
                           tests/net/test_game_protocol.c
ESP_AT_TEST := $(BUILD_DIR)/netchesszx_esp_at_test.exe
ESP_AT_NEXT_TEST := $(BUILD_DIR)/netchesszx_esp_at_next_test.exe
ESP_AT_TEST_SRC := src/spectrum/transport/esp_at.c src/common/protocol/game_protocol.c tests/net/test_esp_at.c
UART_PLATFORM_TEST := $(BUILD_DIR)/netchesszx_uart_platform_test.exe
UART_PLATFORM_TEST_SRC := src/spectrum/platform/platform.c tests/spectrum/test_uart_platform.c
DIRECT_IPD_TEST := $(BUILD_DIR)/netchesszx_direct_ipd_test.exe
DIRECT_IPD_TEST_SRC := tests/spectrum/test_direct_ipd.c \
                       tests/spectrum/text_asm_host.c
MQTT_SESSION_PROTOCOL_TEST := $(BUILD_DIR)/netchesszx_mqtt_session_protocol_test.exe
MQTT_SESSION_PROTOCOL_TEST_SRC := src/common/protocol/mqtt_session_protocol.c \
                                  src/common/protocol/mqtt_session_protocol_format.c \
                                  tests/net/test_mqtt_session_protocol.c
DIRECT_SESSION_PROTOCOL_TEST := $(BUILD_DIR)/netchesszx_direct_session_protocol_test.exe
DIRECT_SESSION_PROTOCOL_TEST_SRC := src/common/protocol/direct_session_protocol.c \
                                    src/common/protocol/game_protocol.c \
                                    tests/net/test_direct_session_protocol.c
SESSION_CORE_TEST := $(BUILD_DIR)/netchesszx_session_core_test.exe
SESSION_CORE_TEST_SRC := src/common/session/session.c \
                         src/common/session/mqtt_session.c \
                         src/common/protocol/game_protocol.c \
                         src/common/protocol/game_protocol_extra.c \
                         src/common/protocol/game_protocol_format.c \
                         src/common/protocol/mqtt_session_protocol.c \
                         src/common/protocol/mqtt_session_protocol_format.c \
                         tests/session/test_session_core.c
SESSION_DIRECT_CORE_TEST := $(BUILD_DIR)/netchesszx_session_direct_core_test.exe
SESSION_DIRECT_CORE_TEST_SRC := src/common/session/session.c \
                                src/common/session/direct_session.c \
                                src/common/session/mqtt_session.c \
                                src/common/protocol/mqtt_session_protocol.c \
                                src/common/protocol/mqtt_session_protocol_format.c \
                                src/common/protocol/direct_session_protocol.c \
                                src/common/protocol/game_protocol.c \
                                src/common/protocol/game_protocol_extra.c \
                                src/common/protocol/game_protocol_format.c \
                                tests/session/test_direct_session_core.c
SESSION_MQTT_PARITY_TEST := $(BUILD_DIR)/netchesszx_mqtt_session_parity_test.exe
SESSION_MQTT_PARITY_TEST_SRC := src/common/session/session.c \
                                   src/common/session/mqtt_session.c \
                                   tests/session/test_mqtt_session_parity.c \
                                  tests/session/mqtt_session_transcripts.c \
                                  tests/spectrum/text_asm_host.c \
                                  src/common/chess/move_coords.c \
                                  src/common/chess/legal.c \
                                  src/common/protocol/direct_session_protocol.c \
                                  src/common/protocol/game_protocol.c \
                                  src/common/protocol/game_protocol_extra.c \
                                  src/common/protocol/game_protocol_format.c \
                                  src/common/protocol/mqtt_session_protocol.c \
                                  src/common/protocol/mqtt_session_protocol_format.c \
                                  src/spectrum/config/session.c \
                                  src/spectrum/session/direct.c \
                                  src/spectrum/session/event.c \
                                  src/spectrum/overlay/control_ovl.c \
                                  src/spectrum/session/mqtt.c \
                                  src/spectrum/session/outgoing.c \
                                  src/spectrum/session/ping.c \
                                  src/spectrum/session/poll.c \
                                  src/spectrum/transport/keepalive_protocol.c \
                                  src/spectrum/transport/mqtt_session_wire.c \
                                  src/spectrum/overlay/restore_ovl.c \
                                  src/spectrum/board/board.c \
                                  src/spectrum/board/san.c \
                                  src/common/chess/rules_compact.c
SESSION_DIRECT_PARITY_TEST := $(BUILD_DIR)/netchesszx_direct_session_parity_test.exe
SESSION_DIRECT_PARITY_NEXT_TEST := $(BUILD_DIR)/netchesszx_direct_session_parity_next_test.exe
SESSION_DIRECT_PARITY_TEST_SRC := tests/session/test_direct_session_parity.c \
                                  tests/session/direct_reference_runner.c \
                                  tests/spectrum/text_asm_host.c \
                                  src/common/session/session.c \
                                  src/common/session/direct_session.c \
                                  src/common/session/mqtt_session.c \
                                  src/common/chess/move_coords.c \
                                  src/common/chess/legal.c \
                                  src/common/protocol/direct_session_protocol.c \
                                  src/common/protocol/mqtt_session_protocol_format.c \
                                  src/common/protocol/game_protocol.c \
                                  src/common/protocol/game_protocol_extra.c \
                                  src/common/protocol/game_protocol_format.c \
                                  src/common/protocol/mqtt_session_protocol.c \
                                  src/spectrum/config/session.c \
                                  src/spectrum/session/direct.c \
                                  src/spectrum/session/event.c \
                                  src/spectrum/overlay/control_ovl.c \
                                  src/spectrum/session/mqtt.c \
                                  src/spectrum/session/outgoing.c \
                                  src/spectrum/session/ping.c \
                                  src/spectrum/session/poll.c \
                                  src/spectrum/transport/keepalive_protocol.c \
                                  src/spectrum/overlay/restore_ovl.c \
                                  src/spectrum/board/board.c \
                                  src/spectrum/board/san.c \
                                  src/common/chess/rules_compact.c
KEEPALIVE_PROTOCOL_TEST := $(BUILD_DIR)/netchesszx_keepalive_protocol_test.exe
KEEPALIVE_PROTOCOL_TEST_SRC := src/spectrum/transport/keepalive_protocol.c \
                               src/common/protocol/game_protocol.c \
                               tests/net/test_keepalive_protocol.c
SESSION_CONFIG_TEST := $(BUILD_DIR)/netchesszx_session_config_test.exe
SESSION_CONFIG_TEST_SRC := src/spectrum/config/session.c \
                           src/common/protocol/game_protocol.c \
                           tests/spectrum/test_session_config.c
SESSION_PING_TEST := $(BUILD_DIR)/netchesszx_session_ping_test.exe
SESSION_PING_TEST_SRC := src/spectrum/session/ping.c tests/spectrum/test_session_ping.c
SESSION_PING_NEXT_TEST := $(BUILD_DIR)/netchesszx_session_ping_next_test.exe
SESSION_POLL_TEST := $(BUILD_DIR)/netchesszx_session_poll_test.exe
SESSION_POLL_TEST_SRC := src/spectrum/config/session.c \
                          src/common/protocol/direct_session_protocol.c \
                          src/common/protocol/game_protocol.c \
                          src/common/protocol/game_protocol_extra.c \
                          src/common/protocol/mqtt_session_protocol.c \
                         src/spectrum/transport/keepalive_protocol.c \
                         src/spectrum/session/mqtt.c src/spectrum/session/event.c \
                         src/spectrum/overlay/control_ovl.c \
                         src/spectrum/session/ping.c src/spectrum/session/poll.c \
                         tests/spectrum/test_session_poll.c
SESSION_DIRECT_TEST := $(BUILD_DIR)/netchesszx_session_direct_test.exe
SESSION_DIRECT_TEST_SRC := src/spectrum/config/session.c \
                            src/common/protocol/direct_session_protocol.c \
                            src/common/protocol/game_protocol.c \
                            src/spectrum/session/direct.c \
                            tests/spectrum/test_session_direct.c
SESSION_EVENT_TEST := $(BUILD_DIR)/netchesszx_session_event_test.exe
SESSION_EVENT_TEST_SRC := src/spectrum/config/session.c \
                           src/common/protocol/direct_session_protocol.c \
                           src/common/protocol/game_protocol.c \
                           src/common/protocol/game_protocol_extra.c \
                           src/common/protocol/mqtt_session_protocol.c \
                          src/spectrum/transport/keepalive_protocol.c \
                          src/spectrum/session/mqtt.c src/spectrum/session/event.c \
                          src/spectrum/overlay/control_ovl.c \
                          tests/spectrum/test_session_event.c
SESSION_MQTT_TEST := $(BUILD_DIR)/netchesszx_session_mqtt_test.exe
SESSION_MQTT_TEST_SRC := src/spectrum/config/session.c \
                         src/common/protocol/game_protocol.c \
                         src/common/protocol/mqtt_session_protocol.c \
                         src/spectrum/session/mqtt.c \
                         tests/spectrum/test_session_mqtt.c
SESSION_SPECTRUM_PAIR_TEST := $(BUILD_DIR)/netchesszx_session_spectrum_pair_test.exe
SESSION_SPECTRUM_PAIR_TEST_SRC := src/spectrum/config/session.c \
                                  src/common/protocol/direct_session_protocol.c \
                                  src/common/protocol/game_protocol.c \
                                  src/common/protocol/mqtt_session_protocol.c \
                                  src/common/protocol/mqtt_session_protocol_format.c \
                                  src/spectrum/session/direct.c \
                                  src/spectrum/session/mqtt.c \
                                  tests/spectrum/test_session_spectrum_pair.c
SESSION_OUTGOING_TEST := $(BUILD_DIR)/netchesszx_session_outgoing_test.exe
SESSION_OUTGOING_TEST_SRC := src/common/protocol/game_protocol.c \
                             src/spectrum/config/session.c \
                             src/spectrum/session/outgoing.c \
                             tests/spectrum/text_asm_host.c \
                             tests/spectrum/test_session_outgoing.c
ZX_TAP := $(RELEASE_DIR)/$(ZX_NAME).tap
ZX_OVL := $(RELEASE_DIR)/$(ZX_NAME).OVL
ZX_DAT := $(RELEASE_DIR)/$(ZX_NAME).DAT
BUILD_DAT := $(BUILD_DIR)/$(ZX_NAME).DAT
OVL_DEFS := $(BUILD_DIR)/overlay_defs.asm
OVL_ATLAS_TABLE := $(BUILD_DIR)/overlay_atlas_table.asm
ABI_MANIFEST := $(BUILD_DIR)/abi_manifest.json
ABI_BASELINE := docs/abi_manifest.baseline.json
NEXT_ABI_MANIFEST = $(NEXT_NEX_BUILD_DIR)/abi_manifest.json
NEXT_ABI_BASELINE := docs/abi_manifest.next.baseline.json
ABI_HEADERS := src/spectrum/overlay/overlay_api.h \
               src/spectrum/overlay/overlay_context.h \
               src/spectrum/overlay/overlay.h \
               src/spectrum/ui/info_panel.h \
               src/spectrum/render_status.h \
               src/spectrum/lowram_map.h \
               src/common/session/session.h
SIZE_REPORT := $(BUILD_DIR)/size_report.json
SIZE_BASELINE := docs/size_report.baseline.json
LITERAL_REPORT := $(BUILD_DIR)/literal_report.json
ZX_BUILD_LOG := $(BUILD_DIR)/$(ZX_NAME).build.log

ZX_TARGET_CFLAGS ?=
UART_BACKEND ?= divmmc
ifeq ($(UART_BACKEND),next)
DAT_PLATFORM_FLAG := --next
else
DAT_PLATFORM_FLAG :=
endif
UART_ASM := asm/uart/$(UART_BACKEND)_uart.asm
SCREEN_ASM ?= asm/spectrum/screen.asm
OVERLAY_LOADER_ASM ?= asm/esxdos/overlay_loader.asm
SHRINK_ASM := asm/spectrum/shrink_kernels.asm
ESX_COMMON_ASM := asm/esxdos/esx_fileio_spectalk.asm
ESX_FILEUI_ASM := asm/esxdos/esx_fileui.asm
ESX_SAVELOAD_ASM := asm/esxdos/esx_saveload.asm

NEXT_OVERLAY_LOADER_ASM := asm/next/overlay_loader_next.asm
NEXT_GRAPHICS_BANK_ASM := asm/next/graphics_bank_next.asm
NEXT_GRAPHICS_BANK_LAYOUT := asm/next/graphics_bank_layout.asm
NEXT_NEX_BUILD_DIR := $(BUILD_DIR)/nex
NEXT_NEX_STAGE_DIR := $(NEXT_NEX_BUILD_DIR)/stage
NEXT_NEX_RELEASE_DIR := release/Next
NEXT_SIZE_REPORT := $(NEXT_NEX_BUILD_DIR)/size_report.json
NEXT_GRAPHICS_BANK_DEFS := $(NEXT_NEX_BUILD_DIR)/next_graphics_defs.asm
NEXT_GRAPHICS_BANK_OBJ := $(NEXT_NEX_BUILD_DIR)/asm/next/graphics_bank_next.o
NEXT_GRAPHICS_BANK_BIN := $(NEXT_NEX_BUILD_DIR)/SHATRANJ_GRAPHICS.BIN
NEXT_GRAPHICS_BANK_ORG := 0x0200
NEXT_GRAPHICS_BANK_OFFSET := 57856
NEXT_GRAPHICS_BANK_LIMIT := 7680
NEXT_ZX0 ?= z88dk-zx0
NEXT_BUNDLE_BANK_BASE := 8
NEXT_RAW_BANK_BASE := 16
NEXT_MAX_BUNDLE_BANKS := 3
NEXT_BUNDLE_DAT_OFFSET := 32768
NEXT_SPRITE_BIN := assets/next/lichess_piece_sprites.bin
NEXT_SPRITE_PALETTE_ASM := assets/next/lichess_sprite_palette.asm
NEXT_SPRITE_PAL_BIN := assets/next/lichess_sprite_palette.bin
NEXT_SPRITE_META := assets/next/lichess_piece_sprites.json
NEXT_SPRITE_OFFSET := 40960
NEXT_SPRITE_PAL_OFFSET := 53760
NEXT_ABOUT_NXI_SRC := assets/next/about_screen.nxi
NEXT_ABOUT_NXI := $(NEXT_NEX_BUILD_DIR)/about_screen_baked.nxi
NEXT_ABOUT_PAL_OFFSET := 57344
NEXT_ABOUT_PIXELS_OFFSET := 65536
ZX_NEX := $(NEXT_NEX_RELEASE_DIR)/$(ZX_NAME).nex

ZX_CLIB := sdcc_iy
ZX_ASMFLAGS := -DNETCHESSZX_SDCC_IY
# The .nex banking build (Next loader) also flags standalone-assembled ASM
# (overlays) so IFDEF NETCHESSZX_NEXT picks the Next variants there too.
ifeq ($(OVERLAY_LOADER_ASM),$(NEXT_OVERLAY_LOADER_ASM))
ZX_ASMFLAGS += -DNETCHESSZX_NEXT
endif
ZX_SDCC_CFLAGS := -compiler=sdcc -Cs--no-reg-params --opt-code-size --fomit-frame-pointer \
                  -DNETCHESSZX_SDCC_IY \
                  -Ca$(ZX_ASMFLAGS)
ZX_LDFLAGS := -Wl,--gc-sections
ZX_Z80ASM := $(Z80ASM) $(ZX_ASMFLAGS)

ZX_CFLAGS := -vn -startup=31 -clib=$(ZX_CLIB) -SO3 -m \
             -custom-copt-rules=$(BUILD_DIR_UP)tools/netchesszx_bool_copt \
             $(ZX_SDCC_CFLAGS) \
             -Ca-I$(patsubst %/,%,$(BUILD_DIR_UP)) \
             -I$(BUILD_DIR_UP)src \
             -pragma-define:CLIB_MALLOC_HEAP_SIZE=0 \
             -pragma-define:CLIB_STDIO_HEAP_SIZE=0 \
             -pragma-define:CRT_ENABLE_STDIO=0 \
             -pragma-define:CRT_ENABLE_EIDI=0 \
             -pragma-define:CRT_STACK_SIZE=512 \
              -DNETCHESSZX_FIXED_LOW_RAM \
             -zorg=$(ZX_ORG) \
             -DNETCHESSZX_PORT=$(PORT) \
             -DNETCHESSZX_MQTT_HOST_TOKEN=$(MQTT_HOST) \
             -DNETCHESSZX_MQTT_PORT=$(MQTT_PORT) \
             -DNETCHESSZX_MQTT_CODE_TOKEN=$(MQTT_CODE) \
              $(ZX_LDFLAGS) \
              $(ZX_EXTRA_CFLAGS) \
              $(ZX_TARGET_CFLAGS)
ZX_OVL_CFLAGS := -vn -clib=$(ZX_CLIB) -SO3 -m \
                  $(ZX_SDCC_CFLAGS) \
                  -I$(BUILD_DIR_UP)src \
                -DNETCHESSZX_FIXED_LOW_RAM \
                  $(ZX_EXTRA_CFLAGS) \
                  $(ZX_TARGET_CFLAGS)
MQTT_CONNECT_OVL_CFLAGS := -DNETCHESSZX_MQTT_PORT=$(MQTT_PORT)

.NOTPARALLEL:

.PHONY: all check full-check module-guards layering-check layering-report overlay-cap-check overlay-cap-report overlay-entry-abi-check transport-contract-check mqtt-client-id-check pc-direct-policy-check pc-policy-guard spectrum-direct-policy-check session-boundaries-check test session-core-test session-mqtt-parity-test session-direct-core-test session-direct-parity-test rules-oracle session-spectrum-pair-test tap tap-direct-overlay tap-divmmc tap-next next nex nex-size-report sdcc-iy-contract-check abi-manifest abi-next-manifest abi-baseline abi-next-baseline abi-check abi-next-check size-report size-baseline size-check literal-report client qt-client pc-client mac-client client-msvc client-cmake clean clean-spectrum clean-client FORCE

all: check clean test tap nex client

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(RULES_TEST): $(RULES_TEST_SRC) src/common/chess/position.h src/common/chess/legal.h src/common/chess/rules_compact.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(RULES_TEST_SRC) -o $@

$(MOVE_COORDS_TEST): $(MOVE_COORDS_TEST_SRC) src/common/chess/move_coords.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(MOVE_COORDS_TEST_SRC) -o $@

$(SAVEGAME_WIRE_TEST): $(SAVEGAME_WIRE_TEST_SRC) src/common/savegame/savegame_wire.h src/common/savegame/savegame_format.h src/spectrum/restore/restore.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) -DNETCHESSZX_HOST_TEST -D__z88dk_fastcall= \
		$(SAVEGAME_WIRE_TEST_SRC) -o $@

$(BOARD_TEST): $(BOARD_TEST_SRC) src/spectrum/board/board.h src/spectrum/board/san.h src/common/chess/rules_compact.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) -DNETCHESSZX_HOST_TEST $(BOARD_TEST_SRC) -o $@

$(RULES_COMPACT_PERFT_TEST): $(RULES_COMPACT_PERFT_TEST_SRC) src/spectrum/board/board.h src/common/chess/rules_compact.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) -DNETCHESSZX_HOST_TEST $(RULES_COMPACT_PERFT_TEST_SRC) -o $@

$(MQTT_TEST): $(MQTT_TEST_SRC) src/common/mqtt/mqtt.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(MQTT_TEST_SRC) -o $@

$(MQTT_STREAM_TEST): $(MQTT_STREAM_TEST_SRC) src/spectrum/transport/net.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -Wno-pointer-to-int-cast -DNETCHESSZX_HOST_TEST -D__z88dk_fastcall= \
		$(HOST_GC_CFLAGS) $(MQTT_STREAM_TEST_SRC) $(HOST_GC_LDFLAGS) -o $@


$(GAME_PROTOCOL_TEST): $(GAME_PROTOCOL_TEST_SRC) src/common/protocol/game_protocol.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(GAME_PROTOCOL_TEST_SRC) -o $@

$(ESP_AT_TEST): $(ESP_AT_TEST_SRC) src/spectrum/transport/esp_at.h src/spectrum/platform/net_runtime.h src/spectrum/platform/uart.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) -DNETCHESSZX_HOST_TEST $(ESP_AT_TEST_SRC) -o $@

$(ESP_AT_NEXT_TEST): $(ESP_AT_TEST_SRC) src/spectrum/transport/esp_at.h src/spectrum/platform/net_runtime.h src/spectrum/platform/uart.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) -Wno-unused-function -DNETCHESSZX_HOST_TEST -DNETCHESSZX_NEXT $(ESP_AT_TEST_SRC) -o $@

$(UART_PLATFORM_TEST): $(UART_PLATFORM_TEST_SRC) src/spectrum/platform/uart.h src/spectrum/lowram_map.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) -DNETCHESSZX_HOST_TEST $(UART_PLATFORM_TEST_SRC) -o $@

$(DIRECT_IPD_TEST): $(DIRECT_IPD_TEST_SRC) src/spectrum/overlay/direct_ovl.c src/spectrum/overlay/overlay_api.h src/spectrum/transport/net.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) -DNETCHESSZX_HOST_TEST -D__z88dk_fastcall= $(DIRECT_IPD_TEST_SRC) -o $@

$(MQTT_SESSION_PROTOCOL_TEST): $(MQTT_SESSION_PROTOCOL_TEST_SRC) src/common/protocol/mqtt_session_protocol.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(MQTT_SESSION_PROTOCOL_TEST_SRC) -o $@

$(DIRECT_SESSION_PROTOCOL_TEST): $(DIRECT_SESSION_PROTOCOL_TEST_SRC) src/common/protocol/direct_session_protocol.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(DIRECT_SESSION_PROTOCOL_TEST_SRC) -o $@

$(SESSION_CORE_TEST): $(SESSION_CORE_TEST_SRC) src/common/session/session.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(SESSION_CORE_TEST_SRC) -o $@

session-core-test: $(SESSION_CORE_TEST)
	./$(SESSION_CORE_TEST)

$(SESSION_MQTT_PARITY_TEST): $(SESSION_MQTT_PARITY_TEST_SRC) tests/session/mqtt_session_transcripts.h src/spectrum/app/app.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -DNETCHESSZX_HOST_TEST -DNETCHESSZX_HOST_SESSION_TEST \
		-D__z88dk_fastcall= $(HOST_GC_CFLAGS) \
		$(SESSION_MQTT_PARITY_TEST_SRC) $(HOST_GC_LDFLAGS) -o $@

session-mqtt-parity-test: $(SESSION_MQTT_PARITY_TEST)
	./$(SESSION_MQTT_PARITY_TEST)

$(SESSION_DIRECT_CORE_TEST): $(SESSION_DIRECT_CORE_TEST_SRC) src/common/session/session.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(SESSION_DIRECT_CORE_TEST_SRC) -o $@

session-direct-core-test: $(SESSION_DIRECT_CORE_TEST)
	./$(SESSION_DIRECT_CORE_TEST)

$(SESSION_DIRECT_PARITY_TEST): $(SESSION_DIRECT_PARITY_TEST_SRC) tests/session/direct_parity.h src/spectrum/app/app.c src/spectrum/overlay/direct_ovl.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -DNETCHESSZX_HOST_TEST -DNETCHESSZX_HOST_SESSION_TEST \
		-D__z88dk_fastcall= $(HOST_GC_CFLAGS) \
		$(SESSION_DIRECT_PARITY_TEST_SRC) $(HOST_GC_LDFLAGS) -o $@

$(SESSION_DIRECT_PARITY_NEXT_TEST): $(SESSION_DIRECT_PARITY_TEST_SRC) tests/session/direct_parity.h src/spectrum/app/app.c src/spectrum/overlay/direct_ovl.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -DNETCHESSZX_HOST_TEST -DNETCHESSZX_HOST_SESSION_TEST \
		-DNETCHESSZX_NEXT -DNETCHESSZX_NEXT_BANKING \
		-D__z88dk_fastcall= $(HOST_GC_CFLAGS) \
		$(SESSION_DIRECT_PARITY_TEST_SRC) $(HOST_GC_LDFLAGS) -o $@

session-direct-parity-test: $(SESSION_DIRECT_PARITY_TEST)
	./$(SESSION_DIRECT_PARITY_TEST)

$(KEEPALIVE_PROTOCOL_TEST): $(KEEPALIVE_PROTOCOL_TEST_SRC) src/spectrum/transport/keepalive_protocol.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(KEEPALIVE_PROTOCOL_TEST_SRC) -o $@

$(SESSION_CONFIG_TEST): $(SESSION_CONFIG_TEST_SRC) src/spectrum/config/session.h src/spectrum/transport/net.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(SESSION_CONFIG_TEST_SRC) -o $@

$(SESSION_PING_TEST): $(SESSION_PING_TEST_SRC) src/spectrum/session/ping.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(SESSION_PING_TEST_SRC) -o $@

$(SESSION_PING_NEXT_TEST): $(SESSION_PING_TEST_SRC) src/spectrum/session/ping.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) -DNETCHESSZX_NEXT $(SESSION_PING_TEST_SRC) -o $@

$(SESSION_POLL_TEST): $(SESSION_POLL_TEST_SRC) src/spectrum/config/session.h src/spectrum/session/poll.h src/spectrum/session/ping.h src/spectrum/session/event.h src/spectrum/transport/link.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(SESSION_POLL_TEST_SRC) -o $@

$(SESSION_DIRECT_TEST): $(SESSION_DIRECT_TEST_SRC) src/spectrum/config/session.h src/spectrum/session/direct.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(SESSION_DIRECT_TEST_SRC) -o $@

$(SESSION_EVENT_TEST): $(SESSION_EVENT_TEST_SRC) src/spectrum/config/session.h src/spectrum/session/event.h src/spectrum/session/mqtt.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(SESSION_EVENT_TEST_SRC) -o $@

$(SESSION_MQTT_TEST): $(SESSION_MQTT_TEST_SRC) src/spectrum/config/session.h src/spectrum/session/mqtt.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(SESSION_MQTT_TEST_SRC) -o $@

$(SESSION_SPECTRUM_PAIR_TEST): $(SESSION_SPECTRUM_PAIR_TEST_SRC) src/spectrum/config/session.h src/spectrum/session/direct.h src/spectrum/session/mqtt.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(SESSION_SPECTRUM_PAIR_TEST_SRC) -o $@

$(SESSION_OUTGOING_TEST): $(SESSION_OUTGOING_TEST_SRC) src/spectrum/config/session.h src/spectrum/session/outgoing.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(SESSION_OUTGOING_TEST_SRC) -o $@

module-guards: layering-check overlay-cap-check overlay-entry-abi-check transport-contract-check mqtt-client-id-check pc-direct-policy-check spectrum-direct-policy-check session-boundaries-check

layering-check: tools/check_layering.py docs/overlay_state_allowlist.json
	$(PYTHON) tools/check_layering.py --root . --overlay-state-allowlist docs/overlay_state_allowlist.json

layering-report: tools/check_layering.py docs/overlay_state_allowlist.json
	$(PYTHON) tools/check_layering.py --root . --overlay-state-allowlist docs/overlay_state_allowlist.json --report

overlay-cap-check: tools/check_overlay_caps.py docs/overlay_capabilities.json tools/gen_overlay_defs.py tests/tools/test_overlay_caps.py
	$(PYTHON) tools/check_overlay_caps.py --root . --policy docs/overlay_capabilities.json
	$(PYTHON) tests/tools/test_overlay_caps.py

overlay-cap-report: tools/check_overlay_caps.py docs/overlay_capabilities.json tools/gen_overlay_defs.py
	$(PYTHON) tools/check_overlay_caps.py --root . --policy docs/overlay_capabilities.json --report

overlay-entry-abi-check: tools/check_overlay_entry_abi.py
	$(PYTHON) tools/check_overlay_entry_abi.py --root .

transport-contract-check: tools/check_transport_contract.py src/spectrum/transport/link.h src/spectrum/transport/net.c
	$(PYTHON) tools/check_transport_contract.py --root .

mqtt-client-id-check: tools/check_mqtt_client_id.py src/pc/client/main_window.cpp src/spectrum/config/session.h asm/overlay/mqtt_connect/entry_mqtt_connect.asm
	$(PYTHON) tools/check_mqtt_client_id.py --root .

pc-direct-policy-check: tools/check_pc_direct_policy.py
	$(PYTHON) tools/check_pc_direct_policy.py --root .

pc-policy-guard: pc-direct-policy-check

spectrum-direct-policy-check: tools/check_spectrum_direct_policy.py
	$(PYTHON) tools/check_spectrum_direct_policy.py --root .

session-boundaries-check: tools/check_session_boundaries.py tests/session/mqtt_session_transcripts.h tests/session/mqtt_session_transcripts.c tests/session/test_mqtt_session_parity.c tests/session/direct_parity.h tests/session/test_direct_session_parity.c src/spectrum/transport/mqtt_session_wire.c src/common/session/session.c src/common/session/session.h src/pc/client/direct_session_adapter.cpp src/pc/client/mqtt_session_adapter.cpp
	$(PYTHON) tools/check_session_boundaries.py --root .

check: module-guards | $(BUILD_DIR) $(RELEASE_DIR)
	@fail=0; \
	for t in $(ZCC) $(Z80ASM) z88dk-appmake grep sed head wc dd $(PYTHON); do \
		command -v "$$t" >/dev/null 2>&1 || { echo "[ERR] Missing tool: $$t"; fail=1; }; \
	done; \
	for f in $(SPECTRUM_SRC) $(UART_ASM) $(SHRINK_ASM) $(SCREEN_ASM) asm/spectrum/text.asm $(OVERLAY_LOADER_ASM) $(PIECE_ASM) tools/gen_overlay_defs.py; do \
		test -f "$$f" || { echo "[ERR] Missing source: $$f"; fail=1; }; \
	done; \
	exit $$fail

test: $(RULES_TEST) $(MOVE_COORDS_TEST) $(SAVEGAME_WIRE_TEST) $(BOARD_TEST) $(RULES_COMPACT_PERFT_TEST) $(MQTT_TEST) $(MQTT_STREAM_TEST) $(GAME_PROTOCOL_TEST) $(MQTT_SESSION_PROTOCOL_TEST) $(DIRECT_SESSION_PROTOCOL_TEST) $(SESSION_CORE_TEST) $(SESSION_MQTT_PARITY_TEST) $(SESSION_DIRECT_CORE_TEST) $(SESSION_DIRECT_PARITY_TEST) $(SESSION_DIRECT_PARITY_NEXT_TEST) $(KEEPALIVE_PROTOCOL_TEST) $(ESP_AT_TEST) $(ESP_AT_NEXT_TEST) $(UART_PLATFORM_TEST) $(DIRECT_IPD_TEST) $(SESSION_CONFIG_TEST) $(SESSION_PING_TEST) $(SESSION_PING_NEXT_TEST) $(SESSION_POLL_TEST) $(SESSION_DIRECT_TEST) $(SESSION_EVENT_TEST) $(SESSION_MQTT_TEST) $(SESSION_OUTGOING_TEST) tests/tools/test_gen_assets_about.py tests/tools/test_next_flip_sprite_slots.py tests/tools/test_next_graphics_bank.py tests/tools/test_next_board_theme_rgb333.py tests/tools/test_tap_image.py
	"$(PYTHON)" -m unittest discover -s tests/tools -p "test_gen_assets_about.py"
	"$(PYTHON)" tests/tools/test_tap_image.py
	"$(PYTHON)" tests/tools/test_next_flip_sprite_slots.py
	"$(PYTHON)" tests/tools/test_next_graphics_bank.py
	"$(PYTHON)" tests/tools/test_next_board_theme_rgb333.py
	./$(RULES_TEST)
	./$(MOVE_COORDS_TEST)
	./$(SAVEGAME_WIRE_TEST)
	./$(BOARD_TEST)
	./$(RULES_COMPACT_PERFT_TEST)
	./$(MQTT_TEST)
	./$(MQTT_STREAM_TEST)
	./$(ESP_AT_TEST)
	./$(ESP_AT_NEXT_TEST)
	./$(UART_PLATFORM_TEST)
	./$(DIRECT_IPD_TEST)
	./$(GAME_PROTOCOL_TEST)
	./$(MQTT_SESSION_PROTOCOL_TEST)
	./$(DIRECT_SESSION_PROTOCOL_TEST)
	./$(SESSION_CORE_TEST)
	./$(SESSION_MQTT_PARITY_TEST)
	./$(SESSION_DIRECT_CORE_TEST)
	./$(SESSION_DIRECT_PARITY_TEST)
	./$(SESSION_DIRECT_PARITY_NEXT_TEST)
	./$(KEEPALIVE_PROTOCOL_TEST)
	./$(SESSION_CONFIG_TEST)
	./$(SESSION_PING_TEST)
	./$(SESSION_PING_NEXT_TEST)
	./$(SESSION_POLL_TEST)
	./$(SESSION_DIRECT_TEST)
	./$(SESSION_EVENT_TEST)
	./$(SESSION_MQTT_TEST)
	./$(SESSION_OUTGOING_TEST)

rules-oracle: $(RULES_COMPACT_PERFT_TEST)
	"$(PYTHON)" tests/spectrum/rules_compact_pychess_oracle.py $(RULES_ORACLE_ARGS)

session-spectrum-pair-test: $(SESSION_SPECTRUM_PAIR_TEST)
	./$(SESSION_SPECTRUM_PAIR_TEST)

tap: check
tap: $(ZX_TAP)
tap: $(ZX_OVL)
tap: $(ZX_DAT)
tap: move-listings

# zcc drops .c.asm listings next to the sources; sweep them into
# $(BUILD_DIR)/listings so src/ stays clean (shrink sessions read them there).
move-listings: $(ZX_TAP) $(ZX_OVL)
	@mkdir -p $(BUILD_DIR)/listings
	@find src -name '*.c.asm' -exec sh -c 'mkdir -p "$(BUILD_DIR)/listings/$$(dirname "$$1")" && mv -f "$$1" "$(BUILD_DIR)/listings/$$1"' _ {} \;

.PHONY: move-listings

tap-divmmc:
	$(MAKE) UART_BACKEND=divmmc tap

tap-next:
	$(MAKE) UART_BACKEND=next ZX_TARGET_CFLAGS='-DNETCHESSZX_NEXT' BUILD_DIR=$(BUILD_DIR)/next RELEASE_DIR=$(BUILD_DIR)/next/stage tap

nex: $(ZX_NEX)

$(NEXT_SPRITE_BIN) $(NEXT_SPRITE_PALETTE_ASM) $(NEXT_SPRITE_PAL_BIN) $(NEXT_SPRITE_META): tools/build_next_piece_sprites.py assets/lichess/selected_next_sets.json assets/lichess/selected_next_boards.json
	$(PYTHON) tools/build_next_piece_sprites.py

$(ZX_NEX): FORCE tools/gen_next_nex.py tools/gen_next_graphics_defs.py tools/next_bundle_codec.py tests/tools/test_next_bundle_codec.py tests/tools/test_next_graphics_bank.py tests/tools/test_next_board_theme_rgb333.py tools/make_about_nxi.py $(NEXT_OVERLAY_LOADER_ASM) $(NEXT_GRAPHICS_BANK_ASM) $(NEXT_GRAPHICS_BANK_LAYOUT) asm/uart/next_uart.asm $(NEXT_SPRITE_BIN) $(NEXT_SPRITE_PAL_BIN) $(NEXT_ABOUT_NXI_SRC)
	rm -rf $(NEXT_NEX_BUILD_DIR) $(NEXT_NEX_RELEASE_DIR)
	$(MAKE) UART_BACKEND=next OVERLAY_LOADER_ASM=$(NEXT_OVERLAY_LOADER_ASM) SCREEN_ASM=asm/spectrum/screen.asm ZX_TARGET_CFLAGS='-DNETCHESSZX_NEXT -DNETCHESSZX_NEXT_BANKING -Ca-DNETCHESSZX_NEXT' BUILD_DIR=$(NEXT_NEX_BUILD_DIR) RELEASE_DIR=$(NEXT_NEX_STAGE_DIR) tap
	$(PYTHON) tools/make_about_nxi.py $(NEXT_ABOUT_NXI_SRC) $(ASSET_ASM) $(NEXT_ABOUT_NXI)
	$(PYTHON) tests/tools/test_next_bundle_codec.py --zx0 "$(NEXT_ZX0)"
	$(PYTHON) tests/tools/test_next_graphics_bank.py
	$(PYTHON) tests/tools/test_next_board_theme_rgb333.py
	$(PYTHON) tools/gen_next_graphics_defs.py $(NEXT_NEX_BUILD_DIR)/$(ZX_NAME).map > $(NEXT_GRAPHICS_BANK_DEFS)
	rm -f $(NEXT_GRAPHICS_BANK_OBJ) $(NEXT_GRAPHICS_BANK_DEFS:.asm=.o)
	$(ZX_Z80ASM) -O=$(NEXT_NEX_BUILD_DIR) $(NEXT_GRAPHICS_BANK_ASM)
	$(ZX_Z80ASM) -b -r$(NEXT_GRAPHICS_BANK_ORG) -o=$(NEXT_GRAPHICS_BANK_BIN) $(NEXT_GRAPHICS_BANK_OBJ) $(NEXT_GRAPHICS_BANK_DEFS)
	@graphics_size=$$(wc -c < $(NEXT_GRAPHICS_BANK_BIN)); \
	if [ "$$graphics_size" -gt $(NEXT_GRAPHICS_BANK_LIMIT) ]; then \
		printf "[ERR] Next graphics bank too large: $$graphics_size bytes (max $(NEXT_GRAPHICS_BANK_LIMIT))\n"; \
		exit 1; \
	fi; \
	printf "[OK] Next graphics bank: $$graphics_size/$(NEXT_GRAPHICS_BANK_LIMIT) bytes\n"
	$(PYTHON) tools/gen_next_nex.py --map $(NEXT_NEX_BUILD_DIR)/$(ZX_NAME).map --code-bin $(NEXT_NEX_BUILD_DIR)/$(ZX_NAME)_CODE.bin --ovl $(NEXT_NEX_STAGE_DIR)/$(ZX_NAME).OVL --dat $(NEXT_NEX_STAGE_DIR)/$(ZX_NAME).DAT --out $(ZX_NEX) --org $(ZX_ORG) --bundle-bank-base $(NEXT_BUNDLE_BANK_BASE) --raw-bank-base $(NEXT_RAW_BANK_BASE) --max-bundle-banks $(NEXT_MAX_BUNDLE_BANKS) --zx0 "$(NEXT_ZX0)" --dat-offset $(NEXT_BUNDLE_DAT_OFFSET) --sprite-patterns $(NEXT_SPRITE_BIN) --sprite-offset $(NEXT_SPRITE_OFFSET) --sprite-pal $(NEXT_SPRITE_PAL_BIN) --sprite-pal-offset $(NEXT_SPRITE_PAL_OFFSET) --about-nxi $(NEXT_ABOUT_NXI) --about-pal-offset $(NEXT_ABOUT_PAL_OFFSET) --about-pixels-offset $(NEXT_ABOUT_PIXELS_OFFSET) --graphics-bank $(NEXT_GRAPHICS_BANK_BIN) --graphics-bank-offset $(NEXT_GRAPHICS_BANK_OFFSET) --graphics-bank-org $(NEXT_GRAPHICS_BANK_ORG)

nex-size-report: nex tools/gen_size_report.py
	$(PYTHON) tools/gen_size_report.py --map $(NEXT_NEX_BUILD_DIR)/$(ZX_NAME).map --code-bin $(NEXT_NEX_BUILD_DIR)/$(ZX_NAME)_CODE.bin --tap $(NEXT_NEX_STAGE_DIR)/$(ZX_NAME).tap --ovl $(NEXT_NEX_STAGE_DIR)/$(ZX_NAME).OVL --dat $(NEXT_NEX_STAGE_DIR)/$(ZX_NAME).DAT --overlay-sizes $(NEXT_NEX_BUILD_DIR)/overlay_sizes.json --output $(NEXT_SIZE_REPORT)

next: nex

tap-direct-overlay:
	$(MAKE) tap

sdcc-iy-contract-check: tools/check_sdcc_iy_contract.py | $(BUILD_DIR)
	$(PYTHON) tools/check_sdcc_iy_contract.py --zcc "$(ZCC)" --build-dir "$(BUILD_DIR)"

abi-next-manifest: nex tools/gen_abi_manifest.py tools/gen_overlay_defs.py $(ABI_HEADERS)
	$(PYTHON) tools/gen_abi_manifest.py $(NEXT_NEX_BUILD_DIR)/$(ZX_NAME).map --output $(NEXT_ABI_MANIFEST)

abi-manifest: abi-next-manifest tap tools/gen_abi_manifest.py tools/gen_overlay_defs.py $(ABI_HEADERS) | $(BUILD_DIR)
	$(PYTHON) tools/gen_abi_manifest.py $(BUILD_DIR)/$(ZX_NAME).map --output $(ABI_MANIFEST)

abi-next-baseline: nex tools/gen_abi_manifest.py tools/gen_overlay_defs.py $(ABI_HEADERS)
	$(PYTHON) tools/gen_abi_manifest.py $(NEXT_NEX_BUILD_DIR)/$(ZX_NAME).map --output $(NEXT_ABI_MANIFEST) --write-baseline $(NEXT_ABI_BASELINE)

abi-baseline: abi-next-baseline tap tools/gen_abi_manifest.py tools/gen_overlay_defs.py $(ABI_HEADERS) | $(BUILD_DIR)
	$(PYTHON) tools/gen_abi_manifest.py $(BUILD_DIR)/$(ZX_NAME).map --output $(ABI_MANIFEST) --write-baseline $(ABI_BASELINE)

abi-next-check: nex tools/gen_abi_manifest.py tools/gen_overlay_defs.py $(ABI_HEADERS)
	$(PYTHON) tools/gen_abi_manifest.py $(NEXT_NEX_BUILD_DIR)/$(ZX_NAME).map --output $(NEXT_ABI_MANIFEST) --baseline $(NEXT_ABI_BASELINE) --fail-on-missing-baseline $(ABI_CHECK_FLAGS)

abi-check: abi-next-check tap tools/gen_abi_manifest.py tools/gen_overlay_defs.py $(ABI_HEADERS) | $(BUILD_DIR)
	$(PYTHON) tools/gen_abi_manifest.py $(BUILD_DIR)/$(ZX_NAME).map --output $(ABI_MANIFEST) --baseline $(ABI_BASELINE) --fail-on-missing-baseline $(ABI_CHECK_FLAGS)

size-report: tap tools/gen_size_report.py | $(BUILD_DIR)
	$(PYTHON) tools/gen_size_report.py --map $(BUILD_DIR)/$(ZX_NAME).map --code-bin $(BUILD_DIR)/$(ZX_NAME)_CODE.bin --tap $(ZX_TAP) --ovl $(ZX_OVL) --dat $(ZX_DAT) --overlay-sizes $(BUILD_DIR)/overlay_sizes.json --output $(SIZE_REPORT)

size-baseline: tap tools/gen_size_report.py | $(BUILD_DIR)
	$(PYTHON) tools/gen_size_report.py --map $(BUILD_DIR)/$(ZX_NAME).map --code-bin $(BUILD_DIR)/$(ZX_NAME)_CODE.bin --tap $(ZX_TAP) --ovl $(ZX_OVL) --dat $(ZX_DAT) --overlay-sizes $(BUILD_DIR)/overlay_sizes.json --output $(SIZE_REPORT) --write-baseline $(SIZE_BASELINE)

size-check: tap tools/gen_size_report.py | $(BUILD_DIR)
	$(PYTHON) tools/gen_size_report.py --map $(BUILD_DIR)/$(ZX_NAME).map --code-bin $(BUILD_DIR)/$(ZX_NAME)_CODE.bin --tap $(ZX_TAP) --ovl $(ZX_OVL) --dat $(ZX_DAT) --overlay-sizes $(BUILD_DIR)/overlay_sizes.json --output $(SIZE_REPORT) --baseline $(SIZE_BASELINE) --fail-on-missing-baseline $(SIZE_CHECK_FLAGS)

full-check:
	$(MAKE) module-guards
	$(MAKE) test
	$(MAKE) abi-check size-check nex-size-report

literal-report: tools/gen_literal_report.py | $(BUILD_DIR)
	$(PYTHON) tools/gen_literal_report.py --root . --output $(LITERAL_REPORT)

client:
ifeq ($(CLIENT_BUILD),auto)
ifneq ($(CLIENT_HOST_IS_WINDOWS),)
	@$(MAKE) client-msvc
else
	@$(MAKE) client-cmake
endif
else
	@$(MAKE) client-$(CLIENT_BUILD)
endif

qt-client: client
pc-client: client
mac-client: client

# Shared desktop dev loop. Windows preserves its external MSVC build tree;
# macOS/Linux use the common CMake tree under build/qt-client.
client-test:
ifneq ($(CLIENT_HOST_IS_WINDOWS),)
	cd client && $(CMAKE) --preset msvc && $(CMAKE) --build --preset msvc-release --parallel && ctest --preset msvc-release
else
	@command -v "$(CMAKE)" >/dev/null 2>&1 || { echo "[ERR] Missing cmake: set CMAKE=/path/to/cmake"; exit 1; }
	@command -v "$(CTEST)" >/dev/null 2>&1 || { echo "[ERR] Missing ctest: set CTEST=/path/to/ctest"; exit 1; }
	$(CMAKE) -S client -B "$(CLIENT_CMAKE_BUILD_DIR)" -DCMAKE_BUILD_TYPE="$(CLIENT_CMAKE_CONFIG)" -DBUILD_TESTING=ON $(CLIENT_CMAKE_ARGS)
	$(CMAKE) --build "$(CLIENT_CMAKE_BUILD_DIR)" --config "$(CLIENT_CMAKE_CONFIG)" --parallel
	$(CTEST) --test-dir "$(CLIENT_CMAKE_BUILD_DIR)" -C "$(CLIENT_CMAKE_CONFIG)" --output-on-failure
endif

client-msvc:
	@command -v "$(POWERSHELL)" >/dev/null 2>&1 || { echo "[ERR] Missing PowerShell 7: set POWERSHELL=pwsh or use CLIENT_BUILD=cmake"; exit 1; }
	$(POWERSHELL) -NoLogo -NoProfile -ExecutionPolicy Bypass -File client/build-msvc.ps1 -QtDir "$(CLIENT_MSVC_QT_DIR)" -Config "$(CLIENT_MSVC_CONFIG)" -Generator "$(CLIENT_MSVC_GENERATOR)" -Architecture "$(CLIENT_MSVC_ARCH)" -DeployTimeoutSeconds $(CLIENT_MSVC_DEPLOY_TIMEOUT) -CleanTimeoutSeconds $(CLIENT_MSVC_CLEAN_TIMEOUT)

client-cmake:
	@command -v "$(CMAKE)" >/dev/null 2>&1 || { echo "[ERR] Missing cmake: set CMAKE=/path/to/cmake"; exit 1; }
	$(CMAKE) -S client -B "$(CLIENT_CMAKE_BUILD_DIR)" -DCMAKE_BUILD_TYPE="$(CLIENT_CMAKE_CONFIG)" $(CLIENT_CMAKE_ARGS)
ifeq ($(HOST_UNAME),Darwin)
	$(CMAKE) -E rm -rf "$(CLIENT_CMAKE_BUILD_DIR)/shatranj-client.app"
endif
	$(CMAKE) --build "$(CLIENT_CMAKE_BUILD_DIR)" --config "$(CLIENT_CMAKE_CONFIG)"
ifeq ($(HOST_UNAME),Darwin)
	@command -v "$(MACDEPLOYQT)" >/dev/null 2>&1 || { echo "[ERR] Missing macdeployqt: set MACDEPLOYQT=/path/to/macdeployqt"; exit 1; }
	@command -v "$(CODESIGN)" >/dev/null 2>&1 || { echo "[ERR] Missing codesign: set CODESIGN=/path/to/codesign"; exit 1; }
	@command -v "$(DITTO)" >/dev/null 2>&1 || { echo "[ERR] Missing ditto: set DITTO=/path/to/ditto"; exit 1; }
	@command -v "$(QTPATHS)" >/dev/null 2>&1 || { echo "[ERR] Missing qtpaths: set QTPATHS=/path/to/qtpaths"; exit 1; }
	$(MACDEPLOYQT) "$(CLIENT_CMAKE_BUILD_DIR)/shatranj-client.app" -always-overwrite -no-codesign -no-plugins
	$(CMAKE) -E make_directory \
		"$(CLIENT_CMAKE_BUILD_DIR)/shatranj-client.app/Contents/PlugIns/platforms" \
		"$(CLIENT_CMAKE_BUILD_DIR)/shatranj-client.app/Contents/PlugIns/styles" \
		"$(CLIENT_CMAKE_BUILD_DIR)/shatranj-client.app/Contents/PlugIns/imageformats"
	$(CMAKE) -E copy_if_different "$$($(QTPATHS) --plugin-dir)/platforms/libqcocoa.dylib" "$(CLIENT_CMAKE_BUILD_DIR)/shatranj-client.app/Contents/PlugIns/platforms/libqcocoa.dylib"
	$(CMAKE) -E copy_if_different "$$($(QTPATHS) --plugin-dir)/styles/libqmacstyle.dylib" "$(CLIENT_CMAKE_BUILD_DIR)/shatranj-client.app/Contents/PlugIns/styles/libqmacstyle.dylib"
	$(CMAKE) -E copy_if_different "$$($(QTPATHS) --plugin-dir)/imageformats/libqjpeg.dylib" "$(CLIENT_CMAKE_BUILD_DIR)/shatranj-client.app/Contents/PlugIns/imageformats/libqjpeg.dylib"
	$(MACDEPLOYQT) "$(CLIENT_CMAKE_BUILD_DIR)/shatranj-client.app" -always-overwrite -no-codesign -no-plugins \
		-executable="$(CLIENT_CMAKE_BUILD_DIR)/shatranj-client.app/Contents/PlugIns/platforms/libqcocoa.dylib" \
		-executable="$(CLIENT_CMAKE_BUILD_DIR)/shatranj-client.app/Contents/PlugIns/styles/libqmacstyle.dylib" \
		-executable="$(CLIENT_CMAKE_BUILD_DIR)/shatranj-client.app/Contents/PlugIns/imageformats/libqjpeg.dylib"
	$(CODESIGN) --force --deep --sign - "$(CLIENT_CMAKE_BUILD_DIR)/shatranj-client.app"
	$(CODESIGN) --verify --deep --strict "$(CLIENT_CMAKE_BUILD_DIR)/shatranj-client.app"
	$(CMAKE) -E make_directory "$(CLIENT_MAC_APPLICATIONS_DIR)"
	$(CMAKE) -E rm -rf "$(CLIENT_MAC_APPLICATIONS_DIR)/Shatranj.app"
	$(DITTO) "$(CLIENT_CMAKE_BUILD_DIR)/shatranj-client.app" "$(CLIENT_MAC_APPLICATIONS_DIR)/Shatranj.app"
endif


$(RELEASE_DIR):
	mkdir -p $(RELEASE_DIR)

$(BUILD_DAT): tools/gen_assets.py $(ASSET_ASM) $(PIECE_ASM) $(ABOUT_BOARD) $(SCREEN_ASM) $(OVERLAY_LOADER_ASM) VERSION | $(BUILD_DIR)
	$(PYTHON) tools/gen_assets.py $(ASSET_ASM) $(PIECE_ASM) $(SCREEN_ASM) $(OVERLAY_LOADER_ASM) $(ABOUT_BOARD) $(BUILD_DAT) --version $(APP_VERSION) $(DAT_PLATFORM_FLAG)

$(ZX_DAT): $(BUILD_DAT) | $(RELEASE_DIR)
	cp -f $(BUILD_DAT) $(ZX_DAT)

$(OVL_ATLAS_TABLE): tools/gen_overlay_atlas.py | $(BUILD_DIR)
	$(PYTHON) tools/gen_overlay_atlas.py --build-dir $(BUILD_DIR) --name $(ZX_NAME) --out $(BUILD_DIR)/$(ZX_NAME).OVL.bootstrap --asm-out $(OVL_ATLAS_TABLE) --bootstrap-asm

$(ZX_TAP): FORCE $(SPECTRUM_SRC) $(UART_ASM) $(SHRINK_ASM) $(SCREEN_ASM) asm/spectrum/text.asm $(OVERLAY_LOADER_ASM) tools/netchesszx_bool_copt tools/check_sdcc_iy_contract.py tools/check_tap_image.py $(BUILD_DAT) $(OVL_ATLAS_TABLE) | $(BUILD_DIR) $(RELEASE_DIR)
	rm -f $(BUILD_DIR)/$(ZX_NAME) $(BUILD_DIR)/$(ZX_NAME).tap $(BUILD_DIR)/$(ZX_NAME)_CODE.bin $(BUILD_DIR)/$(ZX_NAME).map
	rm -f $(BUILD_DIR)/NCHESSZX $(BUILD_DIR)/NCHESSZX.tap $(BUILD_DIR)/NCHESSZX_CODE.bin $(BUILD_DIR)/NCHESSZX.map
	rm -f $(RELEASE_DIR)/NCHESSZX.tap $(RELEASE_DIR)/NCHESSZX.OVL $(RELEASE_DIR)/NCHESSZX.DAT
	@{ cd $(BUILD_DIR) && $(ZCC) +zx $(ZX_CFLAGS) $(addprefix $(BUILD_DIR_UP),$(SPECTRUM_SRC)) $(BUILD_DIR_UP)$(UART_ASM) $(BUILD_DIR_UP)$(SHRINK_ASM) $(BUILD_DIR_UP)$(SCREEN_ASM) $(BUILD_DIR_UP)asm/spectrum/text.asm $(BUILD_DIR_UP)$(OVERLAY_LOADER_ASM) -o $(ZX_NAME) -create-app; printf "%s\n" $$? > $(ZX_NAME).build.status; } 2>&1 | tee $(ZX_BUILD_LOG); \
	build_rc=$$(cat $(BUILD_DIR)/$(ZX_NAME).build.status 2>/dev/null || echo 1); \
	rm -f $(BUILD_DIR)/$(ZX_NAME).build.status; \
	if [ "$$build_rc" -ne 0 ]; then exit $$build_rc; fi
	@$(MAKE) sdcc-iy-contract-check
	$(PYTHON) tools/check_lowmem_layout.py --map $(BUILD_DIR)/$(ZX_NAME).map
	cp -f $(BUILD_DIR)/$(ZX_NAME).tap $(ZX_TAP)
	$(PYTHON) tools/check_tap_image.py --map $(BUILD_DIR)/$(ZX_NAME).map --code-bin $(BUILD_DIR)/$(ZX_NAME)_CODE.bin --tap $(ZX_TAP) --org $(ZX_ORG)

$(ZX_OVL): $(ZX_TAP) asm/overlay/rules/entry_rules.asm asm/overlay/rules/rules_stub.asm asm/overlay/board/entry_board.asm asm/overlay/board/helpers.asm src/spectrum/overlay/board_apply_ovl.c asm/overlay/gui_log/entry_gui_log.asm src/spectrum/overlay/gui_log_ovl.c asm/overlay/input_edit/entry_input_edit.asm src/spectrum/overlay/input_edit_ovl.c asm/overlay/mqtt_connect/entry_mqtt_connect.asm src/spectrum/overlay/mqtt_connect_ovl.c asm/overlay/mqtt_tx/entry_mqtt_tx.asm src/spectrum/overlay/mqtt_tx_ovl.c asm/overlay/direct/entry_direct.asm src/spectrum/overlay/direct_ovl.c asm/overlay/menu_config/entry_menu_config.asm asm/overlay/menu_logic/entry_menu_logic.asm src/spectrum/overlay/status_ovl.c asm/overlay/fileui/entry_fileui.asm src/spectrum/overlay/fileui_ovl.c asm/overlay/setup/entry_setup.asm asm/overlay/saveload/entry_saveload.asm src/spectrum/overlay/saveload_ovl.c asm/overlay/restore/entry_restore.asm src/spectrum/overlay/restore_ovl.c asm/overlay/about/entry_about.asm asm/overlay/control/entry_control.asm src/spectrum/overlay/control_ovl.c $(ESX_COMMON_ASM) $(ESX_FILEUI_ASM) $(ESX_SAVELOAD_ASM) tools/gen_overlay_defs.py tools/gen_overlay_atlas.py src/spectrum/overlay/overlay_api.h | $(BUILD_DIR) $(RELEASE_DIR)
	@SLOT=$$(grep '_overlay_code_slot ' $(BUILD_DIR)/$(ZX_NAME).map | sed -n 's/.*= \$$\([0-9A-Fa-f]*\).*/\1/p' | head -1); \
	if [ -z "$$SLOT" ]; then \
		printf "[ERR] _overlay_code_slot not found in $(BUILD_DIR)/$(ZX_NAME).map\n"; \
		exit 1; \
	fi; \
	echo "  overlay_code_slot = 0x$$SLOT"; \
	$(PYTHON) tools/gen_overlay_defs.py $(BUILD_DIR)/$(ZX_NAME).map > $(OVL_DEFS) || exit 1; \
	echo "  overlay_defs.asm generated"; \
	rm -f $(BUILD_DIR)/overlay_defs.o $(BUILD_DIR)/overlay_defs.o~; \
	$(ZX_Z80ASM) asm/overlay/rules/entry_rules.asm 2>&1 || exit 1; \
	$(ZX_Z80ASM) asm/overlay/rules/rules_stub.asm 2>&1 || exit 1; \
	$(ZX_Z80ASM) -b -r0x$$SLOT -o=$(BUILD_DIR)/$(ZX_NAME)_RULES.OVL \
		asm/overlay/rules/entry_rules.o asm/overlay/rules/rules_stub.o $(OVL_DEFS) 2>&1 || exit 1; \
	$(ZX_Z80ASM) asm/overlay/board/entry_board.asm 2>&1 || exit 1; \
	$(ZX_Z80ASM) asm/overlay/board/helpers.asm 2>&1 || exit 1; \
	(cd $(BUILD_DIR) && $(ZCC) +z80 $(ZX_OVL_CFLAGS) -c $(BUILD_DIR_UP)src/spectrum/overlay/board_apply_ovl.c -o board_apply_ovl.o) 2>&1 || exit 1; \
	rm -f $(BUILD_DIR)/overlay_defs.o $(BUILD_DIR)/overlay_defs.o~; \
	$(ZX_Z80ASM) -b -r0x$$SLOT -o=$(BUILD_DIR)/$(ZX_NAME)_BOARD.OVL \
		asm/overlay/board/entry_board.o asm/overlay/board/helpers.o $(BUILD_DIR)/board_apply_ovl.o $(OVL_DEFS) 2>&1 || exit 1; \
	$(ZX_Z80ASM) asm/overlay/gui_log/entry_gui_log.asm 2>&1 || exit 1; \
	(cd $(BUILD_DIR) && $(ZCC) +z80 $(ZX_OVL_CFLAGS) -c $(BUILD_DIR_UP)src/spectrum/overlay/gui_log_ovl.c -o gui_log_ovl.o) 2>&1 || exit 1; \
	rm -f $(BUILD_DIR)/overlay_defs.o $(BUILD_DIR)/overlay_defs.o~; \
	$(ZX_Z80ASM) -b -r0x$$SLOT -o=$(BUILD_DIR)/$(ZX_NAME)_GUI_LOG.OVL \
		asm/overlay/gui_log/entry_gui_log.o $(BUILD_DIR)/gui_log_ovl.o $(OVL_DEFS) 2>&1 || exit 1; \
	$(ZX_Z80ASM) asm/overlay/input_edit/entry_input_edit.asm 2>&1 || exit 1; \
	(cd $(BUILD_DIR) && $(ZCC) +z80 $(ZX_OVL_CFLAGS) -c $(BUILD_DIR_UP)src/spectrum/overlay/input_edit_ovl.c -o input_edit_ovl.o) 2>&1 || exit 1; \
	rm -f $(BUILD_DIR)/overlay_defs.o $(BUILD_DIR)/overlay_defs.o~; \
	$(ZX_Z80ASM) -b -r0x$$SLOT -o=$(BUILD_DIR)/$(ZX_NAME)_INPUT_EDIT.OVL \
		asm/overlay/input_edit/entry_input_edit.o $(BUILD_DIR)/input_edit_ovl.o $(OVL_DEFS) 2>&1 || exit 1; \
	$(ZX_Z80ASM) asm/overlay/mqtt_connect/entry_mqtt_connect.asm 2>&1 || exit 1; \
	(cd $(BUILD_DIR) && $(ZCC) +z80 $(ZX_OVL_CFLAGS) $(MQTT_CONNECT_OVL_CFLAGS) -c $(BUILD_DIR_UP)src/spectrum/overlay/mqtt_connect_ovl.c -o mqtt_connect_ovl.o) 2>&1 || exit 1; \
	rm -f $(BUILD_DIR)/overlay_defs.o $(BUILD_DIR)/overlay_defs.o~; \
	$(ZX_Z80ASM) -b -r0x$$SLOT -o=$(BUILD_DIR)/$(ZX_NAME)_MQTT_CONNECT.OVL \
		asm/overlay/mqtt_connect/entry_mqtt_connect.o $(BUILD_DIR)/mqtt_connect_ovl.o $(OVL_DEFS) 2>&1 || exit 1; \
	$(ZX_Z80ASM) asm/overlay/mqtt_tx/entry_mqtt_tx.asm 2>&1 || exit 1; \
	(cd $(BUILD_DIR) && $(ZCC) +z80 $(ZX_OVL_CFLAGS) -c $(BUILD_DIR_UP)src/spectrum/overlay/mqtt_tx_ovl.c -o mqtt_tx_ovl.o) 2>&1 || exit 1; \
	rm -f $(BUILD_DIR)/overlay_defs.o $(BUILD_DIR)/overlay_defs.o~; \
	$(ZX_Z80ASM) -b -r0x$$SLOT -o=$(BUILD_DIR)/$(ZX_NAME)_MQTT_TX.OVL \
		asm/overlay/mqtt_tx/entry_mqtt_tx.o $(BUILD_DIR)/mqtt_tx_ovl.o $(OVL_DEFS) 2>&1 || exit 1; \
	$(ZX_Z80ASM) asm/overlay/direct/entry_direct.asm 2>&1 || exit 1; \
	(cd $(BUILD_DIR) && $(ZCC) +z80 $(ZX_OVL_CFLAGS) -c $(BUILD_DIR_UP)src/spectrum/overlay/direct_ovl.c -o direct_ovl.o) 2>&1 || exit 1; \
	rm -f $(BUILD_DIR)/overlay_defs.o $(BUILD_DIR)/overlay_defs.o~; \
	$(ZX_Z80ASM) -b -r0x$$SLOT -o=$(BUILD_DIR)/$(ZX_NAME)_DIRECT.OVL \
		asm/overlay/direct/entry_direct.o $(BUILD_DIR)/direct_ovl.o $(OVL_DEFS) 2>&1 || exit 1
	@SLOT=$$(grep '_overlay_code_slot ' $(BUILD_DIR)/$(ZX_NAME).map | sed -n 's/.*= \$$\([0-9A-Fa-f]*\).*/\1/p' | head -1); \
	ovl_size=$$(wc -c < $(BUILD_DIR)/$(ZX_NAME)_RULES.OVL); \
	hints_size=0; \
	board_size=$$(wc -c < $(BUILD_DIR)/$(ZX_NAME)_BOARD.OVL); \
	gui_log_size=$$(wc -c < $(BUILD_DIR)/$(ZX_NAME)_GUI_LOG.OVL); \
	input_edit_size=$$(wc -c < $(BUILD_DIR)/$(ZX_NAME)_INPUT_EDIT.OVL); \
	mqtt_connect_size=$$(wc -c < $(BUILD_DIR)/$(ZX_NAME)_MQTT_CONNECT.OVL); \
	mqtt_tx_size=$$(wc -c < $(BUILD_DIR)/$(ZX_NAME)_MQTT_TX.OVL); \
	direct_size=$$(wc -c < $(BUILD_DIR)/$(ZX_NAME)_DIRECT.OVL); \
	$(ZX_Z80ASM) asm/overlay/menu_config/entry_menu_config.asm 2>&1 || exit 1; \
	rm -f $(BUILD_DIR)/overlay_defs.o $(BUILD_DIR)/overlay_defs.o~; \
	$(ZX_Z80ASM) -b -r0x$$SLOT -o=$(BUILD_DIR)/$(ZX_NAME)_MENU_CONFIG.OVL \
		asm/overlay/menu_config/entry_menu_config.o $(OVL_DEFS) 2>&1 || exit 1; \
	menu_config_size=$$(wc -c < $(BUILD_DIR)/$(ZX_NAME)_MENU_CONFIG.OVL); \
	$(ZX_Z80ASM) asm/overlay/menu_logic/entry_menu_logic.asm 2>&1 || exit 1; \
	(cd $(BUILD_DIR) && $(ZCC) +z80 $(ZX_OVL_CFLAGS) -c $(BUILD_DIR_UP)src/spectrum/overlay/status_ovl.c -o status_ovl.o) 2>&1 || exit 1; \
	rm -f $(BUILD_DIR)/overlay_defs.o $(BUILD_DIR)/overlay_defs.o~; \
	$(ZX_Z80ASM) -b -r0x$$SLOT -o=$(BUILD_DIR)/$(ZX_NAME)_MENU_LOGIC.OVL \
		asm/overlay/menu_logic/entry_menu_logic.o $(BUILD_DIR)/status_ovl.o $(OVL_DEFS) 2>&1 || exit 1; \
	menu_logic_size=$$(wc -c < $(BUILD_DIR)/$(ZX_NAME)_MENU_LOGIC.OVL); \
	$(ZX_Z80ASM) asm/overlay/fileui/entry_fileui.asm 2>&1 || exit 1; \
	$(ZX_Z80ASM) $(ESX_FILEUI_ASM) 2>&1 || exit 1; \
	(cd $(BUILD_DIR) && $(ZCC) +z80 $(ZX_OVL_CFLAGS) -c $(BUILD_DIR_UP)src/spectrum/overlay/fileui_ovl.c -o fileui_ovl.o) 2>&1 || exit 1; \
	rm -f $(BUILD_DIR)/overlay_defs.o $(BUILD_DIR)/overlay_defs.o~; \
	$(ZX_Z80ASM) -b -r0x$$SLOT -o=$(BUILD_DIR)/$(ZX_NAME)_FILEUI.OVL \
		asm/overlay/fileui/entry_fileui.o $(BUILD_DIR)/fileui_ovl.o asm/esxdos/esx_fileui.o $(OVL_DEFS) 2>&1 || exit 1; \
	fileui_size=$$(wc -c < $(BUILD_DIR)/$(ZX_NAME)_FILEUI.OVL); \
	$(ZX_Z80ASM) asm/overlay/setup/entry_setup.asm 2>&1 || exit 1; \
	rm -f $(BUILD_DIR)/overlay_defs.o $(BUILD_DIR)/overlay_defs.o~; \
	$(ZX_Z80ASM) -b -r0x$$SLOT -o=$(BUILD_DIR)/$(ZX_NAME)_SETUP.OVL \
		asm/overlay/setup/entry_setup.o $(OVL_DEFS) 2>&1 || exit 1; \
	setup_size=$$(wc -c < $(BUILD_DIR)/$(ZX_NAME)_SETUP.OVL); \
	$(ZX_Z80ASM) asm/overlay/saveload/entry_saveload.asm 2>&1 || exit 1; \
	$(ZX_Z80ASM) $(ESX_SAVELOAD_ASM) 2>&1 || exit 1; \
	(cd $(BUILD_DIR) && $(ZCC) +z80 $(ZX_OVL_CFLAGS) -c $(BUILD_DIR_UP)src/spectrum/overlay/saveload_ovl.c -o saveload_ovl.o) 2>&1 || exit 1; \
	rm -f $(BUILD_DIR)/overlay_defs.o $(BUILD_DIR)/overlay_defs.o~; \
	$(ZX_Z80ASM) -b -r0x$$SLOT -o=$(BUILD_DIR)/$(ZX_NAME)_SAVELOAD.OVL \
		asm/overlay/saveload/entry_saveload.o $(BUILD_DIR)/saveload_ovl.o asm/esxdos/esx_saveload.o $(OVL_DEFS) 2>&1 || exit 1; \
	saveload_size=$$(wc -c < $(BUILD_DIR)/$(ZX_NAME)_SAVELOAD.OVL); \
	$(ZX_Z80ASM) asm/overlay/restore/entry_restore.asm 2>&1 || exit 1; \
	(cd $(BUILD_DIR) && $(ZCC) +z80 $(ZX_OVL_CFLAGS) -c $(BUILD_DIR_UP)src/spectrum/overlay/restore_ovl.c -o restore_ovl.o) 2>&1 || exit 1; \
	rm -f $(BUILD_DIR)/overlay_defs.o $(BUILD_DIR)/overlay_defs.o~; \
	$(ZX_Z80ASM) -b -r0x$$SLOT -o=$(BUILD_DIR)/$(ZX_NAME)_RESTORE.OVL \
		asm/overlay/restore/entry_restore.o $(BUILD_DIR)/restore_ovl.o $(OVL_DEFS) 2>&1 || exit 1; \
	restore_size=$$(wc -c < $(BUILD_DIR)/$(ZX_NAME)_RESTORE.OVL); \
	$(ZX_Z80ASM) asm/overlay/about/entry_about.asm 2>&1 || exit 1; \
	rm -f $(BUILD_DIR)/overlay_defs.o $(BUILD_DIR)/overlay_defs.o~; \
	$(ZX_Z80ASM) -b -r0x$$SLOT -o=$(BUILD_DIR)/$(ZX_NAME)_ABOUT.OVL \
		asm/overlay/about/entry_about.o $(OVL_DEFS) 2>&1 || exit 1; \
	about_size=$$(wc -c < $(BUILD_DIR)/$(ZX_NAME)_ABOUT.OVL); \
	$(ZX_Z80ASM) asm/overlay/control/entry_control.asm 2>&1 || exit 1; \
	(cd $(BUILD_DIR) && $(ZCC) +z80 $(ZX_OVL_CFLAGS) -c $(BUILD_DIR_UP)src/spectrum/overlay/control_ovl.c -o control_ovl.o) 2>&1 || exit 1; \
	rm -f $(BUILD_DIR)/overlay_defs.o $(BUILD_DIR)/overlay_defs.o~; \
	$(ZX_Z80ASM) -b -r0x$$SLOT -o=$(BUILD_DIR)/$(ZX_NAME)_CONTROL.OVL \
		asm/overlay/control/entry_control.o $(BUILD_DIR)/control_ovl.o $(OVL_DEFS) 2>&1 || exit 1; \
	control_size=$$(wc -c < $(BUILD_DIR)/$(ZX_NAME)_CONTROL.OVL); \
	status_size=0; \
	$(PYTHON) tools/gen_overlay_atlas.py --build-dir $(BUILD_DIR) --name $(ZX_NAME) --out $(ZX_OVL) --asm-out $(OVL_ATLAS_TABLE) --changed-stamp $(BUILD_DIR)/overlay_atlas_table.changed > $(BUILD_DIR)/overlay_sizes.json || exit 1; \
	atlas_changed=$$(cat $(BUILD_DIR)/overlay_atlas_table.changed 2>/dev/null || echo 0); \
	if [ "$$atlas_changed" = "1" ] && [ "$(ATLAS_FINAL)" != "1" ]; then \
		printf "[INFO] overlay atlas table changed; rebuilding resident with baked offsets\\n"; \
		$(MAKE) ATLAS_FINAL=1 $(ZX_OVL) || exit 1; \
		exit 0; \
	fi; \
	if [ "$$atlas_changed" = "1" ] && [ "$(ATLAS_FINAL)" = "1" ]; then \
		printf "[ERR] overlay atlas table changed during final pass\\n"; \
		exit 1; \
	fi; \
	ovl_total=$$(wc -c < $(ZX_OVL)); \
	printf "[OK] $(ZX_NAME).OVL atlas: RULES $$ovl_size bytes, BOARD $$board_size bytes, GUI_LOG $$gui_log_size bytes, INPUT_EDIT $$input_edit_size bytes, MQTT_CONNECT $$mqtt_connect_size bytes, MQTT_TX $$mqtt_tx_size bytes, DIRECT $$direct_size bytes, MENU_CONFIG $$menu_config_size bytes, MENU_LOGIC $$menu_logic_size bytes, HINTS $$hints_size bytes, SETUP $$setup_size bytes, FILEUI $$fileui_size bytes, STATUS $$status_size bytes, SAVELOAD $$saveload_size bytes, RESTORE $$restore_size bytes, ABOUT $$about_size bytes, CONTROL $$control_size bytes, total $$ovl_total bytes\n"
	@rm -f asm/overlay/rules/entry_rules.o asm/overlay/rules/rules_stub.o asm/overlay/board/entry_board.o asm/overlay/board/helpers.o asm/overlay/gui_log/entry_gui_log.o asm/overlay/input_edit/entry_input_edit.o asm/overlay/mqtt_connect/entry_mqtt_connect.o asm/overlay/mqtt_tx/entry_mqtt_tx.o asm/overlay/direct/entry_direct.o asm/overlay/menu_config/entry_menu_config.o asm/overlay/menu_logic/entry_menu_logic.o asm/overlay/fileui/entry_fileui.o asm/overlay/setup/entry_setup.o asm/overlay/saveload/entry_saveload.o asm/overlay/restore/entry_restore.o asm/overlay/about/entry_about.o asm/esxdos/esx_fileio_spectalk.o asm/esxdos/esx_fileui.o asm/esxdos/esx_saveload.o $(BUILD_DIR)/asm/overlay/rules/rules_stub.o $(BUILD_DIR)/board_apply_ovl.o $(BUILD_DIR)/gui_log_ovl.o $(BUILD_DIR)/input_edit_ovl.o $(BUILD_DIR)/mqtt_connect_ovl.o $(BUILD_DIR)/mqtt_tx_ovl.o $(BUILD_DIR)/direct_ovl.o $(BUILD_DIR)/status_ovl.o $(BUILD_DIR)/fileui_ovl.o $(BUILD_DIR)/saveload_ovl.o $(BUILD_DIR)/restore_ovl.o $(BUILD_DIR)/overlay_defs.o $(BUILD_DIR)/overlay_defs.o~ $(BUILD_DIR)/$(ZX_NAME)_RULES.OVL $(BUILD_DIR)/$(ZX_NAME)_BOARD.OVL $(BUILD_DIR)/$(ZX_NAME)_GUI_LOG.OVL $(BUILD_DIR)/$(ZX_NAME)_INPUT_EDIT.OVL $(BUILD_DIR)/$(ZX_NAME)_MQTT_CONNECT.OVL $(BUILD_DIR)/$(ZX_NAME)_MQTT_TX.OVL $(BUILD_DIR)/$(ZX_NAME)_DIRECT.OVL $(BUILD_DIR)/$(ZX_NAME)_MENU_CONFIG.OVL $(BUILD_DIR)/$(ZX_NAME)_MENU_LOGIC.OVL $(BUILD_DIR)/$(ZX_NAME)_FILEUI.OVL $(BUILD_DIR)/$(ZX_NAME)_SETUP.OVL $(BUILD_DIR)/$(ZX_NAME)_SAVELOAD.OVL $(BUILD_DIR)/$(ZX_NAME)_RESTORE.OVL $(BUILD_DIR)/$(ZX_NAME)_ABOUT.OVL $(BUILD_DIR)/$(ZX_NAME).OVL.tmp $(BUILD_DIR)/overlay_atlas_table.changed $(BUILD_DIR)/$(ZX_NAME).OVL.bootstrap 2>/dev/null || true
	@rm -f asm/overlay/control/entry_control.o $(BUILD_DIR)/control_ovl.o $(BUILD_DIR)/$(ZX_NAME)_CONTROL.OVL

FORCE:

clean: clean-spectrum clean-client

clean-spectrum:
ifneq ($(CLIENT_HOST_IS_WINDOWS),)
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File tools/clean-generated.ps1 -SpectrumOnly
else
	rm -rf $(BUILD_DIR) dist
	rm -rf build-next build-nex release/next release/nex release/Next $(BUILD_DIR)/next $(BUILD_DIR)/nex
	find src -name '*.c.asm' -delete
	rm -f $(RELEASE_DIR)/$(ZX_NAME).tap $(RELEASE_DIR)/$(ZX_NAME).OVL $(RELEASE_DIR)/$(ZX_NAME).DAT
	rm -f $(RELEASE_DIR)/NCHESSZX.tap $(RELEASE_DIR)/NCHESSZX.OVL $(RELEASE_DIR)/NCHESSZX.DAT
	rm -f $(RELEASE_DIR)/$(ZX_NAME)_MQTT_W.tap $(RELEASE_DIR)/$(ZX_NAME)_MQTT_W.OVL $(RELEASE_DIR)/$(ZX_NAME)_MQTT_W.DAT
	rm -f $(RELEASE_DIR)/$(ZX_NAME)_MQTT_B.tap $(RELEASE_DIR)/$(ZX_NAME)_MQTT_B.OVL $(RELEASE_DIR)/$(ZX_NAME)_MQTT_B.DAT
	rm -f $(RELEASE_DIR)/MQTTW $(RELEASE_DIR)/MQTTB $(RELEASE_DIR)/MQTTWKEY $(RELEASE_DIR)/MQTTBKEY $(RELEASE_DIR)/ZXCHNET.tap
	rm -f asm/overlay/rules/entry_rules.o asm/overlay/rules/rules_stub.o asm/overlay/board/entry_board.o asm/overlay/board/helpers.o asm/overlay/gui_log/entry_gui_log.o asm/overlay/input_edit/entry_input_edit.o asm/overlay/mqtt_connect/entry_mqtt_connect.o asm/overlay/mqtt_tx/entry_mqtt_tx.o asm/overlay/direct/entry_direct.o asm/overlay/menu_config/entry_menu_config.o asm/overlay/menu_logic/entry_menu_logic.o asm/overlay/fileui/entry_fileui.o asm/overlay/setup/entry_setup.o asm/overlay/saveload/entry_saveload.o asm/overlay/restore/entry_restore.o asm/overlay/about/entry_about.o asm/esxdos/esx_fileio_spectalk.o asm/esxdos/esx_fileui.o asm/esxdos/esx_saveload.o $(BUILD_DIR)/asm/overlay/rules/rules_stub.o $(BUILD_DIR)/board_apply_ovl.o $(BUILD_DIR)/gui_log_ovl.o $(BUILD_DIR)/input_edit_ovl.o $(BUILD_DIR)/mqtt_connect_ovl.o $(BUILD_DIR)/mqtt_tx_ovl.o $(BUILD_DIR)/direct_ovl.o $(BUILD_DIR)/status_ovl.o $(BUILD_DIR)/fileui_ovl.o $(BUILD_DIR)/saveload_ovl.o $(BUILD_DIR)/restore_ovl.o $(BUILD_DIR)/overlay_defs.o $(BUILD_DIR)/overlay_defs.o~ $(BUILD_DIR)/$(ZX_NAME)_RULES.OVL $(BUILD_DIR)/$(ZX_NAME)_BOARD.OVL $(BUILD_DIR)/$(ZX_NAME)_GUI_LOG.OVL $(BUILD_DIR)/$(ZX_NAME)_INPUT_EDIT.OVL $(BUILD_DIR)/$(ZX_NAME)_MQTT_CONNECT.OVL $(BUILD_DIR)/$(ZX_NAME)_MQTT_TX.OVL $(BUILD_DIR)/$(ZX_NAME)_DIRECT.OVL $(BUILD_DIR)/$(ZX_NAME)_MENU_CONFIG.OVL $(BUILD_DIR)/$(ZX_NAME)_MENU_LOGIC.OVL $(BUILD_DIR)/$(ZX_NAME)_FILEUI.OVL $(BUILD_DIR)/$(ZX_NAME)_SETUP.OVL $(BUILD_DIR)/$(ZX_NAME)_SAVELOAD.OVL $(BUILD_DIR)/$(ZX_NAME)_RESTORE.OVL $(BUILD_DIR)/$(ZX_NAME)_ABOUT.OVL $(BUILD_DIR)/$(ZX_NAME).OVL.tmp $(BUILD_DIR)/overlay_atlas_table.changed $(BUILD_DIR)/$(ZX_NAME).OVL.bootstrap 2>/dev/null || true
	rm -f asm/overlay/control/entry_control.o $(BUILD_DIR)/control_ovl.o $(BUILD_DIR)/$(ZX_NAME)_CONTROL.OVL
	rmdir $(RELEASE_DIR) 2>/dev/null || true
endif

clean-client:
ifneq ($(CLIENT_HOST_IS_WINDOWS),)
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File tools/clean-generated.ps1 -ClientOnly
else
	rm -rf client/build client/build_manual client/build_verify client/dist
	rm -rf $(RELEASE_DIR)/shatranj-client $(RELEASE_DIR)/shatranj $(RELEASE_DIR)/netchesszx-client
	rm -f main.obj
	rmdir $(RELEASE_DIR) 2>/dev/null || true
endif
