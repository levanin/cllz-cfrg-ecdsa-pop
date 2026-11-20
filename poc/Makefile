SAGEFILES := $(basename $(notdir $(wildcard *.sage)))
PYFILES := $(addprefix sagelib/, $(addsuffix .py,$(SAGEFILES)))
.PRECIOUS: $(PYFILES)

.PHONY: setup pyfiles test test-fast clean distclean

setup: pyfiles

pyfiles: sagelib/__init__.py $(PYFILES)

sagelib/__init__.py:
	mkdir -p sagelib
	echo pass > sagelib/__init__.py

sagelib/%.py: %.sage
	@echo "Parsing $<"
	@sage --preparse $<
	@mv $<.py $@

test: pyfiles
	sage -python -m sagelib.test_pop

# 16 SM repetitions: quick functional check (NOT the recommended security level)
test-fast: pyfiles
	POP_LAMBDA=16 sage -python -m sagelib.test_pop

clean:
	rm -rf sagelib *.pyc *.sage.py

distclean: clean
