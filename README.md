# VoltDeck
A full-screen battery, telemetry and power dashboard for FrSky ETHOS 1.6.6 and 26.1.2.

**VoltDeck 2026.10-v4: latest release. Physical X20RS/model testing
passed on ETHOS 26.1.2.**

[Download VoltDeck-2026.10-v4.zip](https://github.com/bliatun-code/VoltDeck/releases/download/voltdeck-2026.10-v4/VoltDeck-2026.10-v4.zip) | [Release notes](https://github.com/bliatun-code/VoltDeck/releases/tag/voltdeck-2026.10-v4)

![VoltDeck: RPM and electrical power](docs/images/rpm-watts-lcd.png)

The screenshots use illustrative values.

[Illustrated configuration guide](docs/Configuration.md) |
[Norsk veiledning](docs/Konfigurasjon-norsk.md) |
[Installation and usage](docs/VoltDeck.md) |
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

## Highlights

- Active model name and optional reuse of its selected model picture.
- Radio theme, black or user-selected background and accent colors.
- Remaining battery from consumed mAh; optional percent source or voltage estimate.
- Green / yellow / orange / red battery thresholds and configurable low-battery WAV.
- Measured RPM, a labelled KV estimate, Watts, average cell voltage or custom telemetry.
- Numeric and retro LCD presentation; one, two or three supported metrics.
- Optional per-model flight counter, session peaks and last-flight RF graphs.
- Optional automatic flight-log opening after sustained pack-voltage loss.
- Source-named RSSI/VFR readings, correct inactive units and per-slot visual profiles.
- Uses native ETHOS fonts and your selected model picture.

## Install VoltDeck

1. Download [VoltDeck-2026.10-v4.zip](https://github.com/bliatun-code/VoltDeck/releases/download/voltdeck-2026.10-v4/VoltDeck-2026.10-v4.zip) from the release assets, not GitHub's automatically generated source archive.
2. Extract its `scripts/VoltDeck` folder onto the radio SD card so the final path is `scripts/VoltDeck/main.lua`.
3. Remove any existing `scripts/VoltDeck/main.luac`, then restart ETHOS.
4. Create a full-screen widget area and select **VoltDeck**.
5. Configure the sensors and battery capacity for that particular model.

The ZIP includes installation instructions, license and notices. Keep a backup
of your model and widget settings when updating.

## Pack sessions and last flight

Motor disarming pauses qualification/flight time but retains the same pack
session, its statistics and RF history. Rearming does not count another flight.
Only continuous loss of valid positive pack voltage for **Pack loss delay**
ends the session (default 10 s; adjustable 3-120 s).

The last qualified log stays visible after disconnecting the aircraft and while
the next flight is qualifying. It is replaced only when that next flight qualifies.
These logs stay in RAM, not across a radio restart. RF graphs include motor pauses;
the flight-time figure only accumulates while all qualification gates pass.
An extended telemetry loss can resemble a disconnected battery; choose a longer
delay, for example 30 s, if needed.

![Last qualified log remains while the next flight qualifies](docs/images/flight-next-qualifying.png)

The previous flight log remains visible while the next flight qualifies.
[See all four transitions](docs/Configuration.md#illustrated-pack-session-transitions).

### Optional automatic flight log

Enable **Auto-open log** under **Flight log** (default Off), then set
**Extra log delay** (default 5 s, range 0-120 s). This additional delay starts
after **Pack loss delay** completes a qualified session. Returning pack voltage
or a manual view/settings change cancels pending navigation.
See the [configuration guide](docs/Configuration.md#automatic-flight-log-view).

## RF names and visual profiles

Names follow the selected source, for example **RSSI 2.4G** or **VFR 900M**.
Dashboard and flight-log sources can differ. Choose a preset for your protocol
or set custom visual limits. Graphs retain brief signal drops and show gaps
when readings are missing.
See the [RF explanation](docs/Configuration.md#11-vfr-graphs-instead-of-rssi).

## Safety and compatibility

Keep native telemetry alarms, failsafe and pre-flight checks enabled.
An armed bench run can still qualify as a flight; use an appropriate airborne
gate when possible. The widget's graph colors do not configure radio alarms.
Check the sources and settings on your own model when using other radio or
firmware combinations.

## License

VoltDeck is available under [MIT](LICENSE). The example artwork has separate
terms described in [NOTICE](NOTICE.md).


## Gasoline models

[GasDeck](https://github.com/bliatun-code/GasDeck) has its own receiver-power, gasoline-engine and fuel dashboard, illustrated guides and independent release cycle.
