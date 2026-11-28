# Development Setup

Everything you need to run Rembo on your machine: the Flutter app on an Android emulator or iOS simulator, plus a local Supabase stack.

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| [Flutter](https://docs.flutter.dev/get-started/install) | **3.47 stable** (Dart 3.13) | Check with `flutter --version` |
| Android Studio | Latest | Android SDK + an emulator |
| Xcode | Latest | macOS only, for the iOS simulator |
| [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started) | Latest | Runs the local backend |
| Docker Desktop (or a compatible runtime) | Latest | Required by `supabase start` |
| Git | 2.40+ | See [Git & PR Workflow](Git-and-PR-Workflow) |

Run `flutter doctor` and fix every ❌ before going further.

## 1. Get the code

Team members clone the repository directly. External contributors [fork it first](Git-and-PR-Workflow#contributing-from-a-fork).

```bash
git clone https://github.com/exceev-technology/rembo.git
cd rembo
flutter pub get
```

## 2. Start the local backend

```bash
supabase start      # starts Postgres, Auth, Storage and Edge Functions in Docker
supabase status     # prints the local API URL and the anon key
```

To reset the local database and re-run migrations and seed data:

```bash
supabase db reset
```

The seed (`supabase/seed.sql`, local only) creates two fictional companies, one person per role and expenses in every status. Every account signs in with `Rembo-2026!`: `sara@atlas.test` and `karim@atlas.test` (managers), `omar@atlas.test` and `salma@atlas.test` (employees), `lina@atlas.test` (accountant), `zed@autre.test` (manager of another company).

## 3. Configure environment variables

The app reads its configuration at build time with `--dart-define-from-file`.

```bash
cp .env.example .env
```

Fill `.env` with the values printed by `supabase status`:

| Variable | Description |
|---|---|
| `SUPABASE_URL` | API URL of your Supabase project (local or dev) |
| `SUPABASE_ANON_KEY` | Public `anon` key, safe on the client because RLS protects the data |
| `REMBO_DEMO` | `true` for the fictional demo (nothing saved) |
| `REMBO_OCR` | `true` once the server receipt reader is deployed (see `supabase/README.md`) |
| `REMBO_WHATSAPP_NUMBER` | The company's WhatsApp line, digits only, when it exists |

**Which data the app uses** at start-up: the Supabase project when both values are set; else the fictional demo when `REMBO_DEMO=true` (or on the web); else real accounts and expenses kept **on the phone only**, which needs no server at all.

> 🔐 **Never** put the `service_role` key, OCR keys or AI keys in `.env`, in the app or in the repository. They live only in Edge Functions secrets. `.env` is git-ignored. See [Data Protection & Security](Data-Protection-and-Security).

## 4. Run the app

```bash
flutter devices                                   # list emulators / simulators
flutter run --dart-define-from-file=.env          # pick the Android or iOS device
```

**On a real Android phone** against the local stack: enable USB debugging, plug the phone in, then forward the API port so that `http://127.0.0.1:54321` in `.env` reaches your computer:

```bash
adb reverse tcp:54321 tcp:54321
flutter run --dart-define-from-file=.env
```

To install a build on a phone: `flutter build apk --debug --dart-define-from-file=.env` then `adb install -r build/app/outputs/flutter-apk/app-debug.apk`.

## 5. Put it online (a hosted Supabase project)

```bash
supabase link --project-ref <ref>
supabase db push                         # migrations only; never the seed
supabase functions deploy read-receipt   # optional, see supabase/README.md
supabase functions deploy read-policy    # company policy import, same engine
supabase secrets set RECEIPT_API_URL=… RECEIPT_MODEL=…
```

Keep « Confirm email » on in Authentication. Then set `SUPABASE_URL` and `SUPABASE_ANON_KEY` of that project in `.env` and build the app.

## Quality checks

Run these before every push. CI runs the same checks in the **Analyze & test** job.

```bash
dart format .          # format the code
flutter analyze        # static analysis (lints from analysis_options.yaml)
flutter test           # unit and widget tests
tool/check_no_secrets.sh   # control C5: no server-only key in the repository
```

The other checks of the CI, to run when you touch their part:

| Part | Command |
|---|---|
| Database (migrations, rights, SQL functions) | `supabase start && supabase test db` |
| Server receipt reader | `deno test supabase/functions/read-receipt/` |
| Company policy reader | `deno test supabase/functions/read-policy/` |
| End-to-end journey (no server needed) | `flutter test integration_test/journey_test.dart -d <device or linux>` |
| OCR bench on a phone | `flutter test integration_test/bench_device_test.dart -d <phone>` |

A test on a phone uninstalls the app when it ends: install your build again afterwards.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `supabase start` fails | Make sure Docker is running, then `supabase stop && supabase start` |
| iOS build fails after a dependency change | `cd ios && pod install && cd ..` |
| Strange build errors after switching branches | `flutter clean && flutter pub get` |
| The app cannot reach the local Supabase from an Android emulator | Use `http://10.0.2.2:54321` instead of `localhost` in `SUPABASE_URL` |
| The computer freezes during an Android build | Gradle asks for 8 GB in `android/gradle.properties`. On a machine with less memory, override it in `~/.gradle/gradle.properties`: `org.gradle.jvmargs=-Xmx2g -XX:MaxMetaspaceSize=768m` and `org.gradle.daemon.idletimeout=600000` |
| `flutter test -d linux` cannot build | `sudo apt install ninja-build libgtk-3-dev libsecret-1-dev` (the secure storage of the on-device mode needs libsecret) |

Still stuck? Ask in a thread in the team Slack channel or open a [Q&A discussion](https://github.com/exceev-technology/rembo/discussions/categories/q-a).
