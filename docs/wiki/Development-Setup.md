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

> The `supabase/` folder (migrations, seed, Edge Functions) arrives in Sprint 1. Until then you can skip this step.

```bash
supabase start      # starts Postgres, Auth, Storage and Edge Functions in Docker
supabase status     # prints the local API URL and the anon key
```

To reset the local database and re-run migrations and seed data:

```bash
supabase db reset
```

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

> 🔐 **Never** put the `service_role` key, OCR keys or AI keys in `.env`, in the app or in the repository. They live only in Edge Functions secrets. `.env` is git-ignored. See [Data Protection & Security](Data-Protection-and-Security).

## 4. Run the app

```bash
flutter devices                                   # list emulators / simulators
flutter run --dart-define-from-file=.env          # pick the Android or iOS device
```

## Quality checks

Run these before every push. CI runs the same checks in the **Analyze & test** job.

```bash
dart format .          # format the code
flutter analyze        # static analysis (lints from analysis_options.yaml)
flutter test           # unit and widget tests
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `supabase start` fails | Make sure Docker is running, then `supabase stop && supabase start` |
| iOS build fails after a dependency change | `cd ios && pod install && cd ..` |
| Strange build errors after switching branches | `flutter clean && flutter pub get` |
| The app cannot reach the local Supabase from an Android emulator | Use `http://10.0.2.2:54321` instead of `localhost` in `SUPABASE_URL` |

Still stuck? Ask in a thread in the team Slack channel or open a [Q&A discussion](https://github.com/exceev-technology/rembo/discussions/categories/q-a).
