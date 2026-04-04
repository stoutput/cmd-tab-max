APP   := CmdTabMaximizer
SWIFT := swiftc
FLAGS := -O -framework Cocoa -framework ApplicationServices
SRC   := $(APP).swift
DIST  := dist

.PHONY: all universal arm64 x86_64 clean install uninstall

all: universal

$(DIST):
	mkdir -p $@

$(DIST)/$(APP)-arm64: $(SRC) | $(DIST)
	$(SWIFT) $(FLAGS) -target arm64-apple-macosx11.0 $(SRC) -o $@

$(DIST)/$(APP)-x86_64: $(SRC) | $(DIST)
	$(SWIFT) $(FLAGS) -target x86_64-apple-macosx11.0 $(SRC) -o $@

$(DIST)/$(APP): $(DIST)/$(APP)-arm64 $(DIST)/$(APP)-x86_64
	lipo -create -output $@ $^
	rm $(DIST)/$(APP)-arm64 $(DIST)/$(APP)-x86_64
	@echo "Built universal binary: $@"

arm64:   $(DIST)/$(APP)-arm64
x86_64:  $(DIST)/$(APP)-x86_64
universal: $(DIST)/$(APP)

clean:
	rm -rf $(DIST)

# ── local install ──────────────────────────────────────────────────────────────
INSTALL_BIN := /usr/local/bin/$(APP)
PLIST_SRC   := com.stoutput.cmdtabmax.plist
PLIST_DST   := $(HOME)/Library/LaunchAgents/$(PLIST_SRC)
LAUNCHD_UID := gui/$$(id -u)

install: universal
	cp $(DIST)/$(APP) $(INSTALL_BIN)
	sed "s|__BINARY__|$(INSTALL_BIN)|g" $(PLIST_SRC) > $(PLIST_DST)
	launchctl bootstrap $(LAUNCHD_UID) $(PLIST_DST)
	@echo "Installed. $(APP) is running and will start automatically on login."

uninstall:
	-launchctl bootout $(LAUNCHD_UID) $(PLIST_DST) 2>/dev/null
	-rm -f $(INSTALL_BIN) $(PLIST_DST)
	@echo "Uninstalled."
