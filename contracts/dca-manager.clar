(use-trait ft-trait-a 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.trait-sip-010.sip-010-trait)
(use-trait ft-trait-b 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait share-fee-to-trait 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to-trait.share-fee-to-trait)
(use-trait strategy-trait .strategy-v0-0.default-strategy)

(define-constant ERR-NOT-AUTHORIZED (err u9999))
(define-constant ERR-INVALID-AMOUNT (err u9001))
(define-constant ERR-INVALID-PRINCIPAL (err u9002))
(define-constant ERR-INVALID-INTERVAL (err u9003))
(define-constant ERR-INVALID-KEY (err u9004))
(define-constant ERR-DCA-ALREADY-EXISTS (err u9005))
(define-constant ERR-INVALID-PRICE (err u9006))
(define-constant ERR-CONFIG-NOT-SET (err u9007))
(define-constant ERR-FETCHING-PRICE (err u9008))
(define-constant ERR-INVALID-STRATEGY (err u9009))
(define-constant ERR-MAX-POSITIONS-EXCEEDED (err u9010))
(define-constant ERR-PAUSED (err u9011))
(define-constant ERR-INVALID-THRESHOLD (err u9012))
(define-constant ERR-INVALID-USER-AMOUNTS (err u9013))

(define-constant ONE_8 u100000000) ;; 8 decimal places
(define-constant ONE_6 u1000000) ;; 6 decimal places

(define-constant TWO_HOURS u7200)
(define-constant SIX_HOURS u21600)
(define-constant TWELVE_HOURS u43200)
(define-constant ONE_DAY u86400)
(define-constant ONE_WEEK u604800)

(define-data-var treasury principal tx-sender)

(define-map sources-targets-config {source: principal, target: principal} 
																{
																fee-fixed: uint, 
																source-factor: uint,
																helper-factor:uint, 
																is-source-numerator: bool, 
																min-dca-threshold: uint, 
																max-dca-threshold: uint, 
																max-slippage: uint,
																id: uint,
																token0: principal,
																token1: principal,
																token-in: principal,
																token-out: principal,
															})

(define-map approved-startegies principal bool)

(define-map fee-map { source: principal } { fee: uint })

(define-map dca-data { user: principal,
												source: principal, 
												target: principal,
												interval: uint,
												strategy: principal} 
											{ is-paused: bool,
												amount: uint, ;; amount per dca
												source-amount-left: uint,
												target-amount: uint,
												min-price: uint,
												max-price: uint,
												last-updated-timestamp: uint})

(define-map interval-id-to-seconds uint uint)
(map-set interval-id-to-seconds u0 TWO_HOURS) 
(map-set interval-id-to-seconds u1 SIX_HOURS) 
(map-set interval-id-to-seconds u2 TWELVE_HOURS) 
(map-set interval-id-to-seconds u3 ONE_DAY) 
(map-set interval-id-to-seconds u4 ONE_WEEK) 
;; ----------------------------------------------------------------------------------------
;; --------------------------------------Getters-------------------------------------------
;; ----------------------------------------------------------------------------------------
(define-read-only (is-none-zero (num uint)) (> num u0))

(define-read-only (get-dca-data (key (tuple (user principal) (source principal) (target principal) (interval uint) (strategy principal))))
	(map-get? dca-data key))

(define-read-only (get-sources-targets-config (source principal) (target principal)) 
	(ok (map-get? sources-targets-config {source:source, target:target})))

(define-read-only (get-fee (source principal)) (default-to  u0 (get fee (map-get? fee-map {source: source}))))

(define-read-only (is-approved) (contract-call? .auth-v0-0 is-approved contract-caller))

(define-read-only (is-approved-dca-network) (contract-call? .auth-v0-0 is-approved-dca-network contract-caller))

(define-read-only (is-approved-startegy (strat principal)) (map-get? approved-startegies strat))

(define-read-only (get-interval-seconds (interval uint))
  (map-get? interval-id-to-seconds interval)
)

(define-read-only (get-block-ts (block uint)) 
	(unwrap-panic (get-block-info? time block))
)
;; ----------------------------------------------------------------------------------------
;; --------------------------------------Setters-------------------------------------------
;; ----------------------------------------------------------------------------------------
(define-public (set-sources-targets-config (source principal) 
																						(target principal) 
																						(id uint)
																						(fee-fixed uint)
																						(source-factor uint) 
																						(helper-factor uint) 
																						(is-source-numerator bool) 
																						(min-dca-threshold uint) 
																						(max-dca-threshold uint) 
																						(max-slippage uint)
																						(token0 principal)
																						(token1 principal)
																						(token-in principal)
																						(token-out principal)
																						) 
	(let ((value {id:id, fee-fixed:fee-fixed, source-factor: source-factor, helper-factor:helper-factor, is-source-numerator:is-source-numerator, min-dca-threshold: min-dca-threshold, max-dca-threshold: max-dca-threshold, max-slippage: max-slippage, token0: token0, token1: token1, token-in: token-in, token-out: token-out})) 		
		(asserts! (is-approved) ERR-NOT-AUTHORIZED)
		(asserts! (not (is-eq source target)) ERR-INVALID-PRINCIPAL)
		(asserts! (> max-dca-threshold min-dca-threshold) ERR-INVALID-THRESHOLD)
		(ok (map-set sources-targets-config {source: source, target: target} value))
))

(define-public (remove-sources-targets-config (source principal) 
																						(target principal) ) 
	(begin 		
		(asserts! (is-approved) ERR-NOT-AUTHORIZED)
		(ok (map-delete sources-targets-config {source: source, target: target}))
))

(define-public (set-approved-strategy (strat principal) (status bool)) 
	(begin 
		(asserts! (is-approved) ERR-NOT-AUTHORIZED) 
		(ok (map-set approved-startegies strat status))
))

(define-public (set-treasury (address principal)) 
	(begin 
	(asserts! (is-approved) ERR-NOT-AUTHORIZED) 
	(ok (var-set treasury address))
))

;; sender can modify his paused; dca-amount, min & max price
(define-public (set-user-dca-data (source principal) (target principal) (interval uint) (strategy principal) (is-paused bool) (amount uint) (min-price uint) (max-price uint)) 
		(let ((user contract-caller)
					(key {user:user, strategy:strategy, source:source, target:target, interval:interval})
					(data (unwrap! (get-dca-data key) ERR-INVALID-KEY))
					)
		;; (asserts! (is-approved) ERR-NOT-AUTHORIZED) 
		(ok (map-set dca-data {user:user, source:source, target:target, interval:interval, strategy:strategy} 
											(merge data {amount: amount, is-paused: is-paused, min-price: min-price, max-price: max-price})
											)) 
))

;; ----------------------------------------------------------------------------------------
;; ----------------------------------------DCA---------------------------------------------
;; ----------------------------------------------------------------------------------------
(define-public (create-dca  (source-trait <ft-trait-b>) 
														(target principal)
														(interval uint)
														(total-amount uint)
														(dca-amount uint)
														(min-price uint)
														(max-price uint)
														(strategy principal))
	(let ((sender tx-sender)
			(source (contract-of source-trait))
			(data {is-paused: false, amount: dca-amount, source-amount-left: total-amount, target-amount: u0, min-price: min-price, max-price: max-price, last-updated-timestamp:u0})
			(sources-targets-conf  (unwrap! (map-get? sources-targets-config {source: source, target: target}) ERR-INVALID-PRINCIPAL) )
			(min-dca-threshold (get min-dca-threshold sources-targets-conf))
			(max-dca-threshold (get max-dca-threshold sources-targets-conf))
			)
		(asserts! (and (>= dca-amount min-dca-threshold) (<= dca-amount max-dca-threshold) (>= total-amount dca-amount)) ERR-INVALID-AMOUNT)
		(asserts! (not (is-eq (contract-of source-trait) target)) ERR-INVALID-PRINCIPAL)
		(unwrap! (map-get? interval-id-to-seconds interval) ERR-INVALID-INTERVAL)
		(unwrap! (map-get? approved-startegies strategy) ERR-INVALID-STRATEGY)
		(asserts! (map-insert dca-data {user:sender, source:source, target:target, interval:interval, strategy: strategy} data) ERR-DCA-ALREADY-EXISTS)
		(contract-call? source-trait transfer total-amount sender .dca-vault-v0-0 none)
))

(define-public (add-to-position (source-trait <ft-trait-b>) (target principal) (interval uint) (strategy principal) (amount uint)) 
	(let (
			(sender tx-sender)
			(source (contract-of source-trait))
			(key {user:sender, strategy:strategy, source:source, target:target, interval:interval})
			(data (unwrap! (get-dca-data key) ERR-INVALID-KEY))
			(prev-amount (get source-amount-left data))
			) 
		(try! (contract-call? source-trait transfer amount sender .dca-vault-v0-0 none))
		(ok (map-set dca-data {user:sender, source:source, target:target, interval:interval, strategy: strategy} (merge data {source-amount-left: (+ amount prev-amount)})))
))

(define-public (reduce-position (source-trait <ft-trait-b>) (target principal) (interval uint) (strategy principal) (amount uint)) 
	(let (
			(sender tx-sender)
			(source (contract-of source-trait))
			(key {user:sender, strategy:strategy, source:source, target:target, interval:interval})
			(data (unwrap! (get-dca-data key) ERR-INVALID-KEY))
			(prev-amount (get source-amount-left data))
			(amount-to-reduce (if (> amount prev-amount) prev-amount amount))
		)
		(asserts! (> amount-to-reduce u0) ERR-INVALID-AMOUNT)
		(as-contract (try! (contract-call? .dca-vault-v0-0 transfer-ft source-trait amount-to-reduce sender)))
		(ok (map-set dca-data {user:sender, source:source, target:target, interval:interval, strategy: strategy} (merge data {source-amount-left: (- prev-amount amount-to-reduce)})))
))

(define-public (withdraw (source principal) (target-trait <ft-trait-b>) (interval uint) (strategy principal) (amount uint)) 
	(let ((sender tx-sender)
			(target (contract-of target-trait))
			(key {user:sender, strategy:strategy, source:source, target:target, interval:interval})
			(data (unwrap! (get-dca-data key) ERR-INVALID-KEY))
			(prev-amount (get target-amount data))
			(amount-to-withdraw (if (> amount prev-amount) prev-amount amount))
			(is-paused (get is-paused data))
		)
		(asserts! (not is-paused) ERR-PAUSED)
		(asserts! (> amount-to-withdraw u0) ERR-INVALID-AMOUNT)
		(as-contract (try! (contract-call? .dca-vault-v0-0 transfer-ft target-trait amount-to-withdraw sender)))
		(ok (map-set dca-data {user:sender, source:source, target:target, interval:interval, strategy: strategy} (merge data {target-amount: (- prev-amount amount-to-withdraw)})))
))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; TODO try moving the fees logic to the withdraw function?
(define-public (dca-users-a (keys (list 50 {user:principal, source:principal, target:principal, interval:uint, strategy: principal}))
													(dca-strategy <strategy-trait>)
													(source-trait <ft-trait-a>)
													(target-trait <ft-trait-a>)
													(helper-trait (optional <ft-trait-a>))
													)
		(let ((source (contract-of source-trait))
					(target (contract-of target-trait))
					(source-target-config (unwrap! (map-get? sources-targets-config {source: source, target: target}) ERR-INVALID-PRINCIPAL))
					(source-factor (get source-factor source-target-config))
					(is-source-numerator (get is-source-numerator source-target-config))
					(price (try! (get-price-a source target (get source-factor source-target-config) is-source-numerator helper-trait (some (get helper-factor source-target-config)))))
					(curr-ts (get-block-ts (- block-height u1)))
					(agg-amounts (fold aggregate-amounts keys {amount:u0, 
																											user-amounts: none,
																											source: source, target:target, price:price, curr-ts: curr-ts }))
					(user-amounts-opt (get user-amounts agg-amounts))
					(total-source-amount (get amount agg-amounts))
				)	
				;; (print {user-amounts: user-amounts-opt, fee:fee })
				(asserts! (> total-source-amount u0) ERR-INVALID-AMOUNT)
				(asserts! (is-approved-dca-network) ERR-NOT-AUTHORIZED) ;; Initially, only approved users can run this function to minimize the risk of intentional slippage. In future versions, a decentralized network will take over this role.
				(unwrap! (map-get? approved-startegies (contract-of dca-strategy)) ERR-INVALID-STRATEGY)
				(match user-amounts-opt user-amounts
															(let ((fee (* (get fee-fixed source-target-config) (len (filter is-none-zero user-amounts))))
																		(traded-source-amount (- total-source-amount fee))
																	)
																	(add-fee fee source) 
																	(try! (as-contract (contract-call? .dca-vault-v0-0 transfer-ft source-trait traded-source-amount (contract-of dca-strategy))))
																	(let ((total-target-amount (as-contract (try! (contract-call? dca-strategy alex-swap-wrapper 
																																								source-trait 
																																								target-trait 
																																								source-factor 
																																								traded-source-amount 
																																								(mul-down (if is-source-numerator (mul-down price traded-source-amount) (div-down traded-source-amount price)) (- ONE_8 (get max-slippage source-target-config))) ;; min-dy
																																								(get helper-factor source-target-config) 
																																								helper-trait))))
																				) 
																			(ok (map set-new-amounts (list total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount)
																															(list total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount)
																															user-amounts ;; traded amount + fees
																															keys
																															)))
															) 
															ERR-INVALID-USER-AMOUNTS
						)
))

(define-private (set-new-amounts (total-source-amount uint)
																	(total-target-amount uint)	
																	(user-dca-amount uint)
																	(key {user:principal, source:principal, target:principal, interval:uint, strategy: principal}) 
																	)  
	(if (> user-dca-amount u0) 
		(let (
				(prev (unwrap-panic (get-dca-data key)))
				(source-amount-left (get source-amount-left prev))
				(prev-user-target-amount (get target-amount prev))
				(user-source-share (div-down user-dca-amount total-source-amount))
				(user-target-amount (mul-down user-source-share total-target-amount))
				(new-target-amount (+ prev-user-target-amount user-target-amount))
			)
			(map-set dca-data key (merge prev {source-amount-left: (- source-amount-left user-dca-amount),
											target-amount: (+ prev-user-target-amount user-target-amount)}))
			user-target-amount
		)
	u0)
)

(define-private (aggregate-amounts (key (tuple (strategy principal) (interval uint) (source principal) (target principal) (user principal)))
																		(prev (tuple (amount uint)
																					;; (fee uint)
																					(user-amounts (optional (list 50 uint))) 
																					(source principal) (target principal) (price uint) (curr-ts uint) ))
																		)
		(let ((interval (get interval key))
					(data-resp (get-dca-data key))
					(curr-ts (get curr-ts prev))
					(price (get price prev))
					;; (fee-fixed (get fee-fixed prev)) 
					(user-amounts (get user-amounts prev))
				) 
				(match data-resp 
						data
							(let ((dca-amount (get amount data))
										(source-amount-left (get source-amount-left data))
										(amount-traded (if (< source-amount-left dca-amount) source-amount-left dca-amount)))  
									(if (and (>= curr-ts (+ (unwrap-panic (get-interval-seconds interval)) (get last-updated-timestamp data))) ;; we dont need to check for valid interval since its part of the getdcadata key check
													(not (get is-paused data))
													(and (<= price (get max-price data)) (>= price (get min-price data)))
													(and (is-eq (get source key) (get source prev)) (is-eq (get target key) (get target prev)))
											) 
										(begin 
											;; (print {source-amount-left: source-amount-left, dca-amount:dca-amount, prev:prev, key:key})
											(map-set dca-data key (merge data {last-updated-timestamp: curr-ts}))
											(merge prev
															;; {amount: (- (+ (if (< source-amount-left dca-amount) source-amount-left dca-amount) (get amount prev)) fee-fixed),
															{amount: (+ amount-traded (get amount prev)),
															user-amounts: (as-max-len? (append (default-to (list ) user-amounts) amount-traded) u50),
															;; fee: (+ fee-fixed (get fee-fixed prev)) ;; TODO could be a cheaper way to do this by filtering user-amounts wher e amount!=0 and then getting its length and multiplying it by fee
															} 
													)
											)
										(merge prev {user-amounts: (as-max-len? (append (default-to (list ) user-amounts) u0) u50) })
							))
				(merge prev {user-amounts: (as-max-len? (append (default-to (list ) user-amounts) u0) u50) })
)))

(define-read-only (get-price-a (source principal) (target principal) (source-factor uint) (is-source-numerator bool) (helper-trait-opt (optional <ft-trait-a>)) (helper-factor (optional uint)))
	(match helper-trait-opt helper-trait (get-price-a-hop source target source-factor helper-trait (unwrap-panic helper-factor) is-source-numerator)  
																			(get-price-a-internal source target source-factor))
)

(define-private (get-price-a-internal (source principal) (target principal) (factor uint))
		(let ((token-x (if (is-eq target 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wstx-v0-0) target source))
					(token-y (if (is-eq target 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wstx-v0-0) source target))
					) 
		(contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01 get-price token-x token-y factor)
))

(define-private (get-price-a-hop (source principal) (target principal) (source-factor uint) (helper-trait <ft-trait-a>) (helper-factor uint) (is-source-numerator bool)) 
	(let ((helper (contract-of helper-trait))
			(price-a (try! (get-price-a-internal helper source source-factor)))
			(price-b (try! (get-price-a-internal helper target helper-factor)))
		)
		(ok (if is-source-numerator (div-down price-b price-a) (div-down price-a price-b)))	
))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; token 0 & 1 define the pool
;; @param token0 define the pool
;; @param token1 define the pool
;; @param mock-price, the velar getprice requires
(define-public (dca-users-b (dca-strategy <strategy-trait>)
														(token0 <ft-trait-b>)
														(token1 <ft-trait-b>)
														(token-in <ft-trait-b>)
														(token-out <ft-trait-b>)
														(mock-price uint)
														(share-fee-to <share-fee-to-trait>)
														(keys (list 50 {user:principal, source:principal, target:principal, interval:uint, strategy: principal}))
														)
		(let ((source (contract-of token-in))
					(target (contract-of token-out))
					(source-target-config (unwrap! (map-get? sources-targets-config {source: source, target: target}) ERR-INVALID-PRINCIPAL))
					(id (get id source-target-config))
					(max-slippage (get max-slippage source-target-config))
					(is-source-numerator (get is-source-numerator source-target-config))
					(curr-ts (get-block-ts (- block-height u1)))
					(agg-amounts (fold aggregate-amounts keys {amount:u0, 
																											user-amounts: none,
																											source: source, target:target, price: mock-price, curr-ts: curr-ts }))
					(user-amounts-opt (get user-amounts agg-amounts))
					(total-source-amount (get amount agg-amounts))
					(price (try! (get-price-b id (contract-of token0) source total-source-amount is-source-numerator)))
				)
				;; (print {user-amounts: user-amounts-opt, fee:fee })
				(asserts! (> total-source-amount u0) ERR-INVALID-AMOUNT)
				(asserts! (and (>= mock-price (mul-down-6 price (- ONE_6 max-slippage))) (<= mock-price (mul-down-6 price (+ ONE_6 max-slippage)))) ERR-INVALID-PRICE)
				(asserts! (is-approved-dca-network) ERR-NOT-AUTHORIZED) ;; Initially, only approved users can run this function to minimize the risk of intentional slippage. In future versions, a decentralized network will take over this role.
				(unwrap! (map-get? approved-startegies (contract-of dca-strategy)) ERR-INVALID-STRATEGY)
					(begin 
						
						
				(match user-amounts-opt user-amounts
															(let ((fee (* (get fee-fixed source-target-config) (len (filter is-none-zero user-amounts))))
																		(traded-source-amount (- total-source-amount fee))
																	) 
																	(add-fee fee source)
																	(try! (as-contract (contract-call? .dca-vault-v0-0 transfer-ft token-in traded-source-amount (contract-of dca-strategy))))
																	(let ((total-target-amount (as-contract (try! (contract-call? dca-strategy velar-swap-wrapper id token0 token1 token-in token-out share-fee-to total-source-amount (mul-down-6 (if is-source-numerator (mul-down-6 price total-source-amount) (div-down-6 total-source-amount price)) (- ONE_6 max-slippage)) ))))
																				)
																			(ok (map set-new-amounts (list total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount total-source-amount)
																															(list total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount total-target-amount)
																															user-amounts ;; total amount + fees
																															keys
																															)))
																)
																ERR-INVALID-USER-AMOUNTS
						)
)))

(define-read-only (get-price-b (id uint) (token0 principal) (token-in principal) (amt-source uint) (is-source-numerator bool)) 
	(let ((pool (contract-call? 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-core do-get-pool id))
				(is-token0 (is-eq token0 token-in))
				(amt-target  (try! (contract-call? 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-library get-amount-out
													amt-source
													(if is-token0 (get reserve0 pool) (get reserve1 pool)) ;; reserve-in
													(if is-token0 (get reserve1 pool) (get reserve0 pool)) ;; reserve-out
													(get swap-fee pool) )))
			)
		(ok (if (is-eq amt-target u0)
				u0
				(if is-source-numerator (div-down-6 amt-target amt-source) (div-down-6 amt-source amt-target))
))))
;; ----------------------------------------------------------------------------------------
;; -----------------------------------------FEES-------------------------------------------
;; ----------------------------------------------------------------------------------------
(define-private (add-fee (new-fee uint) (source principal)) 
	(if (> new-fee u0)  
			(map-set fee-map {source: source} {fee: (+ new-fee (get-fee source))})
			false
		)
)

(define-public (transfer-fee-to-treasury (source-trait <ft-trait-a>))
(let ((source  (contract-of source-trait))
			(fee (unwrap-panic (get fee (map-get? fee-map {source: source})))))
		(try! (contract-call? .dca-vault-v0-0 transfer-ft source-trait fee (var-get treasury)))
		(ok (map-set fee-map {source: source} {fee: u0}))
))
;; ----------------------------------------------------------------------------------------
;; -----------------------------------------MATH-------------------------------------------
;; ----------------------------------------------------------------------------------------
(define-private (mul-down (a uint) (b uint))
	(/ (* a b) ONE_8))

(define-private (mul-down-6 (a uint) (b uint))
	(/ (* a b) ONE_6))

(define-private (div-down (a uint) (b uint))
	(if (is-eq a u0) u0 (/ (* a ONE_8) b)))

(define-private (div-down-6 (a uint) (b uint))
	(if (is-eq a u0) u0 (/ (* a ONE_6) b)))