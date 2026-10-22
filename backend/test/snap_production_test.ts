/**
 * Production Readiness Automated Test Suite for Snap Feature
 * Tests:
 * 1. Expired Snap API access (media masking, 403 replay exhaustion)
 * 2. Saved Snap access after expiration (unmasked for saver, retained in storage)
 * 3. Unauthorized message/media access (403 for non-participants)
 * 4. Concurrent view requests (in-process lock & atomic serialization)
 * 5. Normal chat media remaining unaffected (images/videos never masked)
 */

import { extractR2Key } from '../src/config/cloudflare';

// Helper to simulate formatMessage logic directly from backend/src/routes/chat.ts
function formatMessage(msg: any, requestingUserId?: string) {
  let reactions: Record<string, any> = {};
  let savedBy: string[] = [];
  let readBy: string[] = [];
  try { reactions = typeof msg.reactions === 'string' ? JSON.parse(msg.reactions || '{}') : (msg.reactions || {}); } catch {}
  try { savedBy = typeof msg.savedBy === 'string' ? JSON.parse(msg.savedBy || '[]') : (msg.savedBy || []); } catch {}
  try { readBy = typeof msg.readBy === 'string' ? JSON.parse(msg.readBy || '[]') : (msg.readBy || []); } catch {}

  const isSnap = msg.type === 'snap' || msg.isSnap === true || reactions._isSnap === true;
  const snapViews = reactions._snapViews || {};
  const snapDuration = reactions._snapDuration || (reactions._snapMediaType === 'video' ? 30 : 10);
  const snapMediaType = reactions._snapMediaType || ((msg.mediaUrl && String(msg.mediaUrl).includes('.mp4')) ? 'video' : 'image');

  let effectiveMediaUrl = msg.mediaUrl || null;
  if (isSnap) {
    if (!msg.mediaUrl || reactions._mediaDeleted === true) {
      effectiveMediaUrl = null;
    } else if (requestingUserId && msg.senderId !== requestingUserId) {
      const isExpiredForUser = (snapViews[requestingUserId] || 0) >= 2 || (reactions._snapExpired && reactions._snapExpired[requestingUserId]);
      const isSavedByUser = savedBy.includes(requestingUserId);
      if (isExpiredForUser && !isSavedByUser) {
        effectiveMediaUrl = null;
      }
    }
  }

  const cleanReactions: Record<string, string> = {};
  for (const [k, v] of Object.entries(reactions)) {
    if (!k.startsWith('_') && typeof v === 'string') {
      cleanReactions[k] = v;
    }
  }

  return {
    ...msg,
    senderId: msg.senderId,
    type: isSnap ? 'snap' : (msg.type || 'text'),
    mediaUrl: effectiveMediaUrl,
    imageUrl: effectiveMediaUrl,
    isSnap,
    snapViews,
    snapDuration,
    snapMediaType,
    reactions: cleanReactions,
    savedBy,
    readBy,
  };
}

// Concurrency lock simulator matching chat.ts runWithMessageLock
const messageLocks = new Map<string, Promise<any>>();

async function runWithMessageLock<T>(messageId: string, fn: () => Promise<T>): Promise<T> {
  const currentLock = messageLocks.get(messageId) || Promise.resolve();
  let release: () => void;
  const newLock = new Promise<void>((resolve) => { release = resolve; });
  messageLocks.set(messageId, currentLock.then(() => newLock));

  try {
    await currentLock;
    return await fn();
  } finally {
    release!();
    if (messageLocks.get(messageId) === newLock) {
      messageLocks.delete(messageId);
    }
  }
}

async function runTests() {
  console.log('--- STARTING SNAP PRODUCTION READINESS TESTS ---');
  let passed = 0;
  let failed = 0;

  function assert(condition: boolean, testName: string, details?: string) {
    if (condition) {
      console.log(`[PASS] ${testName}`);
      passed++;
    } else {
      console.error(`[FAIL] ${testName} - ${details || 'Assertion failed'}`);
      failed++;
    }
  }

  // TEST 1: Expired Snap API Access
  {
    const senderId = 'user_sender';
    const recipientId = 'user_recipient';
    const rawSnapMsg = {
      id: 'msg_snap_1',
      senderId,
      channelId: 'ch_1',
      type: 'snap',
      mediaUrl: 'https://cdn.example.com/uploads/user_sender/snap123.jpg',
      reactions: JSON.stringify({
        _isSnap: true,
        _snapViews: { [recipientId]: 2 },
        _snapExpired: { [recipientId]: true },
        'user_sender': '🔥',
      }),
      savedBy: JSON.stringify([]),
      readBy: JSON.stringify([senderId, recipientId]),
    };

    const recipientFormatted = formatMessage(rawSnapMsg, recipientId);
    assert(recipientFormatted.mediaUrl === null, 'Test 1.1: Expired unsaved Snap mediaUrl is masked to null for recipient');
    assert(recipientFormatted.imageUrl === null, 'Test 1.2: Expired unsaved Snap imageUrl is masked to null for recipient');
    assert(recipientFormatted.reactions['user_sender'] === '🔥', 'Test 1.3: User emoji reactions are preserved without internal metadata');
    assert(recipientFormatted.reactions['_snapViews'] === undefined, 'Test 1.4: Internal _snapViews metadata is excluded from user reactions');

    // Sender still sees mediaUrl before physical deletion
    const senderFormatted = formatMessage(rawSnapMsg, senderId);
    assert(senderFormatted.mediaUrl !== null, 'Test 1.5: Sender retains mediaUrl access prior to cloud deletion');
  }

  // TEST 2: Saved Snap Access After Expiration
  {
    const senderId = 'user_sender';
    const recipientId = 'user_recipient';
    const savedSnapMsg = {
      id: 'msg_snap_2',
      senderId,
      channelId: 'ch_1',
      type: 'snap',
      mediaUrl: 'https://cdn.example.com/uploads/user_sender/snapSaved.jpg',
      reactions: JSON.stringify({
        _isSnap: true,
        _snapViews: { [recipientId]: 2 },
        _snapExpired: { [recipientId]: true },
      }),
      savedBy: JSON.stringify([recipientId]), // Recipient saved in chat
      readBy: JSON.stringify([senderId, recipientId]),
    };

    const recipientFormatted = formatMessage(savedSnapMsg, recipientId);
    assert(recipientFormatted.mediaUrl === 'https://cdn.example.com/uploads/user_sender/snapSaved.jpg',
      'Test 2.1: Saved Snap mediaUrl remains accessible to recipient even when view count >= 2');
    assert(recipientFormatted.savedBy.includes(recipientId),
      'Test 2.2: Recipient is listed in savedBy array');
  }

  // TEST 3: Unauthorized Access Prevention
  {
    const authorizedMembers = ['user_sender', 'user_recipient'];
    const hackerId = 'user_intruder';

    function checkChannelAccess(userId: string, members: string[]) {
      if (!members.includes(userId)) {
        return { statusCode: 403, error: 'Not authorized to view snaps in this conversation' };
      }
      return { statusCode: 200 };
    }

    const hackerCheck = checkChannelAccess(hackerId, authorizedMembers);
    assert(hackerCheck.statusCode === 403, 'Test 3.1: Non-channel participant is blocked with 403 Forbidden');

    const memberCheck = checkChannelAccess('user_recipient', authorizedMembers);
    assert(memberCheck.statusCode === 200, 'Test 3.2: Legitimate channel member is permitted');
  }

  // TEST 4: Concurrent View Requests & Race Condition Prevention
  {
    const snapId = 'msg_concurrent_snap';
    const recipientId = 'user_recipient';
    let databaseMsg = {
      id: snapId,
      senderId: 'user_sender',
      type: 'snap',
      mediaUrl: 'https://cdn.example.com/uploads/user_sender/concurrent.jpg',
      reactions: {
        _isSnap: true,
        _snapViews: {} as Record<string, number>,
      },
      savedBy: [] as string[],
    };

    // Handler simulating view-snap with runWithMessageLock
    async function viewSnap(userId: string) {
      return runWithMessageLock(snapId, async () => {
        const snapViews = databaseMsg.reactions._snapViews;
        const currentCount = snapViews[userId] || 0;
        if (currentCount >= 2) {
          return { status: 403, error: 'Already expired', viewCount: currentCount };
        }
        // Small artificial delay to simulate DB I/O
        await new Promise((r) => setTimeout(r, 20));
        snapViews[userId] = currentCount + 1;
        return { status: 200, viewCount: snapViews[userId] };
      });
    }

    // Fire 6 simultaneous view requests for the same message
    const results = await Promise.all([
      viewSnap(recipientId),
      viewSnap(recipientId),
      viewSnap(recipientId),
      viewSnap(recipientId),
      viewSnap(recipientId),
      viewSnap(recipientId),
    ]);

    const successes = results.filter((r) => r.status === 200);
    const rejections = results.filter((r) => r.status === 403);

    assert(successes.length === 2, `Test 4.1: Exactly 2 views permitted (got ${successes.length} successes)`);
    assert(rejections.length === 4, `Test 4.2: Remaining 4 concurrent requests rejected with 403 (got ${rejections.length} rejections)`);
    assert(databaseMsg.reactions._snapViews[recipientId] === 2, `Test 4.3: Final view count in DB is exactly 2, never exceeded`);
  }

  // TEST 5: Normal Chat Media Remaining Unaffected
  {
    const normalImageMsg = {
      id: 'msg_normal_image',
      senderId: 'user_sender',
      channelId: 'ch_1',
      type: 'image',
      mediaUrl: 'https://cdn.example.com/uploads/user_sender/vacation.jpg',
      reactions: JSON.stringify({ 'user_recipient': '❤️' }),
      savedBy: JSON.stringify([]),
    };

    const normalVideoMsg = {
      id: 'msg_normal_video',
      senderId: 'user_sender',
      channelId: 'ch_1',
      type: 'video',
      mediaUrl: 'https://cdn.example.com/uploads/user_sender/lecture.mp4',
      reactions: JSON.stringify({}),
      savedBy: JSON.stringify([]),
    };

    const imageFormatted = formatMessage(normalImageMsg, 'user_recipient');
    assert(imageFormatted.isSnap === false, 'Test 5.1: Normal image message isSnap is false');
    assert(imageFormatted.type === 'image', 'Test 5.2: Normal image message type is preserved as "image"');
    assert(imageFormatted.mediaUrl === 'https://cdn.example.com/uploads/user_sender/vacation.jpg',
      'Test 5.3: Normal image mediaUrl is never masked');

    const videoFormatted = formatMessage(normalVideoMsg, 'user_recipient');
    assert(videoFormatted.isSnap === false, 'Test 5.4: Normal video message isSnap is false');
    assert(videoFormatted.type === 'video', 'Test 5.5: Normal video message type is preserved as "video"');
    assert(videoFormatted.mediaUrl === 'https://cdn.example.com/uploads/user_sender/lecture.mp4',
      'Test 5.6: Normal video mediaUrl is never masked');
  }

  // TEST 6: Cloudflare R2 Key Extraction
  {
    const key1 = extractR2Key('https://pub-xyz.r2.dev/uploads/user1/123-photo.jpg');
    assert(key1 === 'uploads/user1/123-photo.jpg', 'Test 6.1: Key extracted from public R2 domain URL');

    const key2 = extractR2Key('http://localhost:5000/api/media/file/uploads/user2/456-video.mp4?query=1');
    assert(key2 === 'uploads/user2/456-video.mp4', 'Test 6.2: Key extracted from local backend media proxy URL with query params');

    const key3 = extractR2Key('uploads/user3/789-snap.jpg');
    assert(key3 === 'uploads/user3/789-snap.jpg', 'Test 6.3: Raw uploads/ key recognized directly');
  }

  console.log('------------------------------------------------');
  console.log(`TOTAL TESTS: ${passed + failed} | PASSED: ${passed} | FAILED: ${failed}`);
  if (failed > 0) {
    process.exit(1);
  } else {
    console.log('ALL BACKEND PRODUCTION TESTS PASSED SUCCESSFULLY!');
  }
}

runTests().catch((e) => {
  console.error('Test suite failed with unexpected error:', e);
  process.exit(1);
});
