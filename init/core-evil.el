(provide 'core-evil)

;;;; Eeeeeeevil ;;;;;;;;;;;;;;;;;;;;;;;;
(use-package evil
  :pre-load
  (setq evil-want-visual-char-semi-exclusive t
        evil-search-module        'evil-search
        evil-magic                'very-magic
        evil-want-C-u-scroll      t  ; enable C-u for scrolling
        evil-ex-visual-char-range t  ; column range for ex commands

        ;; Color-coded state cursors
        evil-normal-state-cursor  '("white" box)
        evil-emacs-state-cursor   '("cyan" bar)
        evil-insert-state-cursor  '("white" bar)
        evil-god-state-cursor     '("orange" box)
        evil-visual-state-cursor  'hollow

        ace-jump-mode-scope     'window
        ace-jump-mode-move-keys (nconc (loop for i from ?a to ?z collect i)
                                       (loop for i from ?A to ?Z collect i)))
  :config
  (progn
    (evil-mode)
    ;; Always ensure evil-shift-width is consistent with tab-width
    (add-hook! 'find-file-hook (setq evil-shift-width tab-width))
    ;; highlight matching delimiters (only in insert mode)
    (add-hook 'evil-insert-state-entry-hook 'show-paren-mode)
    (add-hook 'evil-insert-state-exit-hook (λ (show-paren-mode -1)))
    ;; Disable highlights on insert-mode
    (add-hook 'evil-insert-state-entry-hook 'evil-ex-nohighlight)

    ;; Evil command window
    ;;(my/cleanup-buffers-add "^\\*Command Line\\*$")

    ;; modes to map to different default states
    (dolist (mode-map '((cider-repl-mode . emacs)
                        (comint-mode . emacs)
                        (fundamental-mode . normal)
                        (help-mode . normal)
                        (term-mode . emacs)))
      (evil-set-initial-state `,(car mode-map) `,(cdr mode-map)))

    (progn ; evil plugins
      (use-package evil-space :init (evil-space-default-setup))

      (use-package evil-exchange
        :config
        (defadvice evil-force-normal-state (before evil-esc-quit-exchange activate)
          (shut-up (evil-exchange-cancel))))

      (use-package evil-ex-registers)

      (use-package evil-indent-textobject)    ; vii/vai/vaI

      (use-package evil-numbers)

      (use-package evil-god-state)

      (use-package evil-matchit :init (global-evil-matchit-mode 1))

      (use-package evil-surround :init (global-evil-surround-mode 1))

      (use-package evil-nerd-commenter
        :pre-load (setq evilnc-hotkey-comment-operator "gc"))

      (use-package evil-jumper
        :pre-load (setq evil-jumper-file (expand-file-name "jumplist" my-tmp-dir))
        :config
        (progn
          (setq evil-jumper-auto-center t
                evil-jumper-auto-save-interval 3600)
          (define-key evil-motion-state-map (kbd "H-i") 'evil-jumper/forward)))

      (use-package ace-window)

      (use-package evil-visualstar))

    (bind evil-ex-completion-map
          "C-r"           #'evil-ex-paste-from-register   ; registers in ex-mode
          "C-a"            'move-beginning-of-line
          "<s-left>"       'move-beginning-of-line
          "<s-right>"      'move-beginning-of-line
          "<s-backspace>"  'evil-delete-whole-line)

    (progn ; evil hacks
      (defadvice evil-force-normal-state (before evil-esc-quit activate)
        (shut-up (evil-ex-nohighlight)        ; turn off highlights
                 ;; Exit minibuffer is alive
                 (if (minibuffer-window-active-p (minibuffer-window))
                     (my--minibuffer-quit))))

      ;; Popwin: close popup window, if any
      (after "popwin"
        (defadvice evil-force-normal-state (before evil-esc-quit-popwin activate)
          (shut-up (popwin:close-popup-window))))

      ;; Ace-Jump: Enable half-cursor blink when using ace-jump
      (defadvice evil-ace-jump-char-mode (before evil-ace-jump-char-mode-op activate)
        (evil-half-cursor))
      (defadvice evil-ace-jump-word-mode (before evil-ace-jump-word-mode-op activate)
        (evil-half-cursor))
      (setq aw-keys '(?a ?s ?d ?f ?g ?h ?j ?k ?l))
      ;; (setq ace-jump-mode-move-keys
      ;;       (nconc (loop for i from ?a to ?z collect i)
      ;;              (loop for i from ?A to ?Z collect i))

      ;; https://github.com/winterTTr/ace-jump-mode/issues/23
      (defun ace-jump-two-chars-mode (&optional query-char query-char-2)
        "AceJump two chars mode"
        (interactive)

        (evil-half-cursor)
        (setq query-char (or query-char (read-char ">")))
        (setq query-char-2 (or query-char-2 (read-char (concat ">" (string query-char)))))

        (if (eq (ace-jump-char-category query-char) 'other)
            (error "[AceJump] Non-printable character"))

        ;; others : digit , alpha, punc
        (setq ace-jump-query-char query-char)
        (setq ace-jump-current-mode 'ace-jump-char-mode)
        (ace-jump-do (regexp-quote (concat (char-to-string query-char)
                                           (char-to-string query-char-2)))))

      ;; Jump to new splits
      (defadvice evil-window-split (after evil-window-split-jump activate)
        (evil-window-down 1))
      (defadvice evil-window-vsplit (after evil-window-vsplit-jump activate)
        (evil-window-right 1)))

    (progn ; extensions
      (defun evil-visual-line-state-p ()
        "Returns non-nil if in visual-line mode, nil otherwise."
        (and (evil-visual-state-p)
             (eq (evil-visual-type) 'line)))

      (defun evil-ex-replace-special-filenames (file-name)
        "Replace special symbols in FILE-NAME.

    % => full path to file (/project/src/thing.c)
    # => alternative file path (/project/include/thing.h)
    %:p => path to project root (/project/)
    %:d => path to current directory (/project/src/)
    %:e => the file's extension (c)
    %:r => the full path without its extension (/project/src/thing)
    %:t => the file's basename (thing.c)"
        (let ((current-fname (buffer-file-name))
              (alternate-fname (and (other-buffer)
                                    (buffer-file-name (other-buffer)))))
          (setq file-name
                ;; %:p:h => the project root (or current directory otherwise)
                (replace-regexp-in-string "\\(^\\|[^\\\\]\\)\\(%:p\\)"
                                          (my--project-root) file-name t t 2))
          (setq file-name
                ;; %:p => the project root (or current directory otherwise)
                (replace-regexp-in-string "\\(^\\|[^\\\\]\\)\\(%:d\\)"
                                          default-directory file-name t t 2))
          (when current-fname
            (setq file-name
                  ;; %:e => ext
                  (replace-regexp-in-string "\\(^\\|[^\\\\]\\)\\(%:e\\)"
                                            (f-ext current-fname) file-name t t 2))
            (setq file-name
                  ;; %:r => filename
                  (replace-regexp-in-string "\\(^\\|[^\\\\]\\)\\(%:r\\)"
                                            (f-no-ext current-fname) file-name t t 2))
            (setq file-name
                  ;; %:t => filename.ext
                  (replace-regexp-in-string "\\(^\\|[^\\\\]\\)\\(%:t\\)"
                                            (f-base current-fname) file-name t t 2))
            (setq file-name
                  ;; % => file path for current frame
                  (replace-regexp-in-string "\\(^\\|[^\\\\]\\)\\(%\\)"
                                            current-fname file-name t t 2)))
          (when alternate-fname
            (setq file-name
                  ;; # => file path for alternative frame
                  (replace-regexp-in-string "\\(^\\|[^\\\\]\\)\\(#\\)"
                                            alternate-fname file-name t t 2)))
          (setq file-name
                (replace-regexp-in-string "\\\\\\([#%]\\)"
                                          "\\1" file-name t)))
        file-name))

    ;; (evil-ex-define-cmd "r[esize]" 'my:resize-window)

    (progn ; ex-commands
      (evil-ex-define-cmd "full[scr]" 'toggle-frame-fullscreen)
      (evil-ex-define-cmd "present" 'toggle-theme)
      (evil-ex-define-cmd "k[ill]" 'kill-this-buffer)      ; Kill current buffer
      (evil-ex-define-cmd "k[ill]o" 'cleanup-buffers)      ; Kill current project buffers

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

      (evil-ex-define-cmd "echo" 'my:echo)
      (evil-define-command my:echo (&optional output)
        (interactive "<a>")
        (message "%s" output))

      (evil-ex-define-cmd "k[ill]all" 'my:kill-buffers)    ; Kill all buffers (bang = project buffers only)
      (evil-define-command my:kill-buffers (&optional bang)
        :repeat nil
        (interactive "<!>")
        (if (and bang (projectile-project-p))
            (projectile-kill-buffers)
          (mapc 'kill-buffer (buffer-list)))
        (delete-other-windows))

      (evil-ex-define-cmd "ini" 'my:init-files)
      (evil-define-command my:init-files (&optional bang)
        :repeat nil
        (interactive "<!>")
        (if bang
            (ido-find-file-in-dir my-init-dir)
          (ido-find-file-in-dir my-dir)))

      (evil-ex-define-cmd "n[otes]" 'my:notes)
      (evil-define-command my:notes ()
        :repeat nil
        (interactive)
        (ido-find-file-in-dir org-directory))

      (evil-ex-define-cmd "recompile" 'my:byte-compile)
      (evil-define-command my:byte-compile (&optional bang)
        :repeat nil
        (interactive "<!>")
        (if bang
            (byte-recompile-directory (concat my-dir ".cask") 0 t)
          (byte-recompile-directory my-dir 0 t)))

      (evil-ex-define-cmd "build" 'my:build)
      (evil-define-command my:build (arguments &optional bang)
        :repeat t
        (interactive "<a><!>")
        (my-build arguments))

      (evil-ex-define-cmd "cd" 'my:cd)
      (evil-define-command my:cd (dir)
        :repeat nil
        (interactive "<f>")
        (cd (if (zerop (length dir)) "~" dir)))

      (defun --save-exit() (save-buffer) (kill-buffer) (remove-hook 'yas-after-exit-snippet-hook '--save-exit))
      (evil-ex-define-cmd "en[ew]" 'my:create-file)
      (evil-define-command my:create-file (path &optional bang)
        "Deploy files (and their associated templates) quickly. Will prompt
you to fill in each snippet field before buffer closes unless BANG is
provided."
        :repeat nil
        (interactive "<f><!>")
        (let ((dir (f-dirname path))
              (fullpath (f-full path))
              (is-auto t))
          (when (and bang (not (f-exists? dir))) (f-mkdir dir))
          (if (f-exists? dir)
              (if (f-exists? fullpath)
                  (error "File already exists: %s" path)
                (find-file fullpath)
                (add-hook 'yas-after-exit-snippet-hook '--save-exit)
                (if bang (--save-exit)))
            (error "Directory doesn't exist: %s" dir))))

      (evil-ex-define-cmd "ren[ame]" 'my:rename-this-file) ; Rename file . Bang: Delete old one
      (evil-define-command my:rename-this-file (new-name &optional bang)
        "Renames current buffer and file it is visiting. Replaces %, # and other
  variables (see `evil-ex-replace-special-filenames')"
        :repeat nil
        (interactive "<f><!>")
        (let ((name (buffer-name))
              (filename (buffer-file-name)))
          (if (not (and filename (file-exists-p filename)))
              (error "Buffer '%s' is not visiting a file!" name)
            (let ((new-name
                   (evil-ex-replace-special-filenames (if new-name
                                                          new-name
                                                        (read-file-name "New name: " filename)))))
              (if (get-buffer new-name)
                  (error "A buffer named '%s' already exists!" new-name)
                (rename-file filename new-name 1)
                (rename-buffer new-name)
                (set-visited-file-name new-name)
                (set-buffer-modified-p nil)
                (save-place-forget-unreadable-files)
                (when bang
                  (delete-file filename))
                (message "File '%s' successfully renamed to '%s'"
                         name (file-name-nondirectory new-name)))))))

      (evil-ex-define-cmd "x" 'my:scratch-buffer)
      (evil-define-operator my:scratch-buffer (beg end &optional bang)
        "Send a selection to the scratch buffer. If BANG, then send it to org-capture
  instead."
        :move-point nil
        :type inclusive
        (interactive "<r><!>")
        (let ((mode major-mode)
              (text (when (and (evil-visual-state-p) beg end)
                      (buffer-substring beg end))))
          (if bang
              ;; use org-capture with bang
              (if text
                  (org-capture-string text)
                (org-capture))
            ;; or scratch buffer by default
            (let ((project-dir (projectile-project-root))
                  (buffer-name (if (projectile-project-p)
                                   (format "*scratch* (%s)" (projectile-project-name))
                                 "*scratch*")))
              (popwin:popup-buffer (get-buffer-create buffer-name))
              (when (eq (get-buffer buffer-name) (current-buffer))
                (cd project-dir)
                (if text (insert text))
                (funcall mode))))))

      (evil-ex-define-cmd "al[ign]" 'my:align)
      (evil-define-command my:align (beg end &optional regexp bang)
        :repeat nil
        (interactive "<r><a><!>")
        (when regexp
          (align-regexp beg end
                        (concat "\\(\\s-*\\)" (rxt-pcre-to-elisp regexp)) 1 1)))

      (evil-ex-define-cmd "retab" 'my:retab)
      (evil-define-operator my:retab (beg end)
        "Akin to vim's :retab, this changes all tabs-to-spaces or spaces-to-tabs,
  depending on `indent-tab-mode'. Untested."
        :motion nil
        :move-point nil
        :type line
        (interactive "<r>")
        (unless (and beg end)
          (setq beg (point-min))
          (setq end (point-max)))
        (if indent-tabs-mode
            (tabify beg end)
          (untabify beg end)))

      (evil-ex-define-cmd "run" 'my:run-code)
      (evil-define-operator my:run-code (beg end)
        :move-point nil
        (interactive "<r>")
        (cond ((and beg end)
               (my-run-code-region beg end))
              (t
               (my-run-code-buffer))))

      (evil-ex-define-cmd "sq[uint]" 'my:narrow-indirect)  ; Narrow buffer to selection
      (evil-define-operator my:narrow-indirect (beg end)
        "Indirectly narrow the region from BEG to END."
        :move-point nil
        :type exclusive
        :repeat nil
        (interactive "<r>")
        (evil-normal-state)
        (narrow-to-region-indirect beg end))

      (evil-define-operator my:send-region-to-repl (beg end &optional bang)
        :motion nil
        :move-point nil
        :type exclusive
        :repeat nil
        (interactive "<r><!>")
        (cond ((and beg end)
               (my-send-region-to-repl beg end))
              (t
               (my-switch-to-repl)))))))
