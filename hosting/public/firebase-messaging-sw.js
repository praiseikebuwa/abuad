importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyAUN1RPPWWdMsuvlPwuxunV6hV-OWfTmBo",
  authDomain: "abuadapp.firebaseapp.com",
  projectId: "abuadapp",
  storageBucket: "abuadapp.firebasestorage.app",
  messagingSenderId: "597625995805",
  appId: "1:597625995805:web:2ff34401fbddb1df237cf4",
  measurementId: "G-6XRN4D0SF6"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/web/icons/Icon-192.png'
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
