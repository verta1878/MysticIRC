SECTION code_user

PUBLIC _saveload_load_nczs_ovl_entry
PUBLIC _saveload_save_nczs_ovl_entry
PUBLIC _saveload_erase_nczs_ovl_entry

EXTERN _saveload_load_nczs_ovl
EXTERN _saveload_save_nczs_ovl
EXTERN _saveload_erase_nczs_ovl

    DEFB 3
    DW _saveload_load_nczs_ovl_entry
    DW _saveload_save_nczs_ovl_entry
    DW _saveload_erase_nczs_ovl_entry

DEFC _saveload_load_nczs_ovl_entry = _saveload_load_nczs_ovl

DEFC _saveload_save_nczs_ovl_entry = _saveload_save_nczs_ovl

DEFC _saveload_erase_nczs_ovl_entry = _saveload_erase_nczs_ovl
