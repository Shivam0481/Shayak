# 🛡️ Shayak: Disaster Response Network

[![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore%20%7C%20Storage-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

**Shayak** (meaning *Helper* or *Arrow*) is a comprehensive disaster response and community assistance platform. It bridges the gap between citizens in distress and local volunteers/administrators, even in resource-constrained environments.

<p align="center">
  <img src="https://raw.githubusercontent.com/Shivam0481/Shayak/main/assets/images/logo.png" width="200" alt="Shayak Logo">
</p>

---

## 🌟 Key Features

### 👤 For Citizens (Users)
- **One-Tap SOS**: Instantly broadcast emergency requests with location data.
- **Hold-to-Send**: Prevent accidental panic alerts with an intuitive circular hold button.
- **Offline Support**: Requests are queued and synced automatically when a connection is restored.
- **Multimedia Reports**: Attach photos and voice notes to give responders more context.

### 🤝 For Volunteers
- **Nearby Map View**: See rescue requests in your immediate vicinity in real-time.
- **Task Management**: Accept, navigate to, and resolve requests directly from the app.
- **Direct Navigation**: Integrated Google Maps for the fastest route to those in need.

### 🛡️ Admin Command Center
- **Fleet Management**: Monitor all active volunteers on a global map.
- **Smart Assignment**: Manually assign specific requests to the best-suited available volunteer.
- **Broadcast Alerts**: Send mass notifications to all users in a specific region.
- **Analytics**: Track request volume, response times, and resource distribution.

---

## 🛠️ Technology Stack

- **Frontend**: Flutter (Cross-platform for Android, iOS, and Web)
- **Backend**: Firebase (Firestore, Auth, Storage, Cloud Messaging)
- **State Management**: Riverpod (Reactive and robust state)
- **Geospatial**: Google Maps API & Geocoding
- **Offline Sync**: Hive (NoSQL local database)
- **Auth**: Google Sign-In & Email/Password

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (>= 3.10.x)
- Firebase Account
- Google Maps API Key

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Shivam0481/Shayak.git
   cd Shayak
   ```

2. **Environment Setup**
   Copy the example environment file and fill in your actual credentials:
   ```bash
   cp .env.example .env
   ```
   > **Note**: For native builds, ensure you also update `android/local.properties` and `ios/Runner/Secrets.plist` with your Google Maps API Key.

3. **Get Dependencies**
   ```bash
   flutter pub get
   ```

4. **Run the App**
   ```bash
   flutter run
   ```

---

## 📂 Project Structure

```text
lib/
├── core/             # Themes, utility constants, and shared styles
├── data/             # Repositories, API services, and data models
├── domain/           # Business logic and complex entities
└── presentation/     # UI Layer (Screens, Providers, and Widgets)
    ├── screens/      # Full-page UI components
    ├── providers/    # Riverpod state management
    └── widgets/      # Reusable UI elements
```

---

## 🤝 Contributing
Contributions are welcome! Whether it's fixing a bug, adding a feature, or improving documentation, please feel free to open a Pull Request.

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
<p align="center">Built with ❤️ for a safer tomorrow.</p>
