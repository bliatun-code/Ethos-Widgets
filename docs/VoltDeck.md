# VoltDeck

## Current development features

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

The readable development source is available in this repository. A public
release will wait for physical-radio/model testing.

See the [illustrated configuration guide](Configuration.md) or the
[Norwegian guide](Konfigurasjon-norsk.md) for settings and synthetic examples.

## Intended installation

The widget must be installed directly beneath the radio's scripts folder:

```text
scripts/
  VoltDeck/
    main.lua
```

Create a full-screen widget area in ETHOS and select VoltDeck.
The folder and displayed name are VoltDeck. The internal key is vdeck:
ETHOS limits widget keys to seven characters, so VoltDeck is too long there.
When upgrading from the experimental Batt-key build, select VoltDeck again
in the widget area and reselect its telemetry sources. Per-model scalar
settings retain their existing file identity.

Select telemetry sources in the widget configuration. No model-specific
sensor configuration or model BIN is distributed with the widget.
The public package will not include the development simulator's test task
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
RF graph colors are visual thresholds, not changes to the radio's alarms.

RF rendering is bounded: up to 180 history points are reduced to at most
48 minimum-preserving time bins per channel. Missing data breaks the trace;
no averaging hides brief lows. Geometry is prepared over several wakeups,
then paint draws cached primitives. Live traces can lag by a few seconds.
The updated RF examples use 180 synthetic input points. Physical-radio
validation is still required before treating this development build as ready.

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

