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

;; Initialize GC metrics - use parameters for mutable state
(define frame-times (make-vector 120 0.0))  ;; Store recent frame times
(define frame-index 0)
(define max-frame-time (make-parameter 0.0))  ;; Parameter for max frame time
(define last-max-reset-time (make-parameter 0.0))
(define gc-pause-threshold 0.020)           ;; Consider pauses over 20ms as GC
(define gc-pause-count (make-parameter 0))
(define gc-longest-pause (make-parameter 0.0))
(define previous-time (make-parameter (current-inexact-milliseconds)))

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

;; Measure frame time and detect GC pauses
(define (update-frame-metrics)
  (define current-time (current-inexact-milliseconds))
  (define delta-time (/ (- current-time (previous-time)) 1000.0))  ;; Convert to seconds
  (previous-time current-time)
  
  ;; Record frame time
  (vector-set! frame-times frame-index delta-time)
  (set! frame-index (modulo (add1 frame-index) (vector-length frame-times)))
  
  ;; Check if we should start monitoring (after stabilization period)
  (when (and (not (monitoring-active))
             (> (- current-time (start-time)) (* (stabilization-period) 1000)))
    (monitoring-active #t)
    ;; Reset metrics upon starting actual monitoring
    (gc-pause-count 0)
    (gc-longest-pause 0.0))
  
  ;; Check for long frame times that might indicate GC pauses (only if monitoring is active)
  (when (and (monitoring-active) (> delta-time gc-pause-threshold))
    (gc-pause-count (add1 (gc-pause-count)))
    (when (> delta-time (gc-longest-pause))
      (gc-longest-pause delta-time)))
  
  ;; Update maximum frame time
  (when (> delta-time (max-frame-time))
    (max-frame-time delta-time))
  
  ;; Reset maximum frame time every 5 seconds
  (when (> (- (/ current-time 1000.0) (last-max-reset-time)) 5.0)
    (last-max-reset-time (/ current-time 1000.0))
    (max-frame-time 0.0)))

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
      (update-frame-metrics)
      
      ;; Update animations
      (update-animations delta-time)
      
      ;; Memory stress test (toggle with G key)
      (when (IsKeyPressed KEY_G)
        (stress-enabled (not (stress-enabled))))
      
      ;; Change stress level with 1, 2, 3 keys
      (when (IsKeyPressed KEY_ONE)
        (stress-level 1))
      (when (IsKeyPressed KEY_TWO)
        (stress-level 2))
      (when (IsKeyPressed KEY_THREE)
        (stress-level 3))
      
      ;; Reset metrics with R key
      (when (IsKeyPressed KEY_R)
        (gc-pause-count 0)
        (gc-longest-pause 0.0)
        (objects-created 0)
        (objects-list '())
        (start-time (current-inexact-milliseconds))
        (monitoring-active #f))
      
      ;; Create memory stress
      (create-memory-stress)
      
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
      
      (DrawText (~a "Memory Usage: " (~r current-memory #:precision 2) " MB") 20 20 20 BLACK)
      (DrawText (~a "FPS: " (GetFPS)) 20 50 20 BLACK)
      (DrawText (~a "Max Frame Time: " (~r (* 1000 (max-frame-time)) #:precision 2) " ms") 20 80 20 BLACK)
      
      (define stabilizing-text (if (monitoring-active) 
                                  ""
                                  (~a " (Stabilizing: " 
                                       (~r (- (stabilization-period) 
                                              (/ (- (current-inexact-milliseconds) (start-time)) 1000))
                                          #:precision 1) 
                                       "s remaining)")))
      
      (define gc-color (if (and (monitoring-active) (> (gc-pause-count) 0)) RED BLACK))
      (DrawText (~a "GC Pauses Detected: " (gc-pause-count) stabilizing-text) 20 110 20 gc-color)
      (DrawText (~a "Longest Pause: " (~r (* 1000 (gc-longest-pause)) #:precision 2) " ms") 20 140 20 gc-color)
      
      (DrawText (~a "Memory Stress: " 
                    (if (stress-enabled) 
                        (~a "ON (Level " (stress-level) ")")
                        "OFF"))
                20 180 20 
                (if (stress-enabled) RED GREEN))
      (DrawText (~a "Objects Created: " (objects-created)) 20 210 20 BLACK)
      (DrawText (~a "Objects Retained: " (length (objects-list))) 20 240 20 BLACK)
      
      ;; Help instructions
      (DrawText "Instructions:" 20 340 20 DARKGRAY)
      (DrawText "- G: Toggle memory stress test" 40 370 18 DARKGRAY)
      (DrawText "- 1/2/3: Select stress level (low/medium/high)" 40 400 18 DARKGRAY)
      (DrawText "- R: Reset metrics" 40 430 18 DARKGRAY)
      (DrawText "- ESC: Exit" 40 460 18 DARKGRAY)
      
      (EndDrawing)
      (loop)))
  
  (CloseWindow))
