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
