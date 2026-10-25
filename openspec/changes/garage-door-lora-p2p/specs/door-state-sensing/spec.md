## Purpose

Defines how the garage door's single reed contact is read and translated into a reported door position, including how mechanical contact chatter during door travel is prevented from producing spurious reports or exhausting the radio budget.

## ADDED Requirements

### Requirement: Door position is derived from the reed contact
The garage node SHALL report the door as `closed` when the reed contact is closed, and as `open` when the reed contact is open. No other door position SHALL be reported, because a single contact cannot distinguish "fully open" from "partially open".

#### Scenario: Door is closed
- **WHEN** the reed contact is closed and has been stable for the debounce interval
- **THEN** the reported door position is `closed`

#### Scenario: Door is not closed
- **WHEN** the reed contact is open and has been stable for the debounce interval
- **THEN** the reported door position is `open`

#### Scenario: Polarity is verified before deployment
- **WHEN** the sensor is commissioned
- **THEN** a magnet is applied to and removed from the reed contact on the bench
- **AND** the reported position is confirmed to be `closed` with the magnet present and `open` with it absent, before the node is installed

### Requirement: Contact transitions are debounced
The garage node SHALL require the reed contact to hold a new level continuously for at least 50 ms before treating it as a position change. Transitions shorter than this SHALL NOT alter the reported position and SHALL NOT cause a transmission.

#### Scenario: Contact chatter during door travel
- **WHEN** the reed contact changes level several times within a 50 ms window while the door is moving
- **THEN** no position change is reported for those transitions
- **AND** no packet is transmitted for them

#### Scenario: Genuine door movement
- **WHEN** the reed contact opens and stays open for longer than 50 ms
- **THEN** the reported position changes to `open`

### Requirement: Event-driven transmissions are rate limited
The garage node SHALL enforce a minimum interval between transmissions triggered by a position change, independent of debouncing. A contact that changes level persistently at a period longer than the debounce interval SHALL NOT be able to exceed the airtime budget defined in the `lora-p2p-link` capability.

#### Scenario: Failing reed contact chatters slowly
- **WHEN** the reed contact alternates position every 200 ms for an extended period
- **THEN** transmissions triggered by those changes are throttled to the configured minimum interval
- **AND** the node's duty cycle stays within the budget defined in `lora-p2p-link`

#### Scenario: Normal door operation is not throttled
- **WHEN** the door is opened and closed once
- **THEN** both position changes are transmitted without delay from the rate limiter

### Requirement: Position is reported on change and on every heartbeat
The current door position SHALL be transmitted both when it changes and as part of every periodic full broadcast, so that a lost change notification is corrected by the next heartbeat rather than persisting until the door next moves.

#### Scenario: Change notification is lost in transit
- **WHEN** the door opens and the resulting transmission is not received by the base node
- **THEN** the next periodic full broadcast reports the door as `open`
- **AND** the base node's reported position is corrected without any door movement

#### Scenario: Position is unchanged
- **WHEN** the door has not moved since the last broadcast
- **THEN** the periodic full broadcast still reports the current position
