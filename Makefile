#COMMON_CONF = apache-credit

CREDIT_ANCHORTEXT = Processwire Appliance
#define CREDIT_STYLE_EXTRA
#body.wp-admin #turnkey-credit, body#image #turnkey-credit, body#media-upload #turnkey-credit { 
#	display: none; 
#}
#endef

include $(FAB_PATH)/common/mk/turnkey/lamp.mk
include $(FAB_PATH)/common/mk/turnkey/composer.mk
include $(FAB_PATH)/common/mk/turnkey.mk
