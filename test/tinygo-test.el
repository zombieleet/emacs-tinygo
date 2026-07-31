;;; tinygo-test.el --- Tests for tinygo.el -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'tinygo)

(defvar lsp-mode nil)

(ert-deftest tinygo-info-value-parses-info-output ()
  (let ((info "GOOS:              linux\nGOARCH:            arm\nbuild tags:        avr baremetal tinygo\ncached GOROOT:     /tmp/tinygo\n"))
    (should (equal (tinygo--info-value "GOOS" info) "linux"))
    (should (equal (tinygo--info-value "GOARCH" info) "arm"))
    (should (equal (tinygo--info-value "build tags" info) "avr baremetal tinygo"))
    (should (equal (tinygo--info-value "cached GOROOT" info) "/tmp/tinygo"))))

(ert-deftest tinygo-info-value-keeps-values-beginning-with-t ()
  ;; Regression: the separator was written "[ \\t]", which is the class
  ;; [space backslash t], so any value starting with `t' lost that letter.
  ;; This is not hypothetical -- the first build tag is `tinygo.wasm' for
  ;; the wasm target and `tinygo.riscv' for the ESP32-C3 ones, and the
  ;; mangled tag made gopls resolve a different implementation file.
  (let ((info (concat "GOOS:              js\n"
                      "GOARCH:            wasm\n"
                      "build tags:        tinygo.wasm tinygo purego\n"
                      "cached GOROOT:     /tmp/root\n")))
    (should (equal (tinygo--info-value "build tags" info)
                   "tinygo.wasm tinygo purego"))))

(ert-deftest tinygo-info-value-handles-tab-separated-output ()
  (let ((info "GOOS:\t\tlinux\nbuild tags:\ttinygo baremetal\n"))
    (should (equal (tinygo--info-value "GOOS" info) "linux"))
    (should (equal (tinygo--info-value "build tags" info) "tinygo baremetal"))))

(ert-deftest tinygo-info-value-returns-nil-for-absent-labels ()
  (should-not (tinygo--info-value "cached GOROOT" "GOOS: linux\n")))

(ert-deftest tinygo-environment-preserves-the-leading-build-tag ()
  (let ((tinygo--environment-cache (make-hash-table :test #'equal))
        (tinygo-command "tinygo"))
    (cl-letf (((symbol-function 'tinygo--info)
               (lambda (_) (concat "GOOS: js\nGOARCH: wasm\n"
                                   "build tags: tinygo.wasm tinygo purego\n"
                                   "cached GOROOT: /tmp/root\n"))))
      (should (member "GOFLAGS=-tags=tinygo.wasm,tinygo,purego"
                      (tinygo--environment-for-target "wasm"))))))

(ert-deftest tinygo-environment-survives-missing-goos-and-goarch ()
  ;; Only GOROOT and the build tags are specified by TinyGo's IDE guidance,
  ;; so a release that renames or drops the GOOS/GOARCH lines should cost
  ;; word-size accuracy, not the whole language server.
  (let ((tinygo--environment-cache (make-hash-table :test #'equal))
        (tinygo-command "tinygo"))
    (cl-letf (((symbol-function 'tinygo--info)
               (lambda (_) "build tags: tinygo baremetal\ncached GOROOT: /tmp/root\n")))
      (should (equal (tinygo--environment-for-target "pico")
                     '("GOROOT=/tmp/root" "GOFLAGS=-tags=tinygo,baremetal"))))))

(ert-deftest tinygo-environment-requires-goroot-and-tags ()
  (let ((tinygo--environment-cache (make-hash-table :test #'equal))
        (tinygo-command "tinygo"))
    (cl-letf (((symbol-function 'tinygo--info)
               (lambda (_) "GOOS: linux\nGOARCH: arm\n")))
      (should-error (tinygo--environment-for-target "pico") :type 'user-error))))

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

(ert-deftest tinygo-eglot-contact-accepts-eglot-context-arguments ()
  (cl-letf (((symbol-function 'tinygo--server-command)
             (lambda () '("env" "GOOS=linux" "gopls"))))
    (should (equal (tinygo--eglot-contact nil 'project)
                   '("env" "GOOS=linux" "gopls")))))

(ert-deftest tinygo-set-target-validates-and-restarts-eglot ()
  (let ((tinygo--project-targets (make-hash-table :test #'equal))
        (validated nil)
        (shutdown nil)
        (started nil))
    (cl-letf (((symbol-function 'tinygo--project-key) (lambda (&optional _) "/project/"))
              ((symbol-function 'tinygo--environment-for-target)
               (lambda (target) (setq validated target) '("GOOS=linux")))
              ((symbol-function 'tinygo--set-project-target)
               (lambda (target) (puthash "/project/" target tinygo--project-targets)))
              ((symbol-function 'eglot-current-server) (lambda () 'server))
              ((symbol-function 'eglot-shutdown) (lambda (server) (setq shutdown server)))
              ((symbol-function 'tinygo-eglot-ensure) (lambda () (setq started t))))
      (tinygo-set-target "  pico  ")
      (should (equal validated "pico"))
      (should (equal (gethash "/project/" tinygo--project-targets) "pico"))
      (should (eq shutdown 'server))
      (should started))))

(ert-deftest tinygo-restart-passes-each-lsp-mode-workspace ()
  (let ((restarted nil))
    (cl-letf (((symbol-value 'lsp-mode) t)
              ((symbol-function 'eglot-current-server) (lambda () nil))
              ((symbol-function 'lsp-workspaces) (lambda () '(one two)))
              ((symbol-function 'lsp-workspace-restart)
               (lambda (workspace) (push workspace restarted))))
      (should (eq (tinygo--restart-active-lsp) 'lsp-mode))
      (should (equal (nreverse restarted) '(one two))))))

(ert-deftest tinygo-project-selection-overrides-target-file ()
  (let ((tinygo--project-targets (make-hash-table :test #'equal))
        (tinygo-target nil))
    (puthash "/project/" "pico" tinygo--project-targets)
    (cl-letf (((symbol-function 'tinygo--project-key) (lambda (&optional _) "/project/"))
              ((symbol-function 'tinygo--file-target) (lambda (_) "arduino")))
      (should (equal (tinygo-current-target "/project/src/") "pico")))))

(ert-deftest tinygo-ensure-honors-explicit-client-selection ()
  (let ((tinygo-lsp-client 'eglot)
        (started nil))
    (cl-letf (((symbol-function 'tinygo-eglot-ensure)
               (lambda () (setq started 'eglot)))
              ((symbol-function 'tinygo-lsp-ensure)
               (lambda () (setq started 'lsp-mode))))
      (tinygo-ensure)
      (should (eq started 'eglot)))))

(ert-deftest tinygo-ensure-auto-respects-active-lsp-mode ()
  (let ((tinygo-lsp-client 'auto)
        (started nil))
    (cl-letf (((symbol-value 'lsp-mode) t)
              ((symbol-function 'eglot-current-server) (lambda () nil))
              ((symbol-function 'tinygo-eglot-ensure)
               (lambda () (setq started 'eglot)))
              ((symbol-function 'tinygo-lsp-ensure)
               (lambda () (setq started 'lsp-mode))))
      (tinygo-ensure)
      (should (eq started 'lsp-mode)))))

(ert-deftest tinygo-auto-ensure-starts-only-marked-projects ()
  (let ((tinygo-auto-start t)
        (marked t)
        (validated nil)
        (started 0))
    (cl-letf (((symbol-function 'tinygo-project-p) (lambda (&optional _) marked))
              ((symbol-function 'tinygo-current-target) (lambda (&optional _) "pico"))
              ((symbol-function 'tinygo--environment-for-target)
               (lambda (target) (setq validated target)))
              ((symbol-function 'tinygo-ensure)
               (lambda () (setq started (1+ started)))))
      (tinygo-auto-ensure)
      (should (equal validated "pico"))
      (should (= started 1))
      (setq marked nil
            validated nil)
      (tinygo-auto-ensure)
      (should-not validated)
      (should (= started 1)))))

(ert-deftest tinygo-installs-automatic-go-hooks ()
  (should (memq #'tinygo-auto-ensure go-mode-hook))
  (should (memq #'tinygo-auto-ensure go-ts-mode-hook)))

(ert-deftest tinygo-global-target-does-not-claim-ordinary-go-projects ()
  ;; The lsp-mode client outranks the stock Go client, so activating on a
  ;; global `tinygo-target' would silently take over every Go project.
  (let ((tinygo--project-targets (make-hash-table :test #'equal)))
    (cl-letf (((symbol-function 'tinygo--file-target) (lambda (_) nil))
              ((symbol-function 'tinygo--project-key) (lambda (&optional _) "/plain/")))
      (setq-default tinygo-target "pico")
      (unwind-protect
          (progn
            (should-not (tinygo-target-configured-p))
            (should-not (tinygo--lsp-mode-activate-p))
            ;; An explicit command still honours the global default.
            (should (equal (tinygo-current-target) "pico")))
        (setq-default tinygo-target nil)))))

(ert-deftest tinygo-target-configured-p-accepts-project-scoped-sources ()
  (let ((tinygo--project-targets (make-hash-table :test #'equal)))
    (cl-letf (((symbol-function 'tinygo--project-key) (lambda (&optional _) "/project/")))
      ;; A .tinygo-target file counts.
      (cl-letf (((symbol-function 'tinygo--file-target) (lambda (_) "pico")))
        (should (tinygo-target-configured-p)))
      ;; So does an interactive selection.
      (cl-letf (((symbol-function 'tinygo--file-target) (lambda (_) nil)))
        (should-not (tinygo-target-configured-p))
        (puthash "/project/" "arduino" tinygo--project-targets)
        (should (tinygo-target-configured-p))))))

(ert-deftest tinygo-environment-alist-splits-on-the-first-equals ()
  ;; GOFLAGS values contain `=', so a naive split would truncate them.
  (cl-letf (((symbol-function 'tinygo--environment-for-target)
             (lambda (_) '("GOROOT=/tmp/root" "GOFLAGS=-tags=a,b"))))
    (should (equal (tinygo-environment-alist "pico")
                   '(("GOROOT" . "/tmp/root")
                     ("GOFLAGS" . "-tags=a,b"))))))

(ert-deftest tinygo-server-command-omits-env-wrapper-when-unavailable ()
  (cl-letf (((symbol-function 'tinygo-current-target) (lambda (&optional _) "pico"))
            ((symbol-function 'tinygo--environment-for-target)
             (lambda (_) '("GOROOT=/tmp/root")))
            ((symbol-function 'tinygo--env-wrapper-available-p) (lambda () nil)))
    (let ((tinygo-lsp-server-command '("gopls")))
      (should (equal (tinygo--server-command) '("gopls"))))))

(ert-deftest tinygo-with-environment-binds-process-environment ()
  (cl-letf (((symbol-function 'tinygo--environment-for-target)
             (lambda (_) '("GOROOT=/tmp/root"))))
    (should (member "GOROOT=/tmp/root"
                    (tinygo--with-environment "pico" process-environment)))
    ;; and does not leak outside the form
    (should-not (member "GOROOT=/tmp/root" process-environment))))

(ert-deftest tinygo-project-p-finds-parent-target-marker ()
  (let* ((root (make-temp-file "tinygo-project-" t))
         (child (expand-file-name "cmd/blink" root)))
    (unwind-protect
        (progn
          (make-directory child t)
          (with-temp-file (expand-file-name ".tinygo-target" root)
            (insert "pico\n"))
          (should (tinygo-project-p child)))
      (delete-directory root t))))

;;; tinygo-test.el ends here
