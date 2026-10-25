## Purpose

Defines how the loss of the sensor, the radio link, or the base node is detected and surfaced, so that a broken system is never mistaken for a healthy one reporting an unchanging door position.

## ADDED Requirements

### Requirement: Loss of the garage node or the radio link is surfaced as a distinct state
The base node SHALL expose the health of the radio link as a value separate from door position. When no valid transmission has been received from the garage node within the configured detection window, that value SHALL indicate the sensor is unreachable.

#### Scenario: Garage node loses power
- **WHEN** the garage node stops transmitting
- **THEN** within the detection window the link health value indicates the sensor is unreachable
- **AND** the door position is no longer presented as current

#### Scenario: Radio link is jammed or obstructed
- **WHEN** transmissions stop arriving although the garage node is still running
- **THEN** the link health value indicates the sensor is unreachable, exactly as for a power loss

#### Scenario: Link recovers
- **WHEN** transmissions from the garage node resume
- **THEN** the link health value returns to reachable
- **AND** the current door position is reported

### Requirement: The detection window is short enough to be useful
The detection window for loss of the garage node SHALL be no longer than 2 minutes. It SHALL NOT be left at a default that is long relative to the heartbeat interval defined in `lora-p2p-link`.

#### Scenario: Detection window is verified
- **WHEN** the garage node is powered down during commissioning
- **THEN** the link health value indicates unreachable within 2 minutes

### Requirement: Loss of the base node is surfaced independently
The base node SHALL be configured so that its own disappearance is announced to the message broker without the base node participating. This announcement SHALL be independent of the radio link health value.

#### Scenario: Base node loses power
- **WHEN** the base node stops running
- **THEN** the broker publishes the base node as unavailable
- **AND** Home Assistant marks the door entity as unavailable rather than showing its last known position as current

#### Scenario: Base node loses WiFi but keeps running
- **WHEN** the base node's connection to the broker drops
- **THEN** the broker publishes the base node as unavailable
- **AND** the base node reconnects and resumes publishing when the connection is restored, without manual intervention

### Requirement: A stale door position is never presented as current
Home Assistant SHALL NOT present a door position as current when either hop between the reed contact and the broker has failed.

#### Scenario: Garage node is dead but the base node is healthy
- **WHEN** the garage node has stopped transmitting and the base node is still connected to the broker
- **THEN** the door entity is presented as unavailable or unknown, not as its last reported position

#### Scenario: Both hops are healthy
- **WHEN** the garage node is transmitting and the base node is connected to the broker
- **THEN** the door entity presents the current position
