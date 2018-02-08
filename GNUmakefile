# until we know what, if anything, is parallelizable, avoid it...
#
.NOTPARALLEL:

basedir := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
make_helpers_path := $(basedir)/make-helpers
precheck := $(shell perl $(make_helpers_path)/precheck.pl 2>&1)
ifdef precheck
  $(error precheck failed: $(precheck))
endif

# Read in some common utils
#
include $(make_helpers_path)/utils.gmk

# Prepare OS specifics
#
include $(make_helpers_path)/settings.gmk

# Define the targets
#
include $(make_helpers_path)/targets.gmk

# Fallback to trap any targets we don't know about
#
%::
	$(at)$(call $(func_echo),Sorry$(comma) the target $(intquote)$@$(intquote) is unknown.)
	$(at)exit 1
