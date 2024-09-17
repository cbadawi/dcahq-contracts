;; 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01
(use-trait ft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait ft-plus-trait 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.ft-plus-trait.ft-plus-trait)
(use-trait share-fee-to-trait 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to-trait.share-fee-to-trait)

(define-public (swap-exact-tokens-for-tokens
    (id             uint)
    (token0         <ft-trait>)
    (token1         <ft-trait>)
    (token-in       <ft-trait>)
    (token-out      <ft-trait>)
    (share-fee-to   <share-fee-to-trait>)
    (amt-in      uint)
    (amt-out-min uint))
    (begin (print 394586775843608) 
		(asserts! true (err u420))
        (ok {amt-out: amt-out-min})
    )
)
(define-read-only (do-get-pool (id uint)) {reserve0: u55926507788, reserve1: u81308328291, swap-fee: {
      den: u1000,
      num: u50
    },}
)
;; {
;;     block-height: u162389,
;;     burn-block-height: u857345,
;;     lp-token: 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx-aeusdc2,
;;     protocol-fee: {
;;       den: u1000,
;;       num: u250
;;     },
;;     reserve0: u55926507788,
;;     reserve1: u81308328291,
;;     share-fee: {
;;       den: u1000,
;;       num: u50
;;     },
;;     swap-fee: {
;;       den: u1000,
;;       num: u997
;;     },
;;     symbol: "wSTX-aeUSDC",
;;     token0: 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx,
;;     token1: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc
;;   }