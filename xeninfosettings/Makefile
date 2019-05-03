include $(THEOS)/makefiles/common.mk
ARCHS = armv7 armv7s arm64 arm64e
BUNDLE_NAME = XenInfoSettings
XenInfoSettings_FILES = XISRootListController.m
XenInfoSettings_INSTALL_PATH = /Library/PreferenceBundles
XenInfoSettings_FRAMEWORKS = UIKit
XenInfoSettings_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/XenInfoSettings.plist$(ECHO_END)
