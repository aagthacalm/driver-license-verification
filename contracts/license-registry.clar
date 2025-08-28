;; Driver License Registry Contract
;; Manages registration and storage of digital driver license credentials

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_LICENSE_EXISTS (err u402))
(define-constant ERR_LICENSE_NOT_FOUND (err u403))
(define-constant ERR_INVALID_STATUS (err u404))
(define-constant ERR_EXPIRED_LICENSE (err u405))

;; License status types
(define-constant STATUS_ACTIVE u1)
(define-constant STATUS_SUSPENDED u2)
(define-constant STATUS_REVOKED u3)
(define-constant STATUS_EXPIRED u4)

;; Data structures
(define-map licenses
  { license-id: (string-ascii 20) }
  {
    holder: principal,
    issue-date: uint,
    expiry-date: uint,
    license-class: (string-ascii 10),
    issuing-authority: (string-ascii 50),
    status: uint,
    verification-hash: (buff 32)
  }
)

(define-map license-holders
  { holder: principal }
  { license-id: (string-ascii 20) }
)

(define-data-var total-licenses uint u0)

;; Public functions

;; Register a new driver license
(define-public (register-license 
  (license-id (string-ascii 20))
  (holder principal)
  (issue-date uint)
  (expiry-date uint)
  (license-class (string-ascii 10))
  (issuing-authority (string-ascii 50))
  (verification-hash (buff 32))
)
  (begin
    ;; Only contract owner can register licenses (representing DMV authority)
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    ;; Check license doesn't already exist
    (asserts! (is-none (map-get? licenses { license-id: license-id })) ERR_LICENSE_EXISTS)
    
    ;; Validate expiry date is in the future
    (asserts! (> expiry-date stacks-block-height) ERR_EXPIRED_LICENSE)
    
    ;; Store license data
    (map-set licenses
      { license-id: license-id }
      {
        holder: holder,
        issue-date: issue-date,
        expiry-date: expiry-date,
        license-class: license-class,
        issuing-authority: issuing-authority,
        status: STATUS_ACTIVE,
        verification-hash: verification-hash
      }
    )
    
    ;; Map holder to license
    (map-set license-holders
      { holder: holder }
      { license-id: license-id }
    )
    
    ;; Increment counter
    (var-set total-licenses (+ (var-get total-licenses) u1))
    
    (ok license-id)
  )
)

;; Update license status (suspend, revoke, reactivate)
(define-public (update-license-status 
  (license-id (string-ascii 20))
  (new-status uint)
)
  (begin
    ;; Only contract owner can update status
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    ;; Validate status value
    (asserts! (and (>= new-status STATUS_ACTIVE) (<= new-status STATUS_EXPIRED)) ERR_INVALID_STATUS)
    
    ;; Check license exists
    (match (map-get? licenses { license-id: license-id })
      license-data
      (begin
        (map-set licenses
          { license-id: license-id }
          (merge license-data { status: new-status })
        )
        (ok new-status)
      )
      ERR_LICENSE_NOT_FOUND
    )
  )
)

;; Read-only functions

;; Get license details by license ID
(define-read-only (get-license (license-id (string-ascii 20)))
  (map-get? licenses { license-id: license-id })
)

;; Get license ID by holder principal
(define-read-only (get-license-by-holder (holder principal))
  (map-get? license-holders { holder: holder })
)

;; Check if license is valid and active
(define-read-only (is-license-valid (license-id (string-ascii 20)))
  (match (map-get? licenses { license-id: license-id })
    license-data
    (and 
      (is-eq (get status license-data) STATUS_ACTIVE)
      (> (get expiry-date license-data) stacks-block-height)
    )
    false
  )
)

;; Get total number of registered licenses
(define-read-only (get-total-licenses)
  (var-get total-licenses)
)

;; Verify license hash matches
(define-read-only (verify-license-hash 
  (license-id (string-ascii 20))
  (provided-hash (buff 32))
)
  (match (map-get? licenses { license-id: license-id })
    license-data
    (is-eq (get verification-hash license-data) provided-hash)
    false
  )
)

