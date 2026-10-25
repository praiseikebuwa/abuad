"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.initSocket = initSocket;
exports.isUserOnline = isUserOnline;
exports.emitToChannel = emitToChannel;
exports.emitToUsers = emitToUsers;
exports.emitToAll = emitToAll;
const socket_io_1 = require("socket.io");
const jwt_1 = require("../utils/jwt");
const db_1 = require("../config/db");
/**
 * Socket.IO realtime layer.
 *
 * Every authenticated socket joins the room `user:<userId>`. Chat events are
 * fanned out to each channel member's user room, so clients receive messages
 * for all their conversations (chat list + open chat) over one connection.
 *
 * Server -> client events:
 *   message:new       { channelId, message }
 *   message:updated   { channelId, message }
 *   message:deleted   { channelId, messageId }
 *   messages:read     { channelId, userId }
 *   channel:updated   { channelId }
 *   typing            { channelId, userId, isTyping }
 *   presence          { userId, status }
 *
 * Client -> server events:
 *   typing            { channelId, isTyping }
 */
let io = null;
const onlineCounts = new Map();
const userRoom = (userId) => `user:${userId}`;
function initSocket(server) {
    io = new socket_io_1.Server(server, {
        cors: { origin: true, credentials: true },
        pingInterval: 25000,
        pingTimeout: 20000,
    });
    // JWT handshake auth: client sends { auth: { token } } (or ?token= query fallback)
    io.use((socket, next) => {
        try {
            const raw = (socket.handshake.auth && socket.handshake.auth.token) ||
                (socket.handshake.query && socket.handshake.query.token) ||
                (socket.handshake.headers.authorization || '').replace(/^Bearer\s+/i, '');
            if (!raw)
                return next(new Error('unauthorized'));
            const payload = (0, jwt_1.verifyAccessToken)(String(raw));
            socket.data.userId = payload.userId;
            next();
        }
        catch {
            next(new Error('unauthorized'));
        }
    });
    io.on('connection', (socket) => {
        const userId = socket.data.userId;
        socket.join(userRoom(userId));
        const count = (onlineCounts.get(userId) || 0) + 1;
        onlineCounts.set(userId, count);
        if (count === 1)
            setPresence(userId, 'online');
        socket.on('typing', async (data) => {
            try {
                if (!data?.channelId)
                    return;
                const members = await getChannelMemberIds(data.channelId);
                if (!members.includes(userId))
                    return;
                for (const memberId of members) {
                    if (memberId === userId)
                        continue;
                    io.to(userRoom(memberId)).emit('typing', {
                        channelId: data.channelId,
                        userId,
                        isTyping: !!data.isTyping,
                    });
                }
            }
            catch (e) {
                console.error('Socket typing error:', e);
            }
        });
        socket.on('disconnect', () => {
            const left = (onlineCounts.get(userId) || 1) - 1;
            if (left <= 0) {
                onlineCounts.delete(userId);
                setPresence(userId, 'offline');
            }
            else {
                onlineCounts.set(userId, left);
            }
        });
    });
    console.log('⚡ Socket.IO realtime server initialised');
    return io;
}
function isUserOnline(userId) {
    return (onlineCounts.get(userId) || 0) > 0;
}
async function setPresence(userId, status) {
    try {
        await db_1.prisma.user.update({ where: { id: userId }, data: { status, lastSeen: new Date() } });
    }
    catch {
        /* user may have been deleted */
    }
    io?.emit('presence', { userId, status });
}
async function getChannelMemberIds(channelId) {
    const channel = await db_1.prisma.chatChannel.findUnique({
        where: { id: channelId },
        select: { memberIds: true },
    });
    if (!channel)
        return [];
    try {
        const ids = JSON.parse(channel.memberIds || '[]');
        return Array.isArray(ids) ? ids.map(String) : [];
    }
    catch {
        return [];
    }
}
/** Emit an event to every member of a chat channel. Never throws. */
async function emitToChannel(channelId, event, payload) {
    if (!io)
        return;
    try {
        const members = await getChannelMemberIds(channelId);
        for (const memberId of members) {
            io.to(userRoom(memberId)).emit(event, { channelId, ...payload });
        }
    }
    catch (e) {
        console.error(`Socket emit "${event}" failed:`, e);
    }
}
/** Emit an event directly to specific users. */
function emitToUsers(userIds, event, payload) {
    if (!io)
        return;
    for (const id of userIds)
        io.to(userRoom(id)).emit(event, payload);
}
/** Emit an event to all connected sockets. */
function emitToAll(event, payload) {
    if (!io)
        return;
    io.emit(event, payload);
}
