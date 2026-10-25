# Rebuild the garage door sensor as an ESPHome LoRa point-to-point link

## Why

The existing `lorawan_doorsensor` Arduino sketch is unreliable in production. It is a deep-sleep design folded into a `loop()`, and it carries the failure modes of that origin: a failed heartbeat is not retried for 15 minutes, the LoRaWAN session is written to NVS on every single uplink, the reed contact is polled every 2 s with no debounce, and there is no watchdog or recovery path. On top of that, The Things Network's Fair Use Policy (30 s airtime per device per day) caps the update rate at roughly one message every 2.5 minutes at SF7 — far below the "frequent alive" the operator wants.

The deployment constraints have also changed. The sensor now has permanent mains power, so the entire battery-life optimisation that shaped the original design is obsolete. A second Heltec WiFi LoRa 32 V3 board is available, the house has stable WiFi, an MQTT broker is already in use, and there are no other LoRaWAN devices — so nothing forces us to keep TTN.

Replacing LoRaWAN with a direct LoRa point-to-point link between two Heltec boards removes six failure domains at once (OTAA join, session persistence, frame-counter sync, gateway availability, network server, webhook) and removes the Fair Use Policy entirely, leaving only the statutory duty cycle. Building it in ESPHome rather than Arduino removes almost all remaining custom code: ESPHome's `sx126x` component drives the radio, and its `packet_transport` component already implements framing, encryption, replay protection, connection status and immediate-on-change transmission — the exact protocol we would otherwise hand-roll. It also delivers the operator's explicit wish for over-the-air firmware updates.

## What Changes

- **BREAKING**: LoRaWAN and The Things Network are removed entirely. The device no longer joins a network, no longer stores a LoRaWAN session, and its uplink payload format is retired. The existing TTN application and device registration become obsolete.
- **BREAKING**: The Arduino sketch `lorawan_doorsensor/lorawan_doorsensor.ino` is replaced by two ESPHome YAML configurations. The custom C++ (`heltec_vbat_v3_2()`, manual payload packing, hand-rolled send scheduling) is deleted rather than ported.
- A **garage node** (Heltec V3 #1) reads the reed contact, debounces it, and broadcasts door state plus health telemetry over encrypted LoRa.
- A **base node** (Heltec V3 #2), sited in the house on stable WiFi, receives those broadcasts and republishes them to the existing MQTT broker for Home Assistant.
- The heartbeat interval becomes a deliberate, budgeted design parameter derived from the statutory duty cycle rather than from a battery-life target. Target: a full state broadcast at least every 15 s, versus the current 15 minutes — a 60x improvement.
- State changes are transmitted within milliseconds rather than up to 2 s later, and are no longer at risk of being missed while a blocking transmission is in progress.
- Sensor health becomes first-class: uptime, boot count, reset reason, supply voltage and link status are published as distinct entities instead of being absent or packed into opaque payload bytes.
- Availability is detected at both hops — the base observes silence from the garage node, and MQTT Last Will observes silence from the base — so a failure anywhere in the chain surfaces in Home Assistant.
- Both nodes gain over-the-air firmware updates. See the constraint under Impact.
- Both OLED displays become diagnostic panels with burn-in mitigation, replacing the current always-on static screen.
- `HELTEC_POWER_BUTTON` (long-press power off) is not carried over; on a permanently powered sensor it is only a way to silently kill the device.

## Capabilities

### New Capabilities

- `door-state-sensing`: How the reed contact is read, debounced and interpreted; what "open", "closed" and "unknown" mean; how contact chatter during door travel is prevented from consuming the radio budget.
- `lora-p2p-link`: The radio link between the two nodes — band, spreading factor, encryption, replay protection, and the airtime budget that bounds the heartbeat rate.
- `sensor-telemetry`: What health and diagnostic data the garage node reports about itself, and how often.
- `availability-detection`: How loss of the sensor, the link, or the base node is detected and surfaced, at both hops.
- `home-assistant-integration`: The MQTT contract — topics, retention, device classes, entity naming — that Home Assistant consumes.
- `device-maintenance`: Firmware update paths, on-device diagnostics, and unattended recovery from a wedged state.

### Modified Capabilities

None. This project has no existing specs; the previous firmware was never spec'd.

## Impact

**Removed**
- `lorawan_doorsensor/lorawan_doorsensor.ino` — the entire sketch
- `lorawan_doorsensor/Makefile` — arduino-cli build/upload targets, superseded by `esphome run`
- `lorawan_doorsensor/.github/copilot-instructions.md` — already stale (it documents the deep-sleep design that no longer exists in the code)
- Dependencies: `heltec_unofficial`, `LoRaWAN_ESP32`, RadioLib, arduino-cli

**Added**
- Two ESPHome YAML configurations plus a shared secrets file
- Dependency: ESPHome (>= a version shipping `sx126x` with `packet_transport` support — to be pinned in design)
- A shared pre-shared key, kept out of version control

**Unchanged**
- The reed contact and its wiring to GPIO4
- The MQTT broker and the Home Assistant instance consuming it
- Both Heltec WiFi LoRa 32 V3 boards

**Confirmed constraint — no WiFi at the garage**

House WiFi does not reach the garage. This confirms rather than complicates the choice of LoRa for the data path: there is no simpler WiFi-based alternative to fall back on.

It does bound the OTA story. The base node is on stable house WiFi and is updated from the desk as normal. The garage node runs its WiFi as a permanently available access point instead, so firmware is pushed from a laptop or phone standing near the garage — no cable, no opening the enclosure, but physical proximity is required. Updates over the LoRa link itself are not viable at these data rates.

**Explicitly out of scope**

- Reed line supervision via an end-of-line resistor (distinguishing "door open" from "cut cable"). Worth doing, but it is a hardware change at the door and can be added later without disturbing this architecture.
- A LiPo cell as a UPS so that a mains failure is reported rather than silently ending transmission. The supply-voltage telemetry specified here is the prerequisite; fitting the cell is a separate decision.
- Detecting a partially open door. A single contact cannot express it; "not closed for longer than N minutes" is a Home Assistant automation, not a firmware feature.
