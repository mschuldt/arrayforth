#lang racket

(require compatibility/defmacro)

(provide (all-defined-out))

(define opcodes (vector ";" "ex" "jump" "call" "unext" "next" "if"
                        "-if" "@p" "@+" "@b" "@" "!p" "!+" "!b" "!" "+*"
                        "2*" "2/" "-" "+" "and" "or" "drop" "dup" "pop"
                        "over" "a" "." "push" "b!" "a!"))

(define opcode-set (list->set (vector->list opcodes)))

(define address-required '("jump" "call" "next" "if" "-if"))

(define last-slot-instructions
  '(";" "unext" "@p" "!p" "+*" "+" "dup" "." ))

(define instructions-preceded-by-nops '("+" "+*"))

(define instructions-using-rest-of-word '(";" "ex" "unext"))

(define ops-that-end-word '("unext" ";"))


(define named-addresses '(("right" . #x1D5)
                          ("down" . #x115)
                          ("left" . #x175)
                          ("up" . #x145)
                          ("io" . #x15D)
                          ("ldata" . #x171)
                          ("data" . #x141)
                          ("warp" . #x157)
                          ("center" . #x1A5)
                          ("top" . #x1B5)
                          ("side" . #x185)
                          ("corner" . #x195)))

(define io-places '(("---u" . #x145)
                    ("--l-" . #x175)
                    ("--lu" . #x165)
                    ("-d--" . #x115)
                    ("-d-u" . #x105)
                    ("-dl-" . #x135)
                    ("-dlu" . #x125)
                    ("r---" . #x1D5)
                    ("r--u" . #x1C5)
                    ("r-l-" . #x1F5)
                    ("r-lu" . #x1E5)
                    ("rd--" . #x195)
                    ("rd-u" . #x185)
                    ("rdl-" . #x1B5)
                    ("rdlu" . #x1A5)))

(define node-to-gpio-pins '((701 . 2)
                            (705 . 4)
                            (708 . 2)
                            (715 . 1)
                            (517 . 1)
                            (417 . 1)
                            (317 . 1)
                            (217 . 1)
                            (008 . 4)
                            (001 . 2)
                            (100 . 1)
                            (200 . 1)
                            (300 . 2)
                            (500 . 1)
                            (600 . 1)))

(define &UP #x145) ;325
(define &DOWN #x115) ;277
(define &LEFT #x175) ;373
(define &RIGHT #x1d5) ;469
(define &IO #x15d)

(define &---U #x145)
(define &--L- #x175)
(define &--LU #x165)
(define &-D-- #x115)
(define &-D-U #x105)
(define &-DL- #x135)
(define &-DLU #x125)
(define &R--- #x1D5)
(define &R--U #x1C5)
(define &R-L- #x1F5)
(define &R-LU #x1E5)
(define &RD-- #x195)
(define &RD-U #x185)
(define &RDL- #x1B5)
(define &RDLU #x1A5)

(define MEM-SIZE #x200)

;; This is the type that holds compiled code and other node info.
;; Compiling a program returns a list of these
(struct node (coord mem len) #:mutable #:transparent)
;; 'coord' is the node coordinate this code belongs to
;; 'mem' is the vector of compiled words
;; 'len' is how many instructions are used in mem. len <= length(mem)
;;       the remaining words in mem are all #f

(define (coord->index n)
  (+ (* (quotient n 100) 18) (remainder n 100)))

(define (index->coord n)
  (+ (* (quotient n 18) 100) (remainder n 18)))

(define (coord->row coord)
  (quotient coord 100))

(define (coord->col coord)
  (remainder coord 100))

(define (convert-direction coord dir)
  ;;converts DIR={North, East, South, West} Into Left, Up, Down, or Right
  ;;depending on the nodes coordinate COORD
  (let ([x (remainder coord 100)]
        [y (quotient coord 100)])
    (cond
     [(equal? dir "north")
      (if (= (modulo y 2) 0) "down" "up")]
     [(equal? dir "south")
      (if (= (modulo y 2) 0) "up" "down")]
     [(equal? dir "east")
      (if (= (modulo x 2) 0) "right" "left")]
     [(equal? dir "west")
      (if (= (modulo x 2) 0) "left" "right")]
     [else (raise "convert-direction: invalid direction")])))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;stack macros
(defmacro push (list item)
  `(set! ,list (cons ,item ,list)))

(defmacro pop (list)
  `(if (equal? ,list '())
       (pretty-display "ERROR: pop -- list is empty")
       (begin0 (car ,list) (set! ,list (cdr ,list)))))

(defmacro swap (list)
  `(set! ,list (cons (cadr ,list) (cons (car ,list) (cddr ,list)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;

(defmacro setq (var val)
  `(let [(__v__ ,val)]
     (set! ,var __v__) __v__))

(defmacro while (condition code)
  `(letrec ((fn (lambda ()
                  (when ,condition
                    ,code
                    (fn)))))
     (fn)))

(defmacro enum (syms)
  (let ((i 0)
        (code '()))
    (for ([sym syms])
      (set! code (cons (list 'define sym i) code))
      (set! i (add1 i)))
    (cons 'begin code)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define & bitwise-and)
(define ^ bitwise-xor)
(define << arithmetic-shift)
(define (>> x n) (arithmetic-shift x (- n)))
(define ior bitwise-ior)
(define ~ bitwise-not)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(enum (LEFT UP DOWN RIGHT))
(define port-names (vector "LEFT" "UP" "DOWN" "RIGHT"))