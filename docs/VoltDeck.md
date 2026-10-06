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

See the [illustrated configuration guide](Configuration.md) or the
[Norwegian guide](Konfigurasjon-norsk.md) for settings and illustrated examples.

## Installation

Download [VoltDeck-2026.10-v4.zip](https://github.com/bliatun-code/VoltDeck/releases/download/voltdeck-2026.10-v4/VoltDeck-2026.10-v4.zip) from the
[release assets](https://github.com/bliatun-code/VoltDeck/releases/tag/voltdeck-2026.10-v4). Use the named widget package,
not the automatically generated repository source archive. Extract its
`scripts/VoltDeck` folder onto the SD card, preserving this structure:

```text
scripts/
  VoltDeck/
    main.lua
```

Remove any existing `scripts/VoltDeck/main.luac`, then restart ETHOS.
Create a full-screen widget area and select **VoltDeck**. Select your model's
telemetry sources and enter its battery capacity in the widget configuration.

## Remaining battery

Use consumed mAh and enter the actual battery capacity:

```text
remaining percent = 100 * (capacity - consumed mAh) / capacity
```

The displayed result is limited to 0 through 100 percent.
Reset the consumption counter when connecting a new or recharged battery.
An incorrect pack capacity or a counter left over from a previous pack
makes this percentage incorrect.

If the consumption reading unexpectedly falls, VoltDeck shows remaining
charge as unknown. Check the battery and the reading, exit preview and disarm
the motor. **Accept battery counter...** lets VoltDeck use that reading again;
it does not reset the sensor.

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

Settings and flight counts are saved separately for each model. Keep the model,
widget settings and flight-counter files together in your backup when updating
or moving to another SD card. Last-flight graphs and statistics are cleared
when the radio restarts.

## Model image

Runtime images are chosen by the user; none are required by the widget.
The Ultimate AMR picture is optional example artwork. See [NOTICE](../NOTICE.md)
for its terms of use.
290 x 191 pixels is the widget's preferred image size. The aspect ratio is
preserved. Large image dimensions can use too much radio memory even when
the PNG file is small.

## Flight log limitations

Flight detection uses configured arm/throttle conditions, a minimum
duration and a high-throttle interval. An optional airborne gate can improve
filtering. A long armed bench test can still qualify without a suitable gate.

One connected-pack session can count at most once. Motor disarming or disabling
the airborne gate pauses qualification/flight time, without clearing the count
latch, statistics or RF history. Valid pack voltage returning before the loss
delay resumes that same session. Only continuous missing/invalid/non-positive
pack voltage for **Pack loss delay** ends it (default 10 s, configurable 3-120 s).

An extended telemetry loss can look like a battery disconnect, and a swap shorter
than the configured delay cannot reliably be detected. Increase the delay, for
example to 30 s, where needed. Logging must remain enabled to detect pack changes;
battery changes while logging is disabled or the radio is off are not observed.

The last qualified log remains visible after aircraft power-off and while a new
candidate qualifies. The new candidate replaces it only on successful qualification.
Qualification and flight time exclude pauses caused by disarming, a closed
airborne gate or missing pack voltage; graph elapsed time includes them.
Radio restart clears these statistics and graphs.

RF graph colors are visual thresholds, not changes to the radio's alarms.

Graphs retain brief signal drops and show gaps when readings are missing.
Live traces can take a few seconds to update.

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

## RF sources and profiles

The selected source's name and unit remain visible without a live
reading. RF accepts only dB and %. Flight graphs may use separate sources
and pin source/name/unit at flight start. Frequency labels do not identify
the protocol.

RF signal profiles: ACCESS/TD/TW uses RSSI 35/32 dB; ACCST uses 45/42 dB;
Custom uses independent limits per slot. VFR presets use 95% early quality
and 50% low. The 95% marker is a widget visual choice, not a native alarm
default. See [FrSky telemetry documentation](https://ethos-doc.frsky-rc.com/model-setup/telemetry/).

Editing a custom limit selects Custom. Native alarms are untouched.

The airborne gate is optional when set to **---**. **Always On** keeps this
gate open. A valid arm condition is still required, together with the configured
voltage, throttle and qualification-time conditions.
