;; Define NFT trait (SIP-009)
(define-trait nft-trait
    (
        (transfer (uint principal principal) (response bool uint))
        (get-owner (uint) (response principal uint))
        (get-token-uri (uint) (response (optional (string-utf8 256)) uint))
        (get-last-token-id () (response uint uint))
    )
)

;; Constants 
(define-data-var contract-nft principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.nft-contract)
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-VAULT (err u101))
(define-constant ERR-NO-DIVIDENDS (err u102))
(define-constant ERR-ALREADY-CLAIMED (err u103))
(define-constant ERR-INSUFFICIENT-SHARES (err u104))
(define-constant ERR-INACTIVE-VAULT (err u105))
(define-constant ERR-ZERO-AMOUNT (err u106))
(define-constant SHARES-PER-NFT u1000)

;; Data Variables
(define-data-var next-vault-id uint u1)

;; Data Maps
(define-map vaults
    { vault-id: uint }
    {
        nft-owner: principal,
        nft-id: uint,
        total-shares: uint,
        accumulated-revenue: uint,
        last-distribution: uint,
        revenue-per-share: uint,
        is-active: bool
    }
)

(define-map share-holdings
    { vault-id: uint, holder: principal }
    { 
        shares: uint,
        last-claim: uint
    }
)

(define-map revenue-periods
    { vault-id: uint, period: uint }
    {
        amount: uint,
        timestamp: uint,
        revenue-type: (string-ascii 20)  ;; rent, parking, or event
    }
)

;; Authorization check
(define-private (is-contract-owner)
    (is-eq tx-sender CONTRACT-OWNER)
)

;; Set NFT contract address - only contract owner can do this
(define-public (set-nft-contract (new-contract principal))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (ok (var-set contract-nft new-contract))
    )
)

;; Initialize new vault with NFT deposit
(define-public (create-vault (token-contract <nft-trait>) (nft-id uint))
    (let
        (
            (vault-id (var-get next-vault-id))
            (sender tx-sender)
            (current-height block-height)
        )
        ;; Transfer NFT to vault
        (try! (contract-call? token-contract transfer nft-id sender (as-contract tx-sender)))

        ;; Create new vault
        (map-set vaults
            { vault-id: vault-id }
            {
                nft-owner: sender,
                nft-id: nft-id,
                total-shares: SHARES-PER-NFT,
                accumulated-revenue: u0,
                last-distribution: current-height,
                revenue-per-share: u0,
                is-active: true
            }
        )
        
        ;; Initialize share holding
        (map-set share-holdings
            { vault-id: vault-id, holder: sender }
            { 
                shares: SHARES-PER-NFT,
                last-claim: current-height
            }
        )
        
        ;; Increment vault ID
        (var-set next-vault-id (+ vault-id u1))
        (ok vault-id)
    )
)

;; Transfer shares between users
(define-public (transfer-shares (vault-id uint) (recipient principal) (amount uint))
    (let
        (
            (sender tx-sender)
            (vault (unwrap! (map-get? vaults { vault-id: vault-id }) ERR-INVALID-VAULT))
            (sender-holding (unwrap! (map-get? share-holdings 
                { vault-id: vault-id, holder: sender }) ERR-INSUFFICIENT-SHARES))
            (current-height block-height)
        )
        ;; Verify vault is active
        (asserts! (get is-active vault) ERR-INACTIVE-VAULT)
        ;; Verify sufficient shares
        (asserts! (>= (get shares sender-holding) amount) ERR-INSUFFICIENT-SHARES)
        
        ;; Process any pending dividends before transfer
        (try! (claim-dividends vault-id))
        
        ;; Update sender's shares
        (map-set share-holdings
            { vault-id: vault-id, holder: sender }
            { 
                shares: (- (get shares sender-holding) amount),
                last-claim: current-height
            }
        )
        
        ;; Update recipient's shares
        (let
            (
                (recipient-holding (default-to 
                    { shares: u0, last-claim: current-height }
                    (map-get? share-holdings { vault-id: vault-id, holder: recipient })))
            )
            (map-set share-holdings
                { vault-id: vault-id, holder: recipient }
                { 
                    shares: (+ (get shares recipient-holding) amount),
                    last-claim: current-height
                }
            )
            (ok true)
        )
    )
)

;; Add revenue to vault
(define-public (add-revenue (vault-id uint) (amount uint) (revenue-type (string-ascii 20)))
    (let
        (
            (vault (unwrap! (map-get? vaults { vault-id: vault-id }) ERR-INVALID-VAULT))
            (current-height block-height)
            (current-period (- current-height (get last-distribution vault)))
        )
        ;; Only contract owner can add revenue
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        ;; Verify amount is positive
        (asserts! (> amount u0) ERR-ZERO-AMOUNT)
        ;; Verify vault is active
        (asserts! (get is-active vault) ERR-INACTIVE-VAULT)
        
        ;; Calculate new revenue per share
        (let
            (
                (new-revenue-per-share (+ (get revenue-per-share vault)
                    (/ (* amount u1000000) SHARES-PER-NFT)))
            )
            ;; Update vault
            (map-set vaults
                { vault-id: vault-id }
                {
                    nft-owner: (get nft-owner vault),
                    nft-id: (get nft-id vault),
                    total-shares: (get total-shares vault),
                    accumulated-revenue: (+ (get accumulated-revenue vault) amount),
                    last-distribution: current-height,
                    revenue-per-share: new-revenue-per-share,
                    is-active: (get is-active vault)
                }
            )
            
            ;; Record revenue period
            (map-set revenue-periods
                { vault-id: vault-id, period: current-period }
                {
                    amount: amount,
                    timestamp: current-height,
                    revenue-type: revenue-type
                }
            )
            (ok true)
        )
    )
)

;; Calculate unclaimed dividends
(define-private (calculate-unclaimed-revenue (vault-id uint) (holder principal))
    (match (map-get? vaults { vault-id: vault-id })
        vault (match (map-get? share-holdings { vault-id: vault-id, holder: holder })
            holder-info (ok (/ (* (get shares holder-info)
                                (- (get revenue-per-share vault)
                                   (get last-claim holder-info)))
                             u1000000))
            ERR-NO-DIVIDENDS)
        ERR-INVALID-VAULT)
)

;; Claim available dividends
(define-public (claim-dividends (vault-id uint))
    (let
        (
            (unclaimed-result (calculate-unclaimed-revenue vault-id tx-sender))
        )
        ;; Verify there are dividends to claim
        (asserts! (is-ok unclaimed-result) ERR-NO-DIVIDENDS)
        (let
            (
                (unclaimed-amount (unwrap! unclaimed-result ERR-NO-DIVIDENDS))
                (vault (unwrap! (map-get? vaults { vault-id: vault-id }) ERR-INVALID-VAULT))
            )
            ;; Verify amount is greater than zero
            (asserts! (> unclaimed-amount u0) ERR-NO-DIVIDENDS)
            
            ;; Update last claim timestamp
            (map-set share-holdings
                { vault-id: vault-id, holder: tx-sender }
                {
                    shares: (get shares (unwrap! (map-get? share-holdings 
                        { vault-id: vault-id, holder: tx-sender }) ERR-NO-DIVIDENDS)),
                    last-claim: (get revenue-per-share vault)
                }
            )
            
            ;; Transfer dividends
            (as-contract (stx-transfer? unclaimed-amount (as-contract tx-sender) tx-sender))
        )
    )
)

;; Buyout the entire NFT
(define-public (buyout-nft (token-contract <nft-trait>) (vault-id uint))
    (let
        (
            (vault (unwrap! (map-get? vaults { vault-id: vault-id }) ERR-INVALID-VAULT))
            (buyer-shares (unwrap! (map-get? share-holdings 
                { vault-id: vault-id, holder: tx-sender }) ERR-INSUFFICIENT-SHARES))
        )
        ;; Verify vault is active
        (asserts! (get is-active vault) ERR-INACTIVE-VAULT)
        ;; Verify buyer owns all shares
        (asserts! (is-eq (get shares buyer-shares) SHARES-PER-NFT) ERR-INSUFFICIENT-SHARES)
        
        ;; Process any remaining dividends
        (try! (claim-dividends vault-id))
        
        ;; Transfer NFT to buyer
        (try! (as-contract (contract-call? token-contract transfer
            (get nft-id vault)
            (as-contract tx-sender)
            tx-sender)))
        
        ;; Deactivate vault
        (map-set vaults
            { vault-id: vault-id }
            {
                nft-owner: tx-sender,
                nft-id: (get nft-id vault),
                total-shares: u0,
                accumulated-revenue: (get accumulated-revenue vault),
                last-distribution: (get last-distribution vault),
                revenue-per-share: (get revenue-per-share vault),
                is-active: false
            }
        )
        
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-vault-info (vault-id uint))
    (map-get? vaults { vault-id: vault-id })
)

(define-read-only (get-share-info (vault-id uint) (holder principal))
    (map-get? share-holdings { vault-id: vault-id, holder: holder })
)

(define-read-only (get-unclaimed-dividends (vault-id uint) (holder principal))
    (calculate-unclaimed-revenue vault-id holder)
)

(define-read-only (get-revenue-period (vault-id uint) (period uint))
    (map-get? revenue-periods { vault-id: vault-id, period: period })
)

(define-read-only (get-nft-contract)
    (ok (var-get contract-nft))
)