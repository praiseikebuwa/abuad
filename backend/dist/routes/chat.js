"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const auth_1 = require("../middleware/auth");
const db_1 = require("../config/db");
const aiBotService_1 = require("../services/aiBotService");
const socket_1 = require("../realtime/socket");
const router = (0, express_1.Router)();
async function formatChannel(ch, currentUserId) {
    let memberIds = [];
    try {
        memberIds = typeof ch.memberIds === 'string' ? JSON.parse(ch.memberIds || '[]') : (ch.memberIds || []);
    }
    catch { }
    // Fetch all members from User table
    const members = await db_1.prisma.user.findMany({
        where: { id: { in: memberIds } },
        select: { id: true, username: true, fullName: true, avatarUrl: true, verificationType: true },
    });
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
function formatMessage(msg) {
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
        mediaUrl: msg.mediaUrl || null,
        imageUrl: msg.mediaUrl || null,
        image_url: msg.mediaUrl || null,
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
        reactions,
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
        const formattedChannels = await Promise.all(userChannels.map(ch => formatChannel(ch, userId)));
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
            const messages = await db_1.prisma.chatMessage.findMany({
                where: { channelId: String(targetChannelId), isDeleted: false },
                orderBy: { createdAt: 'asc' },
                take: msgLimit,
                include: {
                    sender: { select: { id: true, username: true, fullName: true, avatarUrl: true } },
                },
            });
            const formatted = messages.map(formatMessage);
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
        const { receiverId, channelId, text, mediaUrl, type, sharedPostId, replyToId, replyToContent, replyToSenderId, isSnap, duration, mediaType } = req.body;
        if (!text && !mediaUrl && !sharedPostId) {
            return res.status(400).json({ error: 'Message content or media required' });
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
        // Push to all channel members in real time (sender's other devices included)
        (0, socket_1.emitToChannel)(targetChannelId, 'message:new', { message: formattedMessage });
        // Asynchronously check and trigger AI response if chatting with ABUAD AI
        try {
            const aiUser = await (0, aiBotService_1.getOrCreateAiUser)();
            let isAiChannel = false;
            if (inferredReceiverId === aiUser.id || inferredReceiverId === 'abuad_ai') {
                isAiChannel = true;
            }
            else if (targetChannelId) {
                const ch = await db_1.prisma.chatChannel.findUnique({ where: { id: targetChannelId } });
                if (ch) {
                    try {
                        const members = JSON.parse(ch.memberIds);
                        if (members.includes(aiUser.id) || members.includes('abuad_ai')) {
                            isAiChannel = true;
                        }
                    }
                    catch { }
                }
            }
            if (isAiChannel && req.user.id !== aiUser.id) {
                // Trigger conversational reply after 400ms
                setTimeout(() => {
                    (0, aiBotService_1.triggerAiDirectChatReply)(targetChannelId, text || 'Shared media', mediaUrl, req.user?.fullName || req.user?.username || 'User').catch(e => console.error('AI direct chat reply error:', e));
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
    try {
        const { emoji } = req.body;
        const userId = req.user.id;
        const msg = await db_1.prisma.chatMessage.findUnique({ where: { id: String(req.params.id) } });
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
            where: { id: String(req.params.id) },
            data: { reactions: JSON.stringify(reactions) },
        });
        const formattedReaction = formatMessage(updated);
        (0, socket_1.emitToChannel)(updated.channelId, 'message:updated', { message: formattedReaction });
        return res.json({ success: true, data: formattedReaction });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to react to message' });
    }
});
/**
 * POST /api/chat/messages/:id/save - Toggle save snap/message in chat
 */
router.post('/messages/:id/save', auth_1.authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const msg = await db_1.prisma.chatMessage.findUnique({
            where: { id: String(req.params.id) },
        });
        if (!msg)
            return res.status(404).json({ error: 'Message not found' });
        let savedBy = [];
        try {
            savedBy = JSON.parse(msg.savedBy);
        }
        catch { }
        const isSaved = savedBy.includes(userId);
        if (isSaved) {
            savedBy = savedBy.filter((id) => id !== userId);
        }
        else {
            savedBy.push(userId);
        }
        const updated = await db_1.prisma.chatMessage.update({
            where: { id: String(req.params.id) },
            data: { savedBy: JSON.stringify(savedBy) },
        });
        const formatted = formatMessage(updated);
        (0, socket_1.emitToChannel)(updated.channelId, 'message:updated', { message: formatted });
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
        return res.json({ success: true, data: formatted });
    }
    catch (error) {
        console.error('Failed to toggle save message:', error);
        return res.status(500).json({ error: 'Failed to toggle save message' });
    }
});
/**
 * POST /api/chat/messages/:id/view-snap - Mark snap message as viewed
 */
router.post('/messages/:id/view-snap', auth_1.authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const msg = await db_1.prisma.chatMessage.findUnique({
            where: { id: String(req.params.id) },
            include: {
                sender: { select: { id: true, username: true, fullName: true, avatarUrl: true } },
            },
        });
        if (!msg)
            return res.status(404).json({ error: 'Message not found' });
        let readBy = [];
        try {
            readBy = JSON.parse(msg.readBy);
        }
        catch { }
        if (!readBy.includes(userId)) {
            readBy.push(userId);
        }
        let reactions = {};
        try {
            reactions = typeof msg.reactions === 'string' ? JSON.parse(msg.reactions || '{}') : (msg.reactions || {});
        }
        catch { }
        const snapViews = reactions._snapViews || {};
        const currentCount = snapViews[userId] || 0;
        // Increment view count: first view = 1, replay = 2
        snapViews[userId] = currentCount + 1;
        reactions._snapViews = snapViews;
        // Replay limit: Once viewed twice, mark expired for this user
        if (snapViews[userId] >= 2) {
            reactions._snapExpired = reactions._snapExpired || {};
            reactions._snapExpired[userId] = true;
        }
        const updated = await db_1.prisma.chatMessage.update({
            where: { id: String(req.params.id) },
            data: {
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
                    lastMessage: snapViews[userId] >= 2 ? 'Opened Snap' : 'Opened · Replay available',
                },
            });
        }
        catch (_) { }
        const formatted = formatMessage(updated);
        (0, socket_1.emitToChannel)(updated.channelId, 'message:updated', { message: formatted });
        return res.json({ success: true, data: formatted });
    }
    catch (error) {
        console.error('Failed to mark snap viewed:', error);
        return res.status(500).json({ error: 'Failed to mark snap viewed' });
    }
});
exports.default = router;
