;; Quality Verification Contract
;; Validates component specifications and quality standards

(define-constant err-unauthorized (err u300))
(define-constant err-component-not-found (err u301))
(define-constant err-already-verified (err u302))
(define-constant err-invalid-score (err u303))

;; Quality standards
(define-constant min-quality-score u70)
(define-constant max-quality-score u100)

;; Data structures
(define-map quality-verifications
  { component-id: (string-ascii 50), verification-id: uint }
  {
    verifier: principal,
    quality-score: uint,
    test-results: (string-ascii 200),
    certification-standard: (string-ascii 50),
    verification-date: uint,
    passed: bool,
    notes: (string-ascii 300)
  }
)

(define-map component-verification-count
  { component-id: (string-ascii 50) }
  { count: uint }
)

(define-map quality-standards
  { standard-id: (string-ascii 50) }
  {
    standard-name: (string-ascii 100),
    min-score: uint,
    test-procedures: (string-ascii 300),
    created-by: principal
  }
)

;; Public functions
(define-public (create-quality-standard
  (standard-id (string-ascii 50))
  (standard-name (string-ascii 100))
  (min-score uint)
  (test-procedures (string-ascii 300)))
  (begin
    (asserts! (and (>= min-score u1) (<= min-score u100)) err-invalid-score)

    (map-set quality-standards
      { standard-id: standard-id }
      {
        standard-name: standard-name,
        min-score: min-score,
        test-procedures: test-procedures,
        created-by: tx-sender
      }
    )
    (ok true)
  )
)

(define-public (verify-component-quality
  (component-id (string-ascii 50))
  (quality-score uint)
  (test-results (string-ascii 200))
  (certification-standard (string-ascii 50))
  (notes (string-ascii 300)))
  (let ((verification-count (default-to { count: u0 } (map-get? component-verification-count { component-id: component-id })))
        (verification-id (get count verification-count))
        (passed (>= quality-score min-quality-score)))
    (begin
      (asserts! (and (>= quality-score u1) (<= quality-score max-quality-score)) err-invalid-score)

      (map-set quality-verifications
        { component-id: component-id, verification-id: verification-id }
        {
          verifier: tx-sender,
          quality-score: quality-score,
          test-results: test-results,
          certification-standard: certification-standard,
          verification-date: block-height,
          passed: passed,
          notes: notes
        }
      )

      (map-set component-verification-count
        { component-id: component-id }
        { count: (+ verification-id u1) }
      )

      (ok passed)
    )
  )
)

(define-public (batch-verify-components
  (component-ids (list 10 (string-ascii 50)))
  (quality-scores (list 10 uint))
  (certification-standard (string-ascii 50)))
  (let ((results (map verify-single-component component-ids quality-scores)))
    (ok results)
  )
)

;; Private functions
(define-private (verify-single-component (component-id (string-ascii 50)) (quality-score uint))
  (unwrap-panic (verify-component-quality
    component-id
    quality-score
    "Batch verification"
    "ISO-9001"
    "Automated batch quality check"))
)

;; Read-only functions
(define-read-only (get-quality-verification (component-id (string-ascii 50)) (verification-id uint))
  (map-get? quality-verifications { component-id: component-id, verification-id: verification-id })
)

(define-read-only (get-verification-count (component-id (string-ascii 50)))
  (match (map-get? component-verification-count { component-id: component-id })
    count-data (get count count-data)
    u0
  )
)

(define-read-only (get-quality-standard (standard-id (string-ascii 50)))
  (map-get? quality-standards { standard-id: standard-id })
)

(define-read-only (is-component-quality-verified (component-id (string-ascii 50)))
  (let ((count (get-verification-count component-id)))
    (if (> count u0)
      (match (get-quality-verification component-id (- count u1))
        verification (get passed verification)
        false)
      false)
  )
)

(define-read-only (get-latest-quality-score (component-id (string-ascii 50)))
  (let ((count (get-verification-count component-id)))
    (if (> count u0)
      (match (get-quality-verification component-id (- count u1))
        verification (some (get quality-score verification))
        none)
      none)
  )
)
