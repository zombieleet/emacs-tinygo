EMACS ?= emacs
EMACS_BATCH = $(EMACS) -Q --batch -L . -L test

.PHONY: test lint check clean

test:
	$(EMACS_BATCH) -l test/tinygo-test.el -f ert-run-tests-batch-and-exit

lint:
	$(EMACS) -Q --batch -L . --eval '(progn (require (quote tinygo)) (checkdoc-file "tinygo.el"))'
	$(EMACS) -Q --batch -L . --eval '(byte-compile-file "tinygo.el")'
	rm -f tinygo.elc

check: test lint

clean:
	rm -f tinygo.elc
