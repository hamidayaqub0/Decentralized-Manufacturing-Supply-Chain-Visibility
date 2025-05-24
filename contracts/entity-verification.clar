;; Entity Verification Contract
;; Validates and manages supply chain participants

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-already-verified (err u101))
(define-constant err-not-verified (err u102))
(define-constant err-invalid-entity (err u103))

;; Entity types
(define-constant entity-manufacturer u1)
(define-constant entity-supplier u2)
(define-constant entity-distributor u3)
(define-constant entity-retailer u4)

;; Data structures
(define-map verified-entities
  { entity-address: principal }
  {
    entity-type: uint,
    company-name: (string-ascii 100),
    verification-date: uint,
    is-active: bool
  }
)

(define-map entity-certifications
  { entity-address: principal, cert-id: uint }
  {
    cert-name: (string-ascii 50),
    issuer: (string-ascii 50),
    expiry-date: uint
  }
)

(define-data-var next-cert-id uint u1)

;; Public functions
(define-public (verify-entity (entity principal) (entity-type uint) (company-name (string-ascii 100)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-none (map-get? verified-entities { entity-address: entity })) err-already-verified)
    (asserts! (and (>= entity-type u1) (<= entity-type u4)) err-invalid-entity)

    (map-set verified-entities
      { entity-address: entity }
      {
        entity-type: entity-type,
        company-name: company-name,
        verification-date: block-height,
        is-active: true
      }
    )
    (ok true)
  )
)

(define-public (add-certification (entity principal) (cert-name (string-ascii 50)) (issuer (string-ascii 50)) (expiry-date uint))
  (let ((cert-id (var-get next-cert-id)))
    (begin
      (asserts! (is-some (map-get? verified-entities { entity-address: entity })) err-not-verified)

      (map-set entity-certifications
        { entity-address: entity, cert-id: cert-id }
        {
          cert-name: cert-name,
          issuer: issuer,
          expiry-date: expiry-date
        }
      )
      (var-set next-cert-id (+ cert-id u1))
      (ok cert-id)
    )
  )
)

(define-public (deactivate-entity (entity principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-some (map-get? verified-entities { entity-address: entity })) err-not-verified)

    (map-set verified-entities
      { entity-address: entity }
      (merge (unwrap-panic (map-get? verified-entities { entity-address: entity }))
             { is-active: false })
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (is-verified-entity (entity principal))
  (match (map-get? verified-entities { entity-address: entity })
    entity-data (get is-active entity-data)
    false
  )
)

(define-read-only (get-entity-info (entity principal))
  (map-get? verified-entities { entity-address: entity })
)

(define-read-only (get-certification (entity principal) (cert-id uint))
  (map-get? entity-certifications { entity-address: entity, cert-id: cert-id })
)
