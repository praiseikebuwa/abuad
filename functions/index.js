const functions = require("firebase-functions/v1");
const admin = require('firebase-admin');
admin.initializeApp();

/**
 * Helper to fetch FCM tokens and send a multicast notification.
 */
async function sendToUsers(userIds, payload) {
    if (!userIds || userIds.length === 0) return;

    const tokens = [];
    // Firestore 'in' query supports up to 30 items. 
    // For large groups, this would need batching.
    const userSnaps = await admin.firestore()
        .collection('users')
        .where(admin.firestore.FieldPath.documentId(), 'in', userIds)
        .get();

    userSnaps.forEach(doc => {
        const userData = doc.data();
        if (userData.fcmToken) {
            tokens.push(userData.fcmToken);
        }
    });

    if (tokens.length === 0) return;

    try {
        // Modern multicast sending
        const response = await admin.messaging().sendEachForMulticast({
            tokens: tokens,
            notification: {
                title: payload.notification.title,
                body: payload.notification.body,
            },
            data: payload.data,
            android: {
                priority: 'high',
                notification: {
                    clickAction: 'FLUTTER_NOTIFICATION_CLICK',
                }
            },
            apns: {
                payload: {
                    aps: {
                        badge: 1,
                        sound: 'default'
                    }
                }
            }
        });
        console.log(`${response.successCount} messages were sent successfully.`);
    } catch (error) {
        console.error('Error sending multicast message:', error);
    }
}

/**
 * Helper to create a notification record in user's subcollection.
 */
async function createNotification(recipientId, notification) {
    const docRef = admin.firestore()
        .collection('users')
        .doc(recipientId)
        .collection('notifications')
        .doc();

    await docRef.set({
        id: docRef.id,
        recipient_id: recipientId,
        sender_id: notification.senderId,
        sender_name: notification.senderName,
        sender_avatar_url: notification.senderAvatarUrl || null,
        type: notification.type,
        title: notification.title,
        body: notification.body,
        related_id: notification.relatedId || null,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        is_read: false,
    });
}

// 1. Welcome Notification on Sign Up
exports.onUserCreated = functions.auth.user().onCreate(async (user) => {
    const userRef = admin.firestore().collection('users').doc(user.uid);
    const snapshot = await userRef.get();

    if (!snapshot.exists) {
        await userRef.set({
            email: user.email,
            displayName: user.displayName || 'New User',
            photoURL: user.photoURL || null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            isVerified: false,
            role: 'student',
            fcmToken: null
        });
    }
});

// 2. New Chat Message Notification
exports.sendMessageNotification = functions.firestore
    .document('channels/{channelId}/messages/{messageId}')
    .onCreate(async (snapshot, context) => {
        const message = snapshot.data();
        const channelId = context.params.channelId;

        const channelRef = admin.firestore().collection('channels').doc(channelId);
        const channelSnap = await channelRef.get();
        const channelData = channelSnap.data();

        if (!channelData || !channelData.member_ids) return;

        const senderId = message.sender_id; // Using correct field name from Flutter repo
        const recipientIds = channelData.member_ids.filter(uid => uid !== senderId);

        if (recipientIds.length === 0) return;

        const payload = {
            notification: {
                title: channelData.type === 'group' ? channelData.display_name : (message.sender_name || 'New Message'),
                body: message.type === 'text' ? message.content : 'Sent a media file',
            },
            data: {
                type: 'chat',
                id: channelId, // Flutter router expects 'id' for /chat/:id
            }
        };

        await sendToUsers(recipientIds, payload);

        // Create individual notification records
        for (const recipientId of recipientIds) {
            await createNotification(recipientId, {
                senderId: message.sender_id,
                senderName: message.sender_name || 'Someone',
                senderAvatarUrl: null, // Could fetch if needed
                type: 'chat',
                title: payload.notification.title,
                body: payload.notification.body,
                relatedId: channelId,
            });
        }
    });

// 3. New Like Notification
exports.onLikeCreated = functions.firestore
    .document('posts/{postId}/likes/{userId}')
    .onCreate(async (snapshot, context) => {
        const postId = context.params.postId;
        const likerId = context.params.userId;

        const postRef = admin.firestore().collection('posts').doc(postId);
        const postSnap = await postRef.get();
        const postData = postSnap.data();

        if (!postData || postData.author_id === likerId) return;

        const likerSnap = await admin.firestore().collection('users').doc(likerId).get();
        const likerName = likerSnap.data()?.displayName || 'Someone';

        const payload = {
            notification: {
                title: 'New Like',
                body: `${likerName} liked your post`,
            },
            data: {
                type: 'post',
                id: postId,
            }
        };

        await sendToUsers([postData.author_id], payload);

        await createNotification(postData.author_id, {
            senderId: likerId,
            senderName: likerName,
            senderAvatarUrl: likerSnap.data()?.avatarUrl || null,
            type: 'post',
            title: payload.notification.title,
            body: payload.notification.body,
            relatedId: postId,
        });
    });

// 4. New Comment Notification
exports.onCommentCreated = functions.firestore
    .document('posts/{postId}/comments/{commentId}')
    .onCreate(async (snapshot, context) => {
        const comment = snapshot.data();
        const postId = context.params.postId;

        const postRef = admin.firestore().collection('posts').doc(postId);
        const postSnap = await postRef.get();
        const postData = postSnap.data();

        if (!postData || postData.author_id === comment.user_id) return;

        const payload = {
            notification: {
                title: 'New Comment',
                body: `${comment.user_name} commented on your post`,
            },
            data: {
                type: 'post',
                id: postId,
            }
        };

        await sendToUsers([postData.author_id], payload);

        await createNotification(postData.author_id, {
            senderId: comment.user_id,
            senderName: comment.user_name,
            senderAvatarUrl: comment.user_avatar_url || null,
            type: 'post',
            title: payload.notification.title,
            body: payload.notification.body,
            relatedId: postId,
        });
    });

// 5. New Follower Notification
exports.onFollowCreated = functions.firestore
    .document('users/{userId}/followers/{followerId}')
    .onCreate(async (snapshot, context) => {
        const targetUserId = context.params.userId;
        const followerId = context.params.followerId;

        const followerSnap = await admin.firestore().collection('users').doc(followerId).get();
        const followerName = followerSnap.data()?.displayName || 'Someone';

        const payload = {
            notification: {
                title: 'New Follower',
                body: `${followerName} started following you`,
            },
            data: {
                type: 'user',
                id: followerId,
            }
        };

        await sendToUsers([targetUserId], payload);

        await createNotification(targetUserId, {
            senderId: followerId,
            senderName: followerName,
            senderAvatarUrl: followerSnap.data()?.avatarUrl || null,
            type: 'user',
            title: payload.notification.title,
            body: payload.notification.body,
            relatedId: followerId,
        });
    });

// 6. Security Alert (SOS) Notification
exports.onSOSCreated = functions.firestore
    .document('sos_alerts/{alertId}')
    .onCreate(async (snapshot, context) => {
        const alert = snapshot.data();
        
        // Broadcast to nearby users or all active campus users
        // Fetch users with FCM tokens
        const userSnaps = await admin.firestore().collection('users')
            .where('fcmToken', '!=', null)
            .get();

        const tokens = [];
        userSnaps.forEach(doc => {
            const data = doc.data();
            // Don't notify the person who triggered it
            if (data.fcmToken && doc.id !== alert.userId) {
                tokens.push(data.fcmToken);
            }
        });

        if (tokens.length === 0) return;

        const payload = {
            notification: {
                title: '🚨 SECURITY ALERT',
                body: `${alert.userName} triggered an SOS alert!`,
            },
            data: {
                type: 'sos',
                id: context.params.alertId,
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
            }
        };

        try {
            const response = await admin.messaging().sendEachForMulticast({
                tokens: tokens,
                notification: payload.notification,
                data: payload.data,
                android: {
                    priority: 'high',
                },
                apns: {
                    payload: {
                        aps: {
                            sound: 'default'
                        }
                    }
                }
            });
            console.log(`SOS Alert sent to ${response.successCount} users.`);
        } catch (error) {
            console.error('Error broadcasting SOS alert:', error);
        }
    });
