SECTION code_user

PUBLIC _fileui_render_ovl_entry
PUBLIC _fileui_pick_ovl_entry

EXTERN _fileui_render_ovl
EXTERN _fileui_pick_ovl

    DEFB 2
    DW _fileui_render_ovl_entry
    DW _fileui_pick_ovl_entry

DEFC _fileui_render_ovl_entry = _fileui_render_ovl

DEFC _fileui_pick_ovl_entry = _fileui_pick_ovl
