SECTION code_user

EXTERN _rules_play_ovl
EXTERN _rules_check_ovl
EXTERN _rules_hints_ovl
EXTERN _rules_hints_clear_ovl

    DEFB 4
    DW _rules_play_ovl
    DW _rules_check_ovl
    DW _rules_hints_ovl
    DW _rules_hints_clear_ovl
