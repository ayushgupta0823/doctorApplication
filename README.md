# MediConnectAI — Doctor App (Flutter)

A Flutter port of the `doctor_app.html` prototype: a doctor-facing
telehealth app with a consultation queue, video calling with an AI
scribe, ICD-10 lookup, prescription builder, patient history, daily
roster, and profile screens.

## Project layout

```
lib/
  main.dart                  App entry point (MaterialApp + Provider)
  root_shell.dart             Bottom-nav scaffold (5 tabs)
  theme/app_theme.dart        Colors, text styles, ThemeData (ported from :root CSS vars)
  models/models.dart          Data classes (QueuePatient, PatientHistory, Medicine, IcdCode, ...)
  data/mock_data.dart         Static mock data (ported from the JS MOCK DATA section)
  state/app_state.dart        ChangeNotifier holding all mutable app state + actions
  widgets/                    Shared UI: buttons, cards, badges, avatar, sparkline/ekg painters
  screens/
    queue_screen.dart         Consultation Queue tab
    video/
      video_screen.dart       Consult Room shell + sub-tab switcher
      call_tab.dart           Live video call UI + transcript
      ai_tools_tab.dart       AI SOAP notes, vitals sparklines, ICD-10 search, risk summary
      prescription_tab.dart   Prescription builder + signed/QR confirmation
    patients_screen.dart      My Patients (consultation history)
    roster_screen.dart        Daily Roster
    profile_screen.dart       Doctor profile & credentials
```

State management uses `provider` (`ChangeNotifier` + `ChangeNotifierProvider`),
mirroring the single global `state` object and mutator functions from the
original HTML/JS prototype.

## Status: builds, analyzes, and tests clean

A Flutter SDK (3.44.4 stable) was installed and used to fully verify this
project:

- `flutter analyze` — **0 issues**
- `flutter test` — **9/9 passing** (`test/widget_test.dart` boots the app
  and exercises every tab plus the key interactive flows: approve/start/
  no-show, AI summary generation, ICD-10 search, prescription validation
  and sign-off)
- `flutter build web` — builds successfully; the output was served and
  smoke-checked outside the test harness

Along the way this caught and fixed real bugs, not just style nits:

- **`lib/widgets/sparkline_painter.dart`** — `values.reduce(...)` threw a
  runtime `TypeError` (`(num, num) => num` is not `(int, int) => int`)
  because the widget declared `List<num>` but was always called with a
  `List<int>`; Dart's unsound generic covariance let it compile but not
  run. Fixed by copying to a concrete `List<double>` before reducing.
- **`lib/screens/roster_screen.dart`** — the stat-card grid used a fixed
  `childAspectRatio` that overflowed by a couple of pixels once real font
  metrics were laid out (a genuine `RenderFlex overflowed` visual bug).
  Replaced with a self-sizing row/column layout.
- **`lib/screens/video/ai_tools_tab.dart`** — a ternary mixing an empty
  `List<dynamic>` literal with a typed `Iterable<IcdCode>` inferred as
  `Object`, breaking `.map(...)` — a real `flutter analyze` error, not a
  warning. Fixed with an explicit `Iterable<IcdCode>` type and matching
  `<IcdCode>[]` literal.
- Several `RichText` usages were switched to the idiomatic `Text.rich`
  (inherits `DefaultTextStyle`/text scaling correctly, and is what
  `find.text` matches in tests without extra flags).

The platform folders (`android/`, `web/`, `windows/`) have been generated
via `flutter create --platforms=windows,web,android .` and are committed.
`ios/`, `macos/`, and `linux/` were not generated — add them the same way
if you need those targets.

### Running it yourself

```bash
flutter pub get
flutter run            # picks a connected device/emulator
flutter run -d chrome   # run in a browser
flutter run -d windows  # requires Visual Studio "Desktop development with C++"
```

Note: Windows desktop builds need Visual Studio installed (not just
Flutter) — this machine only had Chrome and an Android device available,
which is what was used to verify the build.

## Notes on the port

- All data is mocked in-memory (`lib/data/mock_data.dart`), same as the
  original — there's no backend integration.
- The video call, AI SOAP generation, ICD-10 search, and prescription
  signing are simulated with local state changes and `Future.delayed`
  timers, matching the original `setTimeout`-based mock behavior.
- The HTML version's "phone frame" chrome was just a way to preview a
  mobile layout inside a desktop browser tab — this Flutter app runs full
  screen natively instead, which is the correct behavior for a real
  mobile/desktop app.
- Material icons stand in for the original inline SVG icon set; colors,
  spacing, type scale, and layout structure are ported 1:1 from the CSS.
