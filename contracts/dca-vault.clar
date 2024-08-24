(use-trait ft 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait share-fee-to-trait 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to-trait.share-fee-to-trait)

(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-PAUSED (err u1001))
(define-constant ERR-INVALID-AMOUNT (err u2000))
(define-constant ERR-INVALID-PRICE (err u2006))

(define-data-var paused bool false)

(define-read-only (is-approved)
	(contract-call? .auth is-approved)
)

(define-read-only (is-paused) 
		(var-get paused)
)

(define-public (pause (new-paused bool))
	(begin
		(asserts! (is-approved) ERR-NOT-AUTHORIZED) 
		(ok (var-set paused new-paused))
))

(define-public (transfer-ft (token-trait <ft>) (amount uint) (recipient principal)) 
	(begin 
		(asserts! (is-approved) ERR-NOT-AUTHORIZED) 
		(asserts! (not (is-paused)) ERR-PAUSED) 
		(as-contract (contract-call? token-trait transfer amount tx-sender recipient none ))
))


;; (define-public (swap (numerator bool) (source-trait <ft>) (target-trait <ft>) (factor uint) (dx uint) (min-dy (optional uint)))
;; 	(contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01  swap-helper source-trait target-trait factor dx min-dy)
;; )

(define-public (swap (id uint) 
										(source-trait <ft>) 
										(target-trait <ft>) 
										(share-fee-to <share-fee-to-trait>) 
										(amt-in uint) 
										(amt-out-min uint) 
										(min-price uint) 
										(max-price uint) 
										(source-unit uint)
										(target-unit uint)
										(is-source-numerator bool)) 
	(begin 
		(asserts! (is-approved) ERR-NOT-AUTHORIZED) 
		(asserts! (not (is-paused)) ERR-PAUSED) 
		;; (try! (contract-call? 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-router swap-exact-tokens-for-tokens id source-trait target-trait source-trait target-trait share-fee-to amt-in amt-out-min ))
		(let ((swap-response (unwrap-panic (contract-call? .mock-velar swap-exact-tokens-for-tokens id source-trait target-trait source-trait target-trait share-fee-to amt-in amt-out-min)))
					(amt-out (get amt-out swap-response))
					(price (if is-source-numerator (/ (* (div-down amt-out amt-in) source-unit) target-unit) 
																					(/ (* (div-down amt-in amt-out) target-unit) source-unit))
				))
		(asserts! (and (>= price min-price) (<= price max-price)) ERR-INVALID-PRICE)
		(print {function:"vault:swap", more: {price:price, minprice:min-price, maxprice:max-price, amt-out-min:amt-out-min, actual-amt-out:amt-out, amt-in:amt-in, is-source-numerator:is-source-numerator}})
		(ok {amt-out: amt-out})
)))


(define-constant ONE_8 u100000000) ;; 8 decimal places
(define-private (mul-down (a uint) (b uint))
	(/ (* a b) ONE_8))
(define-private (div-down (a uint) (b uint))
	(if (is-eq a u0) u0 (/ (* a ONE_8) b)))