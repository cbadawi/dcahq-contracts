(impl-trait .strategy.default-strategy)

(use-trait ft-trait-a 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.trait-sip-010.sip-010-trait)
(use-trait ft-trait-b 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait share-fee-to-trait 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to-trait.share-fee-to-trait)


(define-constant ERR-NOT-AUTHORIZED (err u1000))

(define-read-only (is-approved)
	(contract-call? .auth is-approved)
)

(define-public (velar-swap-wrapper (id uint)
																	(token0 <ft-trait-b>)
																	(token1 <ft-trait-b>)
																	(token-in <ft-trait-b>)
																	(token-out <ft-trait-b>)
																	(share-fee-to <share-fee-to-trait>)
																	(amt-in uint)
																	(amt-out-min uint))
  (begin
		(asserts! (is-approved) ERR-NOT-AUTHORIZED) 
		(contract-call? 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-router swap-exact-tokens-for-tokens id token0 token1 token-in token-out share-fee-to amt-in amt-out-min
)))

(define-public (alex-swap-wrapper (source-trait <ft-trait-a>) 
															(target-trait <ft-trait-a>) 
															(source-factor uint) 
															(dx uint) 
															(min-d-target uint)  
															(factor-hop uint)
															(hop-trait-opt (optional <ft-trait-a>))) 
(begin
	(asserts! (is-approved) ERR-NOT-AUTHORIZED) 
	(let ((swap-response (try! (alex-swap-internal source-trait target-trait source-factor dx min-d-target factor-hop hop-trait-opt))))
				(try! (as-contract (contract-call? target-trait transfer swap-response tx-sender .dca-vault none)))
				(print {function:"swap-wrapper", 
								params:{source-trait:source-trait, target-trait:target-trait, source-factor:source-factor, dx:dx, min-d-target:min-d-target, facotr-hop:factor-hop, hop-trait-opt:hop-trait-opt},
								more:{swap-response:swap-response}})
				(ok swap-response)
)))

(define-private (alex-swap-internal (source-trait <ft-trait-a>) 
															(target-trait <ft-trait-a>) 
															(source-factor uint) 
															(dx uint) 
															(min-d-target uint) 
															(factor-hop uint)
															(hop-trait-opt (optional <ft-trait-a>))) 
			(match hop-trait-opt hop-trait 
							(as-contract (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01 swap-helper-a source-trait target-trait hop-trait source-factor factor-hop dx (some min-d-target)))
							(as-contract (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01 swap-helper source-trait target-trait source-factor dx (some min-d-target)))
))