const functions = require("firebase-functions/v1");
const admin = require('firebase-admin');
admin.initializeApp();

// 1. Welcome Notification on Sign Up
exports.onUserCreated = functions.auth.user().onCreate(async (user) => {
    const welcomeNotification = {
        notification: {
            title: 'Welcome to ABUAD App!',
            body: 'We are glad to have you here. Explore events, news, and connect with others!',
        },
        token: null, // We need to store FCM tokens in Firestore to use this
    };

    // Create a user profile in Firestore if it doesn't exist
    const userRef = admin.firestore().collection('users').doc(user.uid);
    const snapshot = await userRef.get();

    if (!snapshot.exists) {
        await userRef.set({
            email: user.email,
            displayName: user.displayName || 'New User',
            photoURL: user.photoURL || null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            isVerified: false,
            role: 'student', // Default role
            fcmToken: null // Placeholder for token
        });
    }
});

// 2. Send Notification for New Announcements
exports.sendAnnouncementNotification = functions.firestore
    .document('announcements/{announcementId}')
    .onCreate(async (snapshot, context) => {
        const announcement = snapshot.data();

        if (!announcement || !announcement.active) return;

        const payload = {
            notification: {
                title: announcement.title || 'New Announcement',
                body: announcement.body || 'Check the app for details.',
                clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            },
            data: {
                type: 'announcement',
                id: context.params.announcementId,
            }
        };

        // Send to a topic 'all_users' (Assuming apps subscribe to this topic)
        try {
            await admin.messaging().sendToTopic('all_users', payload);
            console.log('Announcement sent successfully:', announcement.title);
        } catch (error) {
            console.error('Error sending announcement:', error);
        }
    });

// 3. Send Notification for New Chat Messages
exports.sendMessageNotification = functions.firestore
    .document('channels/{channelId}/messages/{messageId}')
    .onCreate(async (snapshot, context) => {
        const message = snapshot.data();
        const channelId = context.params.channelId;

        // Get channel details to find members
        const channelRef = admin.firestore().collection('channels').doc(channelId);
        const channelSnap = await channelRef.get();
        const channelData = channelSnap.data();

        if (!channelData || !channelData.member_ids) return;

        const senderId = message.senderId;
        const members = channelData.member_ids.filter(uid => uid !== senderId); // Exclude sender

        if (members.length === 0) return;

        // Fetch FCM tokens for these members
        const tokens = [];
        const userSnaps = await admin.firestore().collection('users').where(admin.firestore.FieldPath.documentId(), 'in', members).get();

        userSnaps.forEach(doc => {
            const userData = doc.data();
            if (userData.fcmToken) {
                tokens.push(userData.fcmToken);
            }
        });

        if (tokens.length === 0) return;

        const payload = {
            notification: {
                title: message.senderName || 'New Message',
                body: message.type === 'text' ? message.content : 'Sent a media file',
                clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            },
            data: {
                type: 'chat',
                channelId: channelId,
            }
        };

        // Send multicast
        try {
            await admin.messaging().sendToDevice(tokens, payload);
            console.log(`Message notification sent to ${tokens.length} devices.`);
        } catch (error) {
            console.error('Error sending message notification:', error);
        }
    });
