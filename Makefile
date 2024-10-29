DEBUG = 0
FINALPACKAGE = 1

TARGET := iphone:clang:16.5:15.0
INSTALL_TARGET_PROCESSES = SpringBoard

THEOS_PACKAGE_SCHEME = rootless

THEOS_DEVICE_IP = 192.168.1.26

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Griddy

Griddy_FILES = Tweak.x $(wildcard *.m)
Griddy_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
