# VoltDeck: norsk hurtigguide

[Alle bilder og detaljer](Configuration.md) | [Installasjon](VoltDeck.md)

**VoltDeck 2026.10-v2: siste release. Test på fysisk X20RS med
modell er bestått, bekreftet av eieren 2026-10-05.**

Bildene er fortsatt laget i ETHOS-simulatoren med syntetiske data, ikke fra
en virkelig flyging. Testbekreftelsen gjelder eierens oppsett, ikke alle radioer.

![LCD RPM og Watt](images/rpm-watts-lcd.png)

## Installasjon og grunnoppsett

1. Last ned [VoltDeck-2026.10-v2.zip](https://github.com/bliatun-code/Ethos-Widgets/releases/download/voltdeck-2026.10-v2/VoltDeck-2026.10-v2.zip) fra release-siden.
2. Pakk ut `scripts/VoltDeck` til SD-kortet, slik at filen ligger som `scripts/VoltDeck/main.lua`.
3. Start ETHOS på nytt og velg **VoltDeck** i et fullskjerms widgetfelt.
4. Velg telemetrikildene for akkurat denne modellen.
5. Sett **Battery / Remaining from = Consumed mAh**, korrekt kapasitet og celletall.
6. Nullstill forbruksteller når du kobler til et nytt eller oppladet batteri.

Velg den navngitte widgetpakken, ikke GitHubs automatiske kildekodearkiv.
Ved oppgradering beholder du modellens `.cfg`- og `.dat`-filer. Fjern bare
eventuell gammel `scripts/VoltDeck/main.luac` før omstart, slik at radioen
kompilerer den nye Lua-kilden. ZIP-pakken inneholder ingen bytekode.

Modellnavnet hentes fra valgt modell. **Appearance / Image source =
Selected model** bruker modellbildet som allerede er valgt i radioen.
Et tidligere Batt-widgetfelt må velge VoltDeck og sensorkilder på nytt.

## Velg visning nederst

| Visning | Lower deck / Show | Meter style |
|---|---|---|
| LCD turtall | RPM | Retro LCD |
| LCD turtall + effekt | RPM + Watts | Retro LCD |
| Turtall + effekt + cellevolt | RPM + W + cell | Retro LCD |
| Stor tallverdi | RPM, Watts eller Cell volts | Numeric |
| Valgfri sensor | Custom | Numeric eller Retro LCD |

![LCD turtall](images/rpm-lcd.png)

For målt turtall: velg **Motor / RPM / RPM value = Measured RPM**, velg
**RPM source**, og sett **RPM max**, for eksempel 12000. Dette er
skalagrensen, ikke et løfte om motorens maksturtall.

For RPM + Watt: sett **Watt max**, for eksempel 1600 W. Effekten beregnes
fra pakkespenning ganger strøm. 22,8 V ganger 38,6 A gir omtrent 880 W.
Dette er elektrisk tilført effekt, ikke mekanisk effekt på propellen.

![Tre samtidige verdier](images/rpm-watts-cell-lcd.png)

Cellevolt er pakkespenning delt på antall celler. Gjennomsnittet kan skjule
en svak enkeltcelle og erstatter ikke måling av hver celle.

## Uten RPM-sensor

Velg **RPM value = KV x volts (est.)**, oppgi motorens KV og velg gjerne
**RPM scale = Full-pack KV**. Skalaen blir fast ut fra fulladet pakke,
mens visningen følger aktuell spenning og eventuell voltage sag.

![Estimert turtall](images/kv-estimate-lcd.png)

Eksemplet bruker 420 KV og en illustrativ faktor på 85%. Dette er ikke
en anbefalt standardkorreksjon for propellbelastning. Bruk egne målinger,
eller behold 100% for teoretisk friløpspotensial. Verdien er merket
**RPM ESTIMATE** og må ikke forveksles med målt turtall.

## Batteri, bakgrunn og lyd

Med 2500 mAh kapasitet og 650 mAh forbrukt blir gjenstående kapasitet
1850 mAh, altså 74%. Batteriet blir gult ved 40%, oransje ved 35% og rødt
ved 30% eller lavere. Over 40% er det grønt.

![Lavt batteri, 30 prosent](images/battery-red-30.png)

Velg **Appearance / Background = Radio theme**, **Black** eller **Custom**.
Med Custom kan du velge bakgrunnsfarge og aksentfarge. Tomt fontfelt bruker
radioens innebygde fonter.

Under **Battery alert** velger du lydfil og repetisjonsintervall.
Sett lydmappe først, åpne innstillingene igjen, og velg **Alert WAV**.
Filen må være PCM WAV, 32 kHz, mono, 16-bit. Ugyldig eller manglende fil
gir tone i stedet. Alarmen utløses ved 30% eller lavere, men er deaktivert
i forhåndsvisning og i bildenes private demokjøring.

## Valgfri telemetri

![Valgfri ESC-temperatur](images/custom-temperature-lcd.png)

Velg **Show = Custom**, velg sensoren og sett en passende min/max-skala.
Her vises syntetisk ESC-temperatur på 54 C med 0-100 som skala.
Enheten kommer fra sensoren; widgeten oppretter ikke nye sensorer i modellen.

## Flylogg og RF-grafer

![Flylogg med syntetiske VFR-data](images/flight-log-vfr.png)

Åpne **Flight log** i widgetmenyen. Eksemplet viser 5:18, 10350 rpm maks,
64,8 A maks og 20,8-25,2 V. **42 flights er et eksempel, ikke en ekte teller.**

For faktisk logging: velg arm-betingelse og throttle-kilde. Standardfiltrene
er minst 60 sekunder og minst 50% throttle i til sammen 5 sekunder.
Still **Throttle low (raw) / high (raw)** etter verdiene Lua faktisk leser,
ikke bare prosentene i kanalmonitoren. Kilden kan bruke -1024/+1024,
-100/+100 eller 0/100; bruk endepunktene for akkurat den kilden. En passende **Airborne gate**
kan gi bedre filtrering, men en lang benktest kan likevel bli telt.

### En økt per batteritilkobling

Motor-ARM er et sikkerhets-/kvalifiseringsvilkår, ikke en nullstilling av økten.
Dearming ved inspeksjon eller touch-and-go pauser opptjent flytid og tid over
gassgrensen. Når samme pakke armeres igjen, fortsetter samme logg og telling;
en økt kan bare øke telleren én gang. Airborne gate av pauser også, uten sletting.

Økten avsluttes først når gyldig, positiv pakkespenning mangler sammenhengende
i **Pack loss delay**: standard 10 sekunder, valgbart fra 3 til 120 sekunder.
Det tidligere **End delay** beholder sin lagrede verdi, men får nytt navn og
gjelder nå bare spenningsbortfall. Kortere bortfall nullstiller ikke økten.
Vanlig spenningsfall under belastning, med fortsatt positiv verdi, avslutter
ikke økten. Langt RF-/telemetribortfall kan ligne frakoblet batteri; velg gjerne
30 sekunder ved behov. Et batteribytte kortere enn forsinkelsen kan bli oversett.

Siste kvalifiserte flylogg vises fortsatt etter at flyet slås av, og mens neste
flyging kvalifiseres. **LAST FLIGHT LOG** betyr at statistikken og grafene tilhører
forrige kvalifiserte flyging. Først når den nye flygingen kvalifiserer, erstattes
loggen. En kandidat som ikke kvalifiserer, sletter ikke forrige logg.
Omstart av radioen kan fortsatt tømme loggene; bare telleren er permanent.

RF-grafens tidsakse inkluderer motorpausene, mens flytiden bare øker når
arm-, gate- og telemetrivillkårene passerer. For å nullstille telleren må logging
være aktivert, motoren dearmert og pakkeøkten avsluttet etter frakobling.
Widgeten endrer ikke motorstyring, failsafe eller radioens sikkerhetsfunksjoner.

### Automatisk flylogg

Under **Flight log** kan **Auto-open log** slås på (standard Av).
**Extra log delay** er ekstra ventetid etter **Pack loss delay**:
standard 5 s, valgbart 0-120 s. Med 10 s + 5 s åpnes flyloggen omtrent
15 sekunder etter sammenhengende bortfall av gyldig batterispenning.
Med 0 s ekstra åpnes den idet den kvalifiserte økten avsluttes.

Bare en nylig avsluttet, kvalifisert flyging utløser dette. Manglende
telemetri ved oppstart, korte bortfall og ukvalifiserte benktester gjør det ikke.
Gyldig batterispenning tilbake, modellbytte, avslått logging/automatikk,
forhåndsvisning, åpning av konfigurering eller manuelt visningsvalg avbryter
ventingen. Overgangen skjer én gang; Dashboard åpner ikke samme logg på nytt.
Det er visningen inne i VoltDeck som byttes, ikke radioens aktive hovedside.

Funksjonen er med i release 2026.10-v2. Eieren bekreftet automatisk
flylogg på fysisk radio 2026-10-04 og hele oppdateringen, inkludert
rettelsen for opprydding uten widget-instans, 2026-10-05. Alle 53
regresjonstilfeller og 25 tester i ETHOS-simulatoren bestod; simulatorens
testserie bestod også etter omstart.

### Bilder av overgangene

Bildene nedenfor er tatt i ETHOS under en syntetisk overgangstest.
Testtelleren ligger bare i RAM; tallene 1 og 2 er ikke ekte flyginger.

| Motor dearmert, samme batteri | Batteriet frakoblet lenge nok |
|---|---|
| ![Motorpause beholder samme flyging](images/flight-paused.png) | ![Siste logg beholdes etter frakobling](images/flight-last-retained.png) |
| Teller 1 og statistikken beholdes. | LAST FLIGHT LOG viser fortsatt forrige logg. |

| Neste flyging kvalifiseres | Neste flyging har kvalifisert |
|---|---|
| ![Forrige logg under ny kvalifisering](images/flight-next-qualifying.png) | ![Ny kvalifisert flyging erstatter forrige](images/flight-next-qualified.png) |
| Forrige logg vises, og telleren er fortsatt 1. | Telleren blir 2, og først nå erstattes loggen. |

Testen omfattet også avbrutt neste kandidat, kort spenningsbortfall,
positiv voltage sag og pause fra airborne gate. Ingen av disse slettet
forrige kvalifiserte logg eller telte samme batteri på nytt. Simulatorprøven
bruker syntetiske innganger og erstatter ikke testing på fysisk radio.

### RF-kilder, enheter og signalprofiler

Navnet kommer fra valgt kilde, for eksempel **RSSI 2.4G**, **VFR 900M**
eller **Rx VFR**. En inaktiv RSSI-kilde beholder dB, og en inaktiv VFR-kilde
beholder %. Hovedskjermen og flyloggen kan velge forskjellige kilder.
Frekvensnavnet brukes ikke til å gjette protokoll.

![Inaktive RF-kilder beholder riktige enheter](images/rf-inactive-units.png)

Dette utsnittet bruker syntetiske, inaktive kilder: RSSI 2.4G beholder dB,
og VFR 900M beholder %. Strekene betyr manglende data, ikke null signal.

Under **RF signals** velger du profil separat for RF1 og RF2:

| Profil | RSSI gul / rød | VFR gul / rød |
|---|---|---|
| ACCESS / TD / TW | <=35 / <=32 dB | <=95 / <=50% |
| ACCST | <=45 / <=42 dB | <=95 / <=50% |
| Custom | Egne grenser for hver RF-plass | Egne grenser for hver RF-plass |

VFR-skalaen er alltid 0-100%; RSSI har en justerbar dB-skala.
95% er widgetens tidlige, visuelle kvalitetsmarkering, ikke FrSkys
standardalarm. FrSky oppgir lav VFR ved 50%, men ikke en egen kritisk
VFR-grense. Fargene endrer aldri radioens egne alarmer.

VFR sier hvor stor andel rammer som er gyldige og er vanligvis et bedre
mål på kontrollforbindelsen enn RSSI alene. RSSI er fortsatt nyttig for
mottatt signalstyrke. **Rx VFR**, når tilgjengelig, kombinerer gyldige
rammer fra båndene og er nyttig som samlet kvalitetsmål. Ett svakt bånd
betyr ikke nødvendigvis at samlet forbindelse er like svak.
Kilde: [FrSkys telemetriveiledning](https://ethos-doc.frsky-rc.com/model-setup/telemetry/).

Eksisterende grenser beholdes som **Custom**, også eldre 95/90.
Velg en profil selv hvis du ønsker nye grenser. Endrer du en grenseverdi,
velges Custom automatisk for den RF-plassen. En flyging beholder grafkildene,
navnene og enhetene som var valgt ved start; senere kildevalg blandes
ikke inn i samme kurve.

### Diagnose flytelling

Velg **Flight diagnostics** i widgetmenyen. Visningen viser faktisk
throttle-råverdi, beregnet gass (0-100%), kalibreringsområdet, arm-betingelse,
valgfri airborne gate og gyldig pakkespenning. **Qualifying time** og
**High throttle time** viser opptjente sekunder mot kravene. Statuslinjen
viser også pauset økt, sekunder med sammenhengende pakkebortfall og at
siste logg er beholdt etter avsluttet økt.

Et uvalgt arm-signal blokkerer logging. **Airborne gate = ---** slipper
igjennom, også når ETHOS returnerer et kildeobjekt for valget.
**Always on** slipper også igjennom. En valgt bryter eller logisk betingelse
må være aktiv. Ingen av valgene omgår arm-, spennings-, tids- eller gasskravene. Diagnosen kan åpnes med logging deaktivert og endrer ikke kilder,
innstillinger eller sikkerhetsfunksjoner. Midtstilling tilsvarer 50% gass
selv om kanalmonitoren viser 0%. Hold motoren sikkert deaktivert ved
kontroll av endepunkter, og slå av logging under benktester som ikke skal telles.

![Valgfri airborne gate slipper gjennom](images/flight-diagnostics.png)

![Always on slipper gjennom](images/flight-diagnostics-always-on.png)

Diagnosebildene bruker syntetisk pakkespenning, arm og gass;
gate-valgene kommer fra ETHOS selv. Bildene viser ikke en ekte flyging.

Velg RSSI-kilder for dB-grafer eller VFR-kilder for prosentgrafer.
Gul/rød grafmerking er visuelle grenser, ikke radioens telemetrialarmer.
Brudd i grafen betyr manglende data. Bare telleren lagres permanent;
siste flygings statistikk og grafer ligger i RAM.

RF-tegningen er begrenset: opptil 180 historikkpunkter blir til maksimalt
48 minimumsbevarende tidsfelt per kanal. Korte signalfall beholdes, og
manglende data bryter kurven. Beregningen fordeles over flere oppdateringer;
selve tegningen bruker ferdige koordinater. Grafen kan ligge noen sekunder
etter sanntid. De nye RF-bildene bruker 180 syntetiske inngangspunkter.
Radiotest av 2026.8-v2 er nå bekreftet bestått av eieren. Bildene er
simulator-eksempler; andre radioer, firmwareversjoner og modelloppsett må testes separat.

## Modellbilder og sikkerhet

Eksempelbildet er 290 x 191 piksler. Bruk vanlig 8-bit RGB/RGBA PNG.
480 x 272 og 480 x 320 kan brukes, men tar mer dekodet bildeminne uten
større bildefelt i widgeten. 800 x 480 er over widgetens pikselgrense.

Modellinnstillinger og sensorkilder er modellspesifikke. Ta privat backup
av modellfil, begge innstillingsfiler og tellerfiler. Ikke bruk en annen
modells lagrede filer som en ferdig konfigurasjon.

Behold radioens egne alarmer, failsafe og sikkerhetskontroller.
Bildene dokumenterer utseendet med syntetiske data. Testen på fysisk X20RS
med modell er bekreftet bestått for 2026.8-v2. Dette er ikke en generell
sikkerhetssertifisering; behold radioens egne alarmer og sjekk eget oppsett.
