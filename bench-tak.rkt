#lang racket/base

(require racket/fixnum
         racket/format)

;; ------------------ Benchmark Function ------------------
;; Takeuchi function - recursive function good for benchmarking
(define (tak x y z)
  (if (<= x y)
      z
      (tak (tak (- x 1) y z)
           (tak (- y 1) z x)
           (tak (- z 1) x y))))

;; ------------------ Memory Measurement Utilities ------------------
;; Get baseline memory at startup
(define baseline-memory 
  (begin
    (collect-garbage)
    (collect-garbage)
    (current-memory-use)))

;; Print absolute memory usage
(define (print-absolute-memory-usage label)
  (collect-garbage)
  (collect-garbage)
  (define current-mem (current-memory-use))
  (printf "~a: ~a MB\n" 
          label 
          (~r (/ current-mem (* 1024 1024)) #:precision 2)))

;; Print relative memory usage (compared to baseline)
(define (print-relative-memory-usage label)
  (collect-garbage)
  (collect-garbage)
  (define current-mem (current-memory-use))
  (printf "~a: +~a MB (relative to baseline)\n" 
          label 
          (~r (/ (- current-mem baseline-memory) (* 1024 1024)) #:precision 2)))

;; Measure memory usage of a specific function
(define (measure-memory-for-function fn args)
  (collect-garbage)
  (collect-garbage)
  (define before (current-memory-use))
  
  (time (apply fn args)) ;; Execute and time the function
  
  (collect-garbage)
  (collect-garbage)
  (define after (current-memory-use))
  
  (printf "Memory used by function: ~a MB\n"
          (~r (/ (- after before) (* 1024 1024)) #:precision 2))
  (printf "Relative to baseline: ~a MB\n"
          (~r (/ (- after baseline-memory) (* 1024 1024)) #:precision 2)))

;; ------------------ Benchmark Execution ------------------
;; Print system info
(printf "Racket version: ~a\n" (version))
(printf "~a\n" (system-type 'machine))
(printf "~a on ~a\n" (system-type 'os) (system-type 'vm))
(printf "\n")

;; Print baseline memory
(printf "Baseline memory at startup: ~a MB\n" 
        (~r (/ baseline-memory (* 1024 1024)) #:precision 2))
(printf "\n")

;; Run a small-scale tak benchmark first
(printf "--- Small tak benchmark ---\n")
(measure-memory-for-function tak '(18 12 6))
(printf "\n")

;; Run a larger benchmark with allocations
(printf "--- Creating larger data structures ---\n")
(define (create-large-structures n)
  (define result '())
  (for ([i (in-range n)])
    (set! result (cons (make-vector 1000 i) result)))
  (length result))

(measure-memory-for-function create-large-structures '(10000))

;; Final memory state
(printf "\n--- Final memory state ---\n")
(print-absolute-memory-usage "Final absolute memory")
(print-relative-memory-usage "Final relative memory")
