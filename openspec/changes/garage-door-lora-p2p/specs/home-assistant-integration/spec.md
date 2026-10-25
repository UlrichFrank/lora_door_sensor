## Purpose

Defines the contract between the base node and Home Assistant — how door position, telemetry and availability are published to the existing message broker, and what Home Assistant can rely on.

## ADDED Requirements

### Requirement: State is published to the existing message broker
The base node SHALL publish to the message broker already in use at the site. The system SHALL NOT introduce a second broker or require a cloud service.

#### Scenario: Broker is the existing one
- **WHEN** the base node is deployed
- **THEN** it connects to the site's existing broker
- **AND** no additional messaging infrastructure is added

### Requirement: The door is exposed as a garage door entity
The door SHALL appear in Home Assistant as a binary entity classified as a garage door, so that the correct open/closed semantics, icon and history are applied without per-installation customisation.

#### Scenario: Door is closed
- **WHEN** the reported position is `closed`
- **THEN** the Home Assistant entity shows the garage door as closed

#### Scenario: Door is open
- **WHEN** the reported position is `open`
- **THEN** the Home Assistant entity shows the garage door as open

### Requirement: Door position is retained by the broker
The door position SHALL be published such that a client connecting to the broker receives the last known position immediately, without waiting for the next transmission from the garage node.

#### Scenario: Home Assistant restarts
- **WHEN** Home Assistant restarts and reconnects to the broker
- **THEN** the door entity shows the correct position immediately
- **AND** it does not remain unknown until the next heartbeat

#### Scenario: Retained state is superseded by unavailability
- **WHEN** Home Assistant reconnects while the base node is offline
- **THEN** the retained position is not presented as current, per the `availability-detection` capability

### Requirement: Telemetry and link health are exposed as separate entities
Each telemetry value from `sensor-telemetry` and each health value from `availability-detection` SHALL appear as its own Home Assistant entity, distinct from the door entity, and SHALL be classified as diagnostic where the platform supports it.

#### Scenario: Operator inspects sensor health
- **WHEN** the operator opens the device page in Home Assistant
- **THEN** uptime, restart cause, supply voltage and link health are individually visible
- **AND** they are separated from the primary door entity

### Requirement: Entities carry stable identities
Entity identifiers SHALL remain stable across firmware updates and node restarts, so that automations, history and dashboards do not break.

#### Scenario: Firmware is updated
- **WHEN** either node receives a firmware update
- **THEN** existing entity identifiers are unchanged
- **AND** recorded history remains continuous

### Requirement: Automations depending on door position are not part of this system
Derived behaviour — such as alerting when the door has been open for longer than some period — SHALL be implemented in Home Assistant, not in node firmware. The nodes SHALL report position and duration-relevant facts only.

#### Scenario: Door left open
- **WHEN** the door remains open for an extended period
- **THEN** the nodes continue reporting the position unchanged
- **AND** any alerting is the responsibility of a Home Assistant automation
