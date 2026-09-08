# Backend Cloud Functions

This directory contains Firebase Cloud Functions (v2) for **Nothing Ever Happens**, serving as the serverless Task Hub for cross-app synchronization (with apps like PetalCount and TwelveStars) and automated background processing.

## Scripts

- `npm run build`: Compiles Dart entrypoint (`bin/index.dart`) to JavaScript bundle via `dart compile js` and injects Node preamble.
- `npm run watch`: Fast development compile of Dart entrypoint to JavaScript.
- `npm test`: Runs Dart unit test suite via `dart test`.
- `npm run serve`: Builds and launches the local Firebase Functions emulator.

## Core Endpoints

- `POST /reportExternalTaskEvent`: Accepts normalized task completion / status events from satellite apps (e.g. PetalCount supplement logging, TwelveStars prayer completions) and updates or generates corresponding `TaskInstance` records in Firestore.
- `GET /status`: Health and diagnostics endpoint.

