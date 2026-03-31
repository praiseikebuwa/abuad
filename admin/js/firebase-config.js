// Web Firebase Config
const firebaseConfig = {
  apiKey: 'AIzaSyAUN1RPPWWdMsuvlPwuxunV6hV-OWfTmBo',
    appId: '1:597625995805:web:2ff34401fbddb1df237cf4',
    messagingSenderId: '597625995805',
    projectId: 'abuadapp',
    authDomain: 'abuadapp.firebaseapp.com',
    storageBucket: 'abuadapp.firebasestorage.app',
    measurementId: 'G-6XRN4D0SF6',
};

// Initialize Firebase
firebase.initializeApp(firebaseConfig);
const auth = firebase.auth();
const db = firebase.firestore();
db.settings({ experimentalForceLongPolling: true });
