(use-trait ft 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait share-fee-to-trait 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to-trait.share-fee-to-trait)

(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-INVALID-AMOUNT (err u2001))
(define-constant ERR-INVALID-PRINCIPAL (err u2002))
(define-constant ERR-INVALID-INTERVAL (err u2003))
(define-constant ERR-INVALID-KEY (err u2004))
(define-constant ERR-DCA-ALREADY-EXISTS (err u2005))
(define-constant ERR-INVALID-PRICE (err u2006))
(define-constant ERR-CONFIG-NOT-SET (err u2007))
(define-constant ERR-FETCHING-PRICE (err u2008))

(define-constant ONE_8 u100000000) ;; 8 decimal places

(define-data-var treasury principal tx-sender)

(define-map sources-targets-config {source: principal, target: principal} {id: uint, source-unit:uint, target-unit:uint, is-source-numerator: bool})

(define-map fee-map { source: principal } { fee: uint })

(define-map source-config { source: principal } 
													{ min-dca-threshold: uint, 
														fee-fixed: uint, 
														fee-percent: uint
														})

(define-map dca-data { user: principal,
												source: principal,
												target: principal,
												interval: uint } 
											{ 
												is-paused: bool,
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
(define-read-only (get-dca-data (user principal) (source principal) (target principal) (interval uint))
	(map-get? dca-data {user:user, source:source, target:target, interval:interval}))

(define-read-only (get-source-config (source principal)) (ok (map-get? source-config {source: source})))

(define-read-only (get-sources-targets-config (source principal) (target principal)) 
	(ok (map-get? sources-targets-config {source:source, target:target})))

(define-read-only (get-fee (source principal)) (map-get? fee-map {source: source}))

(define-read-only (is-approved) (contract-call? .auth is-approved))

(define-read-only (get-interval-seconds (interval uint))
  (map-get? interval-id-to-seconds {interval: interval})
)
;; ----------------------------------------------------------------------------------------
;; --------------------------------------Setters-------------------------------------------
;; ----------------------------------------------------------------------------------------
(define-public (set-sources-targets-config (source principal) (target principal) (id uint) (source-unit uint) (target-unit uint) (is-source-numerator bool)) 
	(begin 		
		(asserts! (is-approved) ERR-NOT-AUTHORIZED) 
		(ok (map-set sources-targets-config {source: source, target: target} {id:id, source-unit:source-unit, target-unit:target-unit, is-source-numerator:is-source-numerator}))
))

(define-public (set-source-config (source principal) (min-dca-threshold uint) (fee-fixed uint) (fee-percent uint)) 
	(begin 		
		(asserts! (is-approved) ERR-NOT-AUTHORIZED) 
		(ok (map-set source-config {source: source} {min-dca-threshold: min-dca-threshold, fee-fixed:fee-fixed, fee-percent:fee-percent}))
))
;; ----------------------------------------------------------------------------------------
;; ----------------------------------------DCA---------------------------------------------
;; ----------------------------------------------------------------------------------------
(define-public (create-dca  (source-trait <ft>) 
														(target principal)
														(interval uint)
														(total-amount uint)
														(dca-amount uint)
														(min-price uint)
														(max-price uint))
	(let ((sender tx-sender)
			(source (contract-of source-trait))
			(data {is-paused: false, amount: dca-amount, source-amount-left: total-amount, target-amount: u0, min-price: min-price, max-price: max-price, last-updated-timestamp:u0})
			(min-dca-threshold (default-to u0 (get min-dca-threshold (map-get? source-config {source: source}))))
			)
		(asserts! (and (>= dca-amount min-dca-threshold) (>= total-amount dca-amount)) ERR-INVALID-AMOUNT)
		(unwrap! (map-get? sources-targets-config {source: source, target: target}) ERR-INVALID-PRINCIPAL) 
		(unwrap! (map-get? interval-id-to-seconds {interval: interval}) ERR-INVALID-INTERVAL)
		(asserts! (map-insert dca-data {user:sender, source:source, target:target, interval:interval} data) ERR-DCA-ALREADY-EXISTS)
		(print {function: "create-dca", 
						input: {user: sender, source-trait: source-trait, target:target, interval:interval, total-amount:total-amount, dca-amount:dca-amount, min-price:min-price, max-price: max-price},
						more: {data: data }})
		(contract-call? source-trait transfer total-amount sender .dca-vault none)
))

(define-public (add-to-position (source-trait <ft>) (target principal) (interval uint) (amount uint)) 
	(let (
			(sender tx-sender)
			(source (contract-of source-trait))
			(data (unwrap! (get-dca-data sender source target interval) ERR-INVALID-KEY))
			(prev-amount (get source-amount-left data))
			) 
		(try! (contract-call? source-trait transfer amount sender .dca-vault none))
		(print {function: "add-to-position", 
							input: {source-trait: source-trait, target:target, interval:interval, amount:amount, sender: sender},
							more: {data: data, prev-amount: prev-amount, source-amount-left: (+ amount prev-amount) }})
		(ok (map-set dca-data {user:sender, source:source, target:target, interval:interval} (merge data {source-amount-left: (+ amount prev-amount)})))
))

(define-public (reduce-position (source-trait <ft>) (target principal) (interval uint) (amount uint)) 
	(let (
			(sender tx-sender)
			(source (contract-of source-trait))
			(data (unwrap! (get-dca-data sender source target interval) ERR-INVALID-KEY))
			(prev-amount (get source-amount-left data))
			(amount-to-reduce (if (> amount prev-amount) prev-amount amount))
		)
		(asserts! (> amount-to-reduce u0) ERR-INVALID-AMOUNT)
		(as-contract (try! (contract-call? .dca-vault transfer-ft source-trait amount-to-reduce sender)))
		(print {function: "reduce-position", 
							input: {source-trait: source-trait, target:target, interval:interval, amount:amount, sender: sender},
							more: {data: data, prev-amount: prev-amount, amount-to-reduce: amount-to-reduce }})
		(ok (map-set dca-data {user:sender, source:source, target:target, interval:interval} (merge data {source-amount-left: (- prev-amount amount-to-reduce)})))
))

(define-public (withdraw (source principal) (target-trait <ft>) (interval uint) (amount uint)) 
	(let ((sender tx-sender)
		(target (contract-of target-trait))
		(data (unwrap! (get-dca-data sender source target interval) ERR-INVALID-KEY))
		(prev-amount (get target-amount data))
		(amount-to-withdraw (if (> amount prev-amount) prev-amount amount))
		) 
		(asserts! (> amount-to-withdraw u0) ERR-INVALID-AMOUNT)
		(as-contract (try! (contract-call? .dca-vault transfer-ft target-trait amount-to-withdraw sender)))
		(print {function: "withdraw", 
						input: {target-trait: target-trait, source:source, interval:interval, amount:amount, sender: sender},
						more: {data: data, prev-amount: prev-amount, amount-to-withdraw:amount-to-withdraw }})
	(ok (map-set dca-data {user:sender, source:source, target:target, interval:interval} (merge data {target-amount: (- prev-amount amount-to-withdraw)})))
))

(define-public (dca-users (source-trait <ft>)
												 	(target-trait <ft>)
													(keys (list 20 {user:principal, source:principal, target:principal, interval:uint}))
													(swap-configs (list 20 {target-amount-out: uint})))
		(let ((curr-timestamp (unwrap-panic (get-block-info? time (- block-height u1)))))
			(print { function:"dca-users", source: source-trait, target:target-trait, keys:keys, swap-configs:swap-configs })
			(ok (map dca-user (list source-trait source-trait source-trait source-trait source-trait source-trait source-trait source-trait source-trait source-trait source-trait source-trait source-trait source-trait source-trait source-trait source-trait source-trait source-trait source-trait) 	
						(list target-trait target-trait target-trait target-trait target-trait target-trait target-trait target-trait target-trait target-trait target-trait target-trait target-trait target-trait target-trait target-trait target-trait target-trait target-trait target-trait) 	
						keys
						swap-configs 
						(list curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp curr-timestamp)
))))

;; todo can pass more params to this function instead of calculating them every time sich as curr-tmiestamp to save on gas
(define-private (dca-user (source-trait <ft>)
												 (target-trait <ft>)
												(key (tuple (user principal) (source principal) (target principal) (interval uint))) 
												(swap-configs (tuple (target-amount-out  uint)))
												(curr-timestamp uint))
	(let ((user (get user key))
				(source (get source key))
				(target (get target key))
				(interval (get interval key))
				(data (unwrap! (get-dca-data user source target interval) ERR-INVALID-KEY))
				(source-amount-left (get source-amount-left data))
				(amount (get amount data))
				(target-amount (get target-amount data))
				(last-updated-timestamp (get last-updated-timestamp data))
				(min-price (get min-price data))
				(max-price (get max-price data))
				(amount-to-trade (if (< source-amount-left amount) source-amount-left amount))
				(interval-seconds (unwrap! (get-interval-seconds interval) ERR-INVALID-INTERVAL))
				(target-timestamp (+ (get seconds interval-seconds) last-updated-timestamp))
				) 
				(print {function: "validate-dca", 
								input: {user: user, source: source, target: target, interval: interval, curr-timestamp: curr-timestamp},
								more: {amount-to-trade: amount-to-trade, interval-secoinds: interval-seconds, target-timestamp: target-timestamp}})
				(asserts! (is-eq (contract-of source-trait) source) ERR-INVALID-PRINCIPAL)
				(asserts! (is-eq (contract-of target-trait) target) ERR-INVALID-PRINCIPAL)
				(ok (if (>= curr-timestamp target-timestamp)
						(try! (process-swap source target source-trait target-trait user amount-to-trade min-price max-price source-amount-left interval curr-timestamp target-amount data swap-configs))
						u0		
))))

(define-private (process-swap (source principal)
															(target principal)
															(source-trait <ft>)
															(target-trait <ft>) 
															(user principal)
															(amount-to-trade uint)
															(min-price uint)
															(max-price uint)
															(source-amount-left uint)
															(interval uint)
															(curr-timestamp uint)
															(target-amount uint)
															(data (tuple (is-paused bool) (amount uint) (source-amount-left uint) (target-amount uint) (min-price uint) (max-price uint) (last-updated-timestamp uint)))
															(swap-configs (tuple (target-amount-out  uint)))
															) 
		(let ((sources-targets-conf (unwrap! (map-get? sources-targets-config {source: source, target: target}) ERR-CONFIG-NOT-SET))
				(is-source-numerator (get is-source-numerator sources-targets-conf))
				(source-conf (unwrap! (map-get? source-config {source: source}) ERR-CONFIG-NOT-SET))
				(fee-fixed (get fee-fixed source-conf))
				(fee-percent (get fee-percent source-conf))
				(swap-id (get id sources-targets-conf))
				(source-unit (get source-unit sources-targets-conf))
				(target-unit (get target-unit sources-targets-conf))
				(swap-response (try! (swap source-trait target-trait user swap-id amount-to-trade min-price max-price fee-fixed fee-percent is-source-numerator source-unit target-unit swap-configs)))
				(amt-out (get amt-out swap-response))
			)
		(print {function: "process-swap", more:{curr-timestamp:curr-timestamp, source-amount-left:source-amount-left, amount-to-trade:amount-to-trade, amt-out:amt-out, target-amount:target-amount, source: source, target:target, interval:interval}})
		(if (<= source-amount-left amount-to-trade) 
			(map-delete dca-data {user:user, source:source, target:target, interval:interval})
			(map-set dca-data {user:user, source:source, target:target, interval:interval}
							(merge data {last-updated-timestamp: curr-timestamp, 
													source-amount-left: (- source-amount-left amount-to-trade),
													target-amount: (+ target-amount amt-out)}))
		)
		(ok amt-out)
))

(define-private (swap (source-trait <ft>) 
										(target-trait <ft>)
										(user principal)
										(swap-id uint) 
										(amount uint) 
										(min-price uint)
										(max-price uint)
										(fee-fixed uint)
										(fee-percent uint)
										(is-source-numerator bool)
										(source-unit uint)
										(target-unit uint)
										(trade-configs (tuple (target-amount-out uint)))
										) 
 	(let ((source (contract-of source-trait))
				(target (contract-of target-trait))
				(fees (get-fees amount source fee-fixed fee-percent))
				(fee (get fee fees))
				(next-fee (get next-fee fees))
				(amount-minus-fee (- amount fee))
				(swap-response (as-contract (try! (contract-call? .dca-vault swap 
																										swap-id 
																										source-trait
																										target-trait 
																										'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to
																										amount-minus-fee
																										(get target-amount-out trade-configs)
																										min-price
																										max-price
																										source-unit
																										target-unit
																										is-source-numerator
																										 )))))
					(print {function: "swap", 
							more: {user: user , swap-response: swap-response, next-fee: next-fee }})	
				(map-set fee-map {source: source} {fee: next-fee})
				(ok swap-response)
))


(define-private (get-fees (amount uint) (source principal) (fee-fixed uint) (fee-percent uint)) 
	(let ((fee-perc-amount (mul-down amount fee-percent))
				(fee (+ fee-perc-amount fee-fixed))
				(prev-fee (default-to u0 (get fee (map-get? fee-map {source:source}))))
				(next-fee (+ fee prev-fee))
			)
		(print {function: "get-fees", 
							more: {fee: fee, next-fee: next-fee,  prev-fee:prev-fee, fee-perc-amount:fee-perc-amount, fee-fixed:fee-fixed, amount:amount, feepercent:fee-percent}})	
		{fee: fee, next-fee: next-fee}
))

(define-public (withdraw-fee (source-trait <ft>))
(let ((source  (contract-of source-trait))
			(fee (unwrap-panic (get fee (map-get? fee-map {source: (contract-of source-trait)})))))
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