SECTION code_user

PUBLIC _status_phase_ovl_entry

EXTERN _status_phase_ovl

    DEFB 1
    DW _status_phase_ovl_entry

DEFC _status_phase_ovl_entry = _status_phase_ovl
