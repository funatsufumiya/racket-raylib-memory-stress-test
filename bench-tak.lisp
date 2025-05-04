;;;; Memory usage benchmark for SBCL

;;; Utilities for memory measurement
(defun get-memory-usage ()
  "Returns the current memory usage in bytes"
  (let ((usage 0))
    ;; Run GC twice to ensure consistent measurement
    (sb-ext:gc :full t)
    (sb-ext:gc :full t)
    (setf usage (sb-kernel:dynamic-usage))
    usage))

(defun print-memory-usage (label memory)
  "Prints memory usage in MB"
  (format t "~a: ~,2f MB~%" label (/ memory 1024 1024)))

(defun print-memory-comparison (label before after)
  "Prints the difference in memory usage"
  (let ((diff (- after before)))
    (format t "~a: +~,2f MB~%" label (/ diff 1024 1024))))

;;; Benchmark function
;;; Takeuchi function - recursive function good for benchmarking
(defun tak (x y z)
  (if (<= x y)
      z
      (tak (tak (- x 1) y z)
           (tak (- y 1) z x)
           (tak (- z 1) x y))))

;;; Function to measure memory usage of a function
(defun measure-memory-for-function (fn args)
  (sb-ext:gc :full t)
  (sb-ext:gc :full t)
  (let ((before (get-memory-usage)))
    (print-memory-usage "Memory before function" before)
    
    ;; Execute and time the function
    (time (apply fn args))
    
    (sb-ext:gc :full t)
    (sb-ext:gc :full t)
    (let ((after (get-memory-usage)))
      (print-memory-usage "Memory after function" after)
      (print-memory-comparison "Memory used by function" before after))))

;;; Function to create large data structures
(defun create-large-structures (n)
  (let ((result nil))
    (dotimes (i n)
      (push (make-array 1000 :initial-element i) result))
    (length result)))

;;;; Benchmark execution

;; Print system info
(format t "SBCL version: ~a~%" (lisp-implementation-version))
(format t "~a~%" (machine-type))
(format t "~a~%" (software-type))
(format t "~%")

;; Measure baseline memory at startup
(let ((baseline (get-memory-usage)))
  (print-memory-usage "Baseline memory at startup" baseline)
  (format t "~%")
  
  ;; Run small-scale tak benchmark
  (format t "--- Small tak benchmark ---~%")
  (measure-memory-for-function #'tak '(18 12 6))
  (format t "~%")
  
  ;; Run larger benchmark with allocations
  (format t "--- Creating larger data structures ---~%")
  (measure-memory-for-function #'create-large-structures '(10000))
  
  ;; Final memory state
  (format t "~%--- Final memory state ---~%")
  (let ((final (get-memory-usage)))
    (print-memory-usage "Final absolute memory" final)
    (print-memory-comparison "Final relative memory" baseline final)))

;; Exit with success status
(sb-ext:exit :code 0)
