# Design: ESPHome LoRa point-to-point garage door sensor

## Context

See `proposal.md` — Why, for motivation. This section records only what constrains the approach.

**Hardware, fixed.** Two Heltec WiFi LoRa 32 V3 boards (ESP32-S3 + SX1262 + SSD1306 128x64 OLED), both on permanent mains power. One reed contact on GPIO4; the contact is closed when the garage door is closed. The board pinout is not negotiable:

| Function | Pin | Function | Pin |
|---|---|---|---|
| SPI CLK / MOSI / MISO | GPIO9 / 10 / 11 | OLED SDA / SCL / RST | GPIO17 / 18 / 21 |
| SX1262 CS | GPIO8 | Vext control (OLED power) | GPIO36, inverted |
| SX1262 RST | GPIO12 | Battery ADC | GPIO1 (÷2 divider) |
| SX1262 BUSY | GPIO13 | LED | GPIO35 |
| SX1262 DIO1 | GPIO14 | PRG button | GPIO0 |
| Reed contact | GPIO4, `INPUT_PULLUP` | | |

The SX1262 on this board uses a TCXO, so `tcxo_voltage: 1_8V` and `tcxo_delay: 5ms` are mandatory, as is `rf_switch: true`. Omitting them produces a radio that appears to initialise and then transmits nothing — a failure mode worth naming explicitly, because it looks exactly like a range problem.

**Site.** The base node sits in the house on stable WiFi with an existing MQTT broker feeding Home Assistant. Whether house WiFi reaches the garage is unconfirmed; the design must not depend on it.

**Regulatory.** EU868 SRD. The 868.0–868.6 MHz sub-band permits 1% duty cycle at 14 dBm ERP. This is now the only rate limit — TTN's Fair Use Policy, which was the binding constraint at 30 s airtime per day, disappears with LoRaWAN.

**Platform capability.** ESPHome ships an `sx126x` component for raw LoRa, and a `packet_transport` component that layers a device-to-device protocol on top of it. The latter turns out to already implement most of what a hand-rolled protocol would need; establishing that is what shapes the central decision below.

## Goals / Non-Goals

**Goals**

- A single failure domain that the operator owns end to end: sensor → RF → base → WiFi → own broker.
- Near-zero custom code. Configuration, not firmware.
- Door state latency in milliseconds; a full state refresh at least every 20 s.
- Every failure in the chain visible as an explicit Home Assistant entity, never as stale data that looks healthy.
- Both nodes recover from transient faults unattended, and never reboot-loop because of an absent network.

**Non-Goals**

- Interoperability with anything but these two nodes. No LoRaWAN compatibility, no third-party receivers, no forward compatibility of the wire format.
- Cryptographic strength beyond deterring a local passive or replay attacker. See the XXTEA risk below.
- Mesh, routing, or multi-sensor scaling. If a second sensor arrives, it becomes a second `packet_transport` provider — that path exists, but nothing here is designed for it.
- Any change to the reed contact or its wiring.

## Decisions

### D1 — LoRa point-to-point, not LoRaWAN

**Chosen:** Direct SX1262-to-SX1262 link between the two boards.

The LoRaWAN chain has six hops, four of which the operator does not control (gateway, backhaul, network server, webhook). The P2P chain has three, all owned. Concretely this deletes OTAA join, session persistence, frame-counter synchronisation and the NVS write-per-uplink that is a plausible root cause of the current instability — not by fixing them, but by removing the code they live in.

*Alternatives considered.* **Repair the LoRaWAN firmware** — possible, and the specific bugs are identified, but it leaves both the Fair Use Policy ceiling and the four unowned hops in place. **WiFi/MQTT directly from the garage** (as in the repo's existing `esphome.yml` for an ESP8266) — strictly better *if* WiFi reaches the garage, and would make this entire change unnecessary; the operator's choice of LoRa implies it does not, but this remains the one alternative that would beat the chosen design outright. **ESP-NOW** — simplest of all, no duty cycle, encryption built in, but 2.4 GHz through garage concrete and a metal door is far less forgiving than 868 MHz. Rejected on propagation, not on merit.

### D2 — ESPHome, not Arduino/RadioLib

**Chosen:** ESPHome with the `esp-idf` framework on both nodes.

The operator asked for OTA, which ESPHome provides as a first-class feature. But the larger gain is that the reliability scaffolding this change needs — WiFi supervision, MQTT reconnection with backoff, watchdog, debounce filters, uptime and reset-reason diagnostics, retained-state publication — all exist as configuration rather than as code to be written and debugged. The Arduino sketch's bugs are overwhelmingly in exactly this scaffolding, not in the domain logic.

*Alternative considered.* Arduino + RadioLib, keeping the existing `heltec_unofficial` setup. Gives finer control over radio timing and would permit a per-packet ACK (see D4), but reintroduces hand-written scheduling, retry and persistence — the code that is failing today — and forfeits OTA.

### D3 — `packet_transport` over a hand-rolled protocol

**Chosen:** `packet_transport` on the `sx126x` platform, garage node as provider, base node as consumer.

The custom protocol this change would otherwise require was estimated at ~200 lines: framing, CRC, addressing, sequence numbers, deduplication, retry, and encryption with replay protection. `packet_transport` already provides:

| Requirement | `packet_transport` mechanism |
|---|---|
| Framing, addressing | Provider name + broadcast IDs |
| Integrity | Underlying `sx126x` hardware CRC |
| Confidentiality | `encryption:` — passphrase hashed to a 256-bit XXTEA key |
| Replay protection | `rolling_code_enable: true` — monotonic 64-bit counter |
| Liveness, both directions | `ping_pong_enable: true` — consumer nonce echoed by provider |
| Connection status entity | `binary_sensor` `type: status` |
| Heartbeat | `update_interval` — full broadcast of all values |
| Immediate on change | See below |

On the last point: the component's state callbacks set an `updated_` flag, and `loop()` sends the changed values via a partial broadcast as soon as that flag is set — it does not wait for `update_interval`. ESPHome's main loop runs on the order of milliseconds, so a door state change goes out essentially immediately, while `update_interval` governs the periodic full refresh. This is precisely the "immediate on event, plus frequent heartbeat" behaviour the operator asked for, and it arrives without custom code.

The consequence worth naming: this is a **broadcast** protocol with no per-packet acknowledgement. A lost packet is not retransmitted. That is acceptable only because every full broadcast carries complete current state, so a loss self-heals at the next `update_interval` — this is the "state, not events" property, and it is why D4's interval choice matters more than it otherwise would.

*Alternative considered.* Hand-rolled frames over the raw `sx126x` component with `on_packet` and `send_packet`, giving per-packet ACK, immediate retry, and an SF fallback ladder. Genuinely more robust per-packet, and it would also make link RSSI/SNR directly available (see R1). Rejected because it trades a maintained, tested implementation for ~200 lines of bespoke crypto and protocol code — and hand-rolled crypto is exactly where this kind of project goes wrong. Worth revisiting only if measurement shows the loss rate is high enough that a 20 s self-heal is inadequate.

### D4 — Band, spreading factor and the airtime budget

**Chosen:** 868.2 MHz, SF7, BW 125 kHz, CR 4/5, private sync word, `update_interval: 20s`, transmit power starting at 0 dBm.

The heartbeat rate is now bounded by the statutory 1% duty cycle rather than by a battery. Airtime for SF7/BW125/CR4-5 with an 8-symbol preamble:

| Payload | Airtime | @ 15 s | @ 20 s | @ 30 s |
|---|---|---|---|---|
| 32 B | 72 ms | 0.48% | 0.36% | 0.24% |
| 48 B | 98 ms | 0.65% | 0.49% | 0.33% |
| 64 B | 118 ms | 0.79% | **0.59%** | 0.39% |

20 s at an assumed 64-byte packet sits at 0.59%, leaving roughly 40% of the budget as headroom for event packets, ping-pong traffic and a payload that grows during implementation. 15 s would work but leaves too little margin to be comfortable; the actual packet size must be measured and the interval confirmed against it rather than assumed.

*Frequency.* 868.2 MHz sits between the LoRaWAN default channels at 868.1/868.3/868.5, reducing collisions with any LoRaWAN traffic in the area, and the private sync word (`0x14, 0x24`) means LoRaWAN frames are not decoded at all.

*Power.* The EU limit in this sub-band is 14 dBm ERP, but a garage-to-house link needs far less. Starting at 0 dBm and raising only if the measured margin demands it reduces both interference and the temptation to paper over a bad antenna placement with power. `pa_power` must never be left at the SX1262's 22 dBm maximum.

*Deferred option.* The 869.4–869.65 MHz sub-band permits 10% duty cycle, which would allow roughly a 2 s heartbeat. This is not needed to meet the requirements and is recorded only as a path if a future requirement demands it. Its current regulatory terms must be verified against ERC REC 70-03 before use.

### D5 — Debounce is a duty-cycle control, not just data hygiene

**Chosen:** `delayed_on: 50ms` / `delayed_off: 50ms` on the reed input, plus a minimum interval between event-driven broadcasts.

Because `packet_transport` transmits on every state change, and a garage door vibrates while travelling, an undebounced chattering reed converts directly into radio traffic. The existing `esphome.yml` in this repo already applies 50 ms filters for the same reason on a different door; matching that is the baseline. The additional minimum-interval guard exists because debounce alone does not bound a contact that chatters at a period longer than 50 ms — a stuck or failing reed must not be able to exhaust the airtime budget.

### D6 — Availability is detected at two independent hops

**Chosen:** `ping_pong_enable` on the base for the RF hop; MQTT Last Will for the base itself.

```
 Garage node ──LoRa──▶ Base node ──WiFi/MQTT──▶ Broker ──▶ HA
                          │                        │
              hop 1: ping/pong status     hop 2: MQTT LWT
              "sensor or link is gone"    "base node is gone"
```

Neither alone is sufficient. Without hop 1, a dead garage node looks identical to a healthy one publishing stale retained values. Without hop 2, a dead base node makes the garage node look dead when it is fine — and, worse, a dead base with no LWT leaves the last retained door state in place indefinitely.

`ping_pong_recycle_time` must be shortened well below its 10-minute default; the status entity only reflects loss within one recycle period, and a 10-minute blind spot defeats the point of a 20 s heartbeat.

### D7 — MQTT, not the native Home Assistant API

**Chosen:** `mqtt:` on the base node, with explicit birth and will messages. Retained door state.

The broker already exists and the ESP8266 door sensor in this repo already uses it. MQTT also gives Last Will for free, which D6 depends on, and retained state means Home Assistant knows the door position immediately after a restart rather than waiting for the next broadcast.

The garage node gets **no** `api:` and **no** `mqtt:` — it speaks only LoRa. This matters for D8.

### D8 — The garage node runs WiFi in access-point-only mode

**Chosen:** The garage node configures `wifi:` with an `ap:` block and **no station networks at all**. It carries no `api:` and no `mqtt:` component.

It is now confirmed that house WiFi does not reach the garage. That turns what was a defensive setting into a structural simplification.

ESPHome's `wifi:` component reboots the device after 15 minutes without a connection, and `api:` does the same when no client connects. On a node with no WiFi coverage, both defaults produce a permanent reboot cycle — a device that transmits for a few minutes, dies, boots, and repeats, which from the house looks exactly like intermittent radio trouble. The earlier plan defused this with `reboot_timeout: 0s`.

Access-point-only mode is better than defusing it: `reboot_timeout` applies **only in station mode**, so with no station networks configured the failure cannot occur at all. It is removed rather than suppressed, and a future edit cannot reintroduce it by accident. Three further benefits follow: no continuous scanning for a network that will never appear (which retires R8), no 90-second `ap_timeout` wait before the node becomes reachable, and a node that is always immediately flashable rather than only after it has given up on something.

The access point SHALL carry a strong password, and OTA its own. This is a permanently broadcast SSID on private property; that is an accepted, bounded exposure, and D9 explains why it is preferred over the alternative.

*Alternative considered.* An on-demand access point — WiFi disabled at boot, brought up by a long press on the PRG button or by a maintenance command relayed over the LoRa link from the base node (`packet_transport` supports a device being provider and consumer simultaneously, so this is buildable). Smaller attack surface and no permanent SSID. Rejected on reachability grounds: see D9.

### D9 — Firmware reaches the garage node over its own access point, with safe mode as the backstop

**Chosen:** Always-available access point, `ota: platform: esphome`, plus the `safe_mode` component. Flashing is done from a laptop or phone standing near the garage.

There is no over-the-air path from the desk. OTA over the LoRa link is not viable and was never seriously considered: a ~1 MB image at 118 ms per 64 bytes under a 1% duty cycle is on the order of half a day. So the realistic choice is between walking to the garage with a laptop, and walking to the garage with a screwdriver and a USB cable. The access point buys the former.

**Why always-on rather than on-demand.** This is the deciding argument for D8. ESPHome's safe mode — which recovers a node that crashes on boot by starting nothing but logging, network and OTA — depends on the network coming up. Whether it honours an access point that is configured as manual-only (`ap_timeout: 0s`) is not established. If it does not, then a bad flash of the one node that is hardest to reach leaves exactly one recovery path: opening the enclosure and attaching USB. Trading a permanently broadcast SSID for the certainty that a bricked node can be recovered without disassembly is the right trade for this node specifically. The on-demand variant would be the better choice on a node one can simply pick up.

`safe_mode` is therefore not optional here. Its defaults (safe mode after 10 failed boots, a boot counted good after 1 minute) are appropriate; the point is that it is present at all.

A browser-based upload path — `captive_portal` and/or `web_server` with OTA upload at the access point's address — should be added if it works on this ESPHome version, since it makes a phone sufficient and removes the need to carry a laptop at all. To be confirmed during implementation rather than assumed.

**Accepted ongoing cost.** Every garage-node firmware change now requires physical proximity. This is the price of the site having no WiFi there, and it is bounded: updates are rare once commissioned. It does raise the value of the migration plan's bench-first sequencing, since a configuration error found on the desk costs nothing and the same error found after installation costs a trip.

The base node is unaffected: it sits on stable house WiFi and is updated normally from the desk.

### D10 — Reed polarity is asserted, then verified

**Chosen:** `INPUT_PULLUP`, no inversion, `device_class: garage_door`.

Contact closed (door closed) pulls GPIO4 low; Home Assistant's `garage_door` class treats OFF as closed. So an uninverted GPIO binary sensor maps correctly: LOW → OFF → closed. Note that this is the *opposite* of the `inverted: True` in the repo's existing `esphome.yml`, which describes a differently wired contact. Because a polarity error produces a sensor that is confidently and consistently wrong — the worst kind of failure for this device — this must be verified on the bench with a magnet before deployment, not reasoned about.

### D11 — The OLEDs are diagnostic panels, not decoration

**Chosen:** Both displays show live diagnostics; both mitigate burn-in.

The garage display answers "is this thing working?" while standing in front of it — door state, uptime, time since last successful broadcast, WiFi/AP state. The base display answers the same from the house, plus link status and last-received RSSI if available. With permanent power and static content, an OLED burns in within months; mitigation is either periodic content shifting or blanking with wake on the PRG button.

## Risks / Trade-offs

**R1 — Link quality (RSSI/SNR) may not be observable through `packet_transport`.** The `sx126x` component exposes `rssi` and `snr` to its `on_packet` trigger, but `packet_transport` owns packet handling, and whether it surfaces per-packet link metrics as entities is unverified. → Treat RSSI/SNR as a desirable-but-unconfirmed diagnostic. The binary connected/disconnected status from `ping_pong` is the requirement; signal margin is a bonus. If it proves unavailable and margin measurement matters, a temporary raw-`sx126x` configuration can be flashed for range testing during commissioning, which is when the number actually matters most.

**R2 — XXTEA with a chosen-plaintext weakness.** ESPHome's own documentation notes the cipher is vulnerable to chosen-plaintext attack while arguing it is not applicable here. The threat model is a passive local attacker learning when the garage stands open, and a replay attacker asserting "closed". Rolling code addresses the second. → Accepted. Compared to the status quo, this is strictly an improvement — but it is weaker than LoRaWAN's AES-128, and that is a real thing being given up. If the assessment changes, the fallback is D3's rejected alternative with AES-CTR plus a truncated CMAC.

**R3 — No per-packet acknowledgement (from D3).** A lost event packet is not retransmitted; the door state is wrong until the next full broadcast. → Bounded by `update_interval`, which is why D4 sets it to 20 s rather than something leisurely. Loss rate must be measured during commissioning; if it is high, revisit D3.

**R4 — The base node is a single point of failure.** LoRaWAN could in principle have used multiple gateways. → Accepted deliberately. In practice there was one gateway anyway, and unlike a gateway, this failure is visible: MQTT Last Will surfaces it in Home Assistant within seconds.

**R5 — `sx126x` and `packet_transport` are comparatively new ESPHome components.** Fewer deployments, thinner community knowledge, and a wire format that carries no stability guarantee across ESPHome releases. → Pin an exact ESPHome version, and treat both nodes as a matched pair: **never update one without the other.** A `packet_transport` format change between versions would silently break the link with two nodes that each look healthy in isolation.

**R6 — Rolling-code state across reboots.** If the provider's rolling code resets on power-cycle while the consumer retains a higher value, the consumer may reject packets until it catches up — a garage node that works until its first reboot and then goes permanently silent. Whether and how `packet_transport` persists this counter is unverified. → Must be tested explicitly by power-cycling the garage node repeatedly during commissioning. Named here because the failure is delayed, total, and would otherwise be attributed to the radio.

**R7 — Duty cycle is enforced by configuration, not by the firmware.** ESPHome does no airtime accounting. Nothing prevents a misconfiguration, or a chattering reed, from exceeding 1%. → D5's minimum-interval guard is the backstop; the budget in D4 must be recomputed against measured packet size rather than the assumed 64 bytes.

**R8 — WiFi and LoRa coexisting on the garage node.** Largely retired by D8: in access-point-only mode the node never scans for an absent network, which was the concerning case. A quiet access point with no client associated is close to idle. → Residual risk accepted. If radio timing problems do appear, the on-demand-AP variant rejected in D8 remains available, at the cost of the safe-mode reachability described in D9.

**R9 — A bad flash of the garage node.** It is the least accessible node and the only one without a network path from the desk. Firmware that crashes on boot, or that breaks the access point, is recoverable only on site — and in the worst case only over USB. → `safe_mode` is the primary mitigation (D9), the bench-first migration sequence is the second, and the rule that both nodes are a matched pair (R5) means the garage node should never be the first to receive an untested build. Flash and verify the base node first; it is the one that can be recovered from an armchair.

## Migration Plan

The existing sensor stays deployed and running until the replacement is proven. Nothing here requires taking the garage offline early.

1. **Bench** — both boards on a desk, a magnet on the reed. Verify radio init (the TCXO settings from Context), polarity (D10), debounce, and end-to-end MQTT delivery. Confirm actual packet size and recompute the D4 budget against it.
2. **Reboot and reconnect testing** — power-cycle the garage node repeatedly to settle R6; pull the base's WiFi to confirm MQTT LWT and recovery; power down the garage node to confirm the status entity flips within the expected window (D6).
3. **Range** — garage node in its real position, base in its real position, with the real antennas. Measure margin and loss rate over at least a full day, including with the door in both positions, since a metal door moving changes the RF environment. This is the step that decides whether D4's power setting and R3's assumptions hold.
4. **Parallel run** — new sensor deployed alongside the old one, both reporting, entities compared. The old firmware's known unreliability is exactly what makes this worth doing rather than cutting over directly.
5. **Cutover** — retire the TTN application and device registration; remove the Arduino sketch, Makefile and stale copilot instructions from the repository.

**Rollback.** The old sketch remains in git history and the boards are re-flashable over USB. The reed wiring is untouched throughout, so reverting is a flash operation, not a hardware operation.

## Open Questions

- ~~**Exact ESPHome version to pin.**~~ Resolved: **ESPHome 2026.9.0** ships `sx126x` with `packet_transport` support (verified in the installed package). Both nodes are built with this version. The rolling code's upper 32 bits are persisted in flash and incremented on every boot, which addresses the mechanism behind R6; the reboot test (task 9.1) still has to confirm it.
- **Whether to blank the OLEDs or shift their content** for burn-in mitigation (D11). Cosmetic, decidable during implementation.
- **Whether to fit a LiPo cell as a UPS.** Out of scope per the proposal, but the supply-voltage telemetry specified here is its prerequisite, so the decision stays open without blocking anything.

Resolved since first draft: **house WiFi does not reach the garage.** This confirms the LoRa transport rather than changing it, and it converted D8 and D9 from contingency into concrete choices — access-point-only mode, always-available AP, safe mode mandatory. No spec or architectural consequence beyond those two decisions.

Also still open, and worth confirming early because it decides whether a phone suffices: whether `captive_portal` or `web_server` on the pinned ESPHome version offers a browser-based firmware upload at the access point (D9).

## Implementation Findings

Recorded during bench commissioning (ESPHome 2026.9.0, both boards on USB, ~30 cm apart, 0 dBm).

- **Packet sizes are 32-84 B, and every value change is an immediate packet (R7, D4).** The first build put 24 packets into 80 s (~3 % duty cycle) because the ADC reading rippled and a template sensor re-published every 10 s, each one triggering a broadcast. Fixed by `delta: 0.2` on the voltage, a one-shot publish of the restart cause, and one/two-character broadcast IDs. A full broadcast is now 56 B (98 ms, 0.49 % at 20 s); with the minute-wise uptime update steady state is about 0.6 %. Re-measure over 24 h (task 9.6).
- **R1 resolved.** `sx126x`'s `on_packet` exposes RSSI/SNR alongside `packet_transport` (the transport does not consume it). The base publishes them as diagnostic entities. Bench value: -34 dBm / 13 dB.
- **R6 resolved.** The rolling code's upper 32 bits are persisted in flash and incremented on every boot. Five consecutive power-cycles were all accepted by the base (task 9.1).
- **D6 detection window.** `ping_pong_recycle_time: 60s` gave 127 s (over the 120 s limit); `45s` gives 88 s. Recovery after power-up takes 3-17 s.
- **LWT.** Holding the base in reset puts `garage-door/availability` to `offline` after ~22 s; it returns ~22 s after release.
- **Availability topology.** One topic (`garage-door/availability`) carries both the base's birth/will and the garage link state, so the door and garage telemetry go unavailable when either hop fails. The link entity itself is deliberately ungated (it reports "disconnected", never "unavailable"), so after a base failure it keeps its last retained value.
- **Restart cause** cannot be broadcast as text (`packet_transport` carries numbers). It is sent as a code (0 power-on, 1 software, 2 brownout, 3 watchdog, 4 deep sleep, 9 other) and the base maps it back to a text entity.
- **Garage display shows "ping rx", not "time since last transmission".** `packet_transport` offers no transmit hook; the time since the last ping from the base is the closest observable signal.
- **Supply voltage does not measure the 5 V supply.** GPIO1 is the *battery* sense input; with no LiPo it reads ~0.02 V. The spec scenario "reflects the actual supply" is therefore not met on mains power alone. Needs a decision: fit the LiPo (the stated prerequisite for the UPS idea), measure the 5 V rail through a divider on a spare GPIO, or accept this entity as battery-only.
- **Logging:** the CP2102 bridge is wired to UART0, so `logger: hardware_uart: UART0`. Vext and the OLED reset line are driven in a priority-1100 boot hook, before the I2C bus is set up; otherwise the OLED is not found.
- **Door state after boot (bug found and fixed).** The first build only published `door` on a contact edge, so after a reboot with no edge the node had no door state and the base kept showing a stale retained value. A 1 s reconcile now publishes the first state right after boot, without the 20 s throttle.
- **D10 polarity: verified on the bench.** No magnet: GPIO4 HIGH = `open` (`ON`). Magnet present: `closed` (`OFF`), confirmed over MQTT across two remove/apply cycles. The uninverted configuration from D10 is correct. (An inversion tried earlier from a mis-remembered observation was reverted.) The sub-one-second latency of task 6.7 is not yet timed.
- **OTA over the access point works (task 5.5).** From a Mac joined to `garage-node` (DHCP 192.168.4.100): `esphome upload --device 192.168.4.1` completes in ~9 s; the browser interface at `http://192.168.4.1` accepts the `admin` login (HTTP 200, 401 without). macOS needs "Local Network" permission for the terminal, otherwise every connection fails with "No route to host".
- **Bad-flash recovery (task 5.7) happens by bootloader rollback, not safe mode.** A build that calls `abort()` on every boot was pushed over the AP. After one crash the ESP-IDF bootloader started the previous application image (partition at 0x3d0000) by itself; AP and OTA came back within seconds, with no cable. The ESPHome safe-mode counter was not what recovered it. A failure that neither crashes nor boots (e.g. a hang) still depends on the safe-mode attempt counter and was not exercised.
- **Every serial read resets the board** (RTS), which also raises the safe-mode counter; avoid opening the console on the installed garage node.
- **PRG wake (task 8.4).** Burn-in mitigation: display is dark in every other 5-minute slot of uptime and content shifts 0-3 px per minute; the PRG button keeps it on for 30 s. Ten of ten button presses on the base node reached the handler (logged over serial) and the display "went on" per the operator. The blank slots are half of all time, so an unlit display is normal, not a fault: press PRG. The garage node carries the same log line in `garage.yaml` but still runs the build without it (log-only difference, flash at the next garage update).
- **Event latency (task 6.7).** Measured with host-timestamped serial logs of both boards: from the garage node publishing a door change to the base receiving it takes ~0.10 s (three consecutive changes, 36-byte packets), plus the 50 ms debounce. A change does not wait for the 20 s heartbeat.
- **Replay rejected (task 9.5).** A real 56-byte frame (rolling code 0x2A:0x22) was captured with a raw-`sx126x` sniffer on the base board, then re-sent verbatim from the garage board every 100 s while it ran normally. The base logged `Rolling code for garage-node 0000002A:00000022 is old` for both replays and the door state on the broker did not change. (The sniffer and replayer builds were temporary and are not in the repository.)
