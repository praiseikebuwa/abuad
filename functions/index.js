const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/\"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function getDisplayName(userData) {
  return userData?.display_name || userData?.displayName || 'ABUAD User';
}

function getAvatarUrl(userData) {
  return userData?.avatar_url || userData?.avatarUrl || null;
}

async function sendToUsers(userIds, payload) {
  if (!userIds || userIds.length === 0) return;

  const tokens = [];
  const userSnaps = await db
    .collection('users')
    .where(admin.firestore.FieldPath.documentId(), 'in', userIds)
    .get();

  userSnaps.forEach((doc) => {
    const userData = doc.data();
    if (userData.fcmToken) tokens.push(userData.fcmToken);
  });

  if (tokens.length === 0) return;

  try {
    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: payload.notification.title,
        body: payload.notification.body,
      },
      data: payload.data,
      android: {
        priority: 'high',
        notification: { clickAction: 'FLUTTER_NOTIFICATION_CLICK' },
      },
      apns: {
        payload: {
          aps: {
            badge: 1,
            sound: 'default',
          },
        },
      },
    });
    console.log(`${response.successCount} notifications sent`);
  } catch (error) {
    console.error('Error sending notifications:', error);
  }
}

async function createNotification(recipientId, notification) {
  const docRef = db
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

exports.onUserCreated = functions.auth.user().onCreate(async (user) => {
  const userRef = db.collection('users').doc(user.uid);
  const snapshot = await userRef.get();

  if (!snapshot.exists) {
    await userRef.set({
      email: user.email,
      display_name: user.displayName || 'New User',
      avatar_url: user.photoURL || null,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      is_verified: false,
      role: 'student',
      fcmToken: null,
    });
  }
});

exports.sendMessageNotification = functions.firestore
  .document('channels/{channelId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data() || {};
    const channelId = context.params.channelId;

    const channelRef = db.collection('channels').doc(channelId);
    const channelSnap = await channelRef.get();
    const channelData = channelSnap.data();
    if (!channelData || !channelData.member_ids) return;

    const senderId = message.sender_id;
    const recipientIds = channelData.member_ids.filter((uid) => uid !== senderId);
    if (recipientIds.length === 0) return;

    const senderName =
      (channelData.member_names && channelData.member_names[senderId]) || 'New Message';

    const payload = {
      notification: {
        title: channelData.type === 'group' ? channelData.display_name : senderName,
        body: message.type === 'text' ? (message.content || 'New message') : 'Sent a media file',
      },
      data: {
        type: 'chat',
        id: channelId,
      },
    };

    await sendToUsers(recipientIds, payload);

    for (const recipientId of recipientIds) {
      await createNotification(recipientId, {
        senderId,
        senderName,
        senderAvatarUrl: null,
        type: 'chat',
        title: payload.notification.title,
        body: payload.notification.body,
        relatedId: channelId,
      });
    }
  });

exports.onLikeCreated = functions.firestore
  .document('posts/{postId}/likes/{userId}')
  .onCreate(async (snapshot, context) => {
    const postId = context.params.postId;
    const likerId = context.params.userId;

    const postSnap = await db.collection('posts').doc(postId).get();
    const postData = postSnap.data();
    if (!postData || postData.author_id === likerId) return;

    const likerSnap = await db.collection('users').doc(likerId).get();
    const likerData = likerSnap.data() || {};
    const likerName = getDisplayName(likerData);

    const payload = {
      notification: {
        title: 'New Like',
        body: `${likerName} liked your post`,
      },
      data: {
        type: 'post',
        id: postId,
      },
    };

    await sendToUsers([postData.author_id], payload);
    await createNotification(postData.author_id, {
      senderId: likerId,
      senderName: likerName,
      senderAvatarUrl: getAvatarUrl(likerData),
      type: 'like',
      title: payload.notification.title,
      body: payload.notification.body,
      relatedId: postId,
    });
  });

exports.onCommentCreated = functions.firestore
  .document('posts/{postId}/comments/{commentId}')
  .onCreate(async (snapshot, context) => {
    const comment = snapshot.data() || {};
    const postId = context.params.postId;

    const postSnap = await db.collection('posts').doc(postId).get();
    const postData = postSnap.data();
    if (!postData || postData.author_id === comment.user_id) return;

    const payload = {
      notification: {
        title: 'New Comment',
        body: `${comment.user_name || 'Someone'} commented on your post`,
      },
      data: {
        type: 'post',
        id: postId,
      },
    };

    await sendToUsers([postData.author_id], payload);
    await createNotification(postData.author_id, {
      senderId: comment.user_id,
      senderName: comment.user_name || 'Someone',
      senderAvatarUrl: comment.user_avatar || null,
      type: 'comment',
      title: payload.notification.title,
      body: payload.notification.body,
      relatedId: postId,
    });
  });

exports.onFollowCreated = functions.firestore
  .document('users/{userId}/followers/{followerId}')
  .onCreate(async (snapshot, context) => {
    const targetUserId = context.params.userId;
    const followerId = context.params.followerId;

    const followerSnap = await db.collection('users').doc(followerId).get();
    const followerData = followerSnap.data() || {};
    const followerName = getDisplayName(followerData);

    const payload = {
      notification: {
        title: 'New Follower',
        body: `${followerName} started following you`,
      },
      data: {
        type: 'follow',
        id: followerId,
      },
    };

    await sendToUsers([targetUserId], payload);
    await createNotification(targetUserId, {
      senderId: followerId,
      senderName: followerName,
      senderAvatarUrl: getAvatarUrl(followerData),
      type: 'follow',
      title: payload.notification.title,
      body: payload.notification.body,
      relatedId: followerId,
    });
  });

exports.onFollowDeleted = functions.firestore
  .document('users/{userId}/followers/{followerId}')
  .onDelete(async (snapshot, context) => {
    const targetUserId = context.params.userId;
    const followerId = context.params.followerId;

    const followerSnap = await db.collection('users').doc(followerId).get();
    const followerData = followerSnap.data() || {};
    const followerName = getDisplayName(followerData);

    const payload = {
      notification: {
        title: 'Follower Update',
        body: `${followerName} unfollowed you`,
      },
      data: {
        type: 'unfollow',
        id: followerId,
      },
    };

    await sendToUsers([targetUserId], payload);
    await createNotification(targetUserId, {
      senderId: followerId,
      senderName: followerName,
      senderAvatarUrl: getAvatarUrl(followerData),
      type: 'unfollow',
      title: payload.notification.title,
      body: payload.notification.body,
      relatedId: followerId,
    });
  });

exports.onPostCreatedNotifyFollowers = functions.firestore
  .document('posts/{postId}')
  .onCreate(async (snapshot, context) => {
    const post = snapshot.data() || {};
    const authorId = post.author_id;
    if (!authorId) return;

    const followersSnap = await db
      .collection('users')
      .doc(authorId)
      .collection('followers')
      .limit(200)
      .get();
    if (followersSnap.empty) return;

    const followerIds = followersSnap.docs.map((d) => d.id).filter((id) => id !== authorId);
    if (followerIds.length === 0) return;

    const authorSnap = await db.collection('users').doc(authorId).get();
    const authorData = authorSnap.data() || {};
    const authorName = getDisplayName(authorData);
    const content = String(post.content || '').trim();
    const preview = content.length > 0
      ? content.substring(0, 90) + (content.length > 90 ? '...' : '')
      : 'added a new post';

    const payload = {
      notification: {
        title: 'New Post',
        body: `${authorName} ${content.length > 0 ? `posted: ${preview}` : preview}`,
      },
      data: {
        type: 'post',
        id: context.params.postId,
      },
    };

    await sendToUsers(followerIds, payload);

    for (const followerId of followerIds) {
      await createNotification(followerId, {
        senderId: authorId,
        senderName: authorName,
        senderAvatarUrl: getAvatarUrl(authorData),
        type: 'followingPost',
        title: 'New Post',
        body: payload.notification.body,
        relatedId: context.params.postId,
      });
    }
  });

exports.postPreview = functions.https.onRequest(async (req, res) => {
  try {
    const path = req.path || '';
    const parts = path.split('/').filter(Boolean);
    const postId = parts.length >= 2 ? parts[1] : req.query.postId;

    if (!postId) {
      res.redirect(302, 'https://abuadapp.web.app/');
      return;
    }

    const postSnap = await db.collection('posts').doc(postId).get();
    if (!postSnap.exists) {
      res.status(404).send('Post not found');
      return;
    }

    const post = postSnap.data() || {};
    const authorName = escapeHtml(post.author_name || 'ABUAD User');
    const raw = String(post.content || '').trim();
    const desc = escapeHtml(raw.length > 180 ? `${raw.substring(0, 180)}...` : (raw || 'Check out this post on ABUAD App'));
    const image = escapeHtml(post.media_url || 'https://abuadapp.web.app/icons/Icon-512.png');
    const canonical = `https://abuadapp.web.app/post/${encodeURIComponent(postId)}`;

    res.set('Cache-Control', 'public, max-age=120');
    res.set('Content-Type', 'text/html; charset=utf-8');
    res.status(200).send(`<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>${authorName} on ABUAD App</title>
  <meta name="description" content="${desc}"/>
  <meta property="og:type" content="article"/>
  <meta property="og:site_name" content="ABUAD App"/>
  <meta property="og:title" content="${authorName} on ABUAD App"/>
  <meta property="og:description" content="${desc}"/>
  <meta property="og:image" content="${image}"/>
  <meta property="og:url" content="${canonical}"/>
  <meta name="twitter:card" content="summary_large_image"/>
  <meta name="twitter:title" content="${authorName} on ABUAD App"/>
  <meta name="twitter:description" content="${desc}"/>
  <meta name="twitter:image" content="${image}"/>
  <meta http-equiv="refresh" content="0;url=${canonical}"/>
</head>
<body>
  <p>Opening post... <a href="${canonical}">Continue</a></p>
</body>
</html>`);
  } catch (error) {
    console.error('postPreview error:', error);
    res.status(500).send('Server error');
  }
});

exports.onUserDeleted = functions.auth.user().onDelete(async (user) => {
  const userId = user.uid;
  console.log(`Starting data cleanup for deleted user: ${userId}`);

  try {
    const batch = db.batch();

    // 1. Delete User Profile document
    const userRef = db.collection('users').doc(userId);
    batch.delete(userRef);

    // 2. Delete User's Posts
    const postsQuery = await db.collection('posts').where('author_id', '==', userId).get();
    postsQuery.forEach((doc) => {
      batch.delete(doc.ref);
      // Note: In a production environment with many comments/likes, 
      // you might want a separate trigger for onPostDeleted to clean those up.
    });

    // 3. Delete User's Stories
    const storiesQuery = await db.collection('stories').where('author_id', '==', userId).get();
    storiesQuery.forEach((doc) => batch.delete(doc.ref));

    // 4. Delete Marketplace Items
    const marketplaceQuery = await db.collection('marketplace_items').where('seller_id', '==', userId).get();
    marketplaceQuery.forEach((doc) => batch.delete(doc.ref));

    // 5. Clean up Notifications subcollection
    const notificationsQuery = await db.collection('users').doc(userId).collection('notifications').get();
    notificationsQuery.forEach((doc) => batch.delete(doc.ref));

    // 6. Clean up Followers/Following subcollections
    const followersQuery = await db.collection('users').doc(userId).collection('followers').get();
    followersQuery.forEach((doc) => batch.delete(doc.ref));

    const followingQuery = await db.collection('users').doc(userId).collection('following').get();
    followingQuery.forEach((doc) => batch.delete(doc.ref));

    // 7. Delete Reports made by the user
    const reportsQuery = await db.collection('reports').where('reporter_id', '==', userId).get();
    reportsQuery.forEach((doc) => batch.delete(doc.ref));

    // 8. Remove user from channel memberships
    // This is more complex as it involves arrayRemove in many documents.
    // For now, we focus on the user's primary content.

    await batch.commit();
    console.log(`Successfully deleted all primary data for user: ${userId}`);
  } catch (error) {
    console.error(`Error during user data cleanup for ${userId}:`, error);
  }
});
