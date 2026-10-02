# Ethos Widgets

## VoltDeck
A full-screen battery, telemetry and power dashboard for FrSky ETHOS.

**Development build: 2026.5-v2. Physical X20RS testing is in progress.
No release or flight-ready certification has been published.**

![VoltDeck: RPM and electrical power](docs/images/rpm-watts-lcd.png)

The screen above uses synthetic demonstration values, not a recorded flight.

[Illustrated configuration guide](docs/Configuration.md) |
[Norsk veiledning](docs/Konfigurasjon-norsk.md) |
[Installation and technical notes](docs/VoltDeck.md) |
[Lua source](scripts/VoltDeck/main.lua)

## Choose your lower deck

<table>
<tr>
<td><img src="docs/images/rpm-lcd.png" alt="Retro LCD measured RPM"><br><b>Retro LCD RPM</b><br>Segmented scale and session peak.</td>
<td><img src="docs/images/rpm-watts-lcd.png" alt="Retro LCD RPM and Watts"><br><b>RPM + Watts</b><br>Measured speed beside calculated electrical input power.</td>
</tr>
<tr>
<td><img src="docs/images/rpm-watts-cell-lcd.png" alt="RPM Watts and average cell voltage"><br><b>Three values</b><br>RPM, Watts and average cell voltage.</td>
<td><img src="docs/images/flight-log-vfr.png" alt="Synthetic flight summary and VFR graphs"><br><b>Flight summary</b><br>Peaks, duration and bounded RF history.</td>
</tr>
</table>

All gallery screens are native ETHOS simulator renders with synthetic
readings. The example flight count is illustrative, not a flight-test result.
The Ultimate AMR picture is documentation artwork, not a required widget asset.

## Highlights

- Active model name and optional reuse of its selected model picture.
- Radio theme, black or user-selected background and accent colors.
- Remaining battery from consumed mAh; optional percent source or voltage estimate.
- Green / yellow / orange / red battery thresholds and configurable low-battery WAV.
- Measured RPM, a labelled KV estimate, Watts, average cell voltage or custom telemetry.
- Numeric and retro LCD presentation; one, two or three supported metrics.
- Optional per-model flight counter, session peaks and last-flight RF graphs.
- Readable Lua source. No bundled bytecode, fonts, sounds or runtime artwork.

## Install the development source

1. Download [main.lua](scripts/VoltDeck/main.lua).
2. Put it on the radio SD card as `scripts/VoltDeck/main.lua`.
3. Restart ETHOS, create a full-screen widget area and select **VoltDeck**.
4. Configure the sensors and battery capacity for that particular model.

Do not rename `main.lua` and do not install the private simulator helpers.
Upgrading from the experimental Batt-key build requires selecting VoltDeck
again and reselecting its telemetry sources.

## Safety and compatibility

Development target: **FrSky X20RS, ETHOS 26.1.2**.
Other radio/firmware combinations are not yet confirmed.
Keep native telemetry alarms, failsafe and pre-flight checks enabled.
An armed bench run can still qualify as a flight; use an appropriate airborne
gate when possible. The widget's graph colors do not configure radio alarms.

RF rendering is bounded: up to 180 history points are reduced to at most
48 minimum-preserving time bins per channel. Missing data breaks the trace;
no averaging hides brief lows. Geometry is prepared over several wakeups,
then paint draws cached primitives. Live traces can lag by a few seconds.
The updated RF examples use 180 synthetic input points. Physical-radio
validation is still required before treating this development build as ready.

The first release will be prepared only after physical-radio/model testing.

## License and publication boundary

Our Lua implementation is published under [MIT](LICENSE). See [NOTICE](NOTICE.md)
for the separate status of owner-supplied demonstration artwork.

Public files are explicitly selected: Lua source, documentation and curated
example images. Internal notes, test tools, packet feeders, native model files,
live telemetry logs and generated per-model state stay private.

