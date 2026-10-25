# Garage door sensor: ESPHome LoRa point-to-point

Two Heltec WiFi LoRa 32 V3 boards. The **garage node** reads the reed contact and broadcasts encrypted LoRa; the
**base node** in the house receives it and publishes to MQTT for the [home-new](https://github.com/UlrichFrank/home-new) stack (HomeKit, Telegraf, alerting).

```
Garage node --LoRa 868.2 MHz--> Base node --WiFi/MQTT--> Broker --> home-new
```

## Pinned version

**ESPHome 2026.9.0** for both nodes. They are a matched pair: the `packet_transport` wire format carries no
compatibility guarantee across versions, so always rebuild and reflash both together. Check with `esphome version`.

## Files

| File | Purpose |
|---|---|
| `garage.yaml` | Garage node: reed on GPIO4, WiFi access point only, no API/MQTT |
| `base.yaml` | Base node: LoRa consumer, MQTT, link health |
| `common/heltec-v3.yaml` | Shared board, radio and OLED settings |
| `secrets.sops.yaml` | WiFi/MQTT credentials, LoRa key, AP/OTA passwords, **SOPS/age-encrypted** and committed |
| `secrets.yaml` | Plain copy for ESPHome builds. **Untracked** (see `../.gitignore`), create it with the command below |

## Secrets

All credentials live in `secrets.sops.yaml` (values encrypted with SOPS/age, key names readable). ESPHome only reads a
plain `secrets.yaml`, so decrypt it before building (the age key is in `~/.config/sops/age/keys.txt`):

```bash
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
sops -d secrets.sops.yaml > secrets.yaml      # untracked, never commit
sops secrets.sops.yaml                        # edit the encrypted file in $EDITOR
```

Keys: `wifi_ssid`, `wifi_password`, `mqtt_broker`, `mqtt_username`, `mqtt_password`, `lora_key`,
`garage_ap_password`, `garage_ota_password`, `base_ota_password`.

## Flashing

**Rule: flash and verify the base node first.** It can be recovered from the desk; the garage node cannot.

```bash
# first time, over USB (the CP2102 appears as /dev/cu.usbserial-*)
esphome run base.yaml   --device /dev/cu.usbserial-XXXX
esphome run garage.yaml --device /dev/cu.usbserial-YYYY
```

- **Base node, afterwards:** over the network from the desk: `esphome run base.yaml`.
- **Garage node, afterwards:** no WiFi reaches the garage, so go there with a laptop or phone:
  1. Join the WiFi `garage-node` (password: `garage_ap_password` in `secrets.yaml`).
  2. Either `esphome run garage.yaml --device 192.168.4.1` (OTA password: `garage_ota_password`),
     or open `http://192.168.4.1` and upload `firmware.ota.bin` in the browser
     (login `admin` / `garage_ota_password`).

## Recovery from a bad flash (garage node)

`safe_mode` is enabled. After repeated failed boots the node starts with only the access point and OTA, so
the steps above still work and no cable or disassembly is needed. USB (hold PRG, press RST) is the last resort.

## MQTT interface

Broker `mqtt_broker` from the secrets. The topic tree follows the home-new convention (own root `garage`, flat topics, JSON
payloads, retained). There is **no Home Assistant discovery** and no per-entity topic: every entity in `base.yaml`
is `internal` and the topics below are published explicitly. The only command topic is `garage/debug/set` (log level, below).

| Topic | Payload | Published |
|---|---|---|
| `garage/door` | `{"state":"open"\|"closed"}` | On change and with every node report |
| `garage/link` | `{"up":true,"rssi":-30,"snr":12.8}` | Every received frame and every link change |
| `garage/node` | `{"uptime":3424,"supply_voltage":0.02,"reset_reason":"other"}` | With every garage-node report (~20 s) |
| `garage/status` | `online` / `offline` | Retained birth/will of the base node |

`supply_voltage` is the battery input only, ~0 V without a LiPo. `reset_reason` is `power-on`, `software`,
`brownout`, `watchdog`, `deep-sleep` or `other`. The link is lost when `garage/link.up` is `false`; `garage/door` then
keeps its last value, so consumers should look at `garage/link` or at the age of `garage/node`.

### Logs over MQTT

Off by default (the node runs at `WARN`, also on UART). Switch it on and off at runtime:

```bash
mosquitto_pub -h <broker> -u … -P … -t garage/debug/set -m debug   # or: info
mosquitto_sub -h <broker> -u … -P … -t garage/debug -v            # the log lines (not retained)
mosquitto_pub -h <broker> -u … -P … -t garage/debug/set -m warn    # back to quiet
```

The command is not retained; after a reboot the node is quiet again. This is the only command topic.

Retained leftovers from the old layout (`garage-door/#`) can be cleared with an empty retained publish per topic.

## Radio parameters

868.2 MHz, SF7, BW 125 kHz, CR 4/5, sync word `0x14 0x24`, CRC on, 0 dBm, full broadcast every 20 s,
changes sent immediately. XXTEA key from `lora_key`, rolling code and ping-pong enabled. Raise `pa_power` only if
the installed link margin demands it, never above 14 dBm.

## Troubleshooting

- **Radio initialises but nothing is sent:** check `tcxo_voltage: 1_8V`, `tcxo_delay: 5ms`, `rf_switch: true`.
- **No log output over USB:** the logger must use `hardware_uart: UART0` on this board.
- **OLED stays dark ("Found no devices" on I2C):** Vext (GPIO36, active low) and the OLED reset (GPIO21) must be
  driven before the I2C bus is set up; see the priority-1100 `on_boot` in both configs.
- **Garage node reboot loops:** it must have no WiFi station network, no `api:` and no `mqtt:`.
