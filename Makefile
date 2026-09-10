.PHONY: shellcheck

shellcheck:
	shellcheck -x snap-guest base-rhel10.local.sh
