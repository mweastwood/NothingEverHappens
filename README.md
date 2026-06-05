# NothingEverHappens 🏠📋

A beautifully designed, premium todo-list application built for people who live in households where nothing ever happens.

---

## 🚀 Live Application URL

You can access the production-ready live web application here:

🔗 **[https://nothing-ever-happens-prod.web.app](https://nothing-ever-happens-prod.web.app)**

*Automatically deployed to Firebase Hosting on every successful merge to the `main` branch.*

---

## ✨ Features

- **Smooth Task Management**: Create, view, and check off daily chores or household tasks easily.
- **Task History & Deltas**: View the audit log/history of tasks, tracking exactly what was changed, by whom, and when.
- **Micro-Animations**: Experience premium visual feedback with beautiful task-check and list transitions.
- **Offline Web Persistence**: Work cleanly on the web even without an active internet connection. Changes sync automatically when connection re-establishes.
- **Centralized Error Handling**: Experience reliable user-facing crash/timeout reporting with short high-readability error codes for painless support lookup.

---

## 🛠️ Technology Stack

- **Framework**: [Flutter](https://flutter.dev) (Dart)
- **Database**: [Cloud Firestore](https://firebase.google.com/docs/firestore) (with offline web cache enabled)
- **Authentication**: [Firebase Auth](https://firebase.google.com/docs/auth) (Google Sign-In)
- **Hosting**: [Firebase Hosting](https://firebase.google.com/docs/hosting)
- **CI/CD**: GitHub Actions (Verify, Analyze, Formatting, and Automated Deployments)

---

## 💻 Local Development Setup

To run the application locally, make sure you have the Flutter SDK installed and then execute:

1. **Install Dependencies**:
   ```bash
   cd app
   flutter pub get
   ```

2. **Run Static Checks & Tests**:
   ```bash
   flutter analyze
   flutter test
   ```

3. **Launch the App**:
   ```bash
   flutter run -d chrome
   ```

4. **Git Hooks Setup**:
   To automatically format your code before committing, enable the shared git hooks:
   ```bash
   git config core.hooksPath .githooks
   ```
