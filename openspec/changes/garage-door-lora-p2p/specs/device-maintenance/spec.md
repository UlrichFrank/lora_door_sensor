## Purpose

Defines how firmware reaches each node after deployment, what each node shows on its display for local diagnosis, and how a node recovers from faults without a site visit.

## ADDED Requirements

### Requirement: The base node is updatable over the air
The base node SHALL accept firmware updates over the network without physical access.

#### Scenario: Base node firmware update
- **WHEN** a new firmware build is pushed to the base node over the network
- **THEN** the node updates and restarts
- **AND** it reconnects to the broker and resumes publishing without manual intervention

### Requirement: The garage node is updatable without disassembly
Site WiFi does not reach the garage. The garage node SHALL therefore provide its own access point, permanently available without requiring a button press or any prior action at the device, and SHALL accept firmware updates over it. Updating the node SHALL NOT require opening its enclosure or attaching a cable.

#### Scenario: Routine firmware update
- **WHEN** a technician stands near the garage with a device connected to the node's access point
- **THEN** firmware can be pushed to the node over that connection
- **AND** the enclosure remains closed throughout

#### Scenario: Access point is available without preparation
- **WHEN** the technician arrives with no prior notice given to the node
- **THEN** the access point is already broadcasting and accepts a connection immediately
- **AND** no button press, power cycle, or waiting period is required first

#### Scenario: Access is protected
- **WHEN** the access point is within range of an unauthorised party
- **THEN** connecting to it requires a password
- **AND** pushing firmware requires a further credential

### Requirement: A failed firmware update is recoverable without disassembly
Because the garage node cannot be reached from the desk, it SHALL recover on its own into a state that accepts a replacement firmware image if a newly flashed build fails to run. That recovery state SHALL make the access point and the update path available even though the failing firmware does not.

#### Scenario: Newly flashed firmware crashes on boot
- **WHEN** a firmware image is pushed that fails to boot successfully
- **THEN** after repeated failed boot attempts the node enters a recovery state
- **AND** its access point becomes available and accepts a replacement image
- **AND** no cable or disassembly is needed to restore it

#### Scenario: Recovery path is proven before installation
- **WHEN** the node is commissioned
- **THEN** a deliberately broken build is flashed on the bench
- **AND** recovery over the access point is demonstrated before the node is installed in the garage

#### Scenario: The base node is updated first
- **WHEN** a firmware change is to be rolled out to both nodes
- **THEN** the base node is flashed and verified before the garage node
- **AND** an untested build never reaches the garage node first

### Requirement: Absence of a network never causes a restart loop
Neither node SHALL restart itself as a consequence of a network being unreachable, and the garage node SHALL NOT be configured to attempt to join any network that does not exist at its location. A node whose only unavailable dependency is a network SHALL continue performing every function that does not require that network.

#### Scenario: Garage node runs with no client ever connecting
- **WHEN** the garage node runs for an extended period with nothing associated to its access point
- **THEN** it does not restart on that account
- **AND** it continues to sense the door and transmit over the radio link indefinitely

#### Scenario: Base node loses the broker
- **WHEN** the base node cannot reach the broker
- **THEN** it continues receiving from the radio link
- **AND** it reconnects and resumes publishing when the broker becomes reachable

### Requirement: Each node displays live diagnostics locally
Each node SHALL show, on its own display, enough state to determine whether it is working while standing in front of it.

#### Scenario: Technician inspects the garage node
- **WHEN** a technician looks at the garage node's display
- **THEN** it shows the current door position, how long the node has been running, how long since its last transmission, and whether its access point is up

#### Scenario: The display is the only local diagnostic channel
- **WHEN** the garage node is unreachable over the radio link
- **THEN** its display still reports enough to distinguish a sensing fault, a radio fault and a healthy node from in front of the device

#### Scenario: Operator inspects the base node
- **WHEN** the operator looks at the base node's display
- **THEN** it shows the last received door position, how long since the last reception, radio link health, and broker connection state

### Requirement: Displays do not suffer burn-in
Because both nodes are permanently powered and display largely static content, each display SHALL employ a burn-in mitigation.

#### Scenario: Node runs for months
- **WHEN** a node has been displaying diagnostics continuously for an extended period
- **THEN** no persistent ghost image is visible on the panel

#### Scenario: Diagnostics remain reachable
- **WHEN** the mitigation has blanked or shifted the display
- **THEN** current diagnostics can still be brought up on demand at the device

### Requirement: The device cannot be switched off accidentally
No control on either node SHALL be configured to power the device down. The previous firmware's long-press power-off behaviour SHALL NOT be carried over.

#### Scenario: Button is pressed and held
- **WHEN** the on-board button is pressed and held
- **THEN** the node does not power down
- **AND** it continues sensing and transmitting

### Requirement: Recovery from a wedged state is unattended
Each node SHALL recover automatically from a hung or unresponsive state without requiring a site visit or a power cycle by hand.

#### Scenario: Firmware stops servicing its main loop
- **WHEN** a node stops making progress
- **THEN** it restarts automatically
- **AND** the restart cause is reported per the `sensor-telemetry` capability once it is running again
