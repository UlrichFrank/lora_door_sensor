## 1. Toolchain and repository setup

- [x] 1.1 Install ESPHome and determine the minimum release in which `sx126x` supports `packet_transport`; record the exact pinned version in `design.md` (resolves the first Open Question)
- [x] 1.2 Create the ESPHome project layout alongside the existing `lorawan_doorsensor/` directory, without deleting anything yet
- [x] 1.3 Create a secrets file for the WiFi credentials, broker credentials and the LoRa pre-shared key; add it to `.gitignore` and verify it is untracked (`lora-p2p-link`: key not in version control)
- [x] 1.4 Generate the pre-shared key from a cryptographic random source, not by hand

## 2. Board bring-up — prove the hardware before the protocol

- [x] 2.1 Write a minimal ESPHome config for one board: ESP32-S3 variant, esp-idf framework, WiFi, OTA, logger. Flash over USB and confirm it boots and is reachable
- [x] 2.2 Add the SSD1306 display with Vext control (GPIO36, inverted) and reset on GPIO21; confirm output is visible
- [x] 2.3 Add the `sx126x` component with the Heltec V3 pins (CS 8, RST 12, BUSY 13, DIO1 14, SPI 9/10/11), `rf_switch: true`, `tcxo_voltage: 1_8V`, `tcxo_delay: 5ms`. Confirm the radio initialises — a radio that initialises but never transmits means the TCXO settings are wrong
- [x] 2.4 Repeat 2.1–2.3 on the second board and confirm raw LoRa transmission and reception between them before introducing `packet_transport`
- [x] 2.5 Flash both boards over USB one final time; from here on, all flashing is over the air

## 3. Garage node — sensing

- [x] 3.1 Configure the reed contact on GPIO4 as a binary sensor with `INPUT_PULLUP`, no inversion, `device_class: garage_door`
- [x] 3.2 Add `delayed_on: 50ms` / `delayed_off: 50ms` debounce filters (`door-state-sensing`: contact transitions are debounced)
- [x] 3.3 Add the minimum-interval guard on event-driven transmissions so a chattering contact cannot exhaust the airtime budget (`door-state-sensing`: event-driven transmissions are rate limited)
- [x] 3.4 **Verify polarity on the bench with a magnet**: magnet present must report `closed`. Do not proceed on reasoning alone — note this is the opposite of the `inverted: True` in the repo's existing `esphome.yml`

## 4. Garage node — telemetry

- [x] 4.1 Add an uptime sensor (`sensor-telemetry`: reports its uptime)
- [x] 4.2 Add a restart-cause sensor distinguishing power-on, watchdog, brownout and software restart (`sensor-telemetry`: reports why it last restarted)
- [x] 4.3 Add the supply voltage sensor on GPIO1 with the ÷2 divider and 12 dB attenuation (`sensor-telemetry`: reports its supply voltage)
- [x] 4.4 Confirm every telemetry value is a separately addressable entity, not packed into a payload (`sensor-telemetry`: distinct values, not an opaque payload)

## 5. Garage node — network posture and OTA

- [x] 5.1 Configure `wifi:` with an `ap:` block and **no station networks at all**. Access-point-only mode removes the reboot-loop failure structurally, because `reboot_timeout` applies only in station mode (`device-maintenance`: absence of a network never causes a restart loop)
- [x] 5.2 Set a strong access point password and a separate OTA password; both live in the untracked secrets file from 1.3
- [x] 5.3 Confirm no `api:` and no `mqtt:` component is present on this node, and nothing else that restarts on an unreachable network
- [x] 5.4 Add the `safe_mode` component — mandatory here, since this is the node that cannot be recovered from the desk (`device-maintenance`: recovery from a bad firmware update)
- [x] 5.5 Test OTA over the access point end to end, from the same kind of device you intend to use in the field
- [x] 5.6 Check whether `captive_portal` or `web_server` on the pinned ESPHome version offers a browser-based firmware upload at the AP address; if it does, enable it so a phone suffices and record the outcome against `design.md` D9
- [x] 5.7 **Deliberately flash a broken build on the bench** and confirm the node enters safe mode, brings up the access point, and can be recovered over the air. Do this before the node is installed — it is the test that decides whether a future bad flash costs a walk or a disassembly
- [x] 5.8 Leave the node running for over 20 minutes with no client associated and confirm it neither restarts nor stops transmitting

## 6. Radio link

- [x] 6.1 Configure `packet_transport` on the garage node as provider: 868.2 MHz, SF7, BW 125 kHz, CR 4/5, private sync word, `update_interval: 20s`
- [x] 6.2 Enable `encryption:` with the pre-shared key and `rolling_code_enable: true` on the provider (`lora-p2p-link`: encrypted, replay-resistant)
- [x] 6.3 Configure the base node as consumer with the matching key and `ping_pong_enable: true`
- [x] 6.4 Set `ping_pong_recycle_time` to 1 min or shorter — the 10-minute default defeats a 20-second heartbeat (`availability-detection`: detection window no longer than 2 minutes)
- [x] 6.5 Set `pa_power` to 0 dBm initially; raise only if section 9 shows insufficient margin, and never above the 14 dBm ERP limit for this sub-band
- [x] 6.6 **Measure the actual transmitted packet size** and recompute the duty cycle against `design.md` D4; adjust `update_interval` if the measured size exceeds the assumed 64 bytes (`lora-p2p-link`: airtime budget validated against measured packet size)
- [x] 6.7 Verify a door state change is transmitted within one second rather than waiting for the heartbeat (`lora-p2p-link`: position changes transmitted without waiting)

## 7. Base node — broker integration

- [x] 7.1 Configure WiFi and MQTT against the existing broker (`home-assistant-integration`: existing broker, no new infrastructure)
- [x] 7.2 Configure explicit birth and will messages (`availability-detection`: loss of the base node is surfaced independently)
- [x] 7.3 Publish door position retained (`home-assistant-integration`: retained by the broker)
- [x] 7.4 Expose the `packet_transport` `type: status` binary sensor as the link health entity (`availability-detection`: loss of the garage node surfaced as a distinct state)
- [x] 7.5 Mirror the garage node's telemetry as consumer-side entities, classified as diagnostic
- [x] 7.6 Fix and document entity identifiers so they survive firmware updates (`home-assistant-integration`: stable identities)
- [x] 7.7 Investigate whether per-packet RSSI/SNR is obtainable alongside `packet_transport`; if not, record the outcome against `design.md` R1 rather than leaving it open

## 8. Displays

- [x] 8.1 Garage node display: door position, uptime, time since last transmission, WiFi/AP state (`device-maintenance`: live diagnostics locally)
- [x] 8.2 Base node display: last received position, time since last reception, link health, broker connection state
- [x] 8.3 Implement burn-in mitigation on both and record which approach was chosen (resolves the second Open Question in `design.md`)
- [x] 8.4 Confirm diagnostics remain reachable on demand after the mitigation has blanked or shifted the display
- [x] 8.5 Confirm no button is configured to power the device down (`device-maintenance`: cannot be switched off accidentally)

## 9. Commissioning tests

- [x] 9.1 **Rolling-code reboot test**: power-cycle the garage node repeatedly and confirm the base keeps accepting its packets. This settles `design.md` R6 — a delayed, total failure that would otherwise be blamed on the radio
- [x] 9.2 Availability test: power down the garage node and confirm link health flips to unreachable within 2 minutes; power it back up and confirm recovery
- [x] 9.3 Base failure test: kill the base node and confirm the broker publishes it unavailable and Home Assistant stops presenting the door position as current (`availability-detection`: stale position never presented as current)
- [ ] 9.4 Broker outage test: stop the broker, confirm the base keeps receiving over LoRa and reconnects and resumes publishing unattended
- [x] 9.5 Replay test: capture a packet and retransmit it; confirm the base rejects it
- [ ] 9.6 Range and margin test in the real installed positions with the real antennas, over at least 24 hours, with the door in both positions — a moving metal door changes the RF environment
- [ ] 9.7 Measure packet loss rate over that period; if a 20-second self-heal proves inadequate, revisit `design.md` D3
- [x] 9.8 Watchdog test: confirm a node that stops making progress restarts itself and reports the cause afterwards

## 10. Parallel run and cutover

- [ ] 10.1 Install the garage node in its final position with the existing LoRaWAN sensor still running
- [ ] 10.2 Run both for at least one week and compare reported positions; investigate every divergence before proceeding
- [ ] 10.3 Build the Home Assistant dashboard and any door-left-open automation against the new entities (`home-assistant-integration`: automations live in Home Assistant, not firmware)
- [ ] 10.4 Decommission the old sensor and retire the TTN application and device registration
- [ ] 10.5 Delete `lorawan_doorsensor/lorawan_doorsensor.ino`, `lorawan_doorsensor/Makefile` and the stale `.github/copilot-instructions.md`
- [x] 10.6 Write a README covering the pinned ESPHome version, the flashing procedure for each node, the garage node's access point credentials and address, the safe-mode recovery procedure, and the rule that the base node is always flashed and verified first (`lora-p2p-link`: matched pair; `design.md` R9)
