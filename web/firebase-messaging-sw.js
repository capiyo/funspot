importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Use the SAME values as the `web` block in your firebase_options.dart
firebase.initializeApp({
  apiKey: 'AIzaSyCWMGz6AIRXgu7GVZiJWlkvO6tVZADf5tY',
  authDomain: 'funzy-d56d7.firebaseapp.com',
  projectId: 'funzy-d56d7',
  storageBucket: 'funzy-d56d7.firebasestorage.app',
  messagingSenderId: '661929781606',
  appId: '1:661929781606:web:3f306a659ae64ac7f780a7',
});

// ✅ ADDED — this was missing. Without it, `messaging` below is undefined
// and the service worker throws `ReferenceError: messaging is not defined`
// the moment it tries to register the background handler, silently
// breaking all background/closed-tab push notifications.
const messaging = firebase.messaging();

// Handles messages when the TAB IS NOT FOCUSED / CLOSED
messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || payload.data?.title || 'New notification';
  const body = payload.notification?.body || payload.data?.body || '';
  self.registration.showNotification(title, {
    body: body,
    icon: '/icons/Icon-192.png',
    data: payload.data,
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window' }).then((clientList) => {
      if (clientList.length > 0) return clientList[0].focus();
      return clients.openWindow('/');
    })
  );
});