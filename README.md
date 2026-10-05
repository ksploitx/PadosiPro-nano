<p align="center">
  <img src="docs/padosipro-logo.png" alt="PadosiPro Logo" width="200" />
</p>

<h1 align="center">PadosiPro Nano</h1>

<p align="center">
  <strong>A modern web and mobile application featuring a FastAPI backend and a Flutter mobile app.</strong>
</p>

---

## 📚 Architecture & Design

For a deeper dive into the system's architecture, design decisions, and system flows, refer to the following documentation:

- **[High-Level Design (HLD)](docs/HLD.md)** - System architecture, sequence diagrams, and high-level flows.
- **[Low-Level Design (LLD)](docs/LLD.md)** - Component-level details, database schemas, and API specifications.
- **[Design Decisions](DESIGN.md)** - Technology stack, key decisions, testing strategies, and known trade-offs.

---

## 🛠️ Prerequisites

Ensure you have the following installed before getting started:

- 🐳 **Docker Desktop** (or Docker Engine + Compose plugin)
- 💙 **[Flutter SDK](https://docs.flutter.dev/get-started/install)** (required for the mobile app)
- 🤖 **[Android Studio](https://developer.android.com/studio)** (required for building the APK and running the Android emulator)

---

## 🚀 Backend Setup

The backend runs entirely in Docker for a seamless experience.

```bash
cd backend
cp .env.example .env
docker compose up --build
```

### 🌱 Seeding the Database

The task catalogue is seeded automatically on the first run. However, if you need to manually inject or refresh the seed data at any point, you can run the following Docker command while your container is running:

```bash
docker compose exec api python -m app.seed
```

### 🔗 Useful Links

- **API (Swagger UI):** [http://localhost:8000/docs](http://localhost:8000/docs)
- **Mailpit (OTP Emails):** [http://localhost:8025](http://localhost:8025)

---

## 📱 Mobile Setup

Run the mobile app using Flutter:

```bash
cd mobile
flutter pub get
flutter run
```

> **Note:** Before running, open `lib/services/api_client.dart` and set the `baseUrl` to match your target environment:
>
> - **Android Emulator:** Use `http://10.0.2.2:8000` _(already default in code)_
> - **Physical Device:** Use your machine's LAN IP _(e.g., `http://192.168.x.x:8000`)_

---

## 📦 Building the APK (Release)

To build the Android application package (APK) for production:

1. Ensure your Flutter environment is correctly set up and Android licenses are accepted:
   ```bash
   flutter doctor
   ```
2. Navigate to the mobile directory:
   ```bash
   cd mobile
   ```
3. Fetch Flutter dependencies:
   ```bash
   flutter pub get
   ```
4. Build the APK:
   ```bash
   flutter build apk --release
   ```
5. The generated APK will be located at:
   `build/app/outputs/flutter-apk/app-release.apk`
