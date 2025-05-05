#lang racket/base

(require racket/logging)

;; GC statistics state
(define gc-events '())
(define gc-count 0)
(define gc-total-time 0.0)
(define gc-max-time 0.0)
(define gc-last-time 0.0)
(define gc-log-receiver #f)
(define gc-monitor-thread #f)

;; Enable GC statistics collection
(define (gcstats-enable!)
  ;; Only start if not already running
  (when (not gc-monitor-thread)
    (set! gc-log-receiver (make-log-receiver (current-logger) 'debug))
    (set! gc-monitor-thread
          (thread
           (lambda ()
             (let loop ()
               (define log-event (sync gc-log-receiver))
               (define msg (vector-ref log-event 1))
               
               ;; Check if this is a GC event
               (when (regexp-match #rx"GC" msg)
                 (set! gc-events (cons log-event gc-events))
                 
                 ;; Extract timing information if available
                 (define time-match (regexp-match #rx"([0-9]+\\.?[0-9]*) ms" msg))
                 (when time-match
                   (define time-str (cadr time-match))
                   (define time-ms (string->number time-str))
                   (set! gc-count (add1 gc-count))
                   (set! gc-total-time (+ gc-total-time time-ms))
                   (set! gc-last-time time-ms)
                   (when (> time-ms gc-max-time)
                     (set! gc-max-time time-ms))))
               
               (loop)))))))

;; Reset GC statistics
(define (gcstats-reset!)
  (set! gc-events '())
  (set! gc-count 0)
  (set! gc-total-time 0.0)
  (set! gc-max-time 0.0)
  (set! gc-last-time 0.0))

;; Get GC statistics
(define (gcstats)
  (vector gc-count gc-total-time gc-max-time gc-last-time))

;; Provide the public functions
(provide gcstats-enable! gcstats-reset! gcstats)
