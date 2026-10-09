# VoltDeck: illustrated configuration guide

[Home](../README.md) | [Installation](VoltDeck.md) | [Norsk](Konfigurasjon-norsk.md)

Select **VoltDeck** in a full-screen widget area, then open **Configure widget**
from the widget menu. Follow the groups below in their radio-menu order.
Settings and source selections belong to the active model.

After a page or model change, the first short press may select the widget and
the next opens its menu. The widget renews ETHOS focus while selected and
visible. Short and long presses still use the radio's standard menus.

Grey fields are inactive for the current method or display. Their saved values
remain available when you change back. Source pickers use ETHOS's normal source
list; check the source type and unit as well as its name.

The setup pictures show the simulator's menu fields. Select the sensors fitted
to your own model; the tables explain what each source must measure.
The dashboard and flight-log examples use illustrative readings.

<table>
<tr>
<td><img src="images/widget-menu.png" alt="VoltDeck widget menu"><br><b>Widget menu</b></td>
<td><img src="images/configuration-overview.png" alt="VoltDeck configuration groups"><br><b>Configure widget</b></td>
</tr>
</table>

## 1. Battery

![Battery settings](images/voltdeck-setup-battery.png)

| Field | What to select |
|---|---|
| Remaining from | **Consumed mAh** uses capacity minus consumption after the pack check below. **% sensor** uses a remaining-charge percentage. **Voltage estimate** estimates charge from pack voltage, battery type and cell count. |
| Battery type | Lipo, LiHV, Li-ion or LiFe, matching the pack. Used by the voltage estimate, cell-meter scale, consumption check, full-pack KV scale and battery label. |
| Capacity | Actual pack capacity in mAh. Also used by **mAh display / Remaining**, even when the main battery percentage comes from another method. |
| Cells | Number of series cells. Used by the battery label, average cell voltage, consumption check, voltage estimate and full-pack KV scale. |
| mAh display | **Consumed** shows the selected consumption reading. **Remaining** shows capacity minus trusted consumption. This separate mAh value still needs **Consumed mAh** telemetry with either of the other percentage methods. |

For a checked 2500 mAh pack with 650 mAh consumed, the capacity calculation gives
1850 mAh remaining and 74%. Configure the consumption sensor's reset for each
new or recharged pack; VoltDeck does not reset that sensor.

**Voltage estimate** is approximate and changes with load and voltage sag.
**% sensor** needs a source that actually supplies remaining charge from 0 to
100%; selecting a voltage source does not convert it to a percentage.

An unexpected consumption-counter decrease makes calculated remaining capacity
unknown. After checking the actual charge and mAh reading, use
**Accept battery counter...** as described under [Widget actions](#widget-actions).
Brief telemetry loss or motor disarming does not accept a reset automatically.

With **% sensor** or **Voltage estimate**, this reset guard still protects the
optional **mAh display / Remaining**. Acceptance requires a valid physical ARM
source OFF, valid consumed mAh and live pack voltage when a voltage source is
selected. It affects remaining mAh only; the main percentage keeps following
the selected method.

If your ESC starts at **0 mAh** each time the model is powered on, that reading
does not include earlier flights on the same pack. For multiple flights without
charging, use an accumulated consumption source that retains those earlier
readings. A calculated ETHOS sensor can be used; check its reset settings and
verify that switching the model off and on preserves its total. Reset it only
for a new or recharged pack.

### Check before showing remaining charge

With **Remaining from = Consumed mAh**, radio start or detected pack loss
shows **CHECKING PACK**, **-- %** and empty battery segments until the readings
are checked. The remaining-mAh display is also unknown during this check;
**Consumed** can still show the sensor's reading. The check applies at every
consumption level, not just when the counter is near zero.

Let the pack settle. VoltDeck needs valid pack
voltage, current and consumed mAh, followed by **10 seconds of stable low-current
readings**. Current must be between zero and **3 × capacity / 20000 A**, capped at
**1.5 A**: the limit is **0.375 A for 2500 mAh** or **0.60 A for 4000 mAh**.
The highest and lowest voltage may differ by at most **0.20 V for the whole
pack**, not per cell. Higher current, missing readings or a wider voltage range
starts the window again. There is no separate waiting period. **Arm switch**
does not gate this pack check; it still controls flight logging.

The check compares the counter's remaining percentage with a coarse voltage
reference for the selected type. It checks possible overestimation against the
window's **lowest voltage** and underestimation against its **highest voltage**.
The larger difference determines the result, measured in **percentage points**.
The dialog rounds the difference up to the next 0.1 point; subtracting its two
rounded percentages can therefore give a result 0.1 point lower.

| Difference | Result |
|---|---|
| 10 percentage points or less | Automatically accepted; the calculated percentage and battery segments appear. |
| More than 10, up to and including 20 points | **CHECK PACK/COUNTER** remains red and remaining charge stays unknown. Check the pack and sensor, then use **Accept battery counter...** to review both percentages and the difference before confirming. |
| More than 20 points | Remaining charge stays unknown. Correct the charge, battery settings or consumption reading; the menu cannot bypass this limit. |

**Accept battery counter...** shows what is holding up the check, including
missing or unsuitable sources, measured current versus its limit, voltage
variation or progress through the 10-second window. A higher counter estimate
warns of possible overestimation; a lower one asks you to check consumption,
capacity and sensor calibration. Confirmation uses the checked voltage range,
so variation within that range does not require an identical frozen reading.
Live telemetry and the battery setup must still be valid when you confirm.

For **LiFe**, voltage cannot provide a dependable percentage comparison.
After the same low-current check, inspect actual charge, capacity and consumed
mAh and confirm through **Accept battery counter...**. There is no calculated
voltage percentage or difference to approve for this type.

Acceptance belongs to that battery connection. During flight, VoltDeck uses
the counter without repeating the voltage comparison, so voltage sag does not
revoke acceptance. A consumption-counter reset still needs explicit acceptance.
Continuous loss of **Pack voltage** for **Pack loss delay**, including loss of
all model telemetry, requires a new check. Radio restart or changes to battery
sources, capacity, cells or type also check again. Returning after an extended
pause in the widget's battery readings can require a new check as well. A
shorter gap preserves acceptance, but missing live voltage or consumption still
shows unknown charge.

This is a plausibility check at stable low load, not a measurement of fully
relaxed charge. Its separate references use [ST's 4.20 V and 4.35 V OCV
tables](https://github.com/st-sw/STC3115GenericDriver/blob/master/Docs/Config/STC3115%20OCV%20curve%20-%20default%20register%20values.pdf)
for Lipo/Li-ion and LiHV respectively. Temperature, age, the individual pack
and residual load affect the result. The **Voltage estimate** display retains
its existing scale, including **3.57 V = 30%** for Lipo; it is not the reference
used by this check.

**CHECK CELLS/TYPE** means the highest voltage in the check exceeds the selected
battery type's full cell voltage by more than 0.15 V/cell. Correct
**Cells**, **Battery type** or the voltage source; counter acceptance cannot
dismiss this warning. Total voltage cannot determine the correct cell count.

Check the pack and sensor before accepting a counter. **Do not accept 0 mAh on a
partly used pack**: restore the correct accumulated reading, fit a charged pack,
or select **Voltage estimate** and allow for its limitations. This check cannot
recover missing consumption or validate an incorrect current source.
**Check that the pack is fully charged before every flight.** Compare reported
consumed mAh with the amount the charger puts back over several flights,
returning to the same charge endpoint. Investigate a consistent difference and
follow the ESC manufacturer's calibration instructions if supported; for example,
[Scorpion Tribunus II provides Current Sensitivity Gain](https://www.scorpionsystem.com/files/download/Tribunus%20II%20Instructions%20-%20220922.pdf).
A passed check does not guarantee a particular reserve at landing.

<table>
<tr>
<td><img src="images/battery-checking.png" alt="Battery qualification in progress"><br><b>Checking pack</b><br>Remaining charge stays unknown during the stable low-load check.</td>
<td><img src="images/battery-manual-confirm.png" alt="Confirmation with a 14 percentage-point difference"><br><b>Manual confirmation</b><br>Read both estimates and the difference before accepting the counter.</td>
</tr>
<tr>
<td><img src="images/battery-counter-check.png" alt="Consumption-counter warning"><br><b>Check pack/counter</b><br>6S Lipo at 22.9 V, 303 mAh and 0 A: remaining charge is unknown.</td>
<td><img src="images/battery-blocked-dialog.png" alt="Difference above 20 percentage points with only a Close button"><br><b>Above 20 percentage points</b><br>This dialog explains the mismatch; it cannot approve it.</td>
</tr>
<tr>
<td colspan="2"><img src="images/battery-cells-check.png" width="400" alt="Cell-count or battery-type warning"><br><b>Check cells/type</b><br>25.2 V with 5S selected: correct the battery setup.</td>
</tr>
</table>

## 2. Appearance

![Appearance settings](images/voltdeck-setup-appearance.png)

| Field | What it changes |
|---|---|
| Background | **Radio theme** follows ETHOS colors; **Black** uses a black background; **Custom** uses your background color. |
| Background color | Active with **Custom**. |
| Accent color | Active with **Black** or **Custom**. **Radio theme** supplies its own accent. |
| Font file | Optional font path. Leave blank for native ETHOS fonts. |
| Image source | **Selected model** reuses the model picture; **Image file** selects a separate picture; **Hidden** removes it. |
| Image file | Active with **Image file**. Choose an image from `/bitmaps/models`. |

Use an ordinary **8-bit RGB or RGBA PNG**. **290 × 191** fits the picture area;
**480 × 272** and **480 × 320** are also supported. Aspect ratio is preserved.
The limit is 160,000 pixels, so **800 × 480** is too large. Indexed/palette and
16-bit-channel PNGs are unsupported. Transparency lets the chosen background
show through.

The example [Ultimate AMR artwork](images/ultimate-amr.png) is 290 × 191;
see [NOTICE](../NOTICE.md) for its terms.

## 3. Battery alert

![Battery alert settings](images/voltdeck-setup-alert.png)

| Field | What it does |
|---|---|
| Battery alert | Enables the widget's low-battery sound at **30% or below**. |
| Alert on estimate | Active when the alert is enabled and **Remaining from = Voltage estimate**. Allows the approximate voltage percentage to trigger audio. |
| Repeat | Minimum time between alerts, in seconds. Active when the alert is enabled. |
| Audio folder | Folder for the sound picker, normally `/audio`. Active when the alert is enabled. Change the folder, then reopen configuration before picking a file. |
| Alert WAV | Active when the alert is enabled. Select a PCM WAV: **32 kHz, mono, 16-bit**. A missing or invalid file uses a tone. |

Repetition waits for the selected sound to finish. Brief recovery or missing
readings do not restart the waiting interval. Preview does not play alerts.
These settings do not change ETHOS's own telemetry alarms.

## 4. Telemetry

![Telemetry sources](images/voltdeck-setup-telemetry.png)

![Remaining telemetry sources](images/voltdeck-setup-telemetry-more.png)

Choose sources from **Telemetry** for measurements, and an ETHOS timer for
**Flight timer**. Similar names can represent different units.

| Field, in menu order | Required measurement and use |
|---|---|
| Pack voltage | Total drive-pack voltage in **V**; **mV** is converted to V. Used by the dashboard, Watts, average cell voltage, voltage/KV estimates and pack-session detection. |
| Current | Drive-pack current in **A**; **mA** is converted to A. Used by the dashboard, calculated Watts, flight maximum current and the initial pack check. |
| Consumed mAh | Accumulated consumption since the pack was charged, in **mAh**; **Ah** is converted to mAh. Used by the mAh display and consumption-based remaining capacity. Remains active with every battery method. |
| RF1 source | RSSI in **dB**, or VFR/link quality in **%**, for the first dashboard slot. |
| RF2 source | RSSI in **dB**, or VFR/link quality in **%**, for the second dashboard slot. |
| Rx1 voltage | First receiver-battery voltage in **V** or **mV**. |
| Rx2 voltage | Second receiver-battery voltage in **V** or **mV**, if fitted. |
| Tx voltage | Transmitter voltage in **V** or **mV**. Leave blank to use the radio's own battery source. |
| Flight timer | An ETHOS timer, reported in seconds. This dashboard timer is separate from the flight log's accumulated qualifying time. |
| Battery % source | Remaining charge in **%**, from 0 to 100. Active only with **Remaining from = % sensor**. |

Prefer sources with the correct ETHOS unit. A raw numeric voltage, current,
consumption or RPM source must already supply V, A, mAh or rpm respectively;
its text label does not rescale the value. For **Battery % source**, a raw source
must explicitly carry a `%` unit label and contain a valid 0–100 value.
RF sources require ETHOS's actual dB or % unit; a raw source's text label is not sufficient.
The initial pack check requires actual ETHOS V/mV and A/mA units. Raw voltage
and current sources remain usable for their ordinary displays but cannot
qualify **Consumed mAh** remaining charge.

Missing or rejected telemetry shows **--**. It does not mean zero consumption
or a full pack. An inactive selected RF source keeps its name and unit; unsupported
RF units are rejected. The radio battery and timer may remain available while
model telemetry is absent.

![Unavailable model telemetry](images/telemetry-unavailable.png)

## 5. RF signals

![RF profile settings](images/voltdeck-setup-rf.png)

![Remaining RF thresholds](images/voltdeck-setup-rf-more.png)

| Field, in menu order | What it controls |
|---|---|
| RF1 profile | **ACCESS / TD / TW**, **ACCST** or **Custom**, for slot 1 and its flight graph. Choose the protocol, rather than relying on the sensor's frequency name. |
| RF2 profile | Same choices for slot 2 and its flight graph. |
| RSSI scale min | Lower end of the RSSI meter/graph, in dB. |
| RSSI scale max | Upper end of the RSSI meter/graph, in dB; must exceed the minimum. VFR always uses 0–100%. |
| RF1 low RSSI | Slot 1's yellow threshold in dB; active with **RF1 profile = Custom**. |
| RF1 critical RSSI | Slot 1's red threshold in dB; active with **Custom**. |
| RF1 early VFR | Slot 1's yellow threshold in %; active with **Custom**. |
| RF1 low VFR | Slot 1's red threshold in %; active with **Custom**. |
| RF2 low RSSI | Slot 2's yellow threshold in dB; active with **RF2 profile = Custom**. |
| RF2 critical RSSI | Slot 2's red threshold in dB; active with **Custom**. |
| RF2 early VFR | Slot 2's yellow threshold in %; active with **Custom**. |
| RF2 low VFR | Slot 2's red threshold in %; active with **Custom**. |

Select **Custom** before editing that slot's limits. Both dB and % limits are
available because the dashboard and graph can use different kinds of RF source.

| Profile | RSSI yellow / red | VFR yellow / red |
|---|---|---|
| ACCESS / TD / TW | ≤35 / ≤32 dB | ≤95 / ≤50% |
| ACCST | ≤45 / ≤42 dB | ≤95 / ≤50% |
| Custom | Your limits for that slot | Your limits for that slot |

These are visual thresholds. They do not configure the radio's alarms;
95% is VoltDeck's early VFR marking, not an ETHOS alarm setting.

## 6. Lower deck

![Lower-deck settings](images/voltdeck-setup-lower-deck.png)

![Remaining lower-deck settings](images/voltdeck-setup-lower-deck-more.png)

| Field | What it controls |
|---|---|
| Show | **Only Custom**, **RPM**, **Watts**, **Cell volts**, **Voltage estimate**, **RPM + Watts**, **RPM + W + cell** or **Hidden**. A selected Custom source adds a row to the chosen display. |
| Meter style | **Numeric** for values, or **Retro LCD** for values with segmented meters. Inactive with **Hidden**. |
| Custom source | Any suitable numeric source, available whenever Show is not **Hidden**. Its unit comes from the source. Choose **---** to remove the additional row. |
| Custom position | Position **1**, **2** or **3** from top to bottom. Active when a Custom source accompanies another display. With fewer rows, a position beyond the last row places Custom last. |
| Custom label | Active when Custom is included. Leave blank to use the source name. |
| Custom min | Lower end of the custom meter; active when Custom is included with **Retro LCD**. |
| Custom max | Upper end of the custom meter; active when Custom is included with **Retro LCD**. Must exceed the minimum. |
| Decimals (-1 auto) | Active when Custom is included. **-1** uses the source's decimals; 0–3 selects a fixed number. |
| Red zone | Start of the red part, as a percentage of the meter range, for **RPM**, **Watts** and **Custom** with **Retro LCD**. Cell volts and Voltage estimate use battery thresholds instead. |
| Watt max | Upper limit in W, active when **Watts** is included in a **Retro LCD** display. |

Watts is calculated from **Pack voltage × Current**, so no separate power sensor
is needed. It is electrical input power. Cell volts is **Pack voltage ÷ Cells**;
this average does not identify a weak individual cell. The lower-deck voltage
estimate can be shown alongside a main battery percentage based on consumption.

### Example: RPM, power and ESC temperature

Set **Show = RPM + Watts**, select your ESC temperature sensor as **Custom
source**, and set **Custom position = 3**. The rows become RPM, Watts and ESC
temperature. The temperature source should report °C; its meter limits can, for
example, be 0–100 °C. These limits only set the display scale, not a temperature
alarm. **Only Custom** shows that source alone.

| Custom position | Row 1 | Row 2 | Row 3 |
|---|---|---|---|
| 1 | Custom | RPM | Watts |
| 2 | RPM | Custom | Watts |
| 3 | RPM | Watts | Custom |

The lower deck has at most three rows. With **RPM + W + cell**, selecting a
Custom source replaces the cell row. Clearing Custom brings the cell row back.
A selected source keeps its row during a telemetry gap and shows an unknown
value until readings return.

![RPM, Watts and Custom temperature](images/rpm-watts-custom-lcd.png)

### Cell-voltage scale and colours

**Cell volts** uses a fixed scale for the selected battery type, rather than
starting at zero. Both its value and filled meter segments follow cell voltage.
Values at or below the low boundary, or above the upper boundary, are red.

| Battery type | Meter scale, V/cell | Low red boundary, V/cell | Upper boundary, V/cell |
|---|---|---|---|
| Lipo | 3.27–4.20 | 3.57 | 4.20 |
| LiHV | 3.37–4.35 | 3.685 | 4.35 |
| Li-ion | 2.97–4.20 | 3.36 | 4.20 |
| LiFe | 2.77–3.65 | 3.055 | 3.65 |

For Lipo, the cell value is orange above 3.57 through 3.615 V, yellow above
3.615 through 3.66 V, and green above 3.66 through 4.20 V. Other types use the
same 30/35/40% boundaries of their existing linear voltage estimate. The main
battery percentage keeps its selected calculation method and rounds to a whole
percent, so its colour can differ from the cell value near a boundary.
Cell colours use the unrounded voltage: a displayed 4.20 V can be slightly
above 4.20 V and therefore red.

These are approximate display thresholds, not a measurement of actual charge.
The Lipo estimate retains **3.57 V = 30%**; load and voltage recovery affect the
reading. LiHV's upper boundary is **4.35 V**, matching
[Tattu's LiHV guidance](https://www.genstattu.com/content/instock/LiHv-Manual.pdf).
Always use the limits printed by your battery manufacturer, including for LiFe.
The displayed average cannot establish whether every individual cell is within
its limits.

![Lipo cell voltage at the low red boundary](images/cell-voltage-lipo-low.png)

![LiHV cell voltage at its full-pack boundary](images/cell-voltage-lihv-full.png)

## 7. Motor / RPM

![Motor and RPM settings](images/voltdeck-setup-rpm.png)

| Field | What it controls |
|---|---|
| RPM source | Actual mechanical speed in **rpm** (ETHOS may display **r/m**). Active for a measured-RPM lower deck or when logging is enabled. The flight log keeps measured RPM even if the dashboard shows an estimate. |
| RPM value | **Measured RPM** or **KV x volts (est.)**. Active when the lower deck includes RPM. |
| Motor KV | Motor rating in rpm/V. Used by a KV estimate, the **Full-pack KV** meter scale, and the flight log's KV-potential field. Logging keeps this field active even without an RPM lower deck. |
| Estimate factor | 10–100%, active for a KV-estimated RPM display. Default 100% shows no-load potential; choose a lower factor only from measurements of your motor/propeller setup. |
| RPM scale | **Manual** or **Full-pack KV**, active for an RPM **Retro LCD** meter. The latter uses battery type, cell count and KV to keep a fixed full-pack scale. |
| RPM max | Manual meter ceiling in rpm. Also available as the fallback when **Full-pack KV** has no valid KV value. Active only for the applicable RPM **Retro LCD** scale. |

KV × live pack voltage estimates electrical speed potential. It does not measure
shaft speed. The dashboard labels it **RPM ESTIMATE**. Its factor is separate
from the flight log's uncorrected **KV potential**.

## 8. Flight log

![Flight-log settings](images/voltdeck-setup-flight.png)

![Flight qualification and session timing](images/voltdeck-setup-flight-more.png)

![RF graphs, reset counter and Preview](images/voltdeck-setup-flight-end.png)

| Field, in menu order | What it does |
|---|---|
| Enable log | Enables qualification and per-model flight counting. |
| Arm switch | Actual motor-arm switch or logic condition. Required for logging. Does not gate the **Consumed mAh** pack check. With **% sensor** or **Voltage estimate**, the optional remaining-mAh counter-reset guard still requires a valid actual ARM OFF indication for acceptance, even when logging is Off. |
| Throttle source | Actual throttle control/channel. Remains active for diagnostics when logging is Off. |
| Airborne gate | Optional switch/logic condition that must be ON to accumulate qualifying time. **---** and **Always on** pass. Remains active for diagnostics. |
| Throttle low (raw) | Raw value at zero throttle, shown in **Flight diagnostics**. Default -1024. |
| Throttle high (raw) | Raw value at full throttle. Default 1024; must exceed the low endpoint. Both endpoints remain active for diagnostics. |
| Flight minimum | Minimum accumulated qualifying time; default 60 s. Active when logging is On. |
| Throttle gate | Normalized throttle threshold; default 50%. Active when logging is On. |
| High throttle | Required accumulated time at/above the throttle gate; default 5 s. Active when logging is On. |
| Pack loss delay | Continuous absence of valid positive **Pack voltage** before a session ends; default 10 s, range 3–120 s. Always active because it also requires a new pack check and permits a new consumption-counter reading after pack loss. |
| Auto-open log | Opens the log after a qualified session ends. Active when logging is On; default Off. |
| Extra log delay | Additional wait after **Pack loss delay**; default 5 s, range 0–120 s. Active when logging and auto-open are both On. |
| RF graph 1 | Optional RSSI **dB** or VFR **%** source for graph 1; blank uses **RF1 source**. Active when logging is On. |
| RF graph 2 | Same for graph 2; blank uses **RF2 source**. Active when logging is On. |
| Reset counter | Active when logging is On. **Reset...** opens a confirmation. Disarm and disconnect the pack long enough to end its session first. Confirmation resets this model's count and clears its retained log. |

Read throttle endpoints from **Flight diagnostics**, rather than the channel
monitor's percentage. Sources may use -1024/+1024, -100/+100 or 0/100.
VoltDeck converts the selected endpoints to 0–100%; mid-stick can therefore be
50% even when the channel monitor shows 0%.

Qualification needs ARM ON, valid throttle and pack voltage, a passing airborne
gate and both time requirements. The high-throttle seconds are cumulative.
An armed bench run can qualify; an airborne condition helps filter it but does
not prove that the aircraft is flying. Disable logging for bench work that
should not count.

### One session per battery connection

Disarming or turning the airborne gate OFF pauses qualifying time. Rearming
the same connected pack resumes its record; it can count only once.
RF history continues through those pauses, while the flight-time figure pauses.

Only continuous pack-voltage loss for **Pack loss delay** completes a session.
Returning voltage before the delay expires resumes it. Positive voltage sag
does not end it. A long telemetry outage can resemble disconnecting the pack;
a swap shorter than the delay can be missed.

The last qualified log remains visible after model shutdown and while a new
flight qualifies. A failed candidate does not replace it. Flight counts are
saved per model; last-flight statistics and graphs clear on radio restart.

### Automatic flight-log view

With **Pack loss delay = 10 s** and **Extra log delay = 5 s**, the log opens
about 15 s after continuous pack-voltage loss. Only a newly completed qualified
session triggers it. Returning voltage, changing model, disabling logging or
auto-open, preview, configuration or a manual view change cancels a pending
switch. It opens once for that flight, inside VoltDeck's current widget area.

### Flight diagnostics

The widget-menu action shows live raw/normalized throttle, endpoints, ARM,
airborne gate, pack voltage and progress toward both time requirements.
Read its status banner together with the individual gates. **LOG DISABLED**
means logging is Off even if the other gates pass. Diagnostics do not change
the radio's safety functions. Keep the motor safely disabled while checking
control endpoints.

![Flight diagnostics with no airborne source selected](images/flight-diagnostics.png)

![Flight diagnostics with Always on selected](images/flight-diagnostics-always-on.png)

## 9. Preview

**Preview** supplies example readings for exploring the layout. It does not
count flights, play alerts or change live consumption guards and peaks.
Turn it Off before checking your model's telemetry or accepting a counter.

Preview retains an accepted pack while real telemetry continues. Actual loss of
pack voltage lasting **Pack loss delay** during Preview requires a new check
when you return to live readings.

## Widget actions

| Menu action | Result |
|---|---|
| Configure widget | Opens the setup groups above. |
| Flight log / Dashboard | Switches between the dashboard and flight log. |
| Flight diagnostics | Opens qualification status and live control readings. |
| Reset live peaks | Clears the dashboard's RPM and Watts session peaks. It does not reset the flight count or the recorded flight's maxima. |
| Accept battery counter... | Shows the status and any remaining blockers for [the pack check](#check-before-showing-remaining-charge) with **Consumed mAh**, or reviews a reset of the optional remaining-mAh counter with another method. Check actual charge and the sensor before confirming. It cannot bypass a difference above 20 points or **CHECK CELLS/TYPE** in the pack check. Acceptance does not restore missing consumption, reset the sensor, fill the battery or change the flight count. |

## Display examples

### RPM, Watts and average cell voltage

<table>
<tr>
<td><img src="images/rpm-lcd.png" alt="Retro LCD measured RPM"><br><b>RPM / Retro LCD</b><br>Measured RPM, Manual scale, RPM max 12000.</td>
<td><img src="images/rpm-watts-lcd.png" alt="RPM and electrical Watts"><br><b>RPM + Watts / Retro LCD</b><br>Watt max 1600 W.</td>
</tr>
<tr>
<td><img src="images/rpm-watts-cell-lcd.png" alt="RPM Watts and average cell voltage"><br><b>RPM + W + cell / Retro LCD</b></td>
<td><img src="images/rpm-numeric.png" alt="Numeric RPM"><br><b>RPM / Numeric</b></td>
</tr>
<tr>
<td><img src="images/watts-lcd.png" alt="Standalone Watts"><br><b>Watts / Retro LCD</b></td>
<td><img src="images/cell-volts-numeric.png" alt="Average cell voltage with a custom background"><br><b>Cell volts / Numeric</b><br>Custom background; mAh display Remaining.</td>
</tr>
</table>

22.8 V × 38.6 A gives about **880 W** electrical input power.
21.8 V ÷ 6 cells gives **3.63 V** average cell voltage.
Missing voltage/current gives dashes rather than invented power.

### Custom telemetry and KV estimate

![Custom temperature meter](images/custom-temperature-lcd.png)

Choose **Custom**, a temperature source, label **ESC TEMPERATURE**, range
0–100 and decimals 0. The source supplies the actual temperature unit.

![KV-based estimated RPM](images/kv-estimate-lcd.png)

This example uses **RPM / Retro LCD**, **KV x volts (est.)**, 420 KV,
an illustrative 85% factor and **Full-pack KV**. At 22.8 V it shows
420 × 22.8 × 0.85 ≈ **8140 rpm**. For 6S Lipo the fixed scale is
420 × 6 × 4.20 = 10584, rounded up to **11000 rpm**.
85% is an example, not a general propeller-load correction.

### Battery colors

| Remaining charge | Color |
|---|---|
| More than 40% | Green |
| More than 35%, up to 40% | Yellow |
| More than 30%, up to 35% | Orange |
| 30% or below | Red |

<table>
<tr>
<td><img src="images/battery-yellow-40.png" alt="40 percent battery"><br><b>40%: yellow</b></td>
<td><img src="images/battery-orange-35.png" alt="35 percent battery"><br><b>35%: orange</b></td>
</tr>
</table>

![30 percent battery and low-battery indication](images/battery-red-30.png)

### VFR graphs instead of RSSI

![Flight log with VFR graphs](images/flight-log-vfr.png)

Dashboard **RF1/RF2 source** can show RSSI in dB while **RF graph 1/2**
shows VFR in %. They are separate measurements. Choose graph sources before
flying: each session retains its initial sources, names and units.
Visual profiles remain adjustable. Missing data leaves gaps; brief low readings
remain visible. The live graph may lag by a few seconds.

![Inactive RF sources retain their names and units](images/rf-inactive-units.png)

![Flight log with RSSI graphs](images/flight-log-rssi.png)

The RSSI example uses **ACCST**, with 45/42 dB visual thresholds.
Its summary separates measured RPM from KV potential and shows flight duration,
maximum current/Watts, pack low/high and the model's flight count.

### Illustrated pack-session transitions

| Motor disarmed, same pack | Pack disconnected past the delay |
|---|---|
| ![Qualified session paused](images/flight-paused.png) | ![Last qualified log retained](images/flight-last-retained.png) |
| Count 1 and the existing record remain. | LAST FLIGHT LOG remains with count 1. |

| Next candidate is qualifying | Next candidate has qualified |
|---|---|
| ![Previous log during new qualification](images/flight-next-qualifying.png) | ![New qualified flight](images/flight-next-qualified.png) |
| Previous record remains; count is still 1. | Count becomes 2; the new record replaces it. |

Before flying, check the selected sources, capacity, cell count, consumption
reset, audio and control gates for this model. Keep backups of the model and
SD-card settings, and retain the radio's own alarms and failsafe.
