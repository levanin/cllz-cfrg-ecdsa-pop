# Build the Internet-Draft from kramdown-rfc markdown.
#
# Source:   draft.md
# Outputs:  build/draft.xml, build/draft.txt, build/draft.html
#
# Quick start:
#   make            # build text + html into build/
#   make txt        # build only build/draft.txt
#   make clean      # remove generated documents (keeps the reference cache)
#   make distclean  # remove the entire build/ directory
#
# See README.md for how to install the required tools (kramdown-rfc, xml2rfc).

DRAFT := draft-cllz-cfrg-ecdsa-pop
BUILD := build

# Common install locations for the tools (Homebrew Ruby gems, user pip). These
# are harmless on systems where they do not exist; adjust in README.md if your
# install locations differ.
GEM_BIN    := $(wildcard /opt/homebrew/lib/ruby/gems/*/bin)
PYUSER_BIN := $(wildcard $(HOME)/Library/Python/*/bin)
export PATH := /opt/homebrew/opt/ruby/bin:$(GEM_BIN):$(PYUSER_BIN):$(PATH)

# Tools. Resolve to an absolute path when found in the locations above (so the
# build does not depend on PATH lookup), otherwise fall back to the bare command
# name found on PATH. Override on the command line if installed elsewhere, e.g.
#   make XML2RFC=/path/to/xml2rfc
KRAMDOWN_RFC ?= $(firstword $(wildcard $(GEM_BIN)/kramdown-rfc) kramdown-rfc)
XML2RFC      ?= $(firstword $(wildcard $(PYUSER_BIN)/xml2rfc) xml2rfc)

# Keep the kramdown-rfc reference cache inside build/ so the tree stays clean.
export KRAMDOWN_REFCACHEDIR := $(BUILD)/refcache

.PHONY: all txt html xml clean distclean

all: txt html

xml:  $(BUILD)/$(DRAFT).xml
txt:  $(BUILD)/$(DRAFT).txt
html: $(BUILD)/$(DRAFT).html

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/$(DRAFT).xml: $(DRAFT).md | $(BUILD)
	$(KRAMDOWN_RFC) $< > $@

$(BUILD)/$(DRAFT).txt: $(BUILD)/$(DRAFT).xml
	$(XML2RFC) $< -o $@ --text

$(BUILD)/$(DRAFT).html: $(BUILD)/$(DRAFT).xml
	$(XML2RFC) $< -o $@ --html

# Remove generated documents but keep build/refcache to avoid re-fetching
# references over the network on the next build.
clean:
	rm -f $(BUILD)/$(DRAFT).xml $(BUILD)/$(DRAFT).txt $(BUILD)/$(DRAFT).html

distclean:
	rm -rf $(BUILD)
