# Lilas Robotics – E-Ink Weather Station

ESP32 dev board + diymore 2.9" 296×128 four-colour (black / white / red / yellow) e-paper, 4-wire SPI.

- The board **always broadcasts its own Wi-Fi** `LilasRobotics-XXXX` (password `lilas1234`) with the portal at **http://4.3.2.1**. Phones open it automatically (captive portal).
- From the portal you **scan and join any other Wi-Fi** (up to 3 saved, tried in turn) so the board can fetch weather. The access point stays on.
- The panel shows **Lilas Robotics** branding plus live weather from Open-Meteo (free, no API key): temperature, condition, feels-like, humidity, wind, rain chance and a 3-day forecast.
- **Everything on the panel is configurable** in the portal, with a live preview: brand text, message, 3 layouts, 4 orientations, accent colour, header style, which elements show, 12/24 h, units, location (city search), refresh interval, and even the display pins (validated).

![Dashboard layout](docs/01_dashboard.png)

| Big weather | Brand | Portrait |
|---|---|---|
| ![](docs/04_big.png) | ![](docs/05_brand.png) | ![](docs/07_portrait.png) |

*(These images are rendered by the firmware's own drawing code, so they match the panel pixel for pixel.)*

---

## 1. Wiring

Set the module's interface switch (BS) to **4-line SPI** (you already did). Power the module from **3V3**, not 5V.

| Module pin | Signal | ESP32 GPIO | Why this pin |
|---|---|---|---|
| VCC | 3.3 V | **3V3** | panel logic is 3.3 V |
| GND | ground | **GND** | |
| DIN (SDA) | SPI MOSI | **GPIO23** | native VSPI MOSI (IO_MUX, no GPIO-matrix delay) |
| CLK (SCL) | SPI clock | **GPIO18** | native VSPI SCK |
| CS | chip select | **GPIO27** | general purpose, no boot role |
| DC | data/command | **GPIO25** | general purpose (DAC1 unused) |
| RST | reset | **GPIO26** | general purpose (DAC2 unused) |
| BUSY | busy (input) | **GPIO4** | general purpose, input works with internal pull-up |

GPIO19 (VSPI MISO) is **not** used — the panel is write-only, so it stays free.

### Pin check (what was verified for every pin)

| GPIO | Strapping? | Flash / PSRAM? | UART0? | Output capable? | ADC | Verdict |
|---|---|---|---|---|---|---|
| 18 | no | no | no | yes | – | ✅ VSPI SCK |
| 23 | no | no | no | yes | – | ✅ VSPI MOSI |
| 27 | no | no | no | yes | ADC2_7, T7 | ✅ |
| 25 | no | no | no | yes | ADC2_8, DAC1 | ✅ |
| 26 | no | no | no | yes | ADC2_9, DAC2 | ✅ |
| 4  | **no** (on classic ESP32 the straps are 0, 2, 5, 12, 15) | no | no | yes | ADC2_0, T0 | ✅ |

Design choice: CS/DC/RST/BUSY use **ADC2 pins on purpose** — ADC2 cannot be used for `analogRead()` while Wi-Fi is on, so those pins are worth the least for a Wi-Fi project. That keeps every **ADC1 pin (GPIO32–39)** free for your robot's analog sensors, plus I²C on GPIO21/22.

### Pins deliberately avoided

| GPIO | Reason |
|---|---|
| 0, 2, 5, 12, 15 | **Strapping pins** — sampled at reset. GPIO12 HIGH selects 1.8 V flash (boot loop); GPIO0/2 decide download mode; GPIO5 is the usual e-paper CS in tutorials but is a strap — avoided here. |
| 6–11 | Connected to the **SPI flash** on every ESP32 module. Never use. |
| 16, 17 | **PSRAM** on WROVER modules (and flash on PICO-D4 boards). Avoided so the same wiring works on any dev board. |
| 1, 3 | **UART0** — USB-serial for flashing and the Serial Monitor. |
| 34–39 | **Input-only**, no pull-ups. Fine for BUSY, but can't drive CS/DC/RST/CLK/DIN. Kept free as ADC1 analog inputs. |
| 13, 14 | JTAG (usable, offered with a warning in the portal). GPIO14 toggles during boot. |
| 21, 22 | Default I²C — left for sensors (offered with a warning). |
| 20, 24, 28–31, 37, 38 | Not available on ESP32 modules. |

The firmware enforces these rules: at boot it prints a pin report on Serial, and the **Pins** tab only offers safe GPIOs, flags JTAG/I²C ones, rejects duplicates, and shows the whole ESP32 pin map with each pin's function.

The BOOT button (GPIO0) is only *read* after boot (short press = refresh, hold 6 s = factory reset), which doesn't interfere with its strapping role.

---

## 2. Build and flash (automated)

Plug the board in with a USB data cable and run **one** command. The first run downloads the toolchain (arduino-cli 1.5.1, ESP32 core 3.3.12, GxEPD2, Adafruit GFX, ArduinoJson — pinned versions, ~600 MB, into its own folder so an existing Arduino IDE is not touched); later runs take about a minute.

| System | Command |
|---|---|
| Windows | double-click **`flash.bat`**, or in a terminal: `flash.bat` |
| macOS | double-click **`flash.command`**, or `tools/flash.sh` |
| Linux | `tools/flash.sh` |

It installs what's missing, compiles, finds the board's USB port, flashes, and opens the serial monitor.

### Skip the portal: pre-load Wi-Fi and location

```bash
tools/flash.sh --wifi "My Home Wi-Fi" --pass "secret" --city "Pokhara, Nepal"
flash.bat     --wifi "My Home Wi-Fi" --pass "secret" --city "Pokhara, Nepal"
```

The board then joins your Wi-Fi and shows Pokhara's weather on its first boot, no phone needed. `--city` is looked up on Open-Meteo at build time (the text after the comma picks the right country or region). Other options: `--wifi2/--pass2` (backup network), `--lat/--lon`, `--place`, `--imperial`, `--header`, `--message`, `--ap-password`, `--hostname`, `--refresh`. Run with `--help` for the full list.

To avoid typing them each time, copy `tools/lilas.conf.example` to `tools/lilas.conf` and fill it in (it is git-ignored; on Windows it's also the easy way to use passwords containing `& % ^`).

How it works: the script writes your values into `LilasWeatherEink/provision.h` only for that build and restores the empty file right after (even on Ctrl+C). The firmware applies them once per build; changes you make later in the portal are kept, and a factory reset returns to the pre-loaded values. Because the password is inside such a build, those `build/*-provisioned-*.bin` files shouldn't be shared.

### Other things the script automates

| Task | Command |
|---|---|
| Flash a batch of boards | `tools/flash.sh --loop` — after each board it waits for the next one |
| Update a running board over Wi-Fi (no cable) | `tools/flash.sh ota` on the board's access point, or `--host 192.168.1.42` on your network; `--ota-pass` if you changed its password |
| Only compile | `tools/flash.sh build` → `build/lilas-eink-1.0.0-full.bin` (offset 0x0) and `-ota.bin` |
| Wipe saved settings while flashing | `--erase` |
| List boards / serial monitor | `tools/flash.sh ports`, `tools/flash.sh monitor` |

On Linux, if the port is refused, the script tells you the exact `usermod` command for serial access.

### Automatic builds on GitHub + browser flasher

Push the project to a GitHub repository and `.github/workflows/firmware.yml` builds it on every push (binaries under *Actions → run → Artifacts*). Tag a version to publish a release:

```bash
git tag v1.0.0 && git push --tags      # tag must match FW_VERSION in config.h
```

The release gets the `.bin` files, and a **web flasher** is deployed to GitHub Pages: anyone opens `https://<you>.github.io/<repo>/` in Chrome or Edge, clicks *Install firmware*, and the board is flashed from the browser. Turn it on once under *Settings → Pages → Source: GitHub Actions*. (The web flasher installs the standard build; Wi-Fi is then set in the portal.)

### Manual: Arduino IDE (2.x)

1. **Boards Manager**: install *esp32 by Espressif Systems* **3.x** (written against 3.3.12).
2. **Library Manager**: install **GxEPD2** (≥ 1.6), **Adafruit GFX Library**, **ArduinoJson** (**7.x**).
3. Open `LilasWeatherEink/LilasWeatherEink.ino`.
4. Tools → Board → **ESP32 Dev Module**; Tools → Partition Scheme → **Minimal SPIFFS (1.9MB APP with OTA)** (the default 1.2 MB app slot is too tight).
5. Upload, then open the Serial Monitor at 115200 baud to see the pin report and Wi-Fi log.

### Manual: PlatformIO

`platformio.ini` is included (uses the pioarduino platform for Arduino core 3.x): `pio run -t upload -t monitor`.

---

## 3. First use

1. Power the board. Within about 30 seconds the panel shows the **Wi-Fi setup** screen (a 4-colour refresh itself takes ~20 s).
2. On your phone join **LilasRobotics-XXXX**, password **lilas1234**. The setup page opens by itself; if not, browse to **http://4.3.2.1**.
3. **Wi-Fi tab** → *Scan for networks* → tap yours → password → *Connect*. (Your phone may drop off for a few seconds while the board's radio moves to your router's channel; rejoin if needed.)
4. **Location tab** → search your city (default is Kathmandu) → *Save location*.
5. **Display tab** → change text, layout, colours, orientation; the preview updates live → *Save display*. The panel redraws in about 20 seconds.

Once the board is on your Wi-Fi the same portal also works from your home network at `http://lilas-eink.local` or the IP shown on the panel / in the Wi-Fi tab.

**Tip:** if 4.3.2.1 won't load on Android, turn off mobile data briefly — some phones send traffic for a Wi-Fi with "no internet" over cellular instead.

---

## 4. Portal overview

| Tab | What you can do |
|---|---|
| Wi-Fi | See connection state and signal, scan, join, forget networks (3 saved, rotated automatically if one is unreachable). |
| Location | City search (Open-Meteo geocoding), manual latitude/longitude, metric/imperial, update interval (10–1440 min). |
| Display | Brand text, message, layout (Dashboard / Big weather / Brand), orientation (landscape, portrait, either upside down), accent (red/yellow/black), header bar or line, toggle logo/forecast/footer/message/24 h, redraw now, colour test pattern, panel diagnostics. |
| Pins | Wiring table, change display pins (validated, then restart), full ESP32 GPIO map. |
| System | Access point name/password/channel (or open), mDNS name, chip/flash/PSRAM/heap info, firmware upload at `/update`, restart, factory reset. |

---

## 5. Troubleshooting

| Symptom | Fix |
|---|---|
| Portal says *"Refresh took only N ms: check BUSY…"* | BUSY isn't reaching GPIO4, or the panel has no 3V3 / RST. Check those three wires. |
| *"BUSY never released"* | BUSY is stuck low: wrong pin, or the module is in 3-wire mode (set BS to 4-line). |
| Colours weak / yellow blotchy | In `GxEPD2_290c_JD79661.cpp` set `JD79661_290_BOOSTER_PROFILE` to `0` (GoodDisplay booster values instead of Waveshare's), re-flash. |
| Image mirrored / wrong area | Try *Landscape, upside down*; if still wrong, run *Draw test pattern*: four clean colour bars mean the driver is right; garbage means the panel isn't a JD79661 type. |
| Long wires / glitches | Lower `EPD_SPI_HZ` in `config.h` to `2000000`. |
| Forgot the AP password | Hold BOOT for 6 s → factory reset → back to `lilas1234`. |
| "Sketch too big" | Select the *Minimal SPIFFS* partition scheme (the scripts already do). |
| Script: "no board found" | Use a data cable; install the CH340 or CP210x USB driver; on Linux check `dmesg` after plugging in. |
| Script: "update refused" (ota) | `--ota-pass` must be the board's access point password (default `lilas1234`). |

Notes
- Weather is fetched over HTTPS without certificate pinning (public, read-only data).
- Wi-Fi passwords are stored in the ESP32's NVS flash, like any IoT device; anyone with physical access to the chip could read them.
- 4-colour e-paper takes ~15–25 s per refresh and the panel maker advises at least 3 minutes between refreshes, so the minimum update interval is 10 minutes.

---

## 6. Files

| File | Purpose |
|---|---|
| `LilasWeatherEink.ino` | setup/loop, BOOT button, pin report |
| `config.h` | defaults: AP name/password/IP, pins, text, location |
| `pins.h` | ESP32 GPIO capability table + validator |
| `GxEPD2_290c_JD79661.*` | 128×296 BWRY driver (JD79661) for GxEPD2 |
| `ui.*`, `wmo.h` | all screen layouts, weather icons, robot logo |
| `worker.cpp` | display + weather task (refresh scheduling) |
| `net.cpp` | access point, captive DNS, station reconnect logic, scanning |
| `portal.cpp`, `portal_html.h` | web portal + REST API |
| `weather.cpp` | Open-Meteo forecast + geocoding |
| `settings.cpp` | settings with validation, stored in NVS, build-time provisioning |
| `provision.h` | empty placeholder; filled only during a `--wifi/--city` build |
| `flash.bat`, `flash.command` | double-click launchers (Windows, macOS) |
| `tools/flash.sh`, `tools/flash.ps1` | setup + build + flash + OTA automation (macOS/Linux, Windows) |
| `tools/lilas.conf.example` | template for your Wi-Fi / location defaults |
| `.github/workflows/firmware.yml` | CI build, releases, web flasher deploy |
| `webflash/index.html` | browser flasher page (ESP Web Tools) |

The display driver is derived from GxEPD2 by Jean-Marc Zingg (GPL-3.0); weather data by [Open-Meteo](https://open-meteo.com) (CC BY 4.0).
