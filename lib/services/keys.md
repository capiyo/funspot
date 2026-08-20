// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";
// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries

// Your web app's Firebase configuration
// For Firebase JS SDK v7.20.0 and later, measurementId is optional
const firebaseConfig = {
  apiKey: "AIzaSyCWMGz6AIRXgu7GVZiJWlkvO6tVZADf5tY",
  authDomain: "funzy-d56d7.firebaseapp.com",
  projectId: "funzy-d56d7",
  storageBucket: "funzy-d56d7.firebasestorage.app",
  messagingSenderId: "661929781606",
  appId: "1:661929781606:web:3f306a659ae64ac7f780a7",
  measurementId: "G-J4JX2WVWH9"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const analytics = getAnalytics(app);









steps  1
Register a Web app in Firebase
In the Firebase console, open your existing project (the one your Android app already uses), go to Project Settings → General, and click 'Add app' → Web (</> icon). Give it a nickname (e.g. 'Clash Web'). Firebase will show you a config object with apiKey, authDomain, projectId, etc. — copy it, you'll need it next.
2
Regenerate firebase_options.dart with FlutterFire CLI
Run `dart pub global activate flutterfire_cli` then `flutterfire configure` from your project root. Select the same Firebase project, and make sure 'web' is checked in the platform list. This appends a `DefaultFirebaseOptions.web` block to firebase_options.dart automatically — you don't hand-copy the config.
3
Enable Phone sign-in for Web + authorized domains
In Firebase console → Authentication → Sign-in method, confirm Phone is enabled (it already is for Android). Then go to Authentication → Settings → Authorized domains and add 'localhost' (for dev) and your production domain when you deploy. Without this, phone auth silently fails on web with an auth/unauthorized-domain error.
4
Add a reCAPTCHA container to web/index.html
Web has no SafetyNet/Play Integrity, so Firebase falls back to reCAPTCHA verification. Add `<div id="recaptcha-container"></div>` inside the `<body>` of web/index.html, before the Flutter script tags. The firebase_auth plugin will auto-attach an invisible reCAPTCHA widget to this container when verifyPhoneNumber runs on web — you don't need to touch your Dart code for this.
5
Confirm main.dart initializes Firebase with DefaultFirebaseOptions
Your `main()` should call `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` — if it's currently hardcoded to platform-specific options or skips this on web, fix that. `currentPlatform` will now correctly resolve to the `.web` block you generated in step 2.
6
Test with Firebase test phone numbers first
In Authentication → Sign-in method → Phone → Phone numbers for testing, add a test number (e.g. +254700000000) with a fixed OTP code (e.g. 123456). Run `flutter run -d chrome` and send OTP to that number — this avoids burning real SMS quota and avoids reCAPTCHA rate limits while you debug.
7
Handle the web UX quirk: no auto-fill OTP
On Android your codeAutoRetrievalTimeout/verificationCompleted callbacks can auto-complete sign-in via SMS retrieval. On web, that never fires — the user always has to type the 6-digit code manually. Your existing _otpScreen() already does this correctly since it doesn't rely on auto-verification, so no change needed there — just don't expect verificationCompleted to trigger on web.
8
Deploy and re-check authorized domains
When you deploy (Firebase Hosting, Netlify, etc.), add that exact domain to Authorized domains again — a mismatch here is the single most common cause of phone auth working locally but failing in production.