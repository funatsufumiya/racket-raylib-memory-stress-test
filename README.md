# Racket Raylib Memory Stress Test (for checking GC stop-the-world pauses)

![screenshot](screenshot.png)

## Prerequisites

```bash
$ raco pkg install --auto raylib
```

## Usage

```bash
$ racket gc-monitoring-raylib.rkt
``` 

## Appendix: Memory Consumption Benchmark (Racket vs SBCL)

This appendix compares memory usage patterns between Racket and SBCL (Common Lisp) using both computational (tak function) and memory-intensive allocation tests.

### Usage

Racket benchmark:
```bash
$ racket bench-tak.rkt
```

SBCL benchmark:
```bash
$ sbcl --load bench-tak.lisp
```

### Results (Measured on M1 MacBook Air)

| Measurement | Racket | SBCL |
|-------------|--------|------|
| Baseline memory | 66.08 MB | 37.06 MB |
| Memory increase after tak function | +0.09 MB | +0.00 MB |
| Final memory increase after allocation test | +0.41 MB | +0.07 MB |

Both implementations successfully managed large temporary allocations (~76MB) with minimal permanent memory growth. The GC monitor tool confirmed that Racket performs garbage collection without observable pauses during interactive use.

## Acknowledgement

This project, including both the code and documentation (English), was developed with the assistance of an AI coding assistant (Cody).