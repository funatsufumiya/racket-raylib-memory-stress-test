#!/usr/bin/env racket
#lang racket/base

(require raylib/2d/unsafe
         raylib/generated/unsafe
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

;; Rendering mode and object count parameters
(define render-mode (make-parameter '2d))   ;; '2d or '3d
(define shape-type (make-parameter 'circle)) ;; 'circle, 'rectangle, or 'mixed
(define object-count (make-parameter 100))  ;; Number of objects to render
(define object-count-multiplier (make-parameter 1)) ;; Multiplier for exponential scaling
(define triangle-count (make-parameter 0))  ;; Total triangle count
(define vertex-count (make-parameter 0))    ;; Total vertex count

;; Animation parameters
(define rotation (make-parameter 0.0))
(define circles (make-parameter '()))
(define rectangles (make-parameter '()))

;; 3D objects
(define cubes (make-parameter '()))
(define camera (make-parameter #f))

;; Functions to measure processing time
(define (start-processing-measurement)
  (processing-start-time (current-inexact-milliseconds))
  (measuring-processing #t))

(define (end-processing-measurement)
  (when (measuring-processing)
    (last-processing-time (- (current-inexact-milliseconds) (processing-start-time)))
    (measuring-processing #f)))

;; Update frame metrics
(define (update-frame-metrics delta-time)
  (define current-time (current-inexact-milliseconds))
  (define raw-delta-time (/ (- current-time (previous-time)) 1000.0))  ;; Convert to seconds
  (previous-time current-time)
  
  ;; Record frame time
  (vector-set! frame-times frame-index raw-delta-time)
  (set! frame-index (modulo (add1 frame-index) (vector-length frame-times)))
  
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
             (list wrapped-x y radius speed color)))
  
  ;; Update rectangle positions
  (rectangles (for/list ([rect (rectangles)])
                (match-define (list x y width height speed color) rect)
                (define new-x (+ x (* speed delta-time)))
                (define wrapped-x (if (> new-x (+ 800 width))
                                     (- 0 width)
                                     new-x))
                (list wrapped-x y width height speed color)))
  
  ;; Update 3D objects if in 3D mode
  (when (eq? (render-mode) '3d)
    ;; Update cube rotations
    (cubes (for/list ([cube (cubes)])
             (match-define (list pos size rot color) cube)
             (define new-rot (+ rot (* 45.0 delta-time)))  ;; 45 degrees per second
             (list pos size new-rot color)))))

;; Calculate actual object count based on base count and multiplier
(define (get-actual-object-count)
  (define base (object-count))
  (define mult (object-count-multiplier))
  (inexact->exact (round (* base (expt 10 (- mult 1))))))

;; Create 2D objects
(define (initialize-2d-objects)
  (define actual-count (get-actual-object-count))
  (printf "Creating ~a 2D objects\n" actual-count)
  
  (case (shape-type)
    [(circle)
     ;; Create only circles
     (circles
      (for/list ([i (in-range (min actual-count 10000))])
        (list (random 800)            ;; x position
              (+ 100 (random 400))    ;; y position
              (+ 5 (random 20))       ;; radius
              (+ 50 (random 200))     ;; speed
              (make-Color
               (random 256)           ;; color (R,G,B,A)
               (random 256) 
               (random 256) 
               255))))
     (rectangles '())]
    
    [(rectangle)
     ;; Create only rectangles
     (rectangles
      (for/list ([i (in-range (min actual-count 10000))])
        (list (random 800)            ;; x position
              (+ 100 (random 400))    ;; y position
              (+ 10 (random 40))      ;; width
              (+ 10 (random 40))      ;; height
              (+ 30 (random 150))     ;; speed
              (make-Color
               (random 256)           ;; color (R,G,B,A)
               (random 256) 
               (random 256) 
               255))))
     (circles '())]
    
    [(mixed)
     ;; Create both circles and rectangles
     (define half-count (quotient actual-count 2))
     (circles
      (for/list ([i (in-range (min half-count 5000))])
        (list (random 800)            ;; x position
              (+ 100 (random 400))    ;; y position
              (+ 5 (random 20))       ;; radius
              (+ 50 (random 200))     ;; speed
              (make-Color
               (random 256)           ;; color (R,G,B,A)
               (random 256) 
               (random 256) 
               255))))
     (rectangles
      (for/list ([i (in-range (min half-count 5000))])
        (list (random 800)            ;; x position
              (+ 100 (random 400))    ;; y position
              (+ 10 (random 40))      ;; width
              (+ 10 (random 40))      ;; height
              (+ 30 (random 150))     ;; speed
              (make-Color
               (random 256)           ;; color (R,G,B,A)
               (random 256) 
               (random 256) 
               255))))]))

;; Initialize 3D objects
(define (initialize-3d-objects)
  (define actual-count (get-actual-object-count))
  (printf "Creating ~a 3D objects\n" actual-count)
  
  ;; Create camera
  (camera (make-Camera3D
           (make-Vector3 0.0 10.0 20.0)    ;; position
           (make-Vector3 0.0 0.0 0.0)      ;; target
           (make-Vector3 0.0 1.0 0.0)      ;; up
           45.0                            ;; fov
           CAMERA_PERSPECTIVE))            ;; projection
  
  ;; Create cubes - fixed random issue by using integer values
  (cubes
   (for/list ([i (in-range (min actual-count 5000))])  ;; Limit to prevent excessive memory usage
     (list (make-Vector3 
            (- (random 20) 10.0)           ;; x position (-10 to 10)
            (- (random 10) 5.0)            ;; y position (-5 to 5)
            (- (random 20) 10.0))          ;; z position (-10 to 10)
           (make-Vector3 
            (+ 0.5 (random 2))             ;; width (0.5 to 2.5)
            (+ 0.5 (random 2))             ;; height (0.5 to 2.5)
            (+ 0.5 (random 2)))            ;; depth (0.5 to 2.5)
           (random 360)                    ;; rotation
           (make-Color
            (random 256)                   ;; color (R,G,B,A)
            (random 256) 
            (random 256) 
            255))))
  
  ;; Calculate triangle and vertex counts
  (triangle-count (* actual-count 12))  ;; Each cube has 12 triangles
  (vertex-count (* actual-count 36)))   ;; Each cube has 36 vertices (6 faces * 2 triangles * 3 vertices)

;; Adjust object count with arrow keys
(define (adjust-object-count)
  (cond
    ;; Increase base count with UP arrow
    [(IsKeyPressed KEY_UP)
     (object-count (min 1000 (+ (object-count) 10)))
     (printf "Base value: ~a (Total: ~a)\n" (object-count) (get-actual-object-count))
     (initialize-objects)]
    
    ;; Decrease base count with DOWN arrow
    [(IsKeyPressed KEY_DOWN)
     (object-count (max 10 (- (object-count) 10)))
     (printf "Base value: ~a (Total: ~a)\n" (object-count) (get-actual-object-count))
     (initialize-objects)]
    
    ;; Increase multiplier with RIGHT arrow
    [(IsKeyPressed KEY_RIGHT)
     (object-count-multiplier (min 5 (+ (object-count-multiplier) 1)))
     (printf "Power multiplier: 10^~a (Total: ~a)\n" (- (object-count-multiplier) 1) (get-actual-object-count))
     (initialize-objects)]
    
    ;; Decrease multiplier with LEFT arrow
    [(IsKeyPressed KEY_LEFT)
     (object-count-multiplier (max 1 (- (object-count-multiplier) 1)))
     (printf "Power multiplier: 10^~a (Total: ~a)\n" (- (object-count-multiplier) 1) (get-actual-object-count))
     (initialize-objects)]))

;; Toggle shape type
(define (toggle-shape-type)
  (when (IsKeyPressed KEY_S)
    (shape-type (case (shape-type)
                  [(circle) 'rectangle]
                  [(rectangle) 'mixed]
                  [(mixed) 'circle]))
    (printf "Shape type set to: ~a\n" (shape-type))
    (initialize-objects)))

;; Initialize objects based on current mode
(define (initialize-objects)
  (if (eq? (render-mode) '2d)
      (initialize-2d-objects)
      (initialize-3d-objects)))

;; Toggle between 2D and 3D rendering
(define (toggle-render-mode)
  (when (IsKeyPressed KEY_TAB)
    (render-mode (if (eq? (render-mode) '2d) '3d '2d))
    (printf "Switched to ~a rendering mode\n" (render-mode))
    (initialize-objects)))

;; Helper function to draw text with background
(define (draw-text-with-background text x y size color)
  ;; Calculate text dimensions
  (define text-width (MeasureText text size))
  (define text-height size)
  
  ;; Draw background rectangle with padding
  (DrawRectangle (- x 5) (- y 5) (+ text-width 10) (+ text-height 10) (make-Color 255 255 255 220))
  
  ;; Draw text
  (DrawText text x y size color))

;; Main function
(module+ main
  (InitWindow 800 600 "Raylib Rendering Objects Test")
  (SetTargetFPS 60)
  
  ;; Initialize objects for 2D mode
  (initialize-2d-objects)
  
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
      
      ;; Toggle between 2D and 3D rendering
      (toggle-render-mode)
      
      ;; Toggle shape type
      (toggle-shape-type)
      
      ;; Adjust object count
      (adjust-object-count)
      
      ;; End measuring processing time
      (end-processing-measurement)
      
      ;; Draw screen
      (BeginDrawing)
      (ClearBackground RAYWHITE)
      
      ;; Draw based on current render mode
      (if (eq? (render-mode) '2d)
          ;; 2D rendering
          (begin
            ;; Draw moving circles
            (for ([circle (circles)])
              (match-define (list x y radius speed color) circle)
              (DrawCircle (inexact->exact (round x)) 
                          (inexact->exact (round y)) 
                          (exact->inexact radius)
                          color))
            
            ;; Draw moving rectangles
            (for ([rect (rectangles)])
              (match-define (list x y width height speed color) rect)
              (DrawRectangle (inexact->exact (round x))
                             (inexact->exact (round y))
                             (inexact->exact (round width))
                             (inexact->exact (round height))
                             color)))
          
          ;; 3D rendering
          (begin
            (BeginMode3D (camera))
            
            ;; Draw grid
            (DrawGrid 20 1.0)
            
            ;; Draw cubes
            (for ([cube (cubes)])
              (match-define (list pos size rot color) cube)
              ;; Use DrawCubeV without rotation
              (DrawCubeV pos size color)
              (DrawCubeWiresV pos size BLACK))
            
            (EndMode3D)))
      
      ;; Display information
      (define current-memory (get-memory-usage))
      (define actual-count (get-actual-object-count))
      
      ;; Draw performance information
      (draw-text-with-background (~a "FPS: " (GetFPS)) 20 20 20 BLACK)
      (draw-text-with-background (~a "Memory Usage: " (~r current-memory #:precision 2) " MB") 20 50 20 BLACK)
      (draw-text-with-background (~a "Max Frame Time: " (~r (* 1000 (max-frame-time)) #:precision 2) " ms") 20 80 20 BLACK)
      (draw-text-with-background (~a "Last Processing Time: " (~r (last-processing-time) #:precision 2) " ms") 20 110 20 DARKBLUE)
      
      ;; Draw rendering information
      (draw-text-with-background (~a "Mode: " (render-mode)) 20 150 20 DARKGREEN)
      (draw-text-with-background (~a "Shape Type: " (shape-type)) 20 180 20 DARKGREEN)
      (draw-text-with-background (~a "Base Value: " (object-count)) 20 210 20 DARKGREEN)
      (draw-text-with-background (~a "Power Multiplier: 10^" (- (object-count-multiplier) 1)) 20 240 20 DARKGREEN)
      (draw-text-with-background (~a "Total Objects: " actual-count) 20 270 20 DARKGREEN)
      
      ;; Display triangle and vertex count in 3D mode
      (when (eq? (render-mode) '3d)
        (draw-text-with-background (~a "Triangle Count: " (triangle-count)) 20 300 20 DARKGREEN)
        (draw-text-with-background (~a "Vertex Count: " (vertex-count)) 20 330 20 DARKGREEN))
      
      ;; Help instructions
      (draw-text-with-background "Controls:" 20 380 20 DARKGRAY)
      (draw-text-with-background "- UP/DOWN: Adjust base value by 10" 40 410 18 DARKGRAY)
      (draw-text-with-background "- LEFT/RIGHT: Adjust power multiplier (10^n)" 40 440 18 DARKGRAY)
      (draw-text-with-background "- S: Cycle shape types (Circle → Rectangle → Mixed)" 40 470 18 DARKGRAY)
      (draw-text-with-background "- TAB: Toggle between 2D and 3D mode" 40 500 18 DARKGRAY)
      (draw-text-with-background "- ESC: Exit" 40 530 18 DARKGRAY)
      
      (draw-text-with-background 
       (~a "Formula: " (object-count) " × 10^" (- (object-count-multiplier) 1) " = " actual-count " objects")
       40 560 18 DARKBLUE)
      
      (EndDrawing)
      (loop)))
  
  (CloseWindow))
