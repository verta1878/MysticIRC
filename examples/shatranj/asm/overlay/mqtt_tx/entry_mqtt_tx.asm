SECTION code_user

EXTERN _mqtt_tx_send_text_ovl
EXTERN _mqtt_tx_publish_setup_ovl
EXTERN _mqtt_tx_sync_time_ovl
EXTERN _mqtt_tx_publish_presence_ovl

    DEFB 4
    DW _mqtt_tx_send_text_ovl_entry
    DW _mqtt_tx_publish_setup_ovl_entry
    DW _mqtt_tx_sync_time_ovl
    DW _mqtt_tx_publish_presence_ovl

DEFC _mqtt_tx_send_text_ovl_entry = _mqtt_tx_send_text_ovl

DEFC _mqtt_tx_publish_setup_ovl_entry = _mqtt_tx_publish_setup_ovl
