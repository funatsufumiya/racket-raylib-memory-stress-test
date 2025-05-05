#!/usr/bin/env racket
#lang racket/base

(require raylib/2d/unsafe
         racket/format
         racket/fixnum
         racket/list
         racket/math
         racket/match
         "my-gcstats.rkt")  ;; Use our custom GC statistics module

;; Enable GC statistics collection
(gcstats-enable!)

;; Function to get memory usage
(define (get-memory-usage)
  (/ (current-memory-use) (* 1024 1024.0)))

;; Function to get GC statistics
(define (get-gc-stats)
  (define stats (gcstats))
  (define num-collections (vector-ref stats 0))
  (define total-gc-time-ms (vector-ref stats 1))
  (define max-gc-time-ms (vector-ref stats 2))
  (define last-gc-time-ms (vector-ref stats 3))
  (values num-collections total-gc-time-ms max-gc-time-ms last-gc-time-ms))

;; Initialize metrics - use parameters for mutable state
(define frame-times (make-vector 120 0.0))  ;; Store recent frame times
(define frame-index 0)
(define max-frame-time (make-parameter 0.0))  ;; Parameter for max frame time
(define last-max-reset-time (make-parameter 0.0))
(define previous-time (make-parameter (current-inexact-milliseconds)))

;; Add processing time tracking parameters
(define processing-start-time (make-parameter 0.0))
(define last-processing-time (make-parameter 0.0))
(define measuring-processing (make-parameter #f))

;; Add stabilization period parameters
(define start-time (make-parameter (current-inexact-milliseconds)))
(define stabilization-period (make-parameter 3.0)) ;; 3 seconds before starting to measure
(define monitoring-active (make-parameter #f))

;; Animation parameters
(define rotation (make-parameter 0.0))
(define circles (make-parameter '()))

;; Objects for memory stress testing - use parameters
(define objects-list (make-parameter '()))
(define stress-enabled (make-parameter #f))
(define stress-level (make-parameter 1))    ;; Stress level 1-3
(define objects-created (make-parameter 0))
(define objects-retained 1000)              ;; Number of objects to retain (to force GC)

;; Stress level settings
(define stress-objects-per-level
  (vector 100 1000 10000))  ;; Objects per frame at each stress level

;; Function to calculate the median of a list of numbers
(define (median lst)
  (when (empty? lst)
    (error "Cannot calculate median of empty list"))
  (define sorted (sort lst <))
  (define len (length sorted))
  (if (odd? len)
      (list-ref sorted (quotient len 2))
      (/ (+ (list-ref sorted (quotient len 2))
            (list-ref sorted (- (quotient len 2) 1)))
         2.0)))

;; Functions to measure processing time
(define (start-processing-measurement)
  (processing-start-time (current-inexact-milliseconds))
  (measuring-processing #t))

(define (end-processing-measurement)
  (when (measuring-processing)
    (last-processing-time (- (current-inexact-milliseconds) (processing-start-time)))
    (measuring-processing #f)))

;; Explicitly request a garbage collection and measure pause time
(define (measure-gc-pause)
  (when (IsKeyPressed KEY_M)
    (printf "Manually triggering garbage collection...\n")
    (collect-garbage)))

;; Function to create memory stress
(define (create-memory-stress)
  (when (stress-enabled)
    (define objects-per-frame (vector-ref stress-objects-per-level (sub1 (stress-level))))
    (for ([i (in-range objects-per-frame)])
      (objects-list (cons (make-bytes 1000) (objects-list)))
      (objects-created (add1 (objects-created))))
    
    ;; Limit the number of objects (release old objects to encourage GC)
    (when (> (length (objects-list)) objects-retained)
      (objects-list (take (objects-list) objects-retained)))))

;; Update frame metrics
(define (update-frame-metrics delta-time)
  (define current-time (current-inexact-milliseconds))
  (define raw-delta-time (/ (- current-time (previous-time)) 1000.0))  ;; Convert to seconds
  (previous-time current-time)
  
  ;; Record frame time
  (vector-set! frame-times frame-index raw-delta-time)
  (set! frame-index (modulo (add1 frame-index) (vector-length frame-times)))
  
  ;; Check if we should start monitoring (after stabilization period)
  (when (and (not (monitoring-active))
             (> (- current-time (start-time)) (* (stabilization-period) 1000)))
    (monitoring-active #t)
    (printf "Monitoring activated after stabilization period\n"))
  
  ;; Update maximum frame time
  (when (> raw-delta-time (max-frame-time))
    (max-frame-time raw-delta-time))
  
  ;; Reset maximum frame time every 5 seconds
  (when (> (- (/ current-time 1000.0) (last-max-reset-time)) 5.0)
    (last-max-reset-time (/ current-time 1000.0))
    (max-frame-time 0.0))
    
  ;; Return the raw delta time for animation
  delta-time)

;; Update animations
(define (update-animations delta-time)
  ;; Update rotation angle
  (rotation (+ (rotation) (* 90.0 delta-time)))  ;; 90 degrees per second
  
  ;; Update circle positions
  (circles (for/list ([circle (circles)])
             (match-define (list x y radius speed color) circle)
             (define new-x (+ x (* speed delta-time)))
             (define wrapped-x (if (> new-x (+ 800 radius))
                                  (- 0 radius)
                                  new-x))
             (list wrapped-x y radius speed color))))

;; Create initial circles
(define (initialize-circles)
  (circles
   (for/list ([i (in-range 20)])
     (list (random 800)            ;; x position
           (+ 300 (random 200))    ;; y position
           (+ 5 (random 20))       ;; radius
           (+ 50 (random 200))     ;; speed
           (make-Color
                   (random 256)    ;; color (R,G,B,A)
                   (random 256) 
                   (random 256) 
                   255)))))

;; Main function
(module+ main
  (InitWindow 800 600 "GC Stop-the-World Test")
  (SetTargetFPS 60)
  
  ;; Initialize circles
  (initialize-circles)
  
  ;; Initialize monitoring time
  (start-time (current-inexact-milliseconds))
  
  (let loop ()
    (when (not (WindowShouldClose))
      ;; Calculate delta time
      (define delta-time (GetFrameTime))
      
      ;; Update metrics
      (define animation-delta (update-frame-metrics delta-time))
      
      ;; Start measuring processing time
      (start-processing-measurement)
      
      ;; Update animations
      (update-animations animation-delta)
      
      ;; Memory stress test (toggle with G key)
      (when (IsKeyPressed KEY_G)
        (stress-enabled (not (stress-enabled)))
        (printf "Memory stress test: ~a\n" (if (stress-enabled) "ON" "OFF")))
      
      ;; Change stress level with 1, 2, 3 keys
      (when (IsKeyPressed KEY_ONE)
        (stress-level 1)
        (printf "Stress level set to 1 (low)\n"))
      (when (IsKeyPressed KEY_TWO)
        (stress-level 2)
        (printf "Stress level set to 2 (medium)\n"))
      (when (IsKeyPressed KEY_THREE)
        (stress-level 3)
        (printf "Stress level set to 3 (high)\n"))
      
      ;; Reset metrics with R key
      (when (IsKeyPressed KEY_R)
        (gcstats-reset!)  ;; Reset GC statistics
        (objects-created 0)
        (objects-list '())
        (start-time (current-inexact-milliseconds))
        (monitoring-active #f)
        (printf "Metrics reset\n"))
      
      ;; Measure explicit GC pause (M key)
      (measure-gc-pause)
      
      ;; Create memory stress
      (create-memory-stress)
      
      ;; End measuring processing time
      (end-processing-measurement)
      
      ;; Draw screen
      (BeginDrawing)
      (ClearBackground RAYWHITE)
      
      ;; Draw rotating rectangles
      (define center-x 400)
      (define center-y 300)
      
      ;; Draw moving circles
      (for ([circle (circles)])
        (match-define (list x y radius speed color) circle)
        (DrawCircle (inexact->exact (round x)) 
                    (inexact->exact (round y)) 
                    (exact->inexact radius)
                    color))
      
      ;; Draw rotating rectangle
      (DrawRectanglePro 
       (make-Rectangle
            (exact->inexact center-x)
            (exact->inexact center-y)
            100.0
            100.0)  ;; Rectangle
       (make-Vector2 50.0 50.0)                        ;; Origin (center of rectangle)
       (rotation)                                  ;; Rotation angle
       RED)                                        ;; Color
      
      ;; Display memory and GC information
      (define current-memory (get-memory-usage))
      
      ;; Get GC statistics from our custom module
      (define-values (num-collections total-gc-time max-gc-time last-gc-time) 
        (get-gc-stats))
      
      (DrawText (~a "Memory Usage: " (~r current-memory #:precision 2) " MB") 20 20 20 BLACK)
      (DrawText (~a "FPS: " (GetFPS)) 20 50 20 BLACK)
      (DrawText (~a "Max Frame Time: " (~r (* 1000 (max-frame-time)) #:precision 2) " ms") 20 80 20 BLACK)
      (DrawText (~a "Last Processing Time: " (~r (last-processing-time) #:precision 2) " ms") 20 110 20 DARKBLUE)
      
      ;; Display GC statistics
      (define gc-color (if (> max-gc-time 20.0) RED PURPLE))
      (DrawText (~a "GC Collections: " num-collections) 20 140 20 PURPLE)
      (DrawText (~a "Total GC Time: " (~r total-gc-time #:precision 2) " ms") 20 170 20 PURPLE)
      (DrawText (~a "Max GC Pause: " (~r max-gc-time #:precision 2) " ms") 20 200 20 gc-color)
      (DrawText (~a "Last GC Pause: " (~r last-gc-time #:precision 2) " ms") 20 230 20 PURPLE)
      
      (define stabilizing-text 
        (if (monitoring-active) 
            ""
            (~a " (Stabilizing: " 
                 (~r (- (stabilization-period) 
                        (/ (- (current-inexact-milliseconds) (start-time)) 1000))
                    #:precision 1) 
                 "s remaining)")))
      
      (DrawText (~a "Monitoring Status: " 
                    (if (monitoring-active) "ACTIVE" "STABILIZING") 
                    stabilizing-text) 
                20 260 20 
                (if (monitoring-active) GREEN ORANGE))
      
      (DrawText (~a "Memory Stress: " 
              (if (stress-enabled) 
                  (~a "ON (Level " (stress-level) ")")
                  "OFF"))
                20 290 20 
                (if (stress-enabled) RED GREEN))
      (DrawText (~a "Objects Created: " (objects-created)) 20 320 20 BLACK)
      (DrawText (~a "Objects Retained: " (length (objects-list))) 20 350 20 BLACK)
      
      ;; Help instructions
      (DrawText "Instructions:" 20 390 20 DARKGRAY)
      (DrawText "- G: Toggle memory stress test" 40 420 18 DARKGRAY)
      (DrawText "- 1/2/3: Select stress level (low/medium/high)" 40 450 18 DARKGRAY)
      (DrawText "- M: Force garbage collection" 40 480 18 DARKGRAY)
      (DrawText "- R: Reset metrics" 40 510 18 DARKGRAY)
      (DrawText "- ESC: Exit" 40 540 18 DARKGRAY)
      
      (EndDrawing)
      (loop)))
  
  (CloseWindow))