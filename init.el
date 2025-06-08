;;; build.el --- Minimal emacs installation to build the website -*- lexical-binding: t -*-
;; Based on the one from Bruno Henirques: https://github.com/bphenriques/knowledge-base/blob/8fb31838fd3f682d602eeb269ee7d92eecbbb8dc/tools/init.el
;;
;;; Commentary:
;;; - Requires NOTES_BASE_ORG_SOURCE environment variable
;;; Code:

;; Performance optimizations
(setq gc-cons-threshold (* 50 1000 1000))
(setq read-process-output-max (* 1024 1024))

;; Debug settings
(setq debug-on-error t)
(toggle-debug-on-error)
(setq make-backup-files nil)

;; Load essential libraries
(require 'subr-x)
(require 'find-lisp)

;; Check required environment variables
(defun get-required-env (key)
  "Get environment variable KEY or error if not set."
  (let ((value (getenv key)))
    (message "Checking environment variable: %s = %s" key value)
    (unless value
      (error "Required environment variable %s is not set" key))
    (unless (file-directory-p value)
      (error "Directory specified in %s does not exist: %s" key value))
    value))

;; Set up directories with validation
(defconst notes-org-files
  (let ((dir (get-required-env "NOTES_ORG_SRC")))
    (message "Notes org files directory: %s" dir)
    dir))

(defconst hugo-base-dir
  (let ((dir (get-required-env "HUGO_BASE_DIR")))
    (message "Hugo base directory: %s" dir)
    dir))

(defconst hugo-section
  (let ((section (or (getenv "HUGO_SECTION") "notes")))
    (message "Hugo section: %s" section)
    section))

;; Setup straight.el
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el" user-emacs-directory))
      (bootstrap-version 5))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/raxod502/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

(setq straight-use-package-by-default t)
(straight-use-package 'use-package)

;; Load required packages
(use-package backtrace)
(use-package ox-hugo
  :straight (:type git :host github :repo "kaushalmodi/ox-hugo"))

;; Org mode configuration
(setq org-hugo-base-dir hugo-base-dir)
(setq org-hugo-section hugo-section)

;; Configure org-mode and ox-hugo settings
(setq org-hugo-auto-set-lastmod t
      org-hugo-use-code-for-kbd t
      org-hugo-date-format "%Y-%m-%d"
      org-hugo-suppress-lastmod-period 86400
      org-hugo-delete-trailing-ws t
      org-hugo-prefer-hyphen-in-tags t
      org-hugo-allow-spaces-in-tags nil)

(setq org-export-with-toc nil
      org-export-with-section-numbers nil
      org-export-time-stamp-file nil
      org-export-with-sub-superscripts '{})

;; Export function with improved error handling
(defun build/export-all ()
  "Export all org-files under notes-org-files to Hugo markdown."
  (message "\n=== Starting export process ===\n")
  (message "Source directory: %s" notes-org-files)
  (message "Hugo base directory: %s" org-hugo-base-dir)
  (message "Hugo section: %s" org-hugo-section)
  
  ;; Validate source directory
  (unless (file-directory-p notes-org-files)
    (error "Source directory does not exist: %s" notes-org-files))
  
  ;; Set up org-id extra files
  (let ((org-files (directory-files-recursively notes-org-files "\\.org$")))
    (setq org-id-extra-files org-files)
    
    (if (null org-files)
        (error "No .org files found in %s" notes-org-files)
      (message "\nFound %d files to process\n" (length org-files))
      
      ;; Process each org file
      (let ((success-count 0)
            (error-count 0)
            (error-files '()))
        (dolist (org-file org-files)
          (message "\nProcessing: %s" org-file)
          (condition-case err
              (progn
                (unless (file-readable-p org-file)
                  (error "File is not readable"))
                (with-current-buffer (find-file-noselect org-file)
                  (message "Exporting file: %s" (buffer-file-name))
                  ;; Set local variables for this buffer
                  (setq-local org-hugo-section hugo-section)
                  ;; Ensure we have a title
                  (unless (org-entry-get (point-min) "TITLE")
                    (let ((title (file-name-base org-file)))
                      (goto-char (point-min))
                      (insert (format "#+TITLE: %s\n" title))))
                  ;; Export the file
                  (org-hugo-export-to-md)
                  (kill-buffer))
                (setq success-count (1+ success-count))
                (message "Successfully exported: %s" org-file))
            (error
             (setq error-count (1+ error-count))
             (push (cons org-file (error-message-string err)) error-files)
             (message "Error processing %s: %s" org-file (error-message-string err)))))
        
        (message "\n=== Export Complete ===")
        (message "Successfully exported: %d files" success-count)
        (message "Failed to export: %d files" error-count)
        
        (when error-files
          (message "\nFiles with errors:")
          (dolist (error-file error-files)
            (message "- %s: %s" (car error-file) (cdr error-file)))
          (error "Failed to export %d files" error-count))))))

(provide 'build/export-all)

;;; init.el ends here
