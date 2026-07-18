# Secure Document Vault

A premium, offline-first mobile and desktop vault application built with Flutter. It utilizes military-grade AES-256 encryption to secure your sensitive images, documents, credentials, and media files locally on your device with zero cloud tracking.

---

## Key Features

- **Local AES-256 CBC Encryption**: All secured files are encrypted on-the-fly and stored with a unique, randomly-generated 16-byte Initialization Vector (IV).
- **Secure Key Derivation**: Passcodes are hashed and verified securely using key derivation standards.
- **Passcode & Biometrics**: Access control managed via a secure 4-digit PIN with optional fingerprint/face biometric authentication setup.
- **Real-time In-Memory Previews**: Decrypts secure images directly into runtime memory byte arrays (`Uint8List`) for grid/list/gallery previews without ever writing decrypted temp files to disk.
- **Multi-Tab Dashboard Experience**:
  1. **Vault Explorer**: Interactive file organizer supporting category filtering, text search, download/export, and delete actions.
  2. **Photo Gallery**: Masonry grid layout with favorites/starred tracking.
  3. **Advanced Search**: Filter and search through your secure inventory based on category and security states.
  4. **Upload Center**: Local storage utilization metrics with a circular percentage usage indicator (100 MB safe offline storage limit) and historical upload logs.
  5. **Security Settings**: Manage PIN code changes, toggle biometrics, switch theme modes, or wipe/reset the vault data securely.
- **Minimalist Space-Grey Theme**: Space-grey/titanium gradient background style with clean, solid curved card borders (`24.0` radius) optimized for low contrast fatigue and readability.

---

## Tech Stack

- **Framework**: Flutter (Dart)
- **State Management**: ValueNotifiers & Inherited Widget bindings
- **Cryptography**: AES-256 (CBC mode) local encryption
- **Packages Used**:
  - `file_picker` (system-wide file picker and directory saving)
  - `open_filex` (secure on-the-fly decryption and preview)
  - `local_auth` (biometrics hardware integration)
  - `flutter_launcher_icons` (automatic asset icon compiler)

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Stable Channel)
- [Android Studio / Build Tools](https://developer.android.com/studio) (for Android testing)
- Visual Studio (with C++ Desktop development workload for Windows testing)

### Installation

1. Clone the repository and navigate to the project directory:
   ```bash
   cd Document_Vault
   ```

2. Retrieve project dependencies:
   ```bash
   flutter pub get
   ```

3. Run the launcher icon generation utility (if modifying assets):
   ```bash
   dart run flutter_launcher_icons
   ```

### Running the Application

- **Run on Windows Desktop**:
  ```bash
  flutter run -d windows
  ```

- **Run on Connected Android Device**:
  ```bash
  flutter run -d <device_id>
  ```

### Building the Release Artifacts

- **Build Release APK**:
  ```bash
  flutter build apk --release
  ```

- **Build Windows Executable**:
  ```bash
  flutter build windows --release
  ```

---

## Security Architecture

1. **Zero Network Traffic**: The application runs completely offline; no keys, passcodes, or files are ever sent to external cloud servers.
2. **Dynamic Cleanup**: Any temp file generated during file previewing via native system intents is instantly erased from cache upon application lifecycle pauses, exits, or manually locking the vault.
3. **Wipe Functionality**: Erasing or resetting the vault overwrites all database storage records and deletes all encrypted binaries from local device directories.
