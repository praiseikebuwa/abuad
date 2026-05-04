const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.promoteToAdmin = functions.https.onCall(async (data, context) => {
  // 1. Verify the person making the request is already an admin
  if (context.auth.token.admin !== true) {
    throw new functions.https.HttpsError(
      'permission-denied', 
      'Only existing admins can promote other users.'
    );
  }

  const targetUid = data.uid;

  try {
    // 2. Set the custom claim on the target user
    await admin.auth().setCustomUserClaims(targetUid, { admin: true });
    
    // 3. (Optional) You can still update their Firestore document so the UI knows they are an admin
    await admin.firestore().collection('users').doc(targetUid).update({
      role: 'admin',
      isAdmin: true
    });

    return { message: `Successfully promoted user ${targetUid} to Admin.` };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});