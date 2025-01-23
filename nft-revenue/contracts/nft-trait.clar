;; SIP-009: Standard Trait Definition for Non-Fungible Tokens
;; https://github.com/stacksgov/sips/blob/main/sips/sip-009/sip-009-nft-standard.md

(define-trait nft-trait
    (
        ;; Transfer token to a specified principal
        (transfer (uint principal principal) (response bool uint))

        ;; Get the owner of the specified token ID
        (get-owner (uint) (response principal uint))

        ;; Get the URI for the specified token ID
        (get-token-uri (uint) (response (optional (string-utf8 256)) uint))

        ;; Get the last token ID
        (get-last-token-id () (response uint uint))
    )
)