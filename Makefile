APP     := CmdTabMaximizer
SWIFT   := swiftc
FLAGS   := -O -framework Cocoa -framework ApplicationServices
SRC     := $(APP).swift
DIST    := dist

.PHONY: all universal arm64 x86_64 clean install uninstall

all: universal

arm64:
	@mkdir -p $(DIST)
	$(SWIFT) $(FLAGS) -target arm64-apple-macosx11.0 $(SRC) -o $(DIST)/$(APP)-arm64

x86_64:
	@mkdir -p $(DIST)
	$(SWIFT) $(FLAGS) -target x86_64-apple-macosx11.0 $(SRC) -o $(DIST)/$(APP)-x86_64

universal: arm64 x86_64
	lipo -create -output $(DIST)/$(APP) $(DIST)/$(APP)-arm64 $(DIST)/$(APP)-x86_64
	rm $(DIST)/$(APP)-arm64 $(DIST)/$(APP)-x86_64
	@echo "Built universal binary: $(DIST)/$(APP)"

clean:
	rm -rf $(DIST) .build

# ── local install ──────────────────────────────────────────────────────────────
INSTALL_BIN  := /usr/local/bin/$(APP)
PLIST_SRC    := com.cmdtabmaximizer.plist
PLIST_DST    := $(HOME)/Library/LaunchAgents/$(PLIST_SRC)

install: universal
	cp $(DIST)/$(APP) $(INSTALL_BIN)
	@# Stamp the binary path into the plist, then install it.
	sed "s|__BINARY__|$(INSTALL_BIN)|g" $(PLIST_SRC) > $(PLIST_DST)
	launchctl load -w $(PLIST_DST)
	@echo "Installed and started. $(APP) will launch automatically on login."

uninstall:
	-launchctl unload -w $(PLIST_DST) 2>/dev/null
	-rm -f $(INSTALL_BIN) $(PLIST_DST)
	@echo "Uninstalled."
