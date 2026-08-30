# Backend Cloud Functions

This directory contains Firebase Cloud Functions (v2) for **Nothing Ever Happens**, serving as the serverless Task Hub for cross-app synchronization (with apps like PetalCount and TwelveStars) and automated background processing.

## Scripts

- `npm run build`: Compiles TypeScript sources in `src/` to JavaScript in `lib/`.
- `npm run build:watch`: Watches for changes and continuously compiles TypeScript.
- `npm test`: Runs unit tests with Jest.
- `npm run serve`: Builds and launches the local Firebase Functions emulator.

## Core Endpoints

- `POST /reportExternalTaskEvent`: Accepts normalized task completion / status events from satellite apps (e.g. PetalCount supplement logging, TwelveStars prayer completions) and updates or generates corresponding `TaskInstance` records in Firestore.
- `GET /status`: Health and diagnostics endpoint.

