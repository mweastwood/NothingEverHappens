# Backend Implementation Checklist

## Context
Work was paused on **Jan 19, 2026** due to Google Account suspension when trying to create Firebase projects.

## Immediate Next Steps (When Account is Ready)

1.  **Resume Firebase Setup**
    - [ ] Create `neh-dev` and `neh-prod` projects in Firebase Console.
    - [ ] Run `flutterfire configure` for both environments:
      ```bash
      cd app
      # Dev
      flutterfire configure --project=neh-dev --out=lib/firebase_options_dev.dart --yes 
      # Prod
      flutterfire configure --project=neh-prod --out=lib/firebase_options_prod.dart --yes
      ```

2.  **Add Dependencies**
    - [ ] Add the following to `app/pubspec.yaml`:
      - `firebase_core`
      - `firebase_auth`
      - `cloud_firestore`
      - `google_sign_in`
      - `provider` (or `flutter_riverpod` if preferred later)

3.  **Implement Authentication**
    - [ ] Initialize Firebase in `main.dart` using the appropriate `DefaultFirebaseOptions`.
    - [ ] Create `AuthRepository` class:
        - `Stream<User?> get authStateChanges`
        - `Future<void> signInWithGoogle()`
        - `Future<void> signOut()`
    - [ ] Create `LoginScreen`.
    - [ ] Update `MyApp` to show `LoginScreen` if unauthenticated.

4.  **Implement Database Layer**
    - [ ] Create `TaskRepository` class.
    - [ ] Update `Task` model in `lib/logic/task.dart`:
        - Add `factory Task.fromFirestore(DocumentSnapshot doc)`
        - Add `Map<String, dynamic> toFirestore()`
    - [ ] Verify data persistence (Create a task -> Restart app -> Check if it exists).

## References
- **Implementation Plan**: See `implementation_plan.md` in the artifacts (or brain) directory for the full architectural rationale.
- **Project Structure**:
    - `backend/db/firestore.rules`: Security rules (already created).
    - `backend/firebase.json`: Project config (already created).
