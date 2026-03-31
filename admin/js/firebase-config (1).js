// Web Firebase Config
const firebaseConfig = {
  apiKey: "AIzaSyAVj_lRKd1xVI44_7Hu9LaXGTpZ3pOVkls",
  authDomain: "abuad-app.firebaseapp.com",
  projectId: "abuad-app",
  storageBucket: "abuad-app.firebasestorage.app",
  messagingSenderId: "762694975503",
  appId: "1:762694975503:web:e864d9dd13683bb9b8637a"
};

// Initialize Firebase
firebase.initializeApp(firebaseConfig);
const auth = firebase.auth();
const db = firebase.firestore();
