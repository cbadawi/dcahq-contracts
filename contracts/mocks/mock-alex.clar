;; 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01
(use-trait ft  'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.trait-sip-010.sip-010-trait)

(define-read-only (get-price (token-x principal) (token-y principal) (factor uint)) 
(begin (asserts! true (err u420))
	(ok u200000)
))


(define-public (swap-helper (source-trait <ft>) (target-trait <ft>) (factor uint) (dx uint) (min-dy (optional uint)))
	(let ((sender tx-sender)) 
		(asserts! true (err u420))
		;; (as-contract (try! (contract-call? source-trait burn dx .dca-vault)))
		(as-contract (try! (contract-call? target-trait mint (unwrap-panic min-dy) sender)))
		(ok (unwrap-panic min-dy))
))


(define-public (swap-helper-a (token-x-trait <ft>) (token-y-trait <ft>) (token-z-trait <ft>) (factor-x uint) (factor-y uint) (dx uint) (min-dz (optional uint)))
	(let ((sender tx-sender)) 
		(asserts! true (err u420))
		(as-contract (try! (contract-call? token-x-trait burn dx .dca-vault)))
		(as-contract (try! (contract-call? token-z-trait mint (unwrap-panic min-dz) sender)))
		(ok (unwrap-panic min-dz))
))