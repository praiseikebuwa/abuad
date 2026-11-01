import { Server as HttpServer } from 'http';
import { Server, Socket } from 'socket.io';
import { verifyAccessToken } from '../utils/jwt';
import { prisma } from '../config/db';

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

let io: Server | null = null;
const onlineCounts = new Map<string, number>();

const userRoom = (userId: string) => `user:${userId}`;
export const audioRoomName = (roomId: string) => `audio_room:${roomId}`;

export function initSocket(server: HttpServer) {
  io = new Server(server, {
    cors: { origin: true, credentials: true },
    pingInterval: 25000,
    pingTimeout: 20000,
  });

  // JWT handshake auth: client sends { auth: { token } } (or ?token= query fallback)
  io.use((socket, next) => {
    try {
      const raw =
        (socket.handshake.auth && (socket.handshake.auth as any).token) ||
        (socket.handshake.query && (socket.handshake.query.token as string)) ||
        (socket.handshake.headers.authorization || '').replace(/^Bearer\s+/i, '');
      if (!raw) return next(new Error('unauthorized'));
      const payload = verifyAccessToken(String(raw));
      socket.data.userId = payload.userId;
      next();
    } catch {
      next(new Error('unauthorized'));
    }
  });

  io.on('connection', (socket: Socket) => {
    const userId: string = socket.data.userId;
    socket.join(userRoom(userId));

    const count = (onlineCounts.get(userId) || 0) + 1;
    onlineCounts.set(userId, count);
    if (count === 1) setPresence(userId, 'online');

    socket.on('typing', async (data: { channelId?: string; isTyping?: boolean }) => {
      try {
        if (!data?.channelId) return;
        const members = await getChannelMemberIds(data.channelId);
        if (!members.includes(userId)) return;
        for (const memberId of members) {
          if (memberId === userId) continue;
          io!.to(userRoom(memberId)).emit('typing', {
            channelId: data.channelId,
            userId,
            isTyping: !!data.isTyping,
          });
        }
      } catch (e) {
        console.error('Socket typing error:', e);
      }
    });

    // Audio Room Spaces listeners
    socket.on('audio_room:join', (data: any) => {
      const roomId = typeof data === 'string' ? data : data?.roomId;
      if (roomId) {
        socket.join(audioRoomName(roomId));
        console.log(`⚡ [Socket] User ${userId} joined audio room: ${roomId}`);
      }
    });

    socket.on('audio_room:leave', (data: any) => {
      const roomId = typeof data === 'string' ? data : data?.roomId;
      if (roomId) {
        socket.leave(audioRoomName(roomId));
        console.log(`⚡ [Socket] User ${userId} left audio room: ${roomId}`);
      }
    });

    socket.on('audio_room:reaction', (data: any) => {
      const roomId = typeof data === 'string' ? null : data?.roomId;
      const emoji = data?.emoji;
      if (roomId && emoji) {
        io?.to(audioRoomName(roomId)).emit('audio_room:reaction', {
          roomId,
          userId,
          emoji,
          xOffset: typeof data?.xOffset === 'number' ? data.xOffset : (Math.random() * 0.8),
          timestamp: Date.now(),
        });
      }
    });

    socket.on('audio_room:send_message', async (data: any) => {
      const roomId = data?.roomId;
      const content = data?.message || data?.content;
      if (!roomId || !content || !content.trim()) return;

      try {
        const user = await prisma.user.findUnique({
          where: { id: userId },
          select: {
            id: true,
            username: true,
            fullName: true,
            avatarUrl: true,
            department: true,
            level: true,
            isVerified: true,
            verificationType: true,
          },
        });

        const chatMsg = await (prisma as any).audioRoomMessage.create({
          data: {
            roomId,
            userId,
            message: content.trim(),
            isAnnouncement: !!data?.isAnnouncement,
            isPinned: !!data?.isPinned,
          },
          include: {
            user: {
              select: {
                id: true,
                username: true,
                fullName: true,
                avatarUrl: true,
                department: true,
                level: true,
                isVerified: true,
                verificationType: true,
              },
            },
          },
        });

        emitToAudioRoom(roomId, 'audio_room:message', { message: chatMsg });
      } catch (err) {
        console.error('Failed to create socket audio room message:', err);
      }
    });

    socket.on('audio_room:heartbeat', async (data: { roomId?: string }) => {
      if (data?.roomId) {
        try {
          await (prisma as any).audioRoomParticipant.updateMany({
            where: { roomId: data.roomId, userId },
            data: { lastHeartbeatAt: new Date(), connectionStatus: 'ONLINE' },
          });
        } catch (_) {}
      }
    });

    socket.on('disconnect', () => {
      const left = (onlineCounts.get(userId) || 1) - 1;
      if (left <= 0) {
        onlineCounts.delete(userId);
        setPresence(userId, 'offline');
      } else {
        onlineCounts.set(userId, left);
      }
    });
  });

  console.log('⚡ Socket.IO realtime server initialised');
  return io;
}

export function isUserOnline(userId: string) {
  return (onlineCounts.get(userId) || 0) > 0;
}

async function setPresence(userId: string, status: 'online' | 'offline') {
  try {
    await prisma.user.update({ where: { id: userId }, data: { status, lastSeen: new Date() } });
  } catch {
    /* user may have been deleted */
  }
  io?.emit('presence', { userId, status });
}

async function getChannelMemberIds(channelId: string): Promise<string[]> {
  const channel = await prisma.chatChannel.findUnique({
    where: { id: channelId },
    select: { memberIds: true },
  });
  if (!channel) return [];
  try {
    const ids = JSON.parse(channel.memberIds || '[]');
    return Array.isArray(ids) ? ids.map(String) : [];
  } catch {
    return [];
  }
}

/** Emit an event to every member of a chat channel. Never throws. */
export async function emitToChannel(channelId: string, event: string, payload: Record<string, unknown>) {
  if (!io) return;
  try {
    const members = await getChannelMemberIds(channelId);
    for (const memberId of members) {
      io.to(userRoom(memberId)).emit(event, { channelId, ...payload });
    }
  } catch (e) {
    console.error(`Socket emit "${event}" failed:`, e);
  }
}

/** Emit an event directly to specific users. */
export function emitToUsers(userIds: string[], event: string, payload: Record<string, unknown>) {
  if (!io) return;
  for (const id of userIds) io.to(userRoom(id)).emit(event, payload);
}

/** Emit an event to all connected sockets. */
export function emitToAll(event: string, payload: Record<string, unknown>) {
  if (!io) return;
  io.emit(event, payload);
}

/** Emit an event to all participants in an audio room space. */
export function emitToAudioRoom(roomId: string, event: string, payload: Record<string, unknown>) {
  if (!io) return;
  io.to(audioRoomName(roomId)).emit(event, { roomId, ...payload });
}

