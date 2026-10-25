## Purpose

Defines the radio link between the garage node and the base node: what it guarantees about confidentiality, replay resistance and delivery latency, and the airtime budget that bounds how often it may transmit.

## ADDED Requirements

### Requirement: The link is a direct point-to-point radio link
The garage node and the base node SHALL communicate directly over LoRa. The system SHALL NOT depend on any LoRaWAN gateway, network server, or internet-reachable service for door state to reach the base node.

#### Scenario: Internet connectivity is lost
- **WHEN** the site has no internet connectivity
- **THEN** door state continues to be delivered from the garage node to the base node

#### Scenario: No third-party infrastructure is registered
- **WHEN** the system is deployed
- **THEN** no device registration, application, or account with an external LoRaWAN network operator is required

### Requirement: Transmissions are encrypted
All payloads on the radio link SHALL be encrypted with a pre-shared key known only to the two nodes. Door position SHALL NOT be observable from the raw radio traffic by a passive listener without the key.

#### Scenario: Passive eavesdropper
- **WHEN** a third party captures the radio traffic without possessing the pre-shared key
- **THEN** the captured frames do not reveal the door position

#### Scenario: Key is not committed to version control
- **WHEN** the repository is inspected
- **THEN** the pre-shared key is absent from all tracked files

### Requirement: Replayed transmissions are rejected
Each transmission SHALL carry a monotonically increasing value, and the base node SHALL reject any packet whose value does not exceed the highest it has already accepted.

#### Scenario: Recorded packet is replayed later
- **WHEN** a third party records a packet reporting `closed` and retransmits it after the door has opened
- **THEN** the base node discards the replayed packet
- **AND** the reported door position remains `open`

#### Scenario: Garage node is power-cycled
- **WHEN** the garage node loses power and restarts
- **THEN** its subsequent transmissions are accepted by the base node
- **AND** the link recovers without manual intervention at either node

### Requirement: A full state broadcast occurs at least every 20 seconds
The garage node SHALL transmit a complete set of its current values at an interval no longer than 20 seconds.

#### Scenario: Nothing has changed
- **WHEN** neither the door position nor any telemetry value has changed for several minutes
- **THEN** the garage node still transmits a full state broadcast at least every 20 seconds

### Requirement: Position changes are transmitted without waiting for the heartbeat
A change in door position SHALL be transmitted within one second of the debounce interval elapsing, rather than waiting for the next periodic full broadcast.

#### Scenario: Door opens between heartbeats
- **WHEN** the door opens immediately after a periodic broadcast
- **THEN** the new position is transmitted within one second of the debounce interval elapsing
- **AND** the base node reports `open` without waiting for the next heartbeat

### Requirement: Radio operation stays within the statutory duty cycle
Each node SHALL operate within the duty cycle and transmit power limits of the sub-band in use. Combined periodic, event-driven and liveness traffic from a node SHALL NOT exceed that limit, and the configuration SHALL retain headroom rather than sitting at the limit.

#### Scenario: Airtime budget is validated against measured packet size
- **WHEN** the configuration is commissioned
- **THEN** the actual transmitted packet size is measured
- **AND** the resulting duty cycle is computed and confirmed to be below the sub-band limit with headroom remaining

#### Scenario: Transmit power is set no higher than the link requires
- **WHEN** transmit power is configured
- **THEN** it is set to the lowest value that achieves a reliable link with adequate margin
- **AND** it does not exceed the legal limit for the sub-band in use

### Requirement: The two nodes are treated as a matched pair
The garage node and the base node SHALL run firmware built from the same pinned platform version. The wire format between them carries no compatibility guarantee across versions.

#### Scenario: One node is updated alone
- **WHEN** a platform version upgrade is planned
- **THEN** both nodes are rebuilt and reflashed together
- **AND** neither node is left running a different platform version than the other
