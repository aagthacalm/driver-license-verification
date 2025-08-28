
;; Driver License Verification Service
;; Provides verification services for third-party applications

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_INVALID_LICENSE (err u402))
(define-constant ERR_VERIFICATION_FAILED (err u403))
(define-constant ERR_SERVICE_NOT_REGISTERED (err u404))
(define-constant ERR_ALREADY_REGISTERED (err u405))

;; Verification request status
(define-constant STATUS_PENDING u1)
(define-constant STATUS_VERIFIED u2)
(define-constant STATUS_REJECTED u3)

;; Data structures
(define-map registered-services
  { service-address: principal }
  {
    service-name: (string-ascii 50),
    service-type: (string-ascii 20),
    registration-date: uint,
    is-active: bool
  }
)

(define-map verification-requests
  { request-id: uint }
  {
    requester: principal,
    license-id: (string-ascii 20),
    service-type: (string-ascii 20),
    timestamp: uint,
    status: uint,
    verification-result: bool
  }
)

(define-data-var next-request-id uint u1)
(define-data-var total-verifications uint u0)

;; Public functions

;; Register a verification service (car rental, rideshare, etc.)
(define-public (register-service
  (service-name (string-ascii 50))
  (service-type (string-ascii 20))
)
  (begin
    ;; Check if service is already registered
    (asserts! (is-none (map-get? registered-services { service-address: tx-sender })) ERR_ALREADY_REGISTERED)
    
    ;; Register the service
    (map-set registered-services
      { service-address: tx-sender }
      {
        service-name: service-name,
        service-type: service-type,
        registration-date: stacks-block-height,
        is-active: true
      }
    )
    
    (ok tx-sender)
  )
)

;; Request license verification
(define-public (request-verification
  (license-id (string-ascii 20))
  (service-type (string-ascii 20))
)
  (let 
    (
      (request-id (var-get next-request-id))
      (requester tx-sender)
    )
    
    ;; Check if requester is a registered service
    (asserts! (is-some (map-get? registered-services { service-address: requester })) ERR_SERVICE_NOT_REGISTERED)
    
    ;; Create verification request
    (map-set verification-requests
      { request-id: request-id }
      {
        requester: requester,
        license-id: license-id,
        service-type: service-type,
        timestamp: stacks-block-height,
        status: STATUS_PENDING,
        verification-result: false
      }
    )
    
    ;; Increment request ID counter
    (var-set next-request-id (+ request-id u1))
    
    (ok request-id)
  )
)

;; Complete verification (called by contract owner/DMV)
(define-public (complete-verification
  (request-id uint)
  (is-valid bool)
)
  (begin
    ;; Only contract owner can complete verification
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    ;; Check if request exists
    (match (map-get? verification-requests { request-id: request-id })
      request-data
      (begin
        ;; Update verification status
        (map-set verification-requests
          { request-id: request-id }
          (merge request-data {
            status: (if is-valid STATUS_VERIFIED STATUS_REJECTED),
            verification-result: is-valid
          })
        )
        
        ;; Increment total verifications counter
        (var-set total-verifications (+ (var-get total-verifications) u1))
        
        (ok is-valid)
      )
      ERR_VERIFICATION_FAILED
    )
  )
)

;; Deactivate a service
(define-public (deactivate-service (service-address principal))
  (begin
    ;; Only contract owner can deactivate services
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    ;; Check if service exists
    (match (map-get? registered-services { service-address: service-address })
      service-data
      (begin
        (map-set registered-services
          { service-address: service-address }
          (merge service-data { is-active: false })
        )
        (ok true)
      )
      ERR_SERVICE_NOT_REGISTERED
    )
  )
)

;; Read-only functions

;; Get service registration details
(define-read-only (get-service-info (service-address principal))
  (map-get? registered-services { service-address: service-address })
)

;; Get verification request details
(define-read-only (get-verification-request (request-id uint))
  (map-get? verification-requests { request-id: request-id })
)

;; Check if service is registered and active
(define-read-only (is-service-active (service-address principal))
  (match (map-get? registered-services { service-address: service-address })
    service-data
    (get is-active service-data)
    false
  )
)

;; Get total number of verifications completed
(define-read-only (get-total-verifications)
  (var-get total-verifications)
)

;; Get next request ID
(define-read-only (get-next-request-id)
  (var-get next-request-id)
)

;; Quick license validation for registered services
(define-read-only (quick-verify-license
  (license-id (string-ascii 20))
  (expected-holder principal)
)
  (let 
    (
      (license-registry-contract .license-registry)
    )
    ;; This would typically call the license registry contract
    ;; For this implementation, we'll use a simplified approach
    true  ;; In production, this would check the actual license registry
  )
)

