include $(THEOS)/makefiles/common.mk

export TARGET = iphone:10.1
export ARCHS = armv7 armv7s arm64

TWEAK_NAME = XenInfo
XenInfo_FILES = Tweak/Tweak.xm Tweak/Internal/XIWidgetManager.m Tweak/System/XISystem.m Tweak/Music/XIMusic.m Tweak/Weather/XIWeather.m Tweak/Battery/XIInfoStats.m Tweak/Events/XIEvents.m Tweak/Reminders/XIReminders.m Tweak/Alarms/XIAlarms.m Tweak/Statusbar/XIStatusBar.m
XenInfo_LDFLAGS += -Wl,-segalign,4000
XenInfo_FRAMEWORKS = UIKit
XenInfo_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
