#!/usr/bin/env racket
#lang racket/base

(require raylib/2d/unsafe
         racket/format
         racket/fixnum
         racket/list
         racket/math
         racket/match)

;; Function to get memory usage
(define (get-memory-usage)
  (/ (current-memory-use) (* 1024 1024.0)))

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
(define memory-at-start (make-parameter 0.0))

;; Stress level settings
(define stress-objects-per-level
  (vector 100 1000 10000))  ;; Objects per frame at each stress level

;; Functions to measure processing time
(define (start-processing-measurement)
  (processing-start-time (current-inexact-milliseconds))
  (measuring-processing #t))

(define (end-processing-measurement)
  (when (measuring-processing)
    (last-processing-time (- (current-inexact-milliseconds) (processing-start-time)))
    (measuring-processing #f)))

;; Explicitly request a garbage collection
(define (trigger-gc)
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
    (memory-at-start (get-memory-usage))
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
  (InitWindow 800 600 "Memory Stress Test")
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
        (objects-created 0)
        (objects-list '())
        (start-time (current-inexact-milliseconds))
        (monitoring-active #f)
        (memory-at-start 0.0)
        (printf "Metrics reset\n"))
      
      ;; Trigger garbage collection (M key)
      (trigger-gc)
      
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
      
      ;; Display memory information
      (define current-memory (get-memory-usage))
      
      (DrawText (~a "Memory Usage: " (~r current-memory #:precision 2) " MB") 20 20 20 BLACK)
      
      ;; Show memory change if monitoring is active
      (when (monitoring-active)
        (define memory-change (- current-memory (memory-at-start)))
        (define memory-color (if (> memory-change 10.0) RED (if (> memory-change 0) ORANGE GREEN)))
        (DrawText (~a "Memory Change: " (~r memory-change #:precision 2) " MB") 20 50 20 memory-color))
      
      (DrawText (~a "FPS: " (GetFPS)) 20 80 20 BLACK)
      (DrawText (~a "Max Frame Time: " (~r (* 1000 (max-frame-time)) #:precision 2) " ms") 20 110 20 BLACK)
      (DrawText (~a "Last Processing Time: " (~r (last-processing-time) #:precision 2) " ms") 20 140 20 DARKBLUE)
      
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
                20 170 20 
                (if (monitoring-active) GREEN ORANGE))
      
      (DrawText (~a "Memory Stress: " 
                    (if (stress-enabled) 
                        (~a "ON (Level " (stress-level) ")")
                        "OFF"))
                20 200 20 
                (if (stress-enabled) RED GREEN))
      (DrawText (~a "Objects Created: " (objects-created)) 20 230 20 BLACK)
      (DrawText (~a "Objects Retained: " (length (objects-list))) 20 260 20 BLACK)
      
      ;; Help instructions
      (DrawText "Instructions:" 20 300 20 DARKGRAY)
      (DrawText "- G: Toggle memory stress test" 40 330 18 DARKGRAY)
      (DrawText "- 1/2/3: Select stress level (low/medium/high)" 40 360 18 DARKGRAY)
      (DrawText "- M: Force garbage collection" 40 390 18 DARKGRAY)
      (DrawText "- R: Reset metrics" 40 420 18 DARKGRAY)
      (DrawText "- ESC: Exit" 40 450 18 DARKGRAY)
      
      (EndDrawing)
      (loop)))
  
  (CloseWindow))
