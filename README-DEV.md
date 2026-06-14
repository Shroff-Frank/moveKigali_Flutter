# moveKigali — Dev notes

This file contains quick troubleshooting and hosting instructions I added.

## Chrome websocket error (dev) — "Failed to establish connection with the application instance in Chrome"
Common causes: firewall/proxy blocking websocket, Chrome started with flags, or dev tool binding issues.

Try the following (pick one):

1) Run with explicit hostname:

```bash
flutter run -d chrome --web-hostname=localhost
```

2) Run web-server and open manually:

```bash
flutter run -d web-server --web-port=8080
# Open http://localhost:8080 in Chrome
```

3) If behind a corporate firewall/proxy:
- Allow the Dart VM / devtools traffic or temporarily disable firewall for local dev testing.
- Use `--web-hostname=0.0.0.0` to bind to all interfaces if needed.

4) Kill all Chrome instances and retry:
- Close Chrome fully and run `flutter run -d chrome` again.

If the problem persists, capture the full `flutter run -v` log and inspect websocket connection errors.

---

## Firebase Phone Auth (Web) notes
- In Firebase Console: Authentication → Sign-in method → enable Phone.
- Add your app's hosting domain under Authentication → Authorized domains.
- Web phone auth uses reCAPTCHA; ensure the domain is permitted and your `firebase_options.dart` is correct.
- Android: add SHA-1/256 fingerprints to Firebase project settings for proper verification.

Testing locally on web-server (`flutter run -d web-server`) usually works; for production ensure HTTPS hosting (Firebase Hosting provides this).

---

## Deploying to Firebase Hosting (set public site name)
1. Install Firebase CLI and login:

```bash
npm install -g firebase-tools
firebase login
```

2. Initialize hosting in project root (if not initialized):

```bash
firebase init hosting
# choose the project `movekigali-9d268` (or your project)
# set public directory to `build/web` (or keep default)
# configure as a single-page app: yes
```

3. Build web and deploy:

```bash
flutter build web --base-href="/"
firebase deploy --only hosting
```

After deploy, you can use the Firebase Console to set a custom domain (e.g., moveKigali.example.com) or use the firebaseapp/web.app domain.

---

## App title / manifest
- I updated `web/index.html` and `web/manifest.json` to use `moveKigali` and `assets/images/logo1.png`.
- If you want a different hosting URL or public name, configure Firebase Hosting or update the manifest/title.

---

## Next recommended work
- Full responsive pass (I started with login/register/forgot password). I can continue sweeping major screens and components.
- Add visual breakpoints, consistent `maxWidth` wrappers and adapt grid/list layouts for large screens.

If you'd like, I can proceed to do the full responsiveness sweep now and push more updates.
