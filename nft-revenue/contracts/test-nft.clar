;; Test NFT Contract implementing SIP-009
(impl-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.nft-trait.nft-trait)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-MINTED (err u409))

;; Data Variables
(define-data-var last-token-id uint u0)

;; Data Maps
(define-map token-owners 
    { token-id: uint } 
    { owner: principal }
)

(define-map token-uris
    { token-id: uint }
    { uri: (string-utf8 256) }
)

;; Private Functions
(define-private (is-contract-owner)
    (is-eq tx-sender CONTRACT-OWNER)
)

;; SIP-009 Functions
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (let 
        (
            (token-owner (unwrap! (get-token-owner token-id) ERR-NOT-FOUND))
        )
        (asserts! (is-eq token-owner sender) ERR-NOT-AUTHORIZED)
        (asserts! (not (is-eq sender recipient)) ERR-NOT-AUTHORIZED)
        
        (map-set token-owners
            { token-id: token-id }
            { owner: recipient }
        )
        (ok true)
    )
)

(define-read-only (get-owner (token-id uint))
    (ok (get owner (unwrap! (map-get? token-owners { token-id: token-id }) ERR-NOT-FOUND)))
)

(define-read-only (get-token-uri (token-id uint))
    (ok (some (get uri (unwrap! (map-get? token-uris { token-id: token-id }) ERR-NOT-FOUND))))
)

(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)

;; Additional Functions for Testing
(define-private (get-token-owner (token-id uint))
    (match (map-get? token-owners { token-id: token-id })
        token-info (ok (get owner token-info))
        ERR-NOT-FOUND
    )
)

(define-public (mint (recipient principal) (uri (string-utf8 256)))
    (let
        (
            (token-id (+ (var-get last-token-id) u1))
        )
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        
        (map-set token-owners
            { token-id: token-id }
            { owner: recipient }
        )
        
        (map-set token-uris
            { token-id: token-id }
            { uri: uri }
        )
        
        (var-set last-token-id token-id)
        (ok token-id)
    )
)

(define-public (burn (token-id uint))
    (let
        (
            (token-owner (unwrap! (get-token-owner token-id) ERR-NOT-FOUND))
        )
        (asserts! (is-eq token-owner tx-sender) ERR-NOT-AUTHORIZED)
        
        (map-delete token-owners { token-id: token-id })
        (map-delete token-uris { token-id: token-id })
        (ok true)
    )
)