## Purpose

Defines the health and diagnostic data the garage node reports about itself, so that "is the sensor working correctly?" can be answered from Home Assistant rather than by walking to the garage.

## ADDED Requirements

### Requirement: The garage node reports its uptime
The garage node SHALL report how long it has been running since its last restart, as a distinct value separate from door position.

#### Scenario: Node restarts unexpectedly
- **WHEN** the garage node reboots
- **THEN** the reported uptime resets and begins increasing from near zero
- **AND** the restart is detectable from Home Assistant without inspecting the device

#### Scenario: Node runs continuously
- **WHEN** the garage node has been running for several days
- **THEN** the reported uptime reflects that duration

### Requirement: The garage node reports why it last restarted
The garage node SHALL report the cause of its most recent restart, distinguishing at minimum a normal power-on from a watchdog reset, a brownout, and a software-initiated restart.

#### Scenario: Brownout occurs
- **WHEN** the supply voltage dips far enough to reset the node
- **THEN** the reported restart cause identifies a brownout
- **AND** the cause remains visible until the next restart

#### Scenario: Firmware update causes a restart
- **WHEN** the node restarts after an over-the-air update
- **THEN** the reported restart cause identifies a software-initiated restart rather than a fault

### Requirement: The garage node reports its supply voltage
The garage node SHALL report its supply voltage as a distinct value. This value exists so that mains loss is reportable if a backup cell is later fitted, and so that a failing power supply is visible before it causes resets.

#### Scenario: Supply voltage is stable
- **WHEN** the node is running on mains power
- **THEN** the reported supply voltage is available in Home Assistant and reflects the actual supply

#### Scenario: Supply voltage degrades
- **WHEN** the supply voltage drifts outside its normal range
- **THEN** the change is visible in the reported value before the node resets

### Requirement: Telemetry is reported as distinct values, not as an opaque payload
Each telemetry item SHALL reach Home Assistant as a separately addressable value with its own identity. Telemetry SHALL NOT require a payload decoder or byte-offset knowledge to interpret.

#### Scenario: A new telemetry item is added
- **WHEN** an additional telemetry value is introduced
- **THEN** it appears as its own entity in Home Assistant
- **AND** no decoder elsewhere in the system needs to be updated to interpret existing values

### Requirement: Telemetry is refreshed on every heartbeat
All telemetry values SHALL be included in every periodic full broadcast, at the interval defined in `lora-p2p-link`.

#### Scenario: Telemetry has not changed
- **WHEN** no telemetry value has changed since the last broadcast
- **THEN** the values are still transmitted in the periodic full broadcast
- **AND** Home Assistant's copy is refreshed rather than ageing
