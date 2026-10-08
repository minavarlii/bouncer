APP := build/Bouncer.app

.PHONY: build run clean

build:
	swift build -c release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp .build/release/Bouncer $(APP)/Contents/MacOS/Bouncer
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	codesign --force --sign - $(APP)

run: build
	open $(APP)

clean:
	rm -rf .build build
