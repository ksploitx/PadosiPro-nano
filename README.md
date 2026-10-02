# PadosiPro Nano

A modern web and mobile application featuring a FastAPI backend and a Flutter mobile app. 

## Prerequisites
- [Docker](https://www.docker.com/) and Docker Compose (for containerized execution)
- [Python 3.10+](https://www.python.org/) (for local backend execution)
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (for mobile app)
- [Android Studio](https://developer.android.com/studio) (for building the APK)

## Environment Variables
The backend uses a `.env` file to manage configuration. Never commit real secrets to version control. An example file `.env.example` is provided in the `backend/` directory.

To set up your environment:
1. Copy the example file: `cp backend/.env.example backend/.env`
2. Update the values in `backend/.env` with your actual local configuration.

## Backend Setup

You can run the backend in two ways: using Docker Compose or locally via a Python virtual environment.

### Method 1: Using Docker Compose (Recommended)
This will spin up the FastAPI app, Redis, and Mailpit in isolated containers.

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Start the services in detached mode:
   ```bash
   docker compose up --build -d
   ```
3. Check the logs if needed:
   ```bash
   docker compose logs -f api
   ```
4. Verify the API is running:
   ```bash
   curl http://localhost:8000/health
   ```

### Method 2: Locally with a Virtual Environment (with Docker for backing services)
Use this method if you want to run the FastAPI app directly on your host machine for easier debugging, while keeping the database/redis isolated.

1. Start Redis and Mailpit via Docker Compose:
   ```bash
   cd backend
   docker compose up -d redis mailpit
   ```
2. Create and activate a virtual environment:
   ```bash
   python3 -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Run the FastAPI application:
   ```bash
   uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
   ```

**Testing on Localhost & Postman:**
- Once running, the API is available at `http://localhost:8000`.
- **Swagger UI (Interactive Docs):** Open `http://localhost:8000/docs` in your browser. This is the easiest way to test endpoints without Postman.
- **Mailpit UI (OTP Emails):** Open `http://localhost:8025` in your browser to see the verification emails.

If you prefer **Postman**:
1. Create a new request in Postman.
2. Set the method (e.g., `POST`).
3. Set the URL (e.g., `http://localhost:8000/auth/register`).
4. Go to the **Body** tab, select **raw** and choose **JSON**.
5. Paste the request payload (e.g., `{"email": "test@example.com", "password": "Password123"}`) and click **Send**.

## Building the APK (Mobile)

To build the Android application package (APK) for the Flutter mobile app:

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
