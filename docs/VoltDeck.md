# VoltDeck

## Features

- Full-screen dashboard with radio-theme, black or custom background.
- Active model name and optional reuse of the selected model image.
- Pack voltage, current, consumed or remaining mAh, and remaining percent.
- Battery colors: green above 40%, yellow at 40% or lower, orange at 35%
  or lower, and red at 30% or lower.
- Low-battery alert at 30% or lower with a selectable WAV and repeat interval.
- Receiver signal and voltage readings, transmitter battery and a timer.
- Configurable lower deck: a custom source, RPM, electrical input power,
  average cell voltage, or supported combinations.
- Numeric or retro LCD meter presentation.
- Measured RPM or a clearly labelled KV-and-voltage estimate.
- Optional per-model flight counter and bounded RF history.
- Source-named RSSI/VFR readings and independent visual signal profiles.

VoltDeck 2026.10-v2 is the latest release. The owner confirmed that
physical X20RS/model testing passed on 2026-10-05. The readable Lua source
remains available under MIT; other equipment and firmware need their own tests.

See the [illustrated configuration guide](Configuration.md) or the
[Norwegian guide](Konfigurasjon-norsk.md) for settings and synthetic examples.

## Installation

Download [VoltDeck-2026.10-v2.zip](https://github.com/bliatun-code/VoltDeck/releases/download/voltdeck-2026.10-v2/VoltDeck-2026.10-v2.zip) from the
[release assets](https://github.com/bliatun-code/VoltDeck/releases/tag/voltdeck-2026.10-v2). Use the named widget package,
not the automatically generated repository source archive. Extract its
`scripts/VoltDeck` folder onto the SD card, preserving this structure:

```text
scripts/
  VoltDeck/
    main.lua
```

Keep existing per-model `.cfg` and `.dat` files when upgrading. If an older
`scripts/VoltDeck/main.luac` remains, remove only that generated file before
restarting ETHOS so the radio compiles the installed source. No compiled
bytecode is shipped.

Create a full-screen widget area in ETHOS and select VoltDeck.
The folder and displayed name are VoltDeck. The internal key is vdeck:
ETHOS limits widget keys to seven characters, so VoltDeck is too long there.
When upgrading from the experimental Batt-key build, select VoltDeck again
in the widget area and reselect its telemetry sources. Per-model scalar
settings retain their existing file identity.

Select telemetry sources in the widget configuration. No model-specific
sensor configuration or model BIN is distributed with the widget.
The public package does not include the development simulator's test task
or packet-feeding macros.

## Remaining battery

Use consumed mAh and enter the actual battery capacity:

```text
remaining percent = 100 * (capacity - consumed mAh) / capacity
```

The displayed result is limited to 0 through 100 percent.
Reset the consumption counter when connecting a new or recharged battery.
An incorrect pack capacity or a counter left over from a previous pack
makes this percentage incorrect.

A percent telemetry source or an approximate voltage estimate can be
selected instead. Voltage under load is not a direct measurement of
remaining battery charge. Missing readings are shown as dashes.

## RPM, power and cell voltage

Measured RPM requires an appropriate telemetry source.
KV multiplied by live pack voltage is a speed potential estimate, not
measured shaft RPM. Propeller load and other losses are not automatically
known; any correction factor must come from measurements.

Electrical input power is pack voltage multiplied by current.
Average cell voltage is pack voltage divided by the configured cell count;
it cannot identify an individual weak cell.

## Model settings and backups

Scalar settings are stored in a pair of checked per-model files beneath
scripts, with names of the form vc<model-id>a.cfg and vc<model-id>b.cfg.
Sensor selections stay in the native model/widget record.
The flight counter, when enabled, uses separate per-model persistent state.
Last-flight graphs stay in RAM.

Keep the native model file and both settings files together in a private
backup. Keep flight-counter state too if retaining the count is important.
Actual model state and private counters are not committed to the public
repository. Configuration recipes in the guide are generic reference examples.

Configuration follows the model's file identity, not just its display name.
Renaming, copying or exporting a model needs care to retain the intended
settings.

## Model image

Runtime images are chosen by the user; none are required by the widget.
The documentation includes an owner-supplied Ultimate AMR example, separate
from the installable Lua script. See NOTICE.md for its licensing status.
290 x 191 pixels is the widget's preferred image size. The aspect ratio is
preserved; oversized images are rejected to protect the bitmap budget.
A compressed PNG's on-disk size does not equal its decoded RAM use.

## Flight log limitations

Flight detection uses configured arm/throttle conditions, a minimum
duration and a high-throttle interval. An optional airborne gate can improve
filtering. A long armed bench test can still qualify without a suitable gate.

One connected-pack session can count at most once. Motor disarming or disabling
the airborne gate pauses qualification/flight time, without clearing the count
latch, statistics or RF history. Valid pack voltage returning before the loss
delay resumes that same session. Only continuous missing/invalid/non-positive
pack voltage for **Pack loss delay** ends it (default 10 s, configurable 3-120 s).
The old End delay storage key and saved value are retained for compatibility;
the setting no longer terminates a session on motor disarm.

An extended telemetry loss can look like a battery disconnect, and a swap shorter
than the configured delay cannot reliably be detected. Increase the delay, for
example to 30 s, where needed. Detection requires logging callbacks to keep running;
battery changes while logging is disabled or the radio is off are not observed.

The last qualified log remains visible after aircraft power-off and while a new
candidate qualifies. The new candidate replaces it only on successful qualification.
At most one previous qualified record and one active candidate are retained, each
with at most 180 RF points per channel. No per-flight files are added. Qualification
and flight time exclude motor/gate/invalid-voltage pauses; graph elapsed time includes
them. Radio restart clears these RAM-only statistics and graphs.

The synthetic native simulator exercise passed all 11 transition stages,
including real ETHOS none/always-on gate objects. Focused Lua regression
cases also covered repeated ARM changes, failed candidates, bounded history
and a mocked restart. The native test counter was RAM-only: this does not
verify physical SD-card writes, actual RF loss or physical-radio flight behavior.

RF graph colors are visual thresholds, not changes to the radio's alarms.

RF rendering is bounded: up to 180 history points are reduced to at most
48 minimum-preserving time bins per channel. Missing data breaks the trace;
no averaging hides brief lows. Geometry is prepared over several wakeups,
then paint draws cached primitives. Live traces can lag by a few seconds.
The updated RF examples use 180 synthetic input points. The owner separately
confirmed that physical X20RS/model testing of 2026.10-v2 passed on 2026-10-05.
Other hardware, firmware and model setups still need their own checks.

### Automatic flight-log view

In **Flight log**, enable **Auto-open log** (default Off) and set **Extra log
delay** (default 5 s, range 0-120 s). This is additional time after **Pack loss
delay**, not a replacement for it. With 10 s + 5 s, the log opens about 15 s
after continuous loss of valid pack voltage. Zero extra delay opens it when
the qualified session ends.

Only a newly completed qualified flight triggers the change. Missing telemetry
at startup, short outages and rejected bench candidates do not. Returning valid
pack voltage, changing model, disabling logging/auto-open, preview, opening
configuration or manually choosing a view cancels a pending change. It happens
once per completed flight; returning to Dashboard will not reopen the same log.
This changes the view inside VoltDeck, not the radio's active main page.

This feature is included in the 2026.10-v2 release. The owner confirmed
automatic opening on the physical radio on 2026-10-04 and the complete
2026.10-v2 update, including the cleanup correction, on 2026-10-05.
53 focused regression cases and 25 native ETHOS simulator cases passed;
the native suite also passed after restarting the simulator.

## RF sources and profiles

The selected source's name and canonical unit remain visible without a live
reading. RF accepts only dB and %. Flight graphs may use separate sources
and pin source/name/unit at flight start. Frequency labels do not identify
the protocol.

RF signals profiles: ACCESS/TD/TW uses RSSI 35/32 dB; ACCST uses 45/42 dB;
Custom uses independent limits per slot. VFR presets use 95% early quality
and 50% low. The 95% marker is a widget visual choice, not a native alarm
default. See [FrSky telemetry documentation](https://ethos-doc.frsky-rc.com/model-setup/telemetry/).

Existing complete, checked settings records are accepted and their limits
migrate to Custom. Source-storage order and counter format are unchanged.
Editing a custom limit selects Custom. Native alarms are untouched.

Airborne gate --- is optional: CATEGORY_NONE is normalized to no source.
CATEGORY_ALWAYS_ON passes unconditionally. Other selected conditions retain
positive/true value semantics. A missing arm condition still blocks logging;
voltage, qualification-time and throttle requirements remain.

## RF work and memory bounds

Each wakeup processes at most 32 history entries or 24 display bins.
Only the visible flight-log view prepares a graph. Two bounded geometry
buffers allow the previous complete trace to remain visible while its
replacement is prepared; closing the log or changing models releases them.
No additional bitmap or per-flight file is created for the graph cache.
The 180-point history, flight minima and persistent counter are unchanged.

This replaces the former full-history scan inside paint, which could hit
the callback instruction limit. Background: [FrSky Lua instruction-limit
report](https://github.com/FrSkyRC/ETHOS-Feedback-Community/issues/4103).

## Lua and compiled bytecode

The public source is main.lua: readable and editable text.
main.luac is compiled Lua bytecode, not encrypted source.
Precompiling may reduce loading/compilation work; it does not inherently
make the widget execute faster or shrink its loaded images.

Bytecode formats can differ between Lua versions and architectures.
Do not use an arbitrary desktop luac build as a radio compiler.
Use the compiler supported by the target ETHOS runtime if distributing
bytecode. Keep generated .luac files out of source control; any compiled
release must identify its compatible ETHOS target.

Lua reference: https://www.lua.org/manual/5.4/luac.html
