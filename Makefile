.PHONY: help bootstrap run theme clean

THEME ?= night-owl

help:
	@echo "Targets:"
	@echo "  make bootstrap        Full setup + interactive theme selection"
	@echo "  make run              Alias for make bootstrap"
	@echo "  make theme THEME=...  Apply theme only (non-interactive)"
	@echo "  make clean            Remove temporary bootstrap test dirs"

bootstrap:
	./bootstrap.sh

run: bootstrap

theme:
	./bootstrap.sh --theme "$(THEME)" --theme-only --yes

clean:
	rm -rf .tmp-*
