;; Component Tracking Contract
;; Records and tracks component movement through supply chain

(define-constant err-unauthorized (err u200))
(define-constant err-component-not-found (err u201))
(define-constant err-invalid-status (err u202))
(define-constant err-already-exists (err u203))

;; Component status constants
(define-constant status-manufactured u1)
(define-constant status-in-transit u2)
(define-constant status-received u3)
(define-constant status-quality-checked u4)
(define-constant status-installed u5)

;; Data structures
(define-map components
  { component-id: (string-ascii 50) }
  {
    manufacturer: principal,
    component-type: (string-ascii 50),
    batch-number: (string-ascii 30),
    manufacture-date: uint,
    current-owner: principal,
    current-status: uint,
    created-at: uint
  }
)

(define-map component-history
  { component-id: (string-ascii 50), sequence: uint }
  {
    from-entity: principal,
    to-entity: principal,
    status: uint,
    timestamp: uint,
    location: (string-ascii 100),
    notes: (string-ascii 200)
  }
)

(define-map component-sequences
  { component-id: (string-ascii 50) }
  { next-sequence: uint }
)

;; Public functions
(define-public (create-component
  (component-id (string-ascii 50))
  (component-type (string-ascii 50))
  (batch-number (string-ascii 30)))
  (begin
    (asserts! (is-none (map-get? components { component-id: component-id })) err-already-exists)

    (map-set components
      { component-id: component-id }
      {
        manufacturer: tx-sender,
        component-type: component-type,
        batch-number: batch-number,
        manufacture-date: block-height,
        current-owner: tx-sender,
        current-status: status-manufactured,
        created-at: block-height
      }
    )

    (map-set component-sequences
      { component-id: component-id }
      { next-sequence: u1 }
    )

    (unwrap-panic (add-history-entry component-id tx-sender tx-sender status-manufactured "Manufacturing facility" "Component manufactured"))
    (ok true)
  )
)

(define-public (transfer-component
  (component-id (string-ascii 50))
  (to-entity principal)
  (location (string-ascii 100))
  (notes (string-ascii 200)))
  (let ((component (unwrap! (map-get? components { component-id: component-id }) err-component-not-found)))
    (begin
      (asserts! (is-eq (get current-owner component) tx-sender) err-unauthorized)

      (map-set components
        { component-id: component-id }
        (merge component { current-owner: to-entity, current-status: status-in-transit })
      )

      (unwrap-panic (add-history-entry component-id tx-sender to-entity status-in-transit location notes))
      (ok true)
    )
  )
)

(define-public (update-component-status
  (component-id (string-ascii 50))
  (new-status uint)
  (location (string-ascii 100))
  (notes (string-ascii 200)))
  (let ((component (unwrap! (map-get? components { component-id: component-id }) err-component-not-found)))
    (begin
      (asserts! (is-eq (get current-owner component) tx-sender) err-unauthorized)
      (asserts! (and (>= new-status u1) (<= new-status u5)) err-invalid-status)

      (map-set components
        { component-id: component-id }
        (merge component { current-status: new-status })
      )

      (unwrap-panic (add-history-entry component-id tx-sender tx-sender new-status location notes))
      (ok true)
    )
  )
)

;; Private functions
(define-private (add-history-entry
  (component-id (string-ascii 50))
  (from-entity principal)
  (to-entity principal)
  (status uint)
  (location (string-ascii 100))
  (notes (string-ascii 200)))
  (let ((sequence-data (default-to { next-sequence: u0 } (map-get? component-sequences { component-id: component-id })))
        (sequence (get next-sequence sequence-data)))
    (begin
      (map-set component-history
        { component-id: component-id, sequence: sequence }
        {
          from-entity: from-entity,
          to-entity: to-entity,
          status: status,
          timestamp: block-height,
          location: location,
          notes: notes
        }
      )

      (map-set component-sequences
        { component-id: component-id }
        { next-sequence: (+ sequence u1) }
      )
      (ok true)
    )
  )
)

;; Read-only functions
(define-read-only (get-component (component-id (string-ascii 50)))
  (map-get? components { component-id: component-id })
)

(define-read-only (get-component-history (component-id (string-ascii 50)) (sequence uint))
  (map-get? component-history { component-id: component-id, sequence: sequence })
)

(define-read-only (get-current-sequence (component-id (string-ascii 50)))
  (match (map-get? component-sequences { component-id: component-id })
    sequence-data (get next-sequence sequence-data)
    u0
  )
)
