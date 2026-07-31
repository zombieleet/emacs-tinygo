;;; tinygo-test.el --- Tests for tinygo.el -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'tinygo)

(ert-deftest tinygo-info-value-parses-info-output ()
  (let ((info "GOOS:              linux\nGOARCH:            arm\nbuild tags:        avr baremetal tinygo\ncached GOROOT:     /tmp/tinygo\n"))
    (should (equal (tinygo--info-value "GOOS" info) "linux"))
    (should (equal (tinygo--info-value "GOARCH" info) "arm"))
    (should (equal (tinygo--info-value "build tags" info) "avr baremetal tinygo"))
    (should (equal (tinygo--info-value "cached GOROOT" info) "/tmp/tinygo"))))

(ert-deftest tinygo-environment-uses-tinygo-info ()
  (let ((tinygo--environment-cache (make-hash-table :test #'equal))
        (tinygo-command "tinygo"))
    (cl-letf (((symbol-function 'tinygo--info)
               (lambda (_) "GOOS: linux\nGOARCH: arm\nbuild tags: one two\ncached GOROOT: /tmp/root\n")))
      (should (equal (tinygo--environment-for-target "arduino")
                     '("GOROOT=/tmp/root" "GOOS=linux" "GOARCH=arm"
                       "GOFLAGS=-tags=one,two"))))))

(ert-deftest tinygo-server-command-wraps-configured-server ()
  (let ((tinygo-lsp-server-command '("gopls" "-remote=auto")))
    (cl-letf (((symbol-function 'tinygo-current-target) (lambda () "pico"))
              ((symbol-function 'tinygo--environment-for-target)
               (lambda (_) '("GOROOT=/tmp/root" "GOOS=linux"))))
      (should (equal (tinygo--server-command)
                     '("env" "GOROOT=/tmp/root" "GOOS=linux" "gopls" "-remote=auto"))))))

(ert-deftest tinygo-ensure-honors-explicit-client-selection ()
  (let ((tinygo-lsp-client 'eglot)
        (started nil))
    (cl-letf (((symbol-function 'tinygo-eglot-ensure)
               (lambda () (setq started 'eglot)))
              ((symbol-function 'tinygo-lsp-ensure)
               (lambda () (setq started 'lsp-mode))))
      (tinygo-ensure)
      (should (eq started 'eglot)))))

;;; tinygo-test.el ends here
