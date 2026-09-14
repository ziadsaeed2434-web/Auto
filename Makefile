ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = GestureRecorder
GestureRecorder_FILES = Tweak.xm GestureRecorder.m PTFakeTouch/PTFakeTouch.m
GestureRecorder_CFLAGS = -fobjc-arc -I.
GestureRecorder_FRAMEWORKS = UIKit Foundation QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
