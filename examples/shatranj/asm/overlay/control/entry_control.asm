SECTION code_user
EXTERN _control_classify_ovl
    DEFB 1
    DW _control_classify_ovl_entry
DEFC _control_classify_ovl_entry = _control_classify_ovl
