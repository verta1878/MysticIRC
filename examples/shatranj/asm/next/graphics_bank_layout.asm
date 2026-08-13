; Shared resident/cold-bank entry contract. The code follows the 512-byte
; About palette in raw bundle page 7 (MMU page 39 when raw banks start at 16).
asset_load_addr                    EQU 0x6000
asset_piece_offset                 EQU 812
piece_sprite_set_size              EQU 384
next_bundle_dat_offset             EQU 32768
next_sprite_offset                 EQU 40960
next_sprite_set_size               EQU 3072
next_sprite_pattern_count          EQU 12
next_common_sprite_offset          EQU next_sprite_offset + (3 * next_sprite_set_size)
next_common_sprite_pattern_base    EQU 12
next_board_sprite_pattern_count    EQU 10
next_board_sprite_size             EQU next_board_sprite_pattern_count * 256
next_marker_sprite_offset          EQU next_common_sprite_offset + next_board_sprite_size
next_marker_sprite_pattern_base    EQU 22
next_marker_sprite_pattern_count   EQU 4
sprite_slot_port                   EQU 0x303B
sprite_pattern_port                EQU 0x005B
nextreg_select                     EQU 0x243B
nextreg_data                       EQU 0x253B
nextreg_sprite_layer_system        EQU 0x15
nextreg_palette_index              EQU 0x40
nextreg_palette_value_9            EQU 0x44
nextreg_palette_control            EQU 0x43
nextreg_sprite_transparency_index  EQU 0x4B
next_sprite_transparency           EQU 0xE3
next_sprite_stage                  EQU 0x662B
next_about_pal_offset              EQU 57344
next_about_bank                    EQU 20
layer2_port                        EQU 0x123B
nextreg_layer2_bank                EQU 0x12
next_sprite_palette_size           EQU 160
next_ula_standard_palette_size     EQU 116
next_sprite_pal_offset             EQU 53760

next_graphics_bank_bundle_offset EQU 57856
next_graphics_bank_org           EQU 0x0200
next_graphics_bank_page          EQU 39
next_graphics_bank_init_entry    EQU next_graphics_bank_org
next_graphics_bank_set_entry     EQU next_graphics_bank_org + 3
next_graphics_bank_about_entry   EQU next_graphics_bank_org + 6
next_graphics_bank_table_size    EQU 9
