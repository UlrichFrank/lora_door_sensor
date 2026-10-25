# Garage door sensor

Reed contact in the garage, reported to the house over a private, encrypted LoRa link, published as MQTT for the
[home-new](https://github.com/UlrichFrank/home-new) homeserver (HomeKit, Telegraf, alerting).

```
Garage node --LoRa 868.2 MHz--> Base node --WiFi/MQTT--> Broker --> home-new
(Heltec V3)                     (Heltec V3)
```

- Two Heltec WiFi LoRa 32 V3 boards running ESPHome (`esphome/`), no LoRaWAN gateway or network server.
- Door state, link quality and node health on `garage/door`, `garage/link`, `garage/node`; JSON, retained.
- The OLED on the garage node shows the live contact (`Reed`) next to the last state handed to the radio (`Sent`).
- Credentials are committed SOPS/age-encrypted; see `esphome/README.md`.

Details, pinout, flashing and the MQTT interface: [`esphome/README.md`](esphome/README.md). Design history:
[`openspec/`](openspec/).

## History

Until v1.0.0 this repository held an Arduino sketch (Heltec LoRaWAN node -> ChirpStack -> MQTT). That chain was replaced
by the ESPHome point-to-point link in October 2026; the old sketch is available in the git history before v1.0.0.
