BASE_DIR=$(shell pwd)
SOURCE_ORG_FILES=$(BASE_DIR)/notes
EMACS_BUILD_DIR=/tmp/notes-home-build/
BUILD_DIR=/tmp/notes-home-build/.cache/org-persist/
HUGO_SECTION=notes
LOG_FILE=$(BASE_DIR)/conversion.log

all: org2hugo

.PHONY: clean
clean:
	rm -rf $(EMACS_BUILD_DIR)
	rm -rf $(BUILD_DIR)
	rm -f $(LOG_FILE)

.PHONY: org2hugo
org2hugo: clean
	@echo "Starting org to hugo conversion..."
	@echo "Using source directory: $(SOURCE_ORG_FILES)"
	@echo "Using build directory: $(EMACS_BUILD_DIR)"
	mkdir -p $(BUILD_DIR)
	cp -r $(BASE_DIR)/init.el $(EMACS_BUILD_DIR)
	@# Build temporary minimal EMACS installation separate from the one in the machine.
	@( \
		HOME=$(EMACS_BUILD_DIR) \
		NOTES_ORG_SRC=$(SOURCE_ORG_FILES) \
		HUGO_SECTION=$(HUGO_SECTION) \
		HUGO_BASE_DIR=$(BASE_DIR) \
		emacs -Q --batch \
			--load $(EMACS_BUILD_DIR)/init.el \
			--execute "(build/export-all)" \
			--kill \
	) 2>&1 | tee $(LOG_FILE); \
	exit_code=$${PIPESTATUS[0]}; \
	if [ $$exit_code -ne 0 ]; then \
		echo "Error: Emacs process failed with exit code $$exit_code"; \
		echo "Check $(LOG_FILE) for details"; \
		exit $$exit_code; \
	fi
	@echo "Conversion complete. Check $(LOG_FILE) for details."
