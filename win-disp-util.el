;;; win-disp-util.el --- window display utilities and optimizations

;; Author: Noah Friedman <friedman@splode.com>
;; Created: 1999-06-13
;; Public domain

;; $Id: win-disp-util.el,v 1.13 2017/09/18 22:26:06 friedman Exp $

;;; Commentary:
;;; Code:

(defgroup win-disp-util nil
  "window display utilities and optimizations"
  :group 'win-disp-util)

;;;###autoload
(defcustom wdu-split-window-keep-point nil
  "*If non-nil, split windows keeps the original point in both children.
This is often more convenient for editing.
If nil, adjust point in each of the two windows to minimize redisplay.
This is convenient on slow terminals, but point can move strangely.

If the value is neither `t' nor nil, then if point was hidden by the new
mode line, then make the line point was on visible in the new window by
setting the window start to that line, and select the new window.

This variable is used by `wdu-split-window-vertically'."
  :type  'sexp
  :group 'win-disp-util)

;;;###autoload
(defcustom wdu-delete-window-keep-point nil
  "*If non-nil, when deleting a window and the window above it displays \
the same buffer such that no display motion will occur, move to the \
previous window and preserve point."
  :type 'boolean
  :group 'win-disp-util)

(defvar wdu-temporary-goal-column-commands
  '(wdu-scroll-screen-up
    wdu-scroll-screen-down
    wdu-scroll-down-4-lines
    wdu-scroll-up-4-lines
    next-line
    previous-line)
  "List of commands that uses same `temporary-goal-column'.")

;; XEmacs 21.5 and earlier do not have window-edges.
(defalias 'wdu-window-edges
  (if (fboundp 'window-edges)
      'window-edges
    'window-pixel-edges))


;;;###autoload
(defun wdu-scroll-screen-down (&optional n)
  "Scroll text of current window downward about ARG screenfuls (1 by default).
If point-min is already visible in the window, no scrolling occurs and no
error is signalled."
  (interactive "p")
  (or (pos-visible-in-window-p (point-min))
      (if (and n (> n 0))
          (scroll-down (* n (- (window-height) 1 next-screen-context-lines)))
        (scroll-down)))
  (move-to-column (or goal-column temporary-goal-column)))

;;;###autoload
(defun wdu-scroll-screen-up (&optional n)
  "Scroll text of current window upward about ARG screenfuls (1 by default).
If point-max is already visible in the window, no scrolling occurs and no
error is signalled."
  (interactive "p")
  (or (pos-visible-in-window-p (point-max))
      (if (and n (> n 0))
          (scroll-up (* n (- (window-height) 1 next-screen-context-lines)))
        (scroll-up)))
  (move-to-column (or goal-column temporary-goal-column)))

;;;###autoload
(defun wdu-scroll-down-4-lines ()
  "Scroll down 4 lines.  See scroll-down."
  (interactive)
  (scroll-down 4)
  (move-to-column (or goal-column temporary-goal-column)))

;;;###autoload
(defun wdu-scroll-up-4-lines ()
  "Scroll up 4 lines.  See scroll-up."
  (interactive)
  (scroll-up 4)
  (move-to-column (or goal-column temporary-goal-column)))

;;;###autoload
(defun wdu-recenter-to-top-or-bottom (&optional prefix)
  "Put line at point at top of screen and redisplay.
With prefix arg, put line at bottom of window."
  (interactive "P")
  (if prefix
      (recenter -1)
    (recenter 0)))


;;;###autoload
(defun wdu-toggle-truncate-lines ()
  "Toggle truncation of long lines vs. wrapping."
  (interactive)
  (let ((p (point-marker))
        (wpos (wdu-window-point-coordinates)))
    (make-local-variable 'truncate-lines)
    (setq truncate-lines (not truncate-lines))
    (goto-char p)
    ;; If disabling truncation, make sure that window is entirely scrolled
    ;; to the right, otherwise truncation will remain in effect while still
    ;; horizontally scrolled.
    (or truncate-lines
        (scroll-right (window-hscroll)))
    ;; Make sure the line we are on stays in the same place on the display.
    (recenter (cdr wpos))))

;; This function has the same behavior as delete-other-windows in Emacs 19,
;; but is implemented for the sake of emacs 18 or other emacsen which do
;; not minimize redisplay changes.
;;;###autoload
(defun wdu-delete-other-windows (&optional window)
  "Make WINDOW (or the selected window) fill its frame.
Only the frame WINDOW is on is affected.
This function tries to reduce display jumps
by keeping the text previously visible in WINDOW
in the same place on the frame.  Doing this depends on
the value of (window-start WINDOW), so if calling this function
in a program gives strange scrolling, make sure the window-start
value is reasonable when this function is called."
  (interactive)
  (if window
      (select-window window)
    (setq window (selected-window)))
  (and (eq window (minibuffer-window))
       (error "Can't expand minibuffer to full frame"))
  (set-buffer (window-buffer window))
  (let* ((point (point))
         (top (window-start))
         (frame-pos (nth 1 (wdu-window-edges))))
    (while (not (eq window (next-window nil 'never)))
      (delete-window (next-window nil 'never)))
    (goto-char top)
    (recenter frame-pos)
    (goto-char point)))

;;;###autoload
(defun wdu-split-window-vertically-at-point ()
  "Split window just above the cursor's current line."
  (interactive)
  (wdu-split-window-vertically (cdr (wdu-window-point-coordinates))))

;; Based on Emacs 19.30 window.el version, but modified to improve
;; ability to preserve point when wdu-split-window-keep-point is nil.
;; This version appears in Emacs 19.31 and later.
;; ...except that the behavior when wdu-split-window-keep-point is
;; neither t nor nil is new.
;;;###autoload
(defun wdu-split-window-vertically (&optional arg)
  "Split current window into two windows, one above the other.
The uppermost window gets ARG lines and the other gets the rest.
Negative arg means select the size of the lowermost window instead.
With no argument, split equally or close to it.
Both windows display the same buffer now current.

If the variable wdu-split-window-keep-point is `t', both new windows
will get the same value of point as the current window.  This is often
more convenient for editing.

Otherwise, we chose window starts so as to minimize the amount of
redisplay; this is convenient on slow terminals.  The new selected
window is the one that the current value of point appears in.  The
value of point can change if the text around point is hidden by the
new mode line.

If the value of `wdu-split-window-keep-point' is neither `t' nor nil, then
if point was hidden by the new mode line, then make the line point was on
visible in the new window by setting the window start to that line, and
select the new window."
  (interactive "P")
  (let ((old-w (selected-window))
	(old-point (point))
	(size (and arg (prefix-numeric-value arg)))
        (window-full-p nil)
	new-w bottom switch moved motion-amt)
    (and size
         (< size 0)
         (setq size (+ (window-height) size)))
    (setq new-w
          (split-window nil size))
    (unless (eq wdu-split-window-keep-point t)
      (save-excursion
        (goto-char (window-start))
        (setq moved (vertical-motion (window-height)))
        (set-window-start new-w (point))
        (if (> (point) (window-point new-w))
            (set-window-point new-w (point)))
        (when (= moved (window-height))
          (setq window-full-p t)
          (vertical-motion -1))
        (setq bottom (point)))

      (when window-full-p
        (when (<= bottom (point))
          (goto-char bottom)
          (vertical-motion -1))
        (when (<= (window-start new-w) old-point)
          (set-window-point new-w old-point)
          (select-window new-w)))

      (cond ((null wdu-split-window-keep-point))
            ((pos-visible-in-window-p old-point old-w))
            ((pos-visible-in-window-p old-point new-w))
            (t
             (select-window new-w)
             (goto-char old-point)
             (vertical-motion 0)
             (set-window-start (selected-window) (point))
             (goto-char old-point))))

    new-w))

;;;###autoload
(defun wdu-delete-window (&optional window)
  "Remove WINDOW from the display.  Default is selected window.

If `wdu-split-window-keep-point' not `t', minimize redisplay:

  When the top window of a frame is deleted, the window below it is grown
  to fill the space previously occupied by the deleted window.  When
  possible, instead of preserving the starting position of the window,
  shift the starting position upward so that the absolute position of the
  buffer previously displayed in the frame does not move.

  If `wdu-delete-window-keep-point' is also non-nil, then when deleting a
  window and the window above it displays the same buffer such that no
  display motion will occur, move to the previous window and preserve point."
  (interactive)
  (unless window
    (setq window (selected-window)))

  (if (eq wdu-split-window-keep-point t)
      (delete-window window)

    (let* ((n-win (next-window))
           (n-edges  (window-edges n-win))
           (n-buffer (window-buffer n-win))

           (edges    (window-edges  window))
           (buffer   (window-buffer window))
           (point    (window-point  window)))

      (cond ((and (= (nth 1 edges) 0)                ; top window
                  (= (nth 0 edges) (nth 0 n-edges))) ; left edges match

             (let ((n-win-start (window-start n-win))
                   (n-point     (window-point n-win))
                   (motion      (- (window-height window))))
               (delete-window window)
               (select-window n-win)
               (goto-char n-win-start)
               (vertical-motion motion)
               (set-window-start n-win (point))
               (if (and (eq n-buffer buffer)
                        (pos-visible-in-window-p point))
                   (goto-char point)
                 (goto-char n-point))))

            (wdu-delete-window-keep-point
             (let* ((p-win    (previous-window))
                    (p-height (window-height p-win))

                    (buffer   (window-buffer window))
                    (start    (window-start window)))

               (delete-window window)
               (when (and (eq buffer (window-buffer p-win))
                          (pos-visible-in-window-p point p-win)
                          (save-window-excursion
                            (select-window p-win)
                            (save-excursion
                              (goto-char (window-start))
                              (vertical-motion p-height)
                              (= (point) start))))
                 (select-window p-win)
                 (goto-char point))))

            (t
             (delete-window window))))))


;;;###autoload
(defun wdu-set-window-text-height (window height)
  "Set the height in lines of the text display area of WINDOW to HEIGHT.
WINDOW must be a live window and defaults to the selected one.
HEIGHT doesn't include the mode line or header line, if any, or
any partial-height lines in the text display area.

When called interactively, use a numeric prefix argument to indicate the
desired height of the window.

Note that the current implementation of this function cannot
always set the height exactly, but attempts to be conservative,
by allocating more lines than are actually needed in the case
where some error may be present."
  (interactive "i\np")
  (when (fboundp 'window-normalize-window)
    (setq window (window-normalize-window window t)))
  (let ((delta (- height (window-text-height window))))
    (unless (zerop delta)
      (let ((window-min-height (min 2 height)))
	(window-resize window delta)))))

;;;###autoload
(defun wdu-set-window-text-width (window width)
  "Set the width in columns of the text display area of WINDOW to WIDTH.
WINDOW must be a live window and defaults to the selected one.

WIDTH doesn't include dividers, scrollbars, margins, fringes, nor any
partial-width columns at the right of the text area.

When called interactively, use a numeric prefix argument to indicate the
desired width of the window."
  (interactive "i\np")
  (when (fboundp 'window-normalize-window)
    (setq window (window-normalize-window window t)))
  (let ((delta (- width (window-text-width window))))
    (unless (zerop delta)
      (window-resize window delta t))))


(defun wdu-window-point-coordinates (&optional window pos)
  "Return the window display coordinates in WINDOW of POS.
Calcuate the display offset in lines/columns relative to the upper
left-hand edge of window WINDOW of point POS.  If POS is not visible,
return nil.  Otherwise the result is a cons of the form \(HPOS . VPOS\).

WINDOW and POS arguments are both optional.  If unspecified, they default
to the selected window and to the point of the buffer in that window,
respectively.

When calling this function in a lisp program, be sure that the display is
physically up to date with respect to any motion or editing commands which
may have been performed since the last refresh.  This can be accomplished
with recenter, sit-for, etc."
  (or window (setq window (selected-window)))
  (or pos    (setq pos    (window-point window)))
  (cond ((not (pos-visible-in-window-p pos window)) nil)
        ((fboundp 'compute-motion)
         ;; Emacs has compute-motion, which is in C and should be fast.
         ;; vertical-motion (used below) just calls the C routine directly,
         ;; but calling it repeatedly is more overhead so don't use it
         ;; unless it is necessary.
         (let* ((window-edges (wdu-window-edges window))
                (left-edge (nth 0 window-edges))
                (top-edge  (nth 1 window-edges))
                (coords (compute-motion (window-start window)
                                        (cons left-edge top-edge)
                                        pos
                                        (cons (nth 2 window-edges)
                                              (nth 3 window-edges))
                                        (1- (window-width window))
                                        nil window)))
           (cons (- (nth 1 coords) left-edge)
                 (- (nth 2 coords) top-edge))))
        ((fboundp 'vertical-motion)
         ;; XEmacs' internals do not export compute-motion.
         (save-window-excursion
           (select-window window)
           (save-excursion
             (set-buffer (window-buffer window))
             (let* ((vwidth (1- (window-width)))
                    (ccol (if truncate-lines
                              (min (current-column) vwidth)
                            (current-column)))
                    (wrap-p (and (not truncate-lines)
                                 (>= ccol vwidth)))
                    (vcol (if wrap-p
                              (mod ccol vwidth)
                            ccol))

                    (wstart (window-start))
                    (line-beg (progn
                                (goto-char pos)
                                (beginning-of-line)
                                (point)))
                    (vline (window-height))
                    (vlast 0)
                    (vmin 0)
                    (vfudge (if wrap-p
                                (/ ccol vwidth)
                              0)))
               ;; This works by overshooting and halving the distance moved
               ;; each iteration.  If it undershoots, adjust vmin.
               (goto-char wstart)
               (while (/= (point) line-beg)
                 (goto-char wstart)
                 (vertical-motion vline)
                 (if (< (point) line-beg)
                     (setq vmin vline
                           vline vlast)
                   (setq vlast vline
                         vline (/ (+ vmin vline) 2))))
               (cons vcol (+ vlast vfudge))))))))

(defun wdu-window-list (&optional minibuf all-frames device)
  "Return a list of existing windows.
If the optional argument MINIBUF is non-nil, then include minibuffer
windows in the result.

By default, only the windows in the selected frame are returned.
The optional argument ALL-FRAMES changes this behavior:
ALL-FRAMES = `visible' means include windows on all visible frames.
ALL-FRAMES = 0 means include windows on all visible and iconified frames.
ALL-FRAMES = t means include windows on all frames including invisible frames.
Anything else means restrict to the selected frame.

\(XEmacs only; this argument has no effect in Emacs\):
The optional fourth argument DEVICE further clarifies which frames to
 search as specified by ALL-FRAMES.  This value is only meaningful if
 ALL-FRAMES is non-nil.
If nil or omitted, search only the selected device.
If a device, search frames only on that device.
If a device type, search frames only on devices of that type.
Any other non-nil value means search frames on all devices."
  (let ((wins nil))
    (apply 'walk-windows
           (function (lambda (win)
                       (setq wins (cons win wins))))
           (if (eq (wdu-emacs-variant) 'xemacs)
               '(minibuf all-frames device)
             '(minibuf all-frames)))
    wins))

(defun wdu-buffer-window (buffer &optional allp all-frames device)
  "Return window displaying BUFFER, if any.
Buffer may be a buffer object or the name of one.
Optional argument ALLP non-nil means return a list of all windows
displaying the buffer.

Optional arguments ALL-FRAMES and DEVICE are passed directly to
`wdu-window-list' to determine which windows to search."
  (and (stringp buffer)
       (setq buffer (get-buffer buffer)))
  (let ((window-list (wdu-window-list nil all-frames device))
        (found nil))
    (while window-list
      (and (eq buffer (window-buffer (car window-list)))
           (if allp
               (setq found (cons (car window-list) found))
             (setq found (car window-list))
             (setq window-list nil)))
      (setq window-list (cdr window-list)))
    (if (consp found)
        (nreverse found)
      found)))

(defun wdu-emacs-variant ()
  "Returns a symbol indicating emacs variant.
This can be one of `emacs', `xemacs', `lucid', `epoch', `mule', etc."
  (let ((data (match-data))
        (version (cond
                  ((fboundp 'nemacs-version)
                   (nemacs-version))
                  (t
                   (emacs-version))))
        (alist '(("\\bXEmacs\\b" . xemacs)
                 ("\\bLucid\\b"  . lucid)
                 ("^Nemacs\\b"   . nemacs)
                 ("^GNU Emacs"   . emacs)))
        result)
    (while alist
      (cond
       ((string-match (car (car alist)) version)
        (setq result (cdr (car alist)))
        (setq alist nil))
       (t
        (setq alist (cdr alist)))))
    (store-match-data data)
    result))


(defadvice line-move (around win-disp-util activate)
  "Do not update temporary goal column when wdu scroll commands are called."
  (or (memq last-command wdu-temporary-goal-column-commands)
      (setq temporary-goal-column
	    (if (and track-eol (eolp)
		     ;; Don't count beg of empty line as end of line
		     ;; unless we just did explicit end-of-line.
		     (or (not (bolp)) (eq last-command 'end-of-line)))
		9999
	      (current-column))))
  (let ((temporary-goal-column temporary-goal-column))
    ad-do-it))


(defun wdu-install-keybindings ()
  "Install key bindings for win-disp-util commands.
These bindings will supercede bindings for some standard emacs commands."
  (interactive)
  (define-key global-map "\C-v"    'wdu-scroll-screen-up)
  (define-key global-map "\M-v"    'wdu-scroll-screen-down)
  (define-key global-map "\M-{"    'wdu-scroll-down-4-lines)
  (define-key global-map "\M-}"    'wdu-scroll-up-4-lines)
  (define-key global-map "\M-\C-l" 'wdu-recenter-to-top-or-bottom)
  (define-key global-map "\C-x0"   'wdu-delete-window)
  (define-key global-map "\C-x2"   'wdu-split-window-vertically)
  (define-key global-map "\C-c2"   'wdu-split-window-vertically-at-point)
  (define-key global-map "\C-ct"   'wdu-toggle-truncate-lines))


;; When show-temp-buffer does its thing, make sure that point in the
;; original buffer does not move; if necessary, change window-start so that
;; the original point is still visible.

(defvar wdu-temp-buffer-completion-fixup-data
  ;; [window pos window-start]
  (vector nil (make-marker) (make-marker)))

(defun wdu-temp-buffer-completion-save-point ()
  (save-selected-window
    (let ((data wdu-temp-buffer-completion-fixup-data))
      (aset data 0 (selected-window))
      (set-buffer (window-buffer (selected-window)))
      (set-marker (aref data 1) (point))
      (set-marker (aref data 2) (window-start))))

  ;; Make sure the restoration hook is always run last.  Especially before
  ;; resize-temp-buffer-window runs; otherwise we do not compute the final
  ;; window coordinates accurately.
  (remove-hook 'temp-buffer-show-hook 'wdu-temp-buffer-completion-restore-point)
  (add-hook 'temp-buffer-show-hook 'wdu-temp-buffer-completion-restore-point t))

(defun wdu-temp-buffer-completion-restore-point ()
  (save-selected-window
    (let ((data wdu-temp-buffer-completion-fixup-data))
      (select-window (aref data 0))
      (set-buffer (window-buffer (selected-window)))

      (set-window-point (selected-window) (aref data 1))

      (when (boundp 'redisplay)
        (redisplay t))
      (when (not (pos-visible-in-window-p (aref data 2)))
        (vertical-motion (- 2 (window-height)))
        (set-window-start (selected-window) (point))
        (set-window-point (selected-window) (aref data 1))))))

;;(add-hook 'temp-buffer-setup-hook 'wdu-temp-buffer-completion-save-point)

(provide 'win-disp-util)
(provide 'wdu)

;; This local variable instructs the byte compiler not to warn about using
;; with-current-buffer instead of save-excursion + set-buffer, since we
;; really do need to save point in the buffers.

;; local variables:
;; byte-compile-warnings: '(not suspicious)
;; end:

;;; win-disp-util.el ends here.
