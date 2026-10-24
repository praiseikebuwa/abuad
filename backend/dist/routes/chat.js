"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const auth_1 = require("../middleware/auth");
const db_1 = require("../config/db");
const aiBotService_1 = require("../services/aiBotService");
const socket_1 = require("../realtime/socket");
const cloudflare_1 = require("../config/cloudflare");
const router = (0, express_1.Router)();
// 1. In-memory Deduplication Cache for client-generated message IDs (60s TTL)
const recentClientMsgIds = new Map();
setInterval(() => {
    const cutoff = Date.now() - 60000;
    for (const [k, v] of recentClientMsgIds.entries()) {
        if (v.timestamp < cutoff)
            recentClientMsgIds.delete(k);
    }
}, 30000);
// 2. Chat Spam Velocity Protection (sliding window per user)
const userMessageTimestamps = new Map();
const userRecentTexts = new Map();
function verifyChatSpamAndRateLimit(userId, text) {
    const now = Date.now();
    let timestamps = userMessageTimestamps.get(userId) || [];
    timestamps = timestamps.filter(t => now - t < 10000); // 10s window
    if (timestamps.length >= 12) {
        return { isSpam: true, message: 'You are sending messages too quickly. Please slow down.' };
    }
    const cleanText = text.trim().toLowerCase();
    if (cleanText.length > 2) {
        let recent = userRecentTexts.get(userId) || [];
        recent.push(cleanText);
        if (recent.length > 5)
            recent.shift();
        userRecentTexts.set(userId, recent);
        const identicalCount = recent.filter(t => t === cleanText).length;
        if (identicalCount >= 4) {
            return { isSpam: true, message: 'Identical message spam detected. Please do not flood chat.' };
        }
    }
    timestamps.push(now);
    userMessageTimestamps.set(userId, timestamps);
    return { isSpam: false };
}
// Per-message async lock queue to eliminate concurrent race conditions
const messageLocks = new Map();
async function runWithMessageLock(messageId, fn) {
    const currentLock = messageLocks.get(messageId) || Promise.resolve();
    let release;
    const newLock = new Promise((resolve) => { release = resolve; });
    messageLocks.set(messageId, currentLock.then(() => newLock));
    try {
        await currentLock;
        return await fn();
    }
    finally {
        release();
        if (messageLocks.get(messageId) === newLock) {
            messageLocks.delete(messageId);
        }
    }
}
async function formatChannel(ch, currentUserId, userCache) {
    let memberIds = [];
    try {
        memberIds = typeof ch.memberIds === 'string' ? JSON.parse(ch.memberIds || '[]') : (ch.memberIds || []);
    }
    catch { }
    // Fetch all members from User table (use preloaded cache if available)
    let members = [];
    if (userCache) {
        members = memberIds.map(id => userCache.get(id)).filter(Boolean);
    }
    else {
        members = await db_1.prisma.user.findMany({
            where: { id: { in: memberIds } },
            select: { id: true, username: true, fullName: true, avatarUrl: true, verificationType: true },
        });
    }
    const memberNames = {};
    const memberAvatars = {};
    const verificationTypes = {};
    for (const m of members) {
        memberNames[m.id] = m.fullName || m.username || 'Student';
        memberAvatars[m.id] = m.avatarUrl || null;
        verificationTypes[m.id] = m.verificationType || 'none';
    }
    const isGroup = ch.type === 'group' || ch.isGroup || memberIds.length > 2;
    const otherMemberId = memberIds.find((id) => id !== currentUserId) || memberIds[0] || '';
    const otherUser = members.find((m) => m.id === otherMemberId);
    const displayName = isGroup
        ? (ch.name || 'Group Chat')
        : (otherUser ? (otherUser.fullName || otherUser.username) : (ch.name || 'Direct Message'));
    const displayAvatarUrl = isGroup
        ? null
        : (otherUser?.avatarUrl || null);
    let pinnedBy = [];
    let archivedBy = [];
    let typingUsers = {};
    try {
        pinnedBy = typeof ch.pinnedBy === 'string' ? JSON.parse(ch.pinnedBy || '[]') : (ch.pinnedBy || []);
    }
    catch { }
    try {
        archivedBy = typeof ch.archivedBy === 'string' ? JSON.parse(ch.archivedBy || '[]') : (ch.archivedBy || []);
    }
    catch { }
    try {
        typingUsers = typeof ch.typingUsers === 'string' ? JSON.parse(ch.typingUsers || '{}') : (ch.typingUsers || {});
    }
    catch { }
    return {
        id: ch.id,
        type: isGroup ? 'group' : 'direct',
        isGroup,
        name: displayName,
        displayName,
        display_name: displayName,
        displayAvatarUrl,
        display_avatar_url: displayAvatarUrl,
        memberIds,
        member_ids: memberIds,
        memberNames,
        member_names: memberNames,
        memberAvatars,
        member_avatars: memberAvatars,
        verificationTypes,
        verification_types: verificationTypes,
        adminIds: typeof ch.adminIds === 'string' ? JSON.parse(ch.adminIds || '[]') : (ch.adminIds || []),
        admin_ids: typeof ch.adminIds === 'string' ? JSON.parse(ch.adminIds || '[]') : (ch.adminIds || []),
        lastMessage: ch.lastMessage ? { content: ch.lastMessage, text: ch.lastMessage } : {},
        last_message: ch.lastMessage ? { content: ch.lastMessage, text: ch.lastMessage } : {},
        lastMessageTime: ch.lastMessageTime || ch.createdAt,
        last_message_time: ch.lastMessageTime || ch.createdAt,
        streakCount: ch.streakCount || 0,
        streak_count: ch.streakCount || 0,
        pinnedBy,
        pinned_by: pinnedBy,
        archivedBy,
        archived_by: archivedBy,
        typingUsers,
        typing_users: typingUsers,
        unreadCounts: {},
        unread_counts: {},
    };
}
function formatMessage(msg, requestingUserId) {
    let reactions = {};
    let savedBy = [];
    let readBy = [];
    try {
        reactions = typeof msg.reactions === 'string' ? JSON.parse(msg.reactions || '{}') : (msg.reactions || {});
    }
    catch { }
    try {
        savedBy = typeof msg.savedBy === 'string' ? JSON.parse(msg.savedBy || '[]') : (msg.savedBy || []);
    }
    catch { }
    try {
        readBy = typeof msg.readBy === 'string' ? JSON.parse(msg.readBy || '[]') : (msg.readBy || []);
    }
    catch { }
    let replyToId = msg.replyToId || msg.reply_to_id || null;
    let replyToContent = msg.replyToContent || msg.reply_to_content || null;
    let replyToSenderId = msg.replyToSenderId || msg.reply_to_sender_id || null;
    if (reactions._reply) {
        replyToId = replyToId || reactions._reply.id || null;
        replyToContent = replyToContent || reactions._reply.content || null;
        replyToSenderId = replyToSenderId || reactions._reply.senderId || null;
        delete reactions._reply;
    }
    const isSnap = msg.type === 'snap' || msg.isSnap === true || reactions._isSnap === true;
    const snapViews = reactions._snapViews || {};
    const snapDuration = reactions._snapDuration || (reactions._snapMediaType === 'video' ? 30 : 10);
    const snapMediaType = reactions._snapMediaType || ((msg.mediaUrl && String(msg.mediaUrl).includes('.mp4')) || (msg.text && String(msg.text).includes('Video')) ? 'video' : 'image');
    // Media masking for expired snaps:
    // If the snap has expired for the requesting recipient and is NOT saved in chat, mask mediaUrl
    let effectiveMediaUrl = msg.mediaUrl || null;
    if (isSnap) {
        if (!msg.mediaUrl || reactions._mediaDeleted === true) {
            effectiveMediaUrl = null;
        }
        else if (requestingUserId && msg.senderId !== requestingUserId) {
            const isExpiredForUser = (snapViews[requestingUserId] || 0) >= 2 || (reactions._snapExpired && reactions._snapExpired[requestingUserId]);
            const isSavedByUser = savedBy.includes(requestingUserId);
            if (isExpiredForUser && !isSavedByUser) {
                effectiveMediaUrl = null;
            }
        }
    }
    // Clean emoji reactions without internal underscore metadata
    const cleanReactions = {};
    for (const [k, v] of Object.entries(reactions)) {
        if (!k.startsWith('_') && typeof v === 'string') {
            cleanReactions[k] = v;
        }
    }
    const isRead = readBy.length > 1;
    let sharedPostId = msg.sharedPostId || msg.shared_post_id;
    if (!sharedPostId) {
        if (msg.type === 'post' && msg.mediaUrl) {
            sharedPostId = msg.mediaUrl.startsWith('post:') ? msg.mediaUrl.replace('post:', '') : msg.mediaUrl;
        }
        else if (msg.mediaUrl && typeof msg.mediaUrl === 'string' && msg.mediaUrl.startsWith('post:')) {
            sharedPostId = msg.mediaUrl.replace('post:', '');
        }
    }
    return {
        ...msg,
        senderId: msg.senderId,
        sender_id: msg.senderId,
        content: msg.text || msg.content || '',
        text: msg.text || msg.content || '',
        type: isSnap ? 'snap' : (msg.type || 'text'),
        mediaUrl: effectiveMediaUrl,
        imageUrl: effectiveMediaUrl,
        image_url: effectiveMediaUrl,
        isSnap,
        is_snap: isSnap,
        snapViews,
        snap_views: snapViews,
        snapDuration,
        snap_duration: snapDuration,
        snapMediaType,
        snap_media_type: snapMediaType,
        replyToId,
        reply_to_id: replyToId,
        replyToContent,
        reply_to_content: replyToContent,
        replyToSenderId,
        reply_to_sender_id: replyToSenderId,
        sharedPostId: sharedPostId || null,
        shared_post_id: sharedPostId || null,
        reactions: cleanReactions,
        savedBy,
        saved_by: savedBy,
        readBy,
        read_by: readBy,
        isRead,
        is_read: isRead,
        timestamp: msg.createdAt,
        created_at: msg.createdAt,
    };
}
/**
 * GET /api/chat/channels - List all channels/DMs the user is part of
 */
router.get(['/', '/channels'], auth_1.authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        // Get channels where user is a member
        const allChannels = await db_1.prisma.chatChannel.findMany({
            orderBy: { lastMessageTime: 'desc' },
            take: 100,
        });
        const userChannels = allChannels.filter(ch => {
            try {
                const members = JSON.parse(ch.memberIds);
                if (!members.includes(userId))
                    return false;
                // Hide empty direct DMs with 0 messages from the inbox
                const isGroup = ch.type === 'group' || ch.isGroup || members.length > 2;
                const hasMessage = ch.lastMessage && String(ch.lastMessage).trim().length > 0;
                if (!isGroup && !hasMessage) {
                    return false; // Skip empty direct chats without messages
                }
                return true;
            }
            catch {
                return false;
            }
        });
        // Bulk preload all unique members across all userChannels in a single query
        const allMemberIds = new Set();
        for (const ch of userChannels) {
            try {
                const ids = typeof ch.memberIds === 'string' ? JSON.parse(ch.memberIds || '[]') : (ch.memberIds || []);
                for (const id of ids)
                    allMemberIds.add(id);
            }
            catch { }
        }
        const allUsers = allMemberIds.size > 0
            ? await db_1.prisma.user.findMany({
                where: { id: { in: Array.from(allMemberIds) } },
                select: { id: true, username: true, fullName: true, avatarUrl: true, verificationType: true },
            })
            : [];
        const userCache = new Map(allUsers.map(u => [u.id, u]));
        const formattedChannels = await Promise.all(userChannels.map(ch => formatChannel(ch, userId, userCache)));
        return res.json({ success: true, data: formattedChannels });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to fetch chat channels' });
    }
});
/**
 * DELETE /api/chat/channels/:id - Delete / leave a chat channel
 */
router.delete('/channels/:id', auth_1.authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const channelId = String(req.params.id);
        const channel = await db_1.prisma.chatChannel.findUnique({
            where: { id: channelId },
        });
        if (!channel) {
            return res.status(404).json({ error: 'Channel not found' });
        }
        let memberIds = [];
        try {
            memberIds = JSON.parse(channel.memberIds);
        }
        catch {
            memberIds = [];
        }
        if (!memberIds.includes(userId)) {
            return res.status(403).json({ error: 'Not a member of this chat' });
        }
        // Delete messages and channel
        await db_1.prisma.chatMessage.deleteMany({
            where: { channelId },
        });
        await db_1.prisma.chatChannel.delete({
            where: { id: channelId },
        });
        return res.json({ success: true, message: 'Chat removed successfully' });
    }
    catch (error) {
        console.error('Error deleting channel:', error);
        return res.status(500).json({ error: 'Failed to delete channel' });
    }
});
/**
 * POST /api/chat/direct - Find or create direct DM channel with another user or AI
 */
router.post('/direct', auth_1.authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        let { targetUserId, otherUserName, otherUserAvatar } = req.body;
        if (!targetUserId) {
            return res.status(400).json({ error: 'Target user ID is required' });
        }
        // Handle AI bot alias or username lookup
        if (targetUserId === 'abuad_ai' || targetUserId === 'ai') {
            const aiUser = await (0, aiBotService_1.getOrCreateAiUser)();
            targetUserId = aiUser.id;
            otherUserName = aiUser.fullName;
            otherUserAvatar = aiUser.avatarUrl;
        }
        // Check if direct channel already exists
        const allChannels = await db_1.prisma.chatChannel.findMany({
            where: {
                type: 'direct',
            },
        });
        const existing = allChannels.find(ch => {
            try {
                const members = JSON.parse(ch.memberIds);
                return members.includes(userId) && members.includes(targetUserId) && members.length === 2;
            }
            catch {
                return false;
            }
        });
        if (existing) {
            const formatted = await formatChannel(existing, userId);
            return res.json({ success: true, data: formatted });
        }
        // Fetch other user if name/avatar not provided
        if (!otherUserName) {
            const otherUser = await db_1.prisma.user.findUnique({
                where: { id: targetUserId },
                select: { fullName: true, username: true, avatarUrl: true },
            });
            if (otherUser) {
                otherUserName = otherUser.fullName || otherUser.username;
                otherUserAvatar = otherUser.avatarUrl;
            }
        }
        // Create new direct channel
        const newChannel = await db_1.prisma.chatChannel.create({
            data: {
                name: otherUserName || 'Direct Message',
                type: 'direct',
                isGroup: false,
                memberIds: JSON.stringify([userId, targetUserId]),
            },
        });
        const formatted = await formatChannel(newChannel, userId);
        return res.status(201).json({ success: true, data: formatted });
    }
    catch (error) {
        console.error('Error creating direct chat channel:', error);
        return res.status(500).json({ error: 'Failed to create direct channel' });
    }
});
/**
 * POST /api/chat/channels - Create a new channel or DM
 */
router.post('/channels', auth_1.authenticateToken, async (req, res) => {
    try {
        const { name, type, memberIds, isGroup } = req.body;
        const allMemberIds = [...new Set([req.user.id, ...(memberIds || [])])];
        const channel = await db_1.prisma.chatChannel.create({
            data: {
                name: name || null,
                type: type || (allMemberIds.length > 2 ? 'group' : 'direct'),
                isGroup: isGroup || allMemberIds.length > 2,
                memberIds: JSON.stringify(allMemberIds),
            },
        });
        const formatted = await formatChannel(channel, req.user.id);
        (0, socket_1.emitToUsers)(allMemberIds, 'channel:updated', { channelId: channel.id });
        return res.status(201).json({ success: true, data: formatted });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to create channel' });
    }
});
/**
 * GET /api/chat/channels/:id - Get single channel info
 */
router.get('/channels/:id', auth_1.authenticateToken, async (req, res) => {
    try {
        const channel = await db_1.prisma.chatChannel.findUnique({ where: { id: String(req.params.id) } });
        if (!channel)
            return res.status(404).json({ error: 'Channel not found' });
        const formatted = await formatChannel(channel, req.user.id);
        return res.json({ success: true, data: formatted });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to fetch channel' });
    }
});
/**
 * PATCH /api/chat/channels/:id - Update channel settings
 */
router.patch('/channels/:id', auth_1.authenticateToken, async (req, res) => {
    try {
        const { name, restrictMessaging, restrictInfoUpdates } = req.body;
        const channel = await db_1.prisma.chatChannel.update({
            where: { id: String(req.params.id) },
            data: {
                ...(name !== undefined && { name }),
                ...(restrictMessaging !== undefined && { restrictMessaging }),
                ...(restrictInfoUpdates !== undefined && { restrictInfoUpdates }),
            },
        });
        const formatted = await formatChannel(channel, req.user.id);
        (0, socket_1.emitToChannel)(channel.id, 'channel:updated', {});
        return res.json({ success: true, data: formatted });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to update channel' });
    }
});
/**
 * POST /api/chat/channels/:id/members - Add members to group channel
 */
router.post('/channels/:id/members', auth_1.authenticateToken, async (req, res) => {
    try {
        const channelId = String(req.params.id);
        const { userIds } = req.body;
        if (!Array.isArray(userIds) || userIds.length === 0) {
            return res.status(400).json({ error: 'User IDs array is required' });
        }
        const channel = await db_1.prisma.chatChannel.findUnique({ where: { id: channelId } });
        if (!channel)
            return res.status(404).json({ error: 'Channel not found' });
        let memberIds = [];
        try {
            memberIds = JSON.parse(channel.memberIds || '[]');
        }
        catch { }
        const newMembers = userIds.filter((id) => !memberIds.includes(id));
        if (newMembers.length === 0) {
            const formatted = await formatChannel(channel, req.user.id);
            return res.json({ success: true, data: formatted, addedCount: 0 });
        }
        const updatedMemberIds = [...memberIds, ...newMembers];
        // Fetch added users' names for system notification
        const addedUsers = await db_1.prisma.user.findMany({
            where: { id: { in: newMembers } },
            select: { id: true, fullName: true, username: true }
        });
        const addedNames = addedUsers.map(u => u.fullName || u.username).join(', ');
        const updatedChannel = await db_1.prisma.chatChannel.update({
            where: { id: channelId },
            data: {
                memberIds: JSON.stringify(updatedMemberIds),
                lastMessage: `${req.user?.fullName || req.user?.username || 'Admin'} added ${addedNames || `${newMembers.length} member(s)`}`,
                lastMessageTime: new Date(),
            }
        });
        // Create system message for transparency
        const systemMsg = await db_1.prisma.chatMessage.create({
            data: {
                senderId: req.user.id,
                channelId,
                text: `📌 ${req.user?.fullName || req.user?.username || 'Admin'} added ${addedNames || `${newMembers.length} member(s)`} to the group.`,
                type: 'system',
            },
            include: {
                sender: { select: { id: true, username: true, fullName: true, avatarUrl: true } }
            }
        });
        const formattedSystemMsg = formatMessage(systemMsg);
        (0, socket_1.emitToChannel)(channelId, 'message:new', { message: formattedSystemMsg });
        (0, socket_1.emitToChannel)(channelId, 'channel:updated', { memberIds: updatedMemberIds });
        (0, socket_1.emitToUsers)(updatedMemberIds, 'channel:updated', { channelId });
        const formatted = await formatChannel(updatedChannel, req.user.id);
        return res.json({ success: true, data: formatted, addedCount: newMembers.length });
    }
    catch (error) {
        console.error('Error adding members to channel:', error);
        return res.status(500).json({ error: 'Failed to add members' });
    }
});
/**
 * DELETE /api/chat/channels/:id/members/:userId - Remove member or leave group
 */
router.delete('/channels/:id/members/:userId', auth_1.authenticateToken, async (req, res) => {
    try {
        const channelId = String(req.params.id);
        const targetUserId = String(req.params.userId);
        const channel = await db_1.prisma.chatChannel.findUnique({ where: { id: channelId } });
        if (!channel)
            return res.status(404).json({ error: 'Channel not found' });
        let memberIds = [];
        try {
            memberIds = JSON.parse(channel.memberIds || '[]');
        }
        catch { }
        if (!memberIds.includes(targetUserId)) {
            return res.status(400).json({ error: 'User is not in this group' });
        }
        const updatedMemberIds = memberIds.filter(id => id !== targetUserId);
        const targetUser = await db_1.prisma.user.findUnique({
            where: { id: targetUserId },
            select: { fullName: true, username: true }
        });
        const targetName = targetUser?.fullName || targetUser?.username || 'Member';
        const isSelfLeave = targetUserId === req.user.id;
        const actionText = isSelfLeave
            ? `👋 ${targetName} left the group.`
            : `🚫 ${req.user?.fullName || req.user?.username || 'Admin'} removed ${targetName} from the group.`;
        const updatedChannel = await db_1.prisma.chatChannel.update({
            where: { id: channelId },
            data: {
                memberIds: JSON.stringify(updatedMemberIds),
                lastMessage: actionText,
                lastMessageTime: new Date(),
            }
        });
        const systemMsg = await db_1.prisma.chatMessage.create({
            data: {
                senderId: req.user.id,
                channelId,
                text: actionText,
                type: 'system',
            },
            include: {
                sender: { select: { id: true, username: true, fullName: true, avatarUrl: true } }
            }
        });
        (0, socket_1.emitToChannel)(channelId, 'message:new', { message: formatMessage(systemMsg) });
        (0, socket_1.emitToChannel)(channelId, 'channel:updated', { memberIds: updatedMemberIds });
        (0, socket_1.emitToUsers)(memberIds, 'channel:updated', { channelId });
        return res.json({ success: true, data: await formatChannel(updatedChannel, req.user.id) });
    }
    catch (error) {
        console.error('Error removing member from channel:', error);
        return res.status(500).json({ error: 'Failed to remove member' });
    }
});
/**
 * POST /api/chat/channels/:id/wallpaper - Update group wallpaper
 */
router.post('/channels/:id/wallpaper', auth_1.authenticateToken, async (req, res) => {
    try {
        const channelId = String(req.params.id);
        const { wallpaperUrl } = req.body;
        const channel = await db_1.prisma.chatChannel.findUnique({ where: { id: channelId } });
        if (!channel)
            return res.status(404).json({ error: 'Channel not found' });
        // Store wallpaper in metadata or update channel
        (0, socket_1.emitToChannel)(channelId, 'channel:wallpaper_updated', { channelId, wallpaperUrl });
        return res.json({ success: true, wallpaperUrl });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to update wallpaper' });
    }
});
/**
 * POST /api/chat/channels/:id/pin - Pin/unpin a channel
 */
router.post('/channels/:id/pin', auth_1.authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const channel = await db_1.prisma.chatChannel.findUnique({ where: { id: String(req.params.id) } });
        if (!channel)
            return res.status(404).json({ error: 'Channel not found' });
        let pinnedBy = [];
        try {
            pinnedBy = JSON.parse(channel.pinnedBy);
        }
        catch { }
        const isPinned = pinnedBy.includes(userId);
        const updatedPinnedBy = isPinned ? pinnedBy.filter(id => id !== userId) : [...pinnedBy, userId];
        await db_1.prisma.chatChannel.update({
            where: { id: String(req.params.id) },
            data: { pinnedBy: JSON.stringify(updatedPinnedBy) },
        });
        return res.json({ success: true, isPinned: !isPinned });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to pin/unpin channel' });
    }
});
/**
 * POST /api/chat/channels/:id/archive - Archive/unarchive a channel
 */
router.post('/channels/:id/archive', auth_1.authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const channel = await db_1.prisma.chatChannel.findUnique({ where: { id: String(req.params.id) } });
        if (!channel)
            return res.status(404).json({ error: 'Channel not found' });
        let archivedBy = [];
        try {
            archivedBy = JSON.parse(channel.archivedBy);
        }
        catch { }
        const isArchived = archivedBy.includes(userId);
        const updatedArchivedBy = isArchived ? archivedBy.filter(id => id !== userId) : [...archivedBy, userId];
        await db_1.prisma.chatChannel.update({
            where: { id: String(req.params.id) },
            data: { archivedBy: JSON.stringify(updatedArchivedBy) },
        });
        return res.json({ success: true, isArchived: !isArchived });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to archive/unarchive channel' });
    }
});
/**
 * POST /api/chat/channels/:id/read - Mark messages as read by current user
 */
router.post('/channels/:id/read', auth_1.authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const channelId = String(req.params.id);
        const messages = await db_1.prisma.chatMessage.findMany({
            where: { channelId },
        });
        for (const msg of messages) {
            let readBy = [];
            try {
                readBy = JSON.parse(msg.readBy);
            }
            catch { }
            if (!readBy.includes(userId)) {
                readBy.push(userId);
                await db_1.prisma.chatMessage.update({
                    where: { id: msg.id },
                    data: { readBy: JSON.stringify(readBy) },
                });
            }
        }
        (0, socket_1.emitToChannel)(channelId, 'messages:read', { userId });
        return res.json({ success: true });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to mark channel as read' });
    }
});
/**
 * DELETE /api/chat/channels/:id - Delete/clear conversation
 */
router.delete('/channels/:id', auth_1.authenticateToken, async (req, res) => {
    try {
        const channelId = String(req.params.id);
        const channel = await db_1.prisma.chatChannel.findUnique({ where: { id: channelId } });
        if (!channel)
            return res.status(404).json({ error: 'Channel not found' });
        // Notify members before the channel (and its member list) is removed
        let memberIds = [];
        try {
            memberIds = JSON.parse(channel.memberIds || '[]');
        }
        catch { }
        // Delete associated messages
        await db_1.prisma.chatMessage.deleteMany({
            where: { channelId },
        });
        // Delete channel
        await db_1.prisma.chatChannel.delete({
            where: { id: channelId },
        });
        (0, socket_1.emitToUsers)(memberIds, 'channel:updated', { channelId, deleted: true });
        return res.json({ success: true, message: 'Channel deleted successfully' });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to delete channel' });
    }
});
/**
 * DELETE /api/chat/channels/:id/messages - Clear all messages in channel
 */
router.delete('/channels/:id/messages', auth_1.authenticateToken, async (req, res) => {
    try {
        const channelId = String(req.params.id);
        await db_1.prisma.chatMessage.deleteMany({
            where: { channelId },
        });
        await db_1.prisma.chatChannel.update({
            where: { id: channelId },
            data: { lastMessage: null, lastMessageTime: null },
        });
        (0, socket_1.emitToChannel)(channelId, 'channel:updated', { cleared: true });
        return res.json({ success: true, message: 'Messages cleared successfully' });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to clear messages' });
    }
});
/**
 * GET /api/chat/messages - Get messages for a channel or DM
 */
router.get('/messages', auth_1.authenticateToken, async (req, res) => {
    try {
        const channelId = req.query.channelId ? String(req.query.channelId) : undefined;
        const receiverId = req.query.receiverId ? String(req.query.receiverId) : undefined;
        const limit = req.query.limit ? String(req.query.limit) : undefined;
        const userId = req.user.id;
        const msgLimit = Number(limit) || 150;
        let targetChannelId = channelId;
        if (receiverId) {
            // Find or create a direct channel between the two users
            const allChannels = await db_1.prisma.chatChannel.findMany({
                where: { type: 'direct' },
            });
            const dmChannel = allChannels.find(ch => {
                try {
                    const members = JSON.parse(ch.memberIds);
                    return members.includes(userId) && members.includes(String(receiverId)) && members.length === 2;
                }
                catch {
                    return false;
                }
            });
            if (dmChannel) {
                targetChannelId = dmChannel.id;
            }
        }
        if (targetChannelId) {
            const channel = await db_1.prisma.chatChannel.findUnique({
                where: { id: String(targetChannelId) },
                select: { memberIds: true },
            });
            if (!channel)
                return res.status(404).json({ error: 'Channel not found' });
            let memberIds = [];
            try {
                memberIds = JSON.parse(channel.memberIds || '[]');
            }
            catch { }
            if (!memberIds.includes(userId)) {
                return res.status(403).json({ error: 'Not authorized to view messages in this conversation' });
            }
            const messages = await db_1.prisma.chatMessage.findMany({
                where: { channelId: String(targetChannelId), isDeleted: false },
                orderBy: { createdAt: 'asc' },
                take: msgLimit,
                include: {
                    sender: { select: { id: true, username: true, fullName: true, avatarUrl: true } },
                },
            });
            const formatted = messages.map((m) => formatMessage(m, userId));
            return res.json({ success: true, data: formatted });
        }
        return res.json({ success: true, data: [] });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to fetch messages' });
    }
});
/**
 * POST /api/chat/send - Send a message
 */
router.post('/send', auth_1.authenticateToken, async (req, res) => {
    try {
        const { clientMsgId, receiverId, channelId, text, mediaUrl, type, sharedPostId, replyToId, replyToContent, replyToSenderId, isSnap, duration, mediaType } = req.body;
        if (!text && !mediaUrl && !sharedPostId) {
            return res.status(400).json({ error: 'Message content or media required' });
        }
        // 1. Deduplication: Return existing message if clientMsgId was already processed
        if (clientMsgId && recentClientMsgIds.has(clientMsgId)) {
            const cached = recentClientMsgIds.get(clientMsgId);
            return res.status(200).json({ success: true, data: cached.message, duplicatePrevented: true });
        }
        // 2. Chat Spam Velocity Protection (sliding window)
        const spamCheck = verifyChatSpamAndRateLimit(req.user.id, text || '');
        if (spamCheck.isSpam) {
            return res.status(429).json({ error: spamCheck.message, code: 'CHAT_RATE_LIMITED' });
        }
        // 3. Community Safety & Toxicity Check
        if (text) {
            const safetyCheck = (0, aiBotService_1.isContentInappropriate)(text);
            if (safetyCheck.flagged) {
                return res.status(400).json({ error: safetyCheck.reason, code: 'CHAT_SAFETY_VIOLATION' });
            }
        }
        let targetChannelId = channelId;
        let inferredReceiverId = receiverId;
        if (!inferredReceiverId && channelId && channelId.startsWith('channel_')) {
            inferredReceiverId = channelId.replace('channel_', '');
        }
        const effectiveSharedPostId = sharedPostId || (type === 'post' && mediaUrl ? String(mediaUrl).replace('post:', '') : null);
        const isSnapMessage = Boolean(isSnap || type === 'snap');
        const effectiveType = effectiveSharedPostId ? 'post' : (isSnapMessage ? 'snap' : (type || 'text'));
        const effectiveMediaUrl = mediaUrl || (effectiveSharedPostId ? `post:${effectiveSharedPostId}` : null);
        const effectiveText = text || (effectiveSharedPostId ? 'Shared a post with you' : (isSnapMessage ? '📸 Snap' : ''));
        const initialReactions = {};
        if (replyToId) {
            initialReactions._reply = {
                id: replyToId,
                content: replyToContent || '',
                senderId: replyToSenderId || '',
            };
        }
        if (isSnapMessage) {
            initialReactions._isSnap = true;
            initialReactions._snapViews = {};
            const inferredMediaType = mediaType || (type === 'video' || (mediaUrl && String(mediaUrl).endsWith('.mp4')) || (text && String(text).includes('Video')) ? 'video' : 'image');
            initialReactions._snapMediaType = inferredMediaType;
            initialReactions._snapDuration = duration || (inferredMediaType === 'video' ? 30 : 10);
        }
        const lastMsgSummary = isSnapMessage
            ? (initialReactions._snapMediaType === 'video' ? '🎥 Video Snap' : '📸 Snap')
            : (effectiveType === 'post' ? '📎 Shared a post' : (effectiveText || '📎 Media'));
        const userId = req.user.id;
        if (inferredReceiverId && inferredReceiverId !== userId) {
            const allChannels = await db_1.prisma.chatChannel.findMany({ where: { type: 'direct' } });
            const existing = allChannels.find(ch => {
                try {
                    const members = JSON.parse(ch.memberIds);
                    return members.includes(userId) && members.includes(inferredReceiverId) && members.length === 2;
                }
                catch {
                    return false;
                }
            });
            if (existing) {
                targetChannelId = existing.id;
            }
            else {
                const otherUser = await db_1.prisma.user.findUnique({
                    where: { id: inferredReceiverId },
                    select: { fullName: true, username: true, avatarUrl: true },
                });
                const newChannel = await db_1.prisma.chatChannel.create({
                    data: {
                        id: channelId && !channelId.startsWith('channel_') ? channelId : undefined,
                        name: otherUser ? (otherUser.fullName || otherUser.username) : 'Direct Message',
                        type: 'direct',
                        isGroup: false,
                        memberIds: JSON.stringify([userId, inferredReceiverId]),
                        lastMessage: lastMsgSummary,
                        lastMessageTime: new Date(),
                    },
                });
                targetChannelId = newChannel.id;
            }
        }
        else if (targetChannelId) {
            const existingChannel = await db_1.prisma.chatChannel.findUnique({ where: { id: targetChannelId } });
            if (!existingChannel) {
                await db_1.prisma.chatChannel.create({
                    data: {
                        id: targetChannelId,
                        type: 'direct',
                        isGroup: false,
                        memberIds: JSON.stringify([userId]),
                        lastMessage: lastMsgSummary,
                        lastMessageTime: new Date(),
                    },
                });
            }
        }
        if (!targetChannelId) {
            return res.status(400).json({ error: 'Channel or receiver required' });
        }
        const message = await db_1.prisma.chatMessage.create({
            data: {
                senderId: req.user.id,
                channelId: targetChannelId,
                text: effectiveText,
                mediaUrl: effectiveMediaUrl,
                type: effectiveType,
                reactions: JSON.stringify(initialReactions),
            },
            include: {
                sender: { select: { id: true, username: true, fullName: true, avatarUrl: true } },
            },
        });
        try {
            await db_1.prisma.chatChannel.update({
                where: { id: targetChannelId },
                data: {
                    lastMessage: lastMsgSummary,
                    lastMessageTime: new Date(),
                },
            });
        }
        catch (_) { }
        const formattedMessage = formatMessage(message);
        // Save to clientMsgId idempotency cache
        if (clientMsgId && typeof clientMsgId === 'string') {
            recentClientMsgIds.set(clientMsgId, { message: formattedMessage, timestamp: Date.now() });
        }
        // Push to all channel members in real time (sender's other devices included)
        (0, socket_1.emitToChannel)(targetChannelId, 'message:new', { message: formattedMessage });
        // Asynchronously check and trigger AI response if chatting with ABUAD AI
        try {
            const aiUser = await (0, aiBotService_1.getOrCreateAiUser)();
            let shouldTriggerAi = false;
            let isGroup = false;
            let groupName = 'ABUAD Campus Group';
            if (inferredReceiverId === aiUser.id || inferredReceiverId === 'abuad_ai') {
                // Direct 1-on-1 chat with AI
                shouldTriggerAi = true;
            }
            else if (targetChannelId) {
                const ch = await db_1.prisma.chatChannel.findUnique({ where: { id: targetChannelId } });
                if (ch) {
                    isGroup = ch.isGroup || ch.type === 'group';
                    groupName = ch.name || 'ABUAD Campus Group';
                    let members = [];
                    try {
                        members = JSON.parse(ch.memberIds || '[]');
                    }
                    catch { }
                    const aiInChannel = members.includes(aiUser.id) || members.includes('abuad_ai');
                    if (aiInChannel) {
                        if (!isGroup) {
                            // Direct channel with AI
                            shouldTriggerAi = true;
                        }
                        else {
                            // Group channel: ONLY respond if tagged/mentioned OR replied to Abuad AI!
                            const hasTag = (0, aiBotService_1.containsAiMention)(text || '');
                            const isReplyingToAi = replyToSenderId === aiUser.id;
                            if (hasTag || isReplyingToAi) {
                                shouldTriggerAi = true;
                            }
                        }
                    }
                }
            }
            if (shouldTriggerAi && req.user.id !== aiUser.id) {
                // Trigger conversational reply after 400ms
                setTimeout(() => {
                    (0, aiBotService_1.triggerAiDirectChatReply)(targetChannelId, text || (effectiveMediaUrl ? 'Shared media' : 'Hello'), mediaUrl || undefined, req.user?.fullName || req.user?.username || 'User', {
                        replyToMessageId: message.id,
                        replyToContent: text || 'Tagged message',
                        isGroup,
                        groupName,
                    }).catch(e => console.error('AI direct chat reply error:', e));
                }, 400);
            }
        }
        catch (e) {
            console.error('Error checking AI channel:', e);
        }
        return res.status(201).json({ success: true, data: formattedMessage });
    }
    catch (error) {
        console.error('Error sending chat message:', error);
        return res.status(500).json({ error: 'Failed to send message' });
    }
});
/**
 * PATCH /api/chat/messages/:id - Edit a message
 */
router.patch('/messages/:id', auth_1.authenticateToken, async (req, res) => {
    try {
        const { text } = req.body;
        const msg = await db_1.prisma.chatMessage.findUnique({ where: { id: String(req.params.id) } });
        if (!msg)
            return res.status(404).json({ error: 'Message not found' });
        if (msg.senderId !== req.user.id)
            return res.status(403).json({ error: 'Not authorized' });
        const updated = await db_1.prisma.chatMessage.update({ where: { id: String(req.params.id) }, data: { text, isEdited: true } });
        const formattedUpdated = formatMessage(updated);
        (0, socket_1.emitToChannel)(updated.channelId, 'message:updated', { message: formattedUpdated });
        return res.json({ success: true, data: formattedUpdated });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to edit message' });
    }
});
/**
 * DELETE /api/chat/messages/:id - Delete a message
 */
router.delete('/messages/:id', auth_1.authenticateToken, async (req, res) => {
    try {
        const msg = await db_1.prisma.chatMessage.findUnique({ where: { id: String(req.params.id) } });
        if (!msg)
            return res.status(404).json({ error: 'Message not found' });
        if (msg.senderId !== req.user.id)
            return res.status(403).json({ error: 'Not authorized' });
        await db_1.prisma.chatMessage.update({ where: { id: String(req.params.id) }, data: { isDeleted: true, text: 'This message was deleted' } });
        (0, socket_1.emitToChannel)(msg.channelId, 'message:deleted', { messageId: msg.id });
        return res.json({ success: true });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to delete message' });
    }
});
/**
 * POST /api/chat/messages/:id/reaction - React to a message
 */
router.post('/messages/:id/reaction', auth_1.authenticateToken, async (req, res) => {
    const messageId = String(req.params.id);
    return runWithMessageLock(messageId, async () => {
        try {
            const { emoji } = req.body;
            const userId = req.user.id;
            const msg = await db_1.prisma.chatMessage.findUnique({ where: { id: messageId } });
            if (!msg)
                return res.status(404).json({ error: 'Message not found' });
            let reactions = {};
            try {
                reactions = JSON.parse(msg.reactions);
            }
            catch { }
            if (reactions[userId] === emoji) {
                delete reactions[userId]; // toggle off
            }
            else {
                reactions[userId] = emoji;
            }
            const updated = await db_1.prisma.chatMessage.update({
                where: { id: messageId },
                data: { reactions: JSON.stringify(reactions) },
            });
            const channel = await db_1.prisma.chatChannel.findUnique({
                where: { id: updated.channelId },
                select: { memberIds: true },
            });
            let members = [];
            try {
                members = JSON.parse(channel?.memberIds || '[]');
            }
            catch { }
            for (const mId of members) {
                const memberFormatted = formatMessage(updated, mId);
                (0, socket_1.emitToUsers)([mId], 'message:updated', { message: memberFormatted });
            }
            const formattedReaction = formatMessage(updated, userId);
            return res.json({ success: true, data: formattedReaction });
        }
        catch (error) {
            return res.status(500).json({ error: 'Failed to react to message' });
        }
    });
});
/**
 * POST /api/chat/messages/:id/save - Toggle save snap/message in chat
 */
router.post('/messages/:id/save', auth_1.authenticateToken, async (req, res) => {
    const messageId = String(req.params.id);
    return runWithMessageLock(messageId, async () => {
        try {
            const userId = req.user.id;
            const msg = await db_1.prisma.chatMessage.findUnique({
                where: { id: messageId },
            });
            if (!msg)
                return res.status(404).json({ error: 'Message not found' });
            // Authorization: User must be a participant in the conversation
            const channel = await db_1.prisma.chatChannel.findUnique({
                where: { id: msg.channelId },
                select: { memberIds: true },
            });
            let members = [];
            try {
                members = JSON.parse(channel?.memberIds || '[]');
            }
            catch { }
            if (!members.includes(userId) && msg.senderId !== userId) {
                return res.status(403).json({ error: 'Not authorized to save messages in this conversation' });
            }
            let reactions = {};
            try {
                reactions = typeof msg.reactions === 'string' ? JSON.parse(msg.reactions || '{}') : (msg.reactions || {});
            }
            catch { }
            const isSnap = msg.type === 'snap' || reactions._isSnap === true;
            let savedBy = [];
            try {
                savedBy = JSON.parse(msg.savedBy);
            }
            catch { }
            const isSaved = savedBy.includes(userId);
            // Prevent saving an already expired Snap whose media is deleted or expired
            if (isSnap && !isSaved) {
                const snapViews = reactions._snapViews || {};
                const viewCount = snapViews[userId] || 0;
                if (viewCount >= 2 || reactions._mediaDeleted === true || !msg.mediaUrl) {
                    return res.status(400).json({ error: 'Cannot save an expired Snap' });
                }
            }
            if (isSaved) {
                savedBy = savedBy.filter((id) => id !== userId);
            }
            else {
                savedBy.push(userId);
            }
            let mediaUrlToPersist = msg.mediaUrl;
            // If someone unsaved, and now NO ONE has it saved, and it's already expired for the recipient:
            if (isSnap && isSaved && savedBy.length === 0) {
                const snapViews = reactions._snapViews || {};
                const recipientMemberId = members.find((m) => m !== msg.senderId) || '';
                const recipientViewCount = snapViews[recipientMemberId] || 0;
                if (recipientViewCount >= 2 && msg.mediaUrl) {
                    const r2Key = (0, cloudflare_1.extractR2Key)(msg.mediaUrl);
                    if (r2Key) {
                        const deleted = await (0, cloudflare_1.deleteR2Object)(r2Key);
                        if (deleted) {
                            reactions._mediaDeleted = true;
                            mediaUrlToPersist = null;
                        }
                    }
                }
            }
            const updated = await db_1.prisma.chatMessage.update({
                where: { id: messageId },
                data: {
                    savedBy: JSON.stringify(savedBy),
                    reactions: JSON.stringify(reactions),
                    mediaUrl: mediaUrlToPersist,
                },
            });
            for (const mId of members) {
                const memberFormatted = formatMessage(updated, mId);
                (0, socket_1.emitToUsers)([mId], 'message:updated', { message: memberFormatted });
            }
            if (!isSaved) {
                const saver = await db_1.prisma.user.findUnique({
                    where: { id: userId },
                    select: { fullName: true, username: true },
                });
                (0, socket_1.emitToChannel)(updated.channelId, 'snap:saved', {
                    messageId: updated.id,
                    savedBy: userId,
                    saverName: saver?.fullName || saver?.username || 'A member',
                });
            }
            const formatted = formatMessage(updated, userId);
            return res.json({ success: true, data: formatted });
        }
        catch (error) {
            console.error('Failed to toggle save message:', error);
            return res.status(500).json({ error: 'Failed to toggle save message' });
        }
    });
});
/**
 * POST /api/chat/messages/:id/view-snap - Mark snap message as viewed
 */
router.post('/messages/:id/view-snap', auth_1.authenticateToken, async (req, res) => {
    const messageId = String(req.params.id);
    return runWithMessageLock(messageId, async () => {
        try {
            const userId = req.user.id;
            const msg = await db_1.prisma.chatMessage.findUnique({
                where: { id: messageId },
                include: {
                    sender: { select: { id: true, username: true, fullName: true, avatarUrl: true } },
                },
            });
            if (!msg)
                return res.status(404).json({ error: 'Message not found' });
            // 1. Authorization: user must be sender or an authorized channel member
            const channel = await db_1.prisma.chatChannel.findUnique({
                where: { id: msg.channelId },
                select: { memberIds: true },
            });
            let members = [];
            try {
                members = JSON.parse(channel?.memberIds || '[]');
            }
            catch { }
            if (!members.includes(userId) && msg.senderId !== userId) {
                return res.status(403).json({ error: 'Not authorized to view snaps in this conversation' });
            }
            // 2. Validate that message is actually a snap
            let reactions = {};
            try {
                reactions = typeof msg.reactions === 'string' ? JSON.parse(msg.reactions || '{}') : (msg.reactions || {});
            }
            catch { }
            const isSnap = msg.type === 'snap' || reactions._isSnap === true;
            if (!isSnap) {
                return res.status(400).json({ error: 'Message is not a Snap' });
            }
            const snapViews = reactions._snapViews || {};
            const currentCount = snapViews[userId] || 0;
            // 3. Server-side Replay Limit:
            // If recipient has already exhausted both views (initial view + 1 replay), strictly reject
            if (userId !== msg.senderId) {
                if (currentCount >= 2) {
                    return res.status(403).json({
                        error: 'This Snap has already expired and cannot be replayed again',
                        expired: true,
                        viewCount: currentCount,
                    });
                }
                // Increment view count: view 1 = 1, replay = 2
                snapViews[userId] = currentCount + 1;
                reactions._snapViews = snapViews;
                if (snapViews[userId] >= 2) {
                    reactions._snapExpired = reactions._snapExpired || {};
                    reactions._snapExpired[userId] = true;
                }
            }
            let readBy = [];
            try {
                readBy = JSON.parse(msg.readBy);
            }
            catch { }
            if (!readBy.includes(userId)) {
                readBy.push(userId);
            }
            // 4. Check for Cloudflare R2 media deletion if fully expired and unsaved:
            let savedBy = [];
            try {
                savedBy = JSON.parse(msg.savedBy);
            }
            catch { }
            let mediaUrlToPersist = msg.mediaUrl;
            const isRecipientExpired = userId !== msg.senderId && snapViews[userId] >= 2;
            const isUnsaved = savedBy.length === 0;
            if (isRecipientExpired && isUnsaved && msg.mediaUrl) {
                const r2Key = (0, cloudflare_1.extractR2Key)(msg.mediaUrl);
                if (r2Key) {
                    const deleted = await (0, cloudflare_1.deleteR2Object)(r2Key);
                    if (deleted) {
                        reactions._mediaDeleted = true;
                        mediaUrlToPersist = null;
                    }
                }
            }
            const updated = await db_1.prisma.chatMessage.update({
                where: { id: messageId },
                data: {
                    mediaUrl: mediaUrlToPersist,
                    readBy: JSON.stringify(readBy),
                    reactions: JSON.stringify(reactions),
                },
                include: {
                    sender: { select: { id: true, username: true, fullName: true, avatarUrl: true } },
                },
            });
            // Also update channel last message summary
            try {
                await db_1.prisma.chatChannel.update({
                    where: { id: updated.channelId },
                    data: {
                        lastMessage: (snapViews[userId] || 0) >= 2 ? 'Opened Snap' : 'Opened · Replay available',
                    },
                });
            }
            catch (_) { }
            // Emit real-time updates tailored to each member's permissions
            for (const mId of members) {
                const memberFormatted = formatMessage(updated, mId);
                (0, socket_1.emitToUsers)([mId], 'message:updated', { message: memberFormatted });
            }
            const formatted = formatMessage(updated, userId);
            return res.json({ success: true, data: formatted });
        }
        catch (error) {
            console.error('Failed to mark snap viewed:', error);
            return res.status(500).json({ error: 'Failed to mark snap viewed' });
        }
    });
});
exports.default = router;
