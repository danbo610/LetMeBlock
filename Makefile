# RootHide / rootless / rootful via THEOS_PACKAGE_SCHEME
THEOS_PACKAGE_SCHEME ?= roothide
export THEOS_PACKAGE_SCHEME
export ARCHS = arm64 arm64e

PACKAGE_VERSION = 1.3.0
TARGET = iphone:clang:latest:14.0
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LetMeBlock
$(TWEAK_NAME)_FILES = Tweak.xm
$(TWEAK_NAME)_LIBRARIES = sandy
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -Ivendor/include
$(TWEAK_NAME)_LDFLAGS = -Lvendor/lib

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 mDNSResponder; killall -9 mDNSResponderHelper || true"
