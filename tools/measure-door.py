#!/usr/bin/env python3
"""Fahrzeiten des Garagentors messen (Öffnen/Schließen), aus den Reed-Meldungen auf garage/door.

Aufruf:  tools/measure-door.py <mqtt-host>

Öffnen:   Enter drücken, Tor mit Fernbedienung starten, ab dem Moment läuft die Zeit; Enter, sobald das Tor
          ganz oben ist. Der Reed-Kontakt meldet nur den Start der Fahrt (Kontakt verlässt "closed"), das
          Fahrtende ist von Hand zu stoppen.
Schließen: Enter drücken, Tor mit Fernbedienung starten; die Zeit endet automatisch, wenn der Reed-Kontakt
          wieder schließt.
Mehrere Läufe nacheinander möglich, Strg-C beendet und zeigt die Mittelwerte.
"""
import json, subprocess, sys, threading, time, queue

if len(sys.argv) != 2:
    sys.exit(__doc__)

events = queue.Queue()  # (timestamp, "open"|"closed")

def listen():
    p = subprocess.Popen(["mosquitto_sub", "-h", sys.argv[1], "-t", "garage/door"],
                         stdout=subprocess.PIPE, text=True)
    last = None
    for line in p.stdout:
        try:
            state = json.loads(line)["state"]
        except (ValueError, KeyError):
            continue
        if state != last:           # Heartbeats ignorieren
            events.put((time.time(), state))
            last = state

threading.Thread(target=listen, daemon=True).start()
time.sleep(1.5)
current = None
while not events.empty():
    current = events.get()[1]
print("Tor derzeit:", current)

def wait_for(state, timeout=90):
    end = time.time() + timeout
    while time.time() < end:
        try:
            t, s = events.get(timeout=0.2)
        except queue.Empty:
            continue
        if s == state:
            return t
    return None

opens, closes = [], []
try:
    while True:
        want = "closed" if current == "open" else "open"
        if want == "open":
            input("ÖFFNEN: Enter, dann Fernbedienung drücken ... ")
            t0 = wait_for("open")
            if t0 is None:
                print("  kein Öffnen erkannt"); continue
            print("  Tor fährt (Reed meldet offen). Enter, sobald es ganz oben ist ...")
            input()
            opens.append(time.time() - t0)
            print("  Öffnen: %.1f s" % opens[-1])
            current = "open"
        else:
            input("SCHLIESSEN: Enter, dann Fernbedienung drücken ... ")
            t0 = time.time()
            t1 = wait_for("closed")
            if t1 is None:
                print("  kein Schließen erkannt"); continue
            closes.append(t1 - t0)
            print("  Schließen: %.1f s (inkl. Reaktionszeit beim Drücken, ca. 0,5-1 s)" % closes[-1])
            current = "closed"
except (KeyboardInterrupt, EOFError):
    print()
    for name, v in (("Öffnen", opens), ("Schließen", closes)):
        if v:
            print("%s: %s, Mittel %.1f s" % (name, ", ".join("%.1f" % x for x in v), sum(v) / len(v)))
