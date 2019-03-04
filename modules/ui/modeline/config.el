;;; ui/modeline/config.el -*- lexical-binding: t; -*-

;; TODO Add themes (default, minimal, spacemacs, etc)

(def-package! doom-modeline
  :hook (doom-post-init . doom-modeline-mode)
  :preface
  ;; prevent flash of unstyled modeline at startup
  (setq-default mode-line-format nil)
  ;; We display project info in the modeline ourselves
  (setq projectile-dynamic-mode-line nil)
  :init
  (setq doom-modeline-bar-width 3
        doom-modeline-github nil
        doom-modeline-mu4e nil
        doom-modeline-persp-name nil
        doom-modeline-checker-simple-format nil
        doom-modeline-minor-modes nil
        doom-modeline-major-mode-icon nil
        doom-modeline-buffer-file-name-style 'relative-from-project)

  (add-hook 'doom-modeline-mode-hook #'size-indication-mode) ; filesize in modeline
  (add-hook 'doom-modeline-mode-hook #'column-number-mode)   ; cursor column in modeline

  :config
  (add-hook 'doom-big-font-mode-hook #'+modeline|resize-for-big-font)

  (add-hook 'doom-load-theme-hook #'doom-modeline-refresh-bars)
  (add-hook '+doom-dashboard-mode-hook #'doom-modeline-set-project-modeline)

  ;; Show indentation style in modeline. I'm not using
  ;; `doom-modeline-def-segment' to prevent eager macro expansion from loading
  ;; the package too soon.
  (defun +modeline-indent-segment ()
    "indent modeline segment"
    (propertize (format "%s%d"
                        (if indent-tabs-mode "⭾" "␣")
                        tab-width)
                'mouse-face 'mode-line-highlight
                'help-echo
                (mapconcat #'identity
                           (list (format "Indentation style: %s (%d wide)"
                                         (if indent-tabs-mode "tabs" "spaces")
                                         tab-width)
                                 (if (eq doom-inhibit-indent-detection 'editorconfig)
                                     (propertize "✓ Editorconfig applied" 'face 'success)
                                   (propertize "✘ Indentation auto-detection disabled" 'face 'warning))
                                 (when (bound-and-true-p ws-butler-mode)
                                   (propertize "✓ ws-butler active (whitespace cleanup on save)"
                                               'face 'success))
                                 (when (bound-and-true-p dtrt-indent-original-indent)
                                   (propertize (format "✓ Indentation auto-detected (original: %s)"
                                                       dtrt-indent-original-indent)
                                               'face 'success)))
                           "   ")))
  (add-to-list 'doom-modeline-fn-alist '(indent . +modeline-indent-segment))

  ;; Remove unused segments & extra padding
  (doom-modeline-def-modeline 'main
    '(bar matches buffer-info remote-host buffer-position selection-info)
    '(misc-info persp-name irc mu4e github debug indent input-method buffer-encoding lsp major-mode process vcs checker))

  (doom-modeline-def-modeline 'special
    '(bar matches buffer-info-simple buffer-position selection-info)
    '(misc-info persp-name debug input-method irc-buffers buffer-encoding lsp major-mode process checker))

  (doom-modeline-def-modeline 'project
    '(bar buffer-default-directory)
    '(misc-info mu4e github debug fancy-battery " " major-mode))

  ;; Some functions modify the buffer, causing the modeline to show a false
  ;; modified state, so we try to force them to behave.
  (defun +modeline*inhibit-modification-hooks (orig-fn &rest args)
    (with-silent-modifications (apply orig-fn args)))
  (advice-add #'ws-butler-after-save :around #'+modeline*inhibit-modification-hooks)
  (add-hook 'evil-insert-state-exit-hook #'doom-modeline-update-buffer-file-name)
  (add-hook 'evil-insert-state-exit-hook #'doom-modeline-update-buffer-file-state-icon))


;;
;; Extensions

(def-package! anzu
  :after-call isearch-mode)

(def-package! evil-anzu
  :when (featurep! :feature evil)
  :after-call (evil-ex-start-search evil-ex-start-word-search))
