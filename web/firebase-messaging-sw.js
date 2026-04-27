importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyCLD-vpq_jUJFuqCnlh8g_kMvg2QdDFLbA",
  authDomain: "shayak-6957e.firebaseapp.com",
  projectId: "shayak-6957e",
  storageBucket: "shayak-6957e.firebasestorage.app",
  messagingSenderId: "878485283395",
  appId: "1:878485283395:web:0b2c16cad165b0b6c12af6"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("Background message received:", payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: "/icons/Icon-192.png"
  };

  return self.registration.showNotification(
    notificationTitle,
    notificationOptions
  );
});
