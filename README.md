# 🍱 E-Bentobox: Campus Dining Mobile App

Welcome to the E-Bentobox Flutter application! This is the frontend repository for our cross-platform mobile app designed to solve the "Naubusan ng Ulam" (sold out food) problem and streamline the lunchtime rush at North Eastern Mindanao State University (NEMSU).

This app contains both the **Student Portal** (for browsing and reserving meals) and the **Vendor Dashboard** (for managing orders and generating QR codes), separated by role-based routing.

---

## ✨ Key Features

*   **Next-Day Reservations:** Students can pre-order custom bento boxes a day in advance, eliminating lines and giving vendors accurate forecasting metrics.
*   **Cryptographic QR Fulfillment:** Vendors can natively generate and print A4 PDF sheets of unique QR stickers. Scanning these stickers binds the physical box to the digital order.
*   **Real-Time Notifications:** Integrated `socket_io_client` listens for live order status updates, pushing instant alerts to students when their food is accepted or ready.
*   **Interactive Maps:** OpenStreetMap integration (`flutter_map`) allows vendors to pin their exact GPS coordinates, providing students with live mini-map previews and navigation.
*   **"One-Strike" Ban Warning:** UI logic built-in to warn users of the strict pickup policy, protecting local micro-businesses from abandoned orders.

---

## 🛠 Tech Stack

*   **UI Framework:** [Flutter](https://flutter.dev/) (Dart)
*   **State Management:** `provider`
*   **Real-Time Data:** `socket_io_client`
*   **Map Integration:** `flutter_map` (OpenStreetMap) + `geolocator`
*   **Hardware/Sensors:** `mobile_scanner` (ML Kit QR scanning), `image_picker`
*   **PDF Generation:** `pdf` + `printing`
*   **Asset Management:** `cached_network_image` (to save data bandwidth)

---

## 🚀 Local Setup & Installation

Follow these steps to get the Flutter app running on your local machine or physical device.

### 1. Prerequisites
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
*   An IDE (VS Code or Android Studio) with Flutter extensions.
*   A physical Android/iOS device (Highly recommended for testing the Camera/QR Scanner).

### 2. Clone the Repository
```bash
git clone https://github.com/yourusername/e-bentobox-flutter.git
cd e-bentobox-flutter
```

### 3. Environment Variables (.env)
You must connect the app to your backend VPS. Create a `.env` file in the root directory (same level as `pubspec.yaml`) and add your server's IP address:
```env
API_BASE_URL=http://YOUR_VPS_IP:3000
```
*(Note: Do not commit this file to public repositories!)*

### 4. Install Dependencies
```bash
flutter pub get
```

### 5. Run the App
```bash
flutter run
```

---

## 📂 Folder Structure

We use a modular, feature-based folder structure to keep the code organized:

```text
lib/
├── auth/                   # Login, Registration, and Auth-routing screens
├── shared/                 # Reusable widgets (e.g., QR Scanner Screen)
├── user/                   # Student-facing screens (Explore, Cart, Map, Orders)
├── vendor/                 # Vendor-facing screens (Dashboard, Menu CRUD, Profile)
└── main.dart               # Entry point, Provider initialization, and Theme
```

---

## 🤝 Contributing

1.  Create a new branch for your feature: `git checkout -b feature/amazing-feature`
2.  Commit your changes: `git commit -m 'Add amazing feature'`
3.  Push to the branch: `git push origin feature/amazing-feature`
4.  Open a Pull Request!
