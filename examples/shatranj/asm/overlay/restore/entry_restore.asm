SECTION code_user

EXTERN _restore_build_frame_ovl
EXTERN _restore_decode_ovl

    DEFB 2
    DW _restore_build_frame_ovl_entry
    DW _restore_decode_ovl_entry

DEFC _restore_build_frame_ovl_entry = _restore_build_frame_ovl

DEFC _restore_decode_ovl_entry = _restore_decode_ovl
