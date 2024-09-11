(use-trait ft-trait-a 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.trait-sip-010.sip-010-trait)
(use-trait ft-trait-b 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait share-fee-to-trait 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to-trait.share-fee-to-trait)
(use-trait strategy-trait  .strategy.default-strategy)

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
(define-constant ERR-MAX-SLIPPAGE-EXCEEDED (err u9011))

(define-constant ONE_8 u100000000) ;; 8 decimal places

(define-data-var treasury principal tx-sender)

(define-map sources-targets-config {source: principal, target: principal} 
															{id: uint,
															fee-fixed: uint, 
															fee-percent: uint,
															source-factor: uint,
															helper-factor:uint, 
															is-source-numerator: bool, 
															min-dca-threshold: uint, 
															max-dca-threshold: uint, 
															max-slippage: uint
															})

(define-map user-keys { user: principal }
											(list 1000 {source:principal, target:principal, interval:uint, strategy: principal})
)

(define-map approved-startegies principal bool)

(define-map fee-map { source: principal } { fee: uint })

(define-map dca-data { user: principal,
												source: principal,
												target: principal,
												interval: uint,
												;; a user can have multiple strategies on the same source-target combination
												strategy: principal} 
											{ is-paused: bool,
												amount: uint, ;; amount per dca
												source-amount-left: uint,
												target-amount: uint,
												min-price: uint,
												max-price: uint,
												last-updated-timestamp: uint})

(define-map interval-id-to-seconds { interval: uint  } { seconds: uint })
(map-set interval-id-to-seconds {interval: u0} {seconds: u7200}) ;; 2 hrs
(map-set interval-id-to-seconds {interval: u1} {seconds: u43200})  ;; 12 hrs
(map-set interval-id-to-seconds {interval: u2} {seconds: u86400}) ;; daily
(map-set interval-id-to-seconds {interval: u3} {seconds: u604800}) ;; weekly
;; ----------------------------------------------------------------------------------------
;; --------------------------------------Getters-------------------------------------------
;; ----------------------------------------------------------------------------------------
(define-read-only (get-dca-data (user principal) (source principal) (target principal) (interval uint) (strategy principal))
	(map-get? dca-data {user:user, source:source, target:target, interval:interval, strategy: strategy}))

(define-read-only (get-sources-targets-config (source principal) (target principal)) 
	(ok (map-get? sources-targets-config {source:source, target:target})))
(define-read-only (get-fee (source principal)) (default-to  u0 (get fee (map-get? fee-map {source: source}))))

(define-read-only (is-approved) (contract-call? .auth is-approved))

(define-read-only (is-approved-startegy (strat principal)) (map-get? approved-startegies strat))

(define-read-only (get-interval-seconds (interval uint))
  (map-get? interval-id-to-seconds {interval: interval})
)
;; ----------------------------------------------------------------------------------------
;; --------------------------------------Setters-------------------------------------------
;; ----------------------------------------------------------------------------------------
(define-public (set-sources-targets-config (source principal) (target principal) (id uint) (fee-fixed uint) (fee-percent uint) (source-factor uint) (helper-factor uint) (is-source-numerator bool) (min-dca-threshold uint) (max-dca-threshold uint) (max-slippage uint)) 
	(let ((value {id:id, fee-fixed:fee-fixed, fee-percent:fee-percent, source-factor: source-factor, helper-factor:helper-factor, is-source-numerator:is-source-numerator, min-dca-threshold: min-dca-threshold, max-dca-threshold: max-dca-threshold, max-slippage: max-slippage})) 		
		(asserts! (is-approved) ERR-NOT-AUTHORIZED) 
		(print {function:"set-sources-targets-config", params: value, source:source, target:target})
		(ok (map-set sources-targets-config {source: source, target: target} value))
))

(define-public (set-approved-strategy (strat principal) (status bool)) 
	(begin 
		(asserts! (is-approved) ERR-NOT-AUTHORIZED) 
		(ok (map-set approved-startegies strat status))
))

(define-private (set-new-user-key (user principal) 
														(source principal) 
														(target principal)
														(interval uint)
														(strategy principal))
	(let ((key-opt (map-get? user-keys {user: user}))
					) 
					(ok (match key-opt key 
					(map-set user-keys {user:user}  
															(concat 
																	(unwrap! (as-max-len? key u999) ERR-MAX-POSITIONS-EXCEEDED)  
																	(list {source:source, target:target, interval:interval, strategy: strategy})))
					(map-insert user-keys {user: user} (list {source:source, target:target, interval:interval, strategy: strategy}))				
))))

(define-public (set-treasury (address principal)) 
	(begin 
	(asserts! (is-approved) ERR-NOT-AUTHORIZED) 
	(ok (var-set treasury address))
	))
;; --------------------------------------------------------------------------
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
		(unwrap! (map-get? interval-id-to-seconds {interval: interval}) ERR-INVALID-INTERVAL)
		(unwrap! (map-get? approved-startegies strategy) ERR-INVALID-STRATEGY)
		(asserts! (map-insert dca-data {user:sender, source:source, target:target, interval:interval, strategy: strategy} data) ERR-DCA-ALREADY-EXISTS)
		(try! (set-new-user-key sender source target interval strategy))
		(print {function: "create-dca", 
						input: {user: sender, source-trait: source-trait, target:target, interval:interval, total-amount:total-amount, dca-amount:dca-amount, min-price:min-price, max-price: max-price},
						more: {more: data }})
		(contract-call? source-trait transfer total-amount sender .dca-vault none)
))

(define-public (add-to-position (source-trait <ft-trait-b>) (target principal) (interval uint) (strategy principal) (amount uint)) 
	(let (
			(sender tx-sender)
			(source (contract-of source-trait))
			(data (unwrap! (get-dca-data sender source target interval strategy) ERR-INVALID-KEY))
			(prev-amount (get source-amount-left data))
			) 
		(try! (contract-call? source-trait transfer amount sender .dca-vault none))
		(print {function: "add-to-position", 
							input: {source-trait: source-trait, target:target, interval:interval, amount:amount, sender: sender},
							more: {more: data, prev-amount: prev-amount, source-amount-left: (+ amount prev-amount) }})
		(ok (map-set dca-data {user:sender, source:source, target:target, interval:interval, strategy: strategy} (merge data {source-amount-left: (+ amount prev-amount)})))
))

(define-public (reduce-position (source-trait <ft-trait-b>) (target principal) (interval uint) (strategy principal) (amount uint)) 
	(let (
			(sender tx-sender)
			(source (contract-of source-trait))
			(data (unwrap! (get-dca-data sender source target interval strategy) ERR-INVALID-KEY))
			(prev-amount (get source-amount-left data))
			(amount-to-reduce (if (> amount prev-amount) prev-amount amount))
		)
		(asserts! (> amount-to-reduce u0) ERR-INVALID-AMOUNT)
		(as-contract (try! (contract-call? .dca-vault transfer-ft source-trait amount-to-reduce sender)))
		(print {function: "reduce-position", 
							input: {source-trait: source-trait, target:target, interval:interval, amount:amount, sender: sender},
							more: {more: data, prev-amount: prev-amount, amount-to-reduce: amount-to-reduce }})
		(ok (map-set dca-data {user:sender, source:source, target:target, interval:interval, strategy: strategy} (merge data {source-amount-left: (- prev-amount amount-to-reduce)})))
))

(define-public (withdraw (source principal) (target-trait <ft-trait-b>) (interval uint) (strategy principal) (amount uint)) 
	(let ((sender tx-sender)
		(target (contract-of target-trait))
		(data (unwrap! (get-dca-data sender source target interval strategy) ERR-INVALID-KEY))
		(prev-amount (get target-amount data))
		(amount-to-withdraw (if (> amount prev-amount) prev-amount amount))
		) 
		(asserts! (> amount-to-withdraw u0) ERR-INVALID-AMOUNT)
		(as-contract (try! (contract-call? .dca-vault transfer-ft target-trait amount-to-withdraw sender)))
		(print {function: "withdraw", 
						input: {target-trait: target-trait, source:source, interval:interval, amount:amount, sender: sender},
						more: {more: data, prev-amount: prev-amount, amount-to-withdraw:amount-to-withdraw }})
	(ok (map-set dca-data {user:sender, source:source, target:target, interval:interval, strategy: strategy} (merge data {target-amount: (- prev-amount amount-to-withdraw)})))
))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-public (dca-users-a (keys (list 20 {user:principal, source:principal, target:principal, interval:uint, strategy: principal}))
													(dca-strategy <strategy-trait>)
													(source-trait <ft-trait-a>)
													(target-trait <ft-trait-a>)
													(helper-trait (optional <ft-trait-a>))
													)
		(let ((source (contract-of source-trait))
					(target (contract-of target-trait))
					(curr-timestamp (unwrap-panic (get-block-info? time (- block-height u1))))
					(curr-timestamp-list (list curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp))
					(user-amounts (map dca-user (list source-trait source-trait source-trait source-trait source-trait source-trait source-trait source-trait source-trait source-trait source-trait source-trait source-trait source-trait source-trait source-trait source-trait source-trait source-trait source-trait) 	
																(list target-trait target-trait target-trait target-trait target-trait target-trait target-trait target-trait target-trait target-trait target-trait target-trait target-trait target-trait target-trait target-trait target-trait target-trait target-trait target-trait) 	
																(list helper-trait helper-trait helper-trait helper-trait helper-trait helper-trait helper-trait helper-trait helper-trait helper-trait helper-trait helper-trait helper-trait helper-trait helper-trait helper-trait helper-trait helper-trait helper-trait helper-trait) 	
																keys
																curr-timestamp-list
													))
						)
					(print {user-amounts: user-amounts})
					(let ((agg-amounts (fold aggregate-amounts user-amounts {total-amount: u0, fee: u0, price: u0}))
					(source-total-amount (get total-amount agg-amounts)) ;; u9950000000
					(fee (get fee agg-amounts))
					(source-target-config (unwrap! (map-get? sources-targets-config {source: source, target: target}) ERR-INVALID-PRINCIPAL))
					(is-source-numerator (get is-source-numerator source-target-config))
					(source-factor (get source-factor source-target-config))
					(helper-factor (get helper-factor source-target-config))
					(max-slippage (get max-slippage source-target-config))
					;; (price (try! (get-price source target source-factor is-source-numerator helper-trait (some helper-factor)))) ;; u82513081639
					(price (get price agg-amounts))
					(amount-dy (if is-source-numerator (div-down price source-total-amount) (mul-down source-total-amount price))) ;; u12_058693
					(min-dy (- amount-dy (mul-down amount-dy max-slippage))) 
				) 
				(if (is-eq source-total-amount u0) (ok (list u0)) 
					(begin 
						(try! (as-contract (contract-call? .dca-vault transfer-ft source-trait source-total-amount (contract-of dca-strategy))))
						(let (
								(target-total-amount (as-contract (try! (contract-call? dca-strategy alex-swap-wrapper source-trait target-trait source-factor source-total-amount min-dy helper-factor helper-trait))))
								)
								(print { function:"dca-users", 
												input: {source:source-trait, target:target-trait, keys:keys, dca-strategy:dca-strategy, helper-tait:helper-trait},
												more: {source-target-config:source-target-config, agg-amounts:agg-amounts, amount-dy:amount-dy, min-dy:min-dy, target-total-amount:target-total-amount} })
								(add-fee fee source)
								(ok (map set-new-target-amount (list source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount)
																						(list target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount)
																						curr-timestamp-list
																						user-amounts
																						))
))))))

(define-private (dca-user (source-trait <ft-trait-a>)
													(target-trait <ft-trait-a>)
													(helper-trait (optional <ft-trait-a>))
													(key (tuple (user principal) (source principal) (target principal) (interval uint) (strategy principal))) 
													(curr-timestamp uint))
	(let ((user (get user key))
				(source (get source key))
				(target (get target key))
				(interval (get interval key))
				(strategy (get strategy key))
				(data (unwrap! (get-dca-data user source target interval strategy) ERR-INVALID-KEY))
				(source-amount-left (get source-amount-left data))
				(amount (get amount data))
				(target-amount (get target-amount data))
				(last-updated-timestamp (get last-updated-timestamp data))
				(min-price (get min-price data))
				(max-price (get max-price data))
				(interval-seconds (unwrap! (get-interval-seconds interval) ERR-INVALID-INTERVAL))
				(target-timestamp (+ (get seconds interval-seconds) last-updated-timestamp))
				) 
				(print {function: "dca-user", 
								input: {user: user, source: source, target: target, interval: interval, curr-timestamp: curr-timestamp},
								more: {amount: amount, interval-secoinds: interval-seconds, target-timestamp: target-timestamp}})
				(asserts! (is-eq (contract-of source-trait) source) ERR-INVALID-PRINCIPAL)
				(asserts! (is-eq (contract-of target-trait) target) ERR-INVALID-PRINCIPAL)
				(if (>= curr-timestamp target-timestamp)
						(process-swap source target helper-trait user amount min-price max-price source-amount-left interval strategy)
						(ok {amount-minus-fee: u0, fee: u0, price: u0, key: none})
)))

(define-private (process-swap (source principal)
															(target principal)
															(helper-trait (optional <ft-trait-a>))
															(user principal)
															(dca-amount uint)
															(min-price uint)
															(max-price uint)
															(source-amount-left uint)
															(interval uint)
															(strategy principal)
															) 
		(let ((source-target-config (unwrap! (map-get? sources-targets-config {source: source, target: target}) ERR-CONFIG-NOT-SET))
				(amount-to-trade (if (< source-amount-left dca-amount) source-amount-left dca-amount))
				(is-source-numerator (get is-source-numerator source-target-config))
				(source-factor (get source-factor source-target-config))
				(helper-factor (get helper-factor source-target-config))
				(fee-fixed (get fee-fixed source-target-config))
				(fee-percent (get fee-percent source-target-config))
				(amount-and-fee (get-amount-and-fee amount-to-trade source fee-fixed fee-percent))
				(price (try! (get-price source target source-factor is-source-numerator helper-trait (some helper-factor))))
				(swap-info (merge amount-and-fee { price: price }))
			)
		(print {function: "process-swap", 
						input:{ source:source, target:target, user:user, dca-amount:dca-amount, source-amount-left:source-amount-left, interval:interval, max-price:max-price, min-price:min-price},
						more:{ amount-to-trade:amount-to-trade, price:price, amount-and-fee: amount-and-fee }})
		(asserts! (and (<= price max-price) (>= price min-price)) ERR-INVALID-PRICE)
		(ok (merge swap-info {key:(some {user:user, source:source, target:target, interval:interval, strategy: strategy})})
)))

(define-private (get-amount-and-fee  (amount-to-trade uint) (source principal) (fee-fixed uint) (fee-percent uint)) 
	(let ((fee (calc-fees amount-to-trade source fee-fixed fee-percent))
				(amount-minus-fee (- amount-to-trade fee))
			) 
			{amount-minus-fee: amount-minus-fee, fee: fee}				
))

(define-private (set-new-target-amount (source-total-amount uint) ;; u9999500000
																			(target-total-amount uint)
																			(curr-timestamp uint) 
																			(user-dca-amount-resp (response (tuple (amount-minus-fee uint) (fee uint) (price uint) (key (optional (tuple (interval uint) (source principal) (target principal) (user principal) (strategy principal))))) uint))
																			)  
			(match user-dca-amount-resp user-dca-amount
				(let ((key (unwrap-panic (get key user-dca-amount)))
							(data (unwrap-panic (get-dca-data (get user key) (get source key) (get target key) (get interval key) (get strategy key))))
							(source-amount-left (get source-amount-left data))
							(target-amount (get target-amount data))
							(amount-minus-fee (get amount-minus-fee user-dca-amount))
							(fee (get fee user-dca-amount))								
							(source-amount-traded (+ fee amount-minus-fee))  ;; u10000000000
							(target-amount-traded (mul-down (div-down source-amount-traded source-total-amount) target-total-amount))
						)
						(map-set dca-data key (merge data {last-updated-timestamp: curr-timestamp, 
														source-amount-left: (- source-amount-left source-amount-traded),
														target-amount: (+ target-amount target-amount-traded)}))
						(print {function:"set-new-target-amount", more:{amount-minus-fee: amount-minus-fee, source-amount-traded: source-amount-traded, 
																															target-amount-traded: target-amount-traded, source-total-amount: source-total-amount }})								
						target-amount-traded
					)
			user-dca-err
			u0
	))

(define-private (aggregate-amounts (curr-resp (response (tuple (amount-minus-fee uint) (price uint) (fee uint) (key (optional (tuple (strategy principal) (interval uint) (source principal) (target principal) (user principal))))) uint))
																		(prev (tuple (total-amount uint) (fee uint) (price uint))))
		(let ((curr (match curr-resp curr curr err-curr {amount-minus-fee:u0, fee:u0, price: u0, key: none}))
					(curr-amount-minus-fee (get amount-minus-fee curr))
					(curr-fee (get fee curr))
					(curr-price (get price curr))
					(prev-amount-minus-fee (get total-amount prev))
					(prev-fee (get fee prev))
					(prev-price (get price prev))
				)
	{total-amount: (+ curr-amount-minus-fee prev-amount-minus-fee), fee: (+ curr-fee prev-fee), price: (if (> curr-price prev-price) curr-price prev-price)}
))

(define-private (get-price (source principal) (target principal) (source-factor uint) (is-source-numerator bool) (helper-trait-opt (optional <ft-trait-a>)) (helper-factor (optional uint)))
	(match helper-trait-opt helper-trait (get-price-hop source target source-factor helper-trait (unwrap-panic helper-factor) is-source-numerator)  
																								(get-price-internal source target source-factor))
)

(define-private (get-price-internal (token-x principal) (token-y principal) (factor uint)) 
		(contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01 get-price token-x token-y factor)
)

(define-private (get-price-hop (source principal) (target principal) (source-factor uint) (helper-trait <ft-trait-a>) (helper-factor uint) (is-source-numerator bool)) 
	(let ((helper (contract-of helper-trait))
			(price-a (try! (get-price-internal helper source source-factor))) ;; stx/usd: 1.78986355
			(price-b (try! (get-price-internal helper target helper-factor))) ;; stx/welsh : 958.02094616
			)
			(print {function:"get-price-hop", 
							params:{source:source, target:target, source-facotr:source-factor, helper-trait:helper-trait, helper-factor:helper-factor, is-source-numerator:is-source-numerator},
							more:{price-a:price-a, price-b:price-b}
			})										  
			(ok (if is-source-numerator (div-down price-b price-a) (div-down price-a price-b)))	
))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; token 0 & 1 define the pool
(define-public (dca-users-b (dca-strategy <strategy-trait>)
														(token0 <ft-trait-b>)
														(token1 <ft-trait-b>)
														(token-in <ft-trait-b>)
														(token-out <ft-trait-b>)
														(share-fee-to <share-fee-to-trait>)
														(swap-configs {target-amount-out: uint})
														(keys (list 20 {user:principal, source:principal, target:principal, interval:uint, strategy: principal}))
														)
		(let ((source (contract-of token-in))
					(target (contract-of token-out))
					(curr-timestamp (unwrap-panic (get-block-info? time (- block-height u1))))
					(curr-timestamp-list (list curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp))
					(user-amounts (map dca-user-b (list token0 token0 token0 token0 token0 token0 token0 token0 token0 token0 token0 token0 token0 token0 token0 token0 token0 token0 token0 token0)
																					(list token1 token1 token1 token1 token1 token1 token1 token1 token1 token1 token1 token1 token1 token1 token1 token1 token1 token1 token1 token1)
																					(list token-in token-in token-in token-in token-in token-in token-in token-in token-in token-in token-in token-in token-in token-in token-in token-in token-in token-in token-in token-in)
																					(list token-out token-out token-out token-out token-out token-out token-out token-out token-out token-out token-out token-out token-out token-out token-out token-out token-out token-out token-out token-out)
																					keys
																					curr-timestamp-list
																				))
		)
			(print {user-amounts: user-amounts})
			(let ((agg-amounts (fold aggregate-amounts user-amounts {total-amount: u0, fee: u0, price: u0}))
					(source-total-amount (get total-amount agg-amounts))
					(fee (get fee agg-amounts))
					(source-target-config (unwrap! (map-get? sources-targets-config {source: source, target: target}) ERR-INVALID-PRINCIPAL))
					(id (get id source-target-config))
					(max-slippage (get max-slippage source-target-config))
					(amt-out-min (get target-amount-out swap-configs))
					(is-source-numerator (get is-source-numerator source-target-config))
					(price (get price agg-amounts))
					(amount-dy (if is-source-numerator (div-down price source-total-amount) (mul-down source-total-amount price))) ;; u12_058693
					(min-dy (- amount-dy (mul-down amount-dy max-slippage)))
				)
				(if (is-eq source-total-amount u0) (ok (list u0)) 
					(begin 
						(asserts! (> min-dy amt-out-min) ERR-MAX-SLIPPAGE-EXCEEDED)
						(try! (as-contract (contract-call? .dca-vault transfer-ft token-in source-total-amount (contract-of dca-strategy))))
						(let ((swap-response (as-contract (try! (contract-call? dca-strategy velar-swap-wrapper id token0 token1 token-in token-out share-fee-to source-total-amount amt-out-min ))))
									(target-total-amount (get amt-out swap-response))
								)
								(print { function:"dca-users-b", 
												input: {tokeno:token0, token1:token1, token-in:token-in, token-out:token-out, keys:keys, dca-strategy:dca-strategy},
												more: {agg-amounts:agg-amounts, user-amounts:user-amounts, swap-configs:swap-configs, amount-dy:amount-dy, min-dy: min-dy} })
								(add-fee fee source)
								(ok (map set-new-target-amount (list source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount source-total-amount)
																						(list target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount target-total-amount)
																						curr-timestamp-list
																						user-amounts
																						))
))))))


(define-private (dca-user-b (token0 <ft-trait-b>)
														(token1 <ft-trait-b>)
														(token-in <ft-trait-b>)
														(token-out <ft-trait-b>)
														(key (tuple (user principal) (source principal) (target principal) (interval uint) (strategy principal))) 
														(curr-timestamp uint)) 
(let ((source-trait token-in)
				(target-trait token-out)
				(user (get user key))
				(source (get source key))
				(target (get target key))
				(interval (get interval key))
				(strategy (get strategy key))
				(data (unwrap! (get-dca-data user source target interval strategy) ERR-INVALID-KEY))
				(source-amount-left (get source-amount-left data))
				(dca-amount (get amount data))
				(target-amount (get target-amount data))
				(last-updated-timestamp (get last-updated-timestamp data))
				(min-price (get min-price data))
				(max-price (get max-price data))
				(interval-seconds (unwrap! (get-interval-seconds interval) ERR-INVALID-INTERVAL))
				(target-timestamp (+ (get seconds interval-seconds) last-updated-timestamp))
				) 
				(print {function: "dca-user-b", 
								input: {user: user, source: source, target: target, interval: interval, curr-timestamp: curr-timestamp},
								more: {interval-secoinds: interval-seconds, target-timestamp: target-timestamp}})
				(asserts! (is-eq (contract-of source-trait) source) ERR-INVALID-PRINCIPAL)
				(asserts! (is-eq (contract-of target-trait) target) ERR-INVALID-PRINCIPAL)
				(if (>= curr-timestamp target-timestamp)
						(process-swap-b (contract-of token0) source target user source-amount-left dca-amount min-price max-price interval strategy)
						(ok {amount-minus-fee: u0, fee: u0, price: u0, key: none}		
))))												

(define-private (process-swap-b (token0 principal)
																(token-in principal)
																(token-out principal)
																(user principal)
																(source-amount-left uint)
																(dca-amount uint)
																(min-price uint)
																(max-price uint)
																(interval uint)
																(strategy principal)
																) 
	(let ((source-target-config (unwrap! (map-get? sources-targets-config {source: token-in, target: token-out}) ERR-CONFIG-NOT-SET))
			(id (get id source-target-config))
			(fee-fixed (get fee-fixed source-target-config))
			(fee-percent (get fee-percent source-target-config))
			(is-source-numerator (get is-source-numerator source-target-config))
			(amount-to-trade (if (< source-amount-left dca-amount) source-amount-left dca-amount))
			(price (try! (get-price-b id token0 token-in dca-amount is-source-numerator)))
			(amount-and-fee (get-amount-and-fee amount-to-trade token-in fee-fixed fee-percent))
			(swap-info (merge amount-and-fee { price: price }))
			) 
		(print {function: "process-swap", 
						input:{ token-in:token-in, token-out:token-out, user:user, dca-amount:dca-amount, source-amount-left:source-amount-left, interval:interval, max-price:max-price, min-price:min-price},
						more:{ amount-to-trade:amount-to-trade, price: price, amount-and-fee: amount-and-fee }})	
		(asserts! (and (<= price max-price) (>= price min-price)) ERR-INVALID-PRICE)
		(ok (merge swap-info {key:(some {user:user, source:token-in, target:token-out, interval:interval, strategy: strategy})})
)))

(define-private (get-price-b (id uint) (token0 principal) (token-in principal) (amt-in uint) (is-source-numerator bool)) 
	(let ((pool (contract-call? 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-core do-get-pool id))
				(is-token0 (is-eq token0 token-in))
				(amt-out  (try! (contract-call? 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-library get-amount-out
													amt-in
													(if is-token0 (get reserve0 pool) (get reserve1 pool)) ;; reserve-in
													(if is-token0 (get reserve1 pool) (get reserve0 pool)) ;; reserve-out
													(get swap-fee pool) )))
				(price (if is-source-numerator (div-down amt-in amt-out) (div-down amt-out amt-in)))
			)
			(print {function: "get-price-b", input:{id: id, token0: token0, token-in: token-in, amt-in:amt-in}, 
												more: {price: price,  pool: pool, amt-out: amt-out}})
			(ok price)  ;; todo needs some condition based on is-numerator, token0 vs token-in etc & order of token1 vs token0
))
;; ----------------------------------------------------------------------------------------
;; -----------------------------------------FEES-------------------------------------------
;; ----------------------------------------------------------------------------------------
(define-private (calc-fees (amount uint) (source principal) (fee-fixed uint) (fee-percent uint)) 
	(let ((fee-perc-amount (mul-down amount fee-percent))
				(fee (+ fee-perc-amount fee-fixed))
				(prev-fee (default-to u0 (get fee (map-get? fee-map {source:source}))))
				(next-fee (+ fee prev-fee))
			)
		(print {function: "calc-fees", 
							more: {fee: fee, next-fee: next-fee,  prev-fee:prev-fee, fee-perc-amount:fee-perc-amount, fee-fixed:fee-fixed, amount:amount, fee-percent:fee-percent}})	
		fee
))

(define-private (add-fee (new-fee uint) (source principal)) 
	(let ((prev-fee (get-fee source))
			) 
		(map-set fee-map {source: source} {fee: (+ new-fee prev-fee)})
))

(define-public (transfer-fee-to-treasury (source-trait <ft-trait-a>))
(let ((source  (contract-of source-trait))
			(fee (unwrap-panic (get fee (map-get? fee-map {source: source})))))
		(try! (contract-call? .dca-vault transfer-ft source-trait fee (var-get treasury)))
		(print {function:"withdraw-fee", args:{source-trait:source-trait}, more:{fee:fee}})
		(ok (map-set fee-map {source: source} {fee: u0}))
))
;; ----------------------------------------------------------------------------------------
;; -----------------------------------------MATH-------------------------------------------
;; ----------------------------------------------------------------------------------------
(define-private (mul-down (a uint) (b uint))
	(/ (* a b) ONE_8))
(define-private (div-down (a uint) (b uint))
	(if (is-eq a u0) u0 (/ (* a ONE_8) b)))