;; Delivery Confirmation Contract
;; Records receipt of materials and delivery confirmations

(define-constant err-unauthorized (err u400))
(define-constant err-delivery-not-found (err u401))
(define-constant err-already-confirmed (err u402))
(define-constant err-invalid-delivery (err u403))

;; Delivery status constants
(define-constant status-pending u1)
(define-constant status-in-transit u2)
(define-constant status-delivered u3)
(define-constant status-confirmed u4)
(define-constant status-disputed u5)

;; Data structures
(define-map deliveries
  { delivery-id: (string-ascii 50) }
  {
    sender: principal,
    recipient: principal,
    component-ids: (list 20 (string-ascii 50)),
    expected-delivery-date: uint,
    actual-delivery-date: (optional uint),
    delivery-status: uint,
    delivery-location: (string-ascii 100),
    carrier: (string-ascii 50),
    tracking-number: (string-ascii 50),
    created-at: uint
  }
)

(define-map delivery-confirmations
  { delivery-id: (string-ascii 50) }
  {
    confirmed-by: principal,
    confirmation-date: uint,
    received-components: (list 20 (string-ascii 50)),
    condition-notes: (string-ascii 300),
    signature: (string-ascii 100),
    damages-reported: bool
  }
)

(define-map delivery-disputes
  { delivery-id: (string-ascii 50) }
  {
    disputed-by: principal,
    dispute-reason: (string-ascii 300),
    dispute-date: uint,
    resolution-status: uint,
    resolver: (optional principal)
  }
)

;; Public functions
(define-public (create-delivery
  (delivery-id (string-ascii 50))
  (recipient principal)
  (component-ids (list 20 (string-ascii 50)))
  (expected-delivery-date uint)
  (delivery-location (string-ascii 100))
  (carrier (string-ascii 50))
  (tracking-number (string-ascii 50)))
  (begin
    (asserts! (is-none (map-get? deliveries { delivery-id: delivery-id })) err-invalid-delivery)

    (map-set deliveries
      { delivery-id: delivery-id }
      {
        sender: tx-sender,
        recipient: recipient,
        component-ids: component-ids,
        expected-delivery-date: expected-delivery-date,
        actual-delivery-date: none,
        delivery-status: status-pending,
        delivery-location: delivery-location,
        carrier: carrier,
        tracking-number: tracking-number,
        created-at: block-height
      }
    )
    (ok true)
  )
)

(define-public (update-delivery-status
  (delivery-id (string-ascii 50))
  (new-status uint))
  (let ((delivery (unwrap! (map-get? deliveries { delivery-id: delivery-id }) err-delivery-not-found)))
    (begin
      (asserts! (is-eq (get sender delivery) tx-sender) err-unauthorized)
      (asserts! (and (>= new-status u1) (<= new-status u5)) err-invalid-delivery)

      (map-set deliveries
        { delivery-id: delivery-id }
        (merge delivery {
          delivery-status: new-status,
          actual-delivery-date: (if (is-eq new-status status-delivered)
                                  (some block-height)
                                  (get actual-delivery-date delivery))
        })
      )
      (ok true)
    )
  )
)

(define-public (confirm-delivery
  (delivery-id (string-ascii 50))
  (received-components (list 20 (string-ascii 50)))
  (condition-notes (string-ascii 300))
  (signature (string-ascii 100))
  (damages-reported bool))
  (let ((delivery (unwrap! (map-get? deliveries { delivery-id: delivery-id }) err-delivery-not-found)))
    (begin
      (asserts! (is-eq (get recipient delivery) tx-sender) err-unauthorized)
      (asserts! (is-none (map-get? delivery-confirmations { delivery-id: delivery-id })) err-already-confirmed)

      (map-set delivery-confirmations
        { delivery-id: delivery-id }
        {
          confirmed-by: tx-sender,
          confirmation-date: block-height,
          received-components: received-components,
          condition-notes: condition-notes,
          signature: signature,
          damages-reported: damages-reported
        }
      )

      (map-set deliveries
        { delivery-id: delivery-id }
        (merge delivery { delivery-status: status-confirmed })
      )

      (ok true)
    )
  )
)

(define-public (dispute-delivery
  (delivery-id (string-ascii 50))
  (dispute-reason (string-ascii 300)))
  (let ((delivery (unwrap! (map-get? deliveries { delivery-id: delivery-id }) err-delivery-not-found)))
    (begin
      (asserts! (is-eq (get recipient delivery) tx-sender) err-unauthorized)

      (map-set delivery-disputes
        { delivery-id: delivery-id }
        {
          disputed-by: tx-sender,
          dispute-reason: dispute-reason,
          dispute-date: block-height,
          resolution-status: u1,
          resolver: none
        }
      )

      (map-set deliveries
        { delivery-id: delivery-id }
        (merge delivery { delivery-status: status-disputed })
      )

      (ok true)
    )
  )
)

;; Read-only functions
(define-read-only (get-delivery (delivery-id (string-ascii 50)))
  (map-get? deliveries { delivery-id: delivery-id })
)

(define-read-only (get-delivery-confirmation (delivery-id (string-ascii 50)))
  (map-get? delivery-confirmations { delivery-id: delivery-id })
)

(define-read-only (get-delivery-dispute (delivery-id (string-ascii 50)))
  (map-get? delivery-disputes { delivery-id: delivery-id })
)

(define-read-only (is-delivery-confirmed (delivery-id (string-ascii 50)))
  (is-some (map-get? delivery-confirmations { delivery-id: delivery-id }))
)

(define-read-only (get-delivery-status (delivery-id (string-ascii 50)))
  (match (map-get? deliveries { delivery-id: delivery-id })
    delivery (get delivery-status delivery)
    u0
  )
)
