import { Router, Response } from 'express';
import { authenticateToken, AuthenticatedRequest } from '../middleware/auth';
import { prisma } from '../config/db';
import {
  generateLiveKitToken,
  endLiveKitRoom,
  removeLiveKitParticipant,
} from '../services/livekitService';
import { emitToAudioRoom, emitToAll, emitToUsers } from '../realtime/socket';

const router = Router();

const userSelect = {
  id: true,
  username: true,
  fullName: true,
  avatarUrl: true,
  department: true,
  level: true,
  isVerified: true,
  verificationType: true,
};

// In-memory timers for automatic lifecycle management
const gracePeriodTimers = new Map<string, NodeJS.Timeout>();
const emptyRoomTimers = new Map<string, NodeJS.Timeout>();

/**
 * Terminate a live audio space session safely across DB and LiveKit.
 */
async function terminateAudioRoom(roomId: string, reason: string = 'ENDED') {
  try {
    if (gracePeriodTimers.has(roomId)) {
      clearTimeout(gracePeriodTimers.get(roomId)!);
      gracePeriodTimers.delete(roomId);
    }
    if (emptyRoomTimers.has(roomId)) {
      clearTimeout(emptyRoomTimers.get(roomId)!);
      emptyRoomTimers.delete(roomId);
    }

    const updated = await (prisma as any).audioRoom.update({
      where: { id: roomId },
      data: {
        status: 'ENDED',
        endedAt: new Date(),
        hostGracePeriodEndsAt: null,
      },
    });

    await endLiveKitRoom(roomId);

    emitToAudioRoom(roomId, 'audio_room:ended', { roomId, reason });
    emitToAll('audio_room:ended', { roomId, reason });
    return updated;
  } catch (e) {
    console.error(`[AudioRooms] Failed to terminate room ${roomId}:`, e);
  }
}

/**
 * Trigger host succession when the primary host disconnects or leaves.
 */
async function triggerHostSuccession(roomId: string) {
  try {
    const room = await (prisma as any).audioRoom.findUnique({
      where: { id: roomId },
      include: {
        participants: {
          include: { user: { select: userSelect } },
          orderBy: { joinedAt: 'asc' },
        },
      },
    });

    if (!room || room.status === 'ENDED') return;

    // Filter active participants who are NOT the departed host
    const eligibleParticipants = room.participants.filter(
      (p: any) => p.userId !== room.hostId && p.connectionStatus !== 'DISCONNECTED'
    );

    if (eligibleParticipants.length === 0) {
      console.log(`[AudioRooms] No eligible participants left for room ${roomId}. Ending room.`);
      await terminateAudioRoom(roomId, 'NO_REPLACEMENT_HOST');
      return;
    }

    // Successor priority:
    // 1. First active CO_HOST
    // 2. First active MODERATOR
    // 3. Earliest joined SPEAKER
    // 4. Earliest joined LISTENER
    let successor = eligibleParticipants.find((p: any) => p.role === 'CO_HOST');
    if (!successor) {
      successor = eligibleParticipants.find((p: any) => p.role === 'MODERATOR');
    }
    if (!successor) {
      successor = eligibleParticipants.find((p: any) => p.role === 'SPEAKER');
    }
    if (!successor) {
      successor = eligibleParticipants[0];
    }

    const newHostId = successor.userId;
    const previousHostId = room.hostId;

    await prisma.$transaction([
      (prisma as any).audioRoom.update({
        where: { id: roomId },
        data: {
          hostId: newHostId,
          currentHostId: newHostId,
          hostGracePeriodEndsAt: null,
        },
      }),
      (prisma as any).audioRoomParticipant.update({
        where: { roomId_userId: { roomId, userId: newHostId } },
        data: { role: 'HOST', isMuted: false },
      }),
      (prisma as any).audioRoomParticipant.updateMany({
        where: { roomId, userId: previousHostId },
        data: { role: 'CO_HOST' },
      }),
    ]);

    const token = await generateLiveKitToken({
      roomId,
      userId: successor.user.id,
      userName: successor.user.fullName || successor.user.username,
      userAvatar: successor.user.avatarUrl,
      role: 'HOST',
    });

    emitToUsers([newHostId], 'audio_room:role_promoted', {
      roomId,
      role: 'HOST',
      token,
      isSuccession: true,
    });

    emitToAudioRoom(roomId, 'audio_room:host_transferred', {
      roomId,
      previousHostId,
      newHostId,
      successor: successor.user,
      reason: 'HOST_SUCCESSION',
    });
    emitToAll('audio_room:updated', { roomId, hostId: newHostId });
    console.log(`[AudioRooms] Succession complete: ${newHostId} is now host of ${roomId}`);
  } catch (e) {
    console.error(`[AudioRooms] Host succession error:`, e);
  }
}

/**
 * GET /api/audio-rooms
 * List active & scheduled audio spaces with filtering.
 */
router.get('/', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { category, status } = req.query;

    const where: any = {};
    if (status) {
      where.status = String(status).toUpperCase();
    } else {
      where.status = { in: ['LIVE', 'SCHEDULED'] };
    }

    if (category && category !== 'ALL') {
      where.category = String(category).toUpperCase();
    }

    const rooms = await (prisma as any).audioRoom.findMany({
      where,
      orderBy: [
        { status: 'asc' }, // LIVE before SCHEDULED
        { createdAt: 'desc' },
      ],
      include: {
        host: { select: userSelect },
        participants: {
          take: 8,
          include: { user: { select: userSelect } },
          orderBy: { joinedAt: 'asc' },
        },
        _count: {
          select: {
            participants: true,
            requests: true,
          },
        },
      },
    });

    return res.json({ success: true, data: rooms });
  } catch (error: any) {
    console.error('[AudioRooms] Failed to list rooms:', error);
    if (error?.message?.includes('does not exist') || error?.code === 'P2021') {
      return res.json({ success: true, data: [] });
    }
    return res.status(500).json({ error: 'Failed to fetch audio rooms', details: error.message });
  }
});

/**
 * POST /api/audio-rooms
 * Create and start or schedule a new live audio room.
 */
router.post('/', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.id;
    const {
      title,
      description,
      category = 'ACADEMIC',
      visibility = 'PUBLIC',
      speakersPermission = 'HOST_APPROVED',
      isRecording = false,
      isChatEnabled = true,
      scheduledAt,
      taggedGroupIds = [],
      taggedUserIds = [],
      tags = [],
    } = req.body;

    if (!title || !title.trim()) {
      return res.status(400).json({ error: 'Room title is required' });
    }

    const isScheduled = !!scheduledAt;
    const roomStatus = isScheduled ? 'SCHEDULED' : 'LIVE';

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: userSelect,
    });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const room = await (prisma as any).audioRoom.create({
      data: {
        hostId: userId,
        currentHostId: userId,
        title: title.trim(),
        description: description?.trim() || null,
        category: category.toUpperCase(),
        visibility: visibility.toUpperCase(),
        speakersPermission: speakersPermission.toUpperCase(),
        status: roomStatus,
        isRecording: !!isRecording,
        isChatEnabled: !!isChatEnabled,
        taggedGroupIds: JSON.stringify(taggedGroupIds || []),
        taggedUserIds: JSON.stringify(taggedUserIds || []),
        tags: JSON.stringify(tags || []),
        scheduledAt: scheduledAt ? new Date(scheduledAt) : null,
        startedAt: isScheduled ? null : new Date(),
        participants: isScheduled
          ? undefined
          : {
              create: {
                userId,
                role: 'HOST',
                isMuted: false,
                connectionStatus: 'ONLINE',
              },
            },
      },
      include: {
        host: { select: userSelect },
        participants: {
          include: { user: { select: userSelect } },
        },
      },
    });

    let liveKitToken: string | null = null;
    if (!isScheduled) {
      liveKitToken = await generateLiveKitToken({
        roomId: room.id,
        userId: user.id,
        userName: user.fullName || user.username,
        userAvatar: user.avatarUrl,
        role: 'HOST',
      });
    }

    if (!isScheduled) {
      emitToAll('audio_room:created', { room });
    }

    // Dispatch invitations to tagged users and groups
    const invitedUserIds = new Set<string>();
    if (Array.isArray(taggedUserIds)) {
      taggedUserIds.forEach(id => {
        if (id && id !== userId) invitedUserIds.add(id);
      });
    }

    if (Array.isArray(taggedGroupIds) && taggedGroupIds.length > 0) {
      const groups = await prisma.chatChannel.findMany({
        where: { id: { in: taggedGroupIds } },
      });
      for (const group of groups) {
        try {
          const members: string[] = JSON.parse(group.memberIds || '[]');
          members.forEach(m => {
            if (m && m !== userId) invitedUserIds.add(m);
          });
        } catch (_) {}

        try {
          await prisma.chatMessage.create({
            data: {
              senderId: userId,
              channelId: group.id,
              text: `🎙️ ${user.fullName || user.username} started a Live Space: "${room.title}"! Tap to tune in.`,
              type: 'text',
              reactions: JSON.stringify({
                _liveSpace: {
                  roomId: room.id,
                  title: room.title,
                  category: room.category,
                  hostName: user.fullName || user.username,
                  hostAvatar: user.avatarUrl,
                },
              }),
            },
          });
          emitToAll('channel:updated', { channelId: group.id, roomId: room.id });
        } catch (_) {}
      }
    }

    if (invitedUserIds.size > 0) {
      emitToUsers(Array.from(invitedUserIds), 'audio_room:invitation', {
        roomId: room.id,
        title: room.title,
        host: user,
        category: room.category,
        isLive: !isScheduled,
        scheduledAt: room.scheduledAt,
      });
    }

    return res.status(201).json({
      success: true,
      data: {
        room,
        token: liveKitToken,
        role: 'HOST',
      },
    });
  } catch (error: any) {
    console.error('[AudioRooms] Failed to create room:', error);
    return res.status(500).json({ error: 'Failed to create audio room', details: error.message });
  }
});

/**
 * GET /api/audio-rooms/:id
 * Retrieve live room details with categorized participants.
 */
router.get('/:id', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const id = req.params.id as string;

    const room = await (prisma as any).audioRoom.findUnique({
      where: { id },
      include: {
        host: { select: userSelect },
        participants: {
          include: { user: { select: userSelect } },
          orderBy: { joinedAt: 'asc' },
        },
        requests: {
          where: { status: 'PENDING' },
          include: { user: { select: userSelect } },
          orderBy: { createdAt: 'asc' },
        },
        _count: {
          select: {
            participants: true,
            requests: true,
          },
        },
      },
    });

    if (!room) {
      return res.status(404).json({ error: 'Audio room not found' });
    }

    return res.json({ success: true, data: room });
  } catch (error: any) {
    console.error('[AudioRooms] Failed to fetch room details:', error);
    return res.status(500).json({ error: 'Failed to fetch audio room', details: error.message });
  }
});

/**
 * POST /api/audio-rooms/:id/join
 * Join an audio room as host, speaker, or listener and get a LiveKit JWT token.
 */
router.post('/:id/join', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.id;
    const roomId = req.params.id as string;

    const room = await (prisma as any).audioRoom.findUnique({
      where: { id: roomId },
    });

    if (!room) {
      return res.status(404).json({ error: 'Audio room not found' });
    }

    if (room.status === 'ENDED') {
      return res.status(400).json({ error: 'This audio room has already ended' });
    }

    if (room.isLocked && room.hostId !== userId) {
      return res.status(403).json({ error: 'This audio space is currently locked by the host' });
    }

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: userSelect,
    });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Clear empty room timer if someone joins
    if (emptyRoomTimers.has(roomId)) {
      clearTimeout(emptyRoomTimers.get(roomId)!);
      emptyRoomTimers.delete(roomId);
    }

    // Determine role
    let assignedRole: 'HOST' | 'CO_HOST' | 'MODERATOR' | 'SPEAKER' | 'LISTENER' = 'LISTENER';
    if (room.hostId === userId || room.currentHostId === userId) {
      assignedRole = 'HOST';
      // If host rejoins, cancel any grace period timer
      if (gracePeriodTimers.has(roomId)) {
        clearTimeout(gracePeriodTimers.get(roomId)!);
        gracePeriodTimers.delete(roomId);
        await (prisma as any).audioRoom.update({
          where: { id: roomId },
          data: { hostGracePeriodEndsAt: null },
        });
        emitToAudioRoom(roomId, 'audio_room:host_reconnected', { roomId, hostId: userId });
      }
    } else {
      const existing = await (prisma as any).audioRoomParticipant.findUnique({
        where: { roomId_userId: { roomId, userId } },
      });
      if (existing) {
        assignedRole = existing.role;
      } else if (room.speakersPermission === 'EVERYONE') {
        assignedRole = 'SPEAKER';
      }
    }

    const participant = await (prisma as any).audioRoomParticipant.upsert({
      where: { roomId_userId: { roomId, userId } },
      update: {
        role: assignedRole,
        isMuted: assignedRole === 'LISTENER',
        connectionStatus: 'ONLINE',
        lastHeartbeatAt: new Date(),
      },
      create: {
        roomId,
        userId,
        role: assignedRole,
        isMuted: assignedRole === 'LISTENER',
        connectionStatus: 'ONLINE',
        lastHeartbeatAt: new Date(),
      },
      include: { user: { select: userSelect } },
    });

    if (room.status === 'SCHEDULED' && assignedRole === 'HOST') {
      await (prisma as any).audioRoom.update({
        where: { id: roomId },
        data: { status: 'LIVE', startedAt: new Date() },
      });
    }

    const token = await generateLiveKitToken({
      roomId,
      userId,
      userName: user.fullName || user.username,
      userAvatar: user.avatarUrl,
      role: assignedRole as any,
    });

    emitToAudioRoom(roomId, 'audio_room:participant_joined', { participant });

    return res.json({
      success: true,
      data: {
        token,
        role: assignedRole,
        participant,
      },
    });
  } catch (error: any) {
    console.error('[AudioRooms] Join failed:', error);
    return res.status(500).json({ error: 'Failed to join audio room', details: error.message });
  }
});

/**
 * POST /api/audio-rooms/:id/heartbeat
 * Client presence tracking and host reconnection handling.
 */
router.post('/:id/heartbeat', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.id;
    const roomId = req.params.id as string;

    await (prisma as any).audioRoomParticipant.updateMany({
      where: { roomId, userId },
      data: {
        lastHeartbeatAt: new Date(),
        connectionStatus: 'ONLINE',
      },
    });

    const room = await (prisma as any).audioRoom.findUnique({
      where: { id: roomId },
      select: { hostId: true, hostGracePeriodEndsAt: true },
    });

    if (room && room.hostId === userId && room.hostGracePeriodEndsAt) {
      if (gracePeriodTimers.has(roomId)) {
        clearTimeout(gracePeriodTimers.get(roomId)!);
        gracePeriodTimers.delete(roomId);
      }
      await (prisma as any).audioRoom.update({
        where: { id: roomId },
        data: { hostGracePeriodEndsAt: null },
      });
      emitToAudioRoom(roomId, 'audio_room:host_reconnected', { roomId, hostId: userId });
    }

    return res.json({ success: true });
  } catch (error: any) {
    return res.status(500).json({ error: 'Heartbeat update failed' });
  }
});

/**
 * POST /api/audio-rooms/:id/leave
 * Participant leaves the audio space. If host departs without ending, starts grace period.
 */
router.post('/:id/leave', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.id;
    const roomId = req.params.id as string;

    const room = await (prisma as any).audioRoom.findUnique({
      where: { id: roomId },
      include: {
        participants: true,
      },
    });

    if (!room) {
      return res.status(404).json({ error: 'Audio room not found' });
    }

    const isHost = room.hostId === userId;

    await (prisma as any).audioRoomParticipant.deleteMany({
      where: { roomId, userId },
    });

    await (prisma as any).audioRoomRequest.deleteMany({
      where: { roomId, userId },
    });

    emitToAudioRoom(roomId, 'audio_room:participant_left', { userId });

    const remainingParticipants = room.participants.filter((p: any) => p.userId !== userId);

    if (remainingParticipants.length === 0) {
      // Empty room cleanup: reap after 30 seconds if still empty
      if (emptyRoomTimers.has(roomId)) clearTimeout(emptyRoomTimers.get(roomId)!);
      const timer = setTimeout(async () => {
        const check = await (prisma as any).audioRoomParticipant.count({ where: { roomId } });
        if (check === 0) {
          console.log(`[AudioRooms] Empty room timeout fired for ${roomId}. Auto-terminating.`);
          await terminateAudioRoom(roomId, 'EMPTY_ROOM');
        }
      }, 30000);
      emptyRoomTimers.set(roomId, timer);
    }

    if (isHost && remainingParticipants.length > 0) {
      // Host departed without explicitly ending room -> initiate 60s reconnection grace period
      const gracePeriodEndsAt = new Date(Date.now() + 60000);
      await (prisma as any).audioRoom.update({
        where: { id: roomId },
        data: { hostGracePeriodEndsAt: gracePeriodEndsAt },
      });

      emitToAudioRoom(roomId, 'audio_room:host_disconnected', {
        roomId,
        gracePeriodSeconds: 60,
        endsAt: gracePeriodEndsAt.toISOString(),
      });

      if (gracePeriodTimers.has(roomId)) clearTimeout(gracePeriodTimers.get(roomId)!);
      const timer = setTimeout(async () => {
        console.log(`[AudioRooms] Grace period expired for room ${roomId}. Executing succession.`);
        await triggerHostSuccession(roomId);
      }, 60000);
      gracePeriodTimers.set(roomId, timer);
    }

    return res.json({ success: true, message: 'Left audio room' });
  } catch (error: any) {
    console.error('[AudioRooms] Leave failed:', error);
    return res.status(500).json({ error: 'Failed to leave audio room', details: error.message });
  }
});

/**
 * POST /api/audio-rooms/:id/transfer-host
 * Propose transferring primary host privileges to another participant.
 */
router.post('/:id/transfer-host', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const callerId = req.user!.id;
    const roomId = req.params.id as string;
    const { proposedHostId } = req.body;

    if (!proposedHostId) {
      return res.status(400).json({ error: 'proposedHostId is required' });
    }

    const room = await (prisma as any).audioRoom.findUnique({
      where: { id: roomId },
      include: {
        host: { select: userSelect },
        participants: {
          include: { user: { select: userSelect } },
        },
      },
    });

    if (!room) {
      return res.status(404).json({ error: 'Audio room not found' });
    }

    if (room.hostId !== callerId) {
      return res.status(403).json({ error: 'Only the current primary host can transfer ownership' });
    }

    const targetParticipant = room.participants.find((p: any) => p.userId === proposedHostId);
    if (!targetParticipant) {
      return res.status(400).json({ error: 'Proposed host is not currently in this space' });
    }

    // Create a pending host transfer record
    const transfer = await (prisma as any).audioRoomHostTransfer.create({
      data: {
        roomId,
        previousHostId: callerId,
        proposedHostId,
        status: 'PENDING',
      },
      include: {
        proposedHost: { select: userSelect },
        previousHost: { select: userSelect },
      },
    });

    // Notify the proposed host directly
    emitToUsers([proposedHostId], 'audio_room:transfer_proposed', {
      transferId: transfer.id,
      roomId,
      previousHost: room.host,
      roomTitle: room.title,
    });

    // Notify the room that a transfer request is pending
    emitToAudioRoom(roomId, 'audio_room:transfer_pending', {
      transferId: transfer.id,
      proposedHost: targetParticipant.user,
    });

    return res.json({
      success: true,
      data: transfer,
      message: `Host transfer proposed to ${targetParticipant.user.fullName || targetParticipant.user.username}`,
    });
  } catch (error: any) {
    console.error('[AudioRooms] Transfer host failed:', error);
    return res.status(500).json({ error: 'Failed to initiate host transfer', details: error.message });
  }
});

/**
 * POST /api/audio-rooms/:id/respond-host-transfer
 * Target user accepts or declines the primary host handover.
 */
router.post('/:id/respond-host-transfer', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const callerId = req.user!.id;
    const roomId = req.params.id as string;
    const { transferId, accept } = req.body;

    if (!transferId || typeof accept !== 'boolean') {
      return res.status(400).json({ error: 'transferId and accept (boolean) are required' });
    }

    const transfer = await (prisma as any).audioRoomHostTransfer.findUnique({
      where: { id: transferId },
      include: {
        room: true,
        proposedHost: { select: userSelect },
        previousHost: { select: userSelect },
      },
    });

    if (!transfer || transfer.roomId !== roomId || transfer.proposedHostId !== callerId) {
      return res.status(404).json({ error: 'Valid pending host transfer request not found' });
    }

    if (transfer.status !== 'PENDING') {
      return res.status(400).json({ error: `Transfer already resolved as ${transfer.status}` });
    }

    if (!accept) {
      await (prisma as any).audioRoomHostTransfer.update({
        where: { id: transferId },
        data: { status: 'REJECTED' },
      });

      emitToUsers([transfer.previousHostId], 'audio_room:transfer_rejected', {
        roomId,
        targetUser: transfer.proposedHost,
      });
      emitToAudioRoom(roomId, 'audio_room:transfer_rejected', {
        roomId,
        targetUser: transfer.proposedHost,
      });

      return res.json({ success: true, message: 'Transfer rejected' });
    }

    // Atomic host transfer transaction
    await prisma.$transaction([
      (prisma as any).audioRoomHostTransfer.update({
        where: { id: transferId },
        data: {
          status: 'ACCEPTED',
          acceptedAt: new Date(),
        },
      }),
      (prisma as any).audioRoom.update({
        where: { id: roomId },
        data: {
          hostId: callerId,
          currentHostId: callerId,
          hostGracePeriodEndsAt: null,
        },
      }),
      (prisma as any).audioRoomParticipant.update({
        where: { roomId_userId: { roomId, userId: callerId } },
        data: { role: 'HOST', isMuted: false },
      }),
      (prisma as any).audioRoomParticipant.updateMany({
        where: { roomId, userId: transfer.previousHostId },
        data: { role: 'CO_HOST' },
      }),
    ]);

    // Generate fresh tokens
    const newHostToken = await generateLiveKitToken({
      roomId,
      userId: callerId,
      userName: transfer.proposedHost.fullName || transfer.proposedHost.username,
      userAvatar: transfer.proposedHost.avatarUrl,
      role: 'HOST',
    });

    const previousHostToken = await generateLiveKitToken({
      roomId,
      userId: transfer.previousHostId,
      userName: transfer.previousHost.fullName || transfer.previousHost.username,
      userAvatar: transfer.previousHost.avatarUrl,
      role: 'CO_HOST',
    });

    // Notify new host
    emitToUsers([callerId], 'audio_room:role_promoted', {
      roomId,
      role: 'HOST',
      token: newHostToken,
    });

    // Notify former host
    emitToUsers([transfer.previousHostId], 'audio_room:role_demoted', {
      roomId,
      role: 'CO_HOST',
      token: previousHostToken,
    });

    // Broadcast room update to everyone
    emitToAudioRoom(roomId, 'audio_room:host_transferred', {
      roomId,
      previousHostId: transfer.previousHostId,
      newHostId: callerId,
      newHost: transfer.proposedHost,
      reason: 'VOLUNTARY_HANDOVER',
    });
    emitToAll('audio_room:updated', { roomId, hostId: callerId });

    return res.json({
      success: true,
      message: 'Host ownership successfully transferred',
      role: 'HOST',
      token: newHostToken,
    });
  } catch (error: any) {
    console.error('[AudioRooms] Respond host transfer failed:', error);
    return res.status(500).json({ error: 'Failed to process host transfer response', details: error.message });
  }
});

/**
 * POST /api/audio-rooms/:id/raise-hand
 * Listener requests speaking permissions.
 */
router.post('/:id/raise-hand', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.id;
    const roomId = req.params.id as string;

    let request = await (prisma as any).audioRoomRequest.findFirst({
      where: { roomId, userId },
      include: { user: { select: userSelect } },
    });

    if (request) {
      request = await (prisma as any).audioRoomRequest.update({
        where: { id: request.id },
        data: { status: 'PENDING', createdAt: new Date() },
        include: { user: { select: userSelect } },
      });
    } else {
      request = await (prisma as any).audioRoomRequest.create({
        data: {
          roomId,
          userId,
          status: 'PENDING',
        },
        include: { user: { select: userSelect } },
      });
    }

    await (prisma as any).audioRoomParticipant.updateMany({
      where: { roomId, userId },
      data: { isHandRaised: true },
    });

    emitToAudioRoom(roomId, 'audio_room:hand_raised', { request });

    return res.json({ success: true, data: request });
  } catch (error: any) {
    console.error('[AudioRooms] Raise hand failed:', error);
    return res.status(500).json({ error: 'Failed to raise hand', details: error.message });
  }
});

/**
 * POST /api/audio-rooms/:id/lower-hand
 * Listener lowers their hand or host dismisses it.
 */
router.post('/:id/lower-hand', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.id;
    const roomId = req.params.id as string;
    const targetUserId = (req.body.targetUserId || userId) as string;

    await (prisma as any).audioRoomRequest.deleteMany({
      where: { roomId, userId: targetUserId },
    });

    await (prisma as any).audioRoomParticipant.updateMany({
      where: { roomId, userId: targetUserId },
      data: { isHandRaised: false },
    });

    emitToAudioRoom(roomId, 'audio_room:hand_lowered', { userId: targetUserId });

    return res.json({ success: true, message: 'Hand lowered' });
  } catch (error: any) {
    console.error('[AudioRooms] Lower hand failed:', error);
    return res.status(500).json({ error: 'Failed to lower hand', details: error.message });
  }
});

/**
 * POST /api/audio-rooms/:id/moderate
 * Comprehensive moderation actions:
 * APPROVE_SPEAKER, INVITE_SPEAKER, DEMOTE_TO_LISTENER, MAKE_CO_HOST, REVOKE_CO_HOST,
 * MAKE_MODERATOR, REVOKE_MODERATOR, MUTE, MUTE_ALL, LOCK_ROOM, UNLOCK_ROOM, KICK.
 */
router.post('/:id/moderate', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const callerId = req.user!.id;
    const roomId = req.params.id as string;
    const { targetUserId, action } = req.body;

    if (!action) {
      return res.status(400).json({ error: 'action is required' });
    }

    const room = await (prisma as any).audioRoom.findUnique({
      where: { id: roomId },
      include: {
        participants: true,
      },
    });

    if (!room) {
      return res.status(404).json({ error: 'Audio room not found' });
    }

    const callerParticipant = room.participants.find((p: any) => p.userId === callerId);
    const isHost = room.hostId === callerId || callerParticipant?.role === 'HOST';
    const isCoHost = callerParticipant?.role === 'CO_HOST';
    const isModerator = callerParticipant?.role === 'MODERATOR';

    if (!isHost && !isCoHost && !isModerator) {
      return res.status(403).json({ error: 'Only hosts, co-hosts, or moderators can perform moderation actions' });
    }

    // Global room actions (no single target user required)
    if (action === 'MUTE_ALL') {
      await (prisma as any).audioRoomParticipant.updateMany({
        where: {
          roomId,
          role: { in: ['SPEAKER', 'MODERATOR', 'CO_HOST'] },
          userId: { not: room.hostId },
        },
        data: { isMuted: true },
      });

      emitToAudioRoom(roomId, 'audio_room:all_muted', { roomId });
      return res.json({ success: true, action: 'MUTE_ALL', message: 'All speakers muted' });
    }

    if (action === 'LOCK_ROOM' || action === 'UNLOCK_ROOM') {
      if (!isHost && !isCoHost) {
        return res.status(403).json({ error: 'Only hosts or co-hosts can lock or unlock the room' });
      }
      const isLocked = action === 'LOCK_ROOM';
      await (prisma as any).audioRoom.update({
        where: { id: roomId },
        data: { isLocked },
      });
      emitToAudioRoom(roomId, 'audio_room:locked_changed', { roomId, isLocked });
      return res.json({ success: true, isLocked });
    }

    if (!targetUserId) {
      return res.status(400).json({ error: 'targetUserId is required for this action' });
    }

    const targetUser = await prisma.user.findUnique({
      where: { id: targetUserId },
      select: userSelect,
    });
    if (!targetUser) {
      return res.status(404).json({ error: 'Target user not found' });
    }

    let updatedParticipant: any = null;
    let newLiveKitToken: string | null = null;

    switch (action) {
      case 'APPROVE_SPEAKER':
      case 'INVITE_SPEAKER': {
        await (prisma as any).audioRoomRequest.deleteMany({
          where: { roomId, userId: targetUserId },
        });

        updatedParticipant = await (prisma as any).audioRoomParticipant.upsert({
          where: { roomId_userId: { roomId, userId: targetUserId } },
          update: { role: 'SPEAKER', isMuted: false, isHandRaised: false },
          create: { roomId, userId: targetUserId, role: 'SPEAKER', isMuted: false, isHandRaised: false },
          include: { user: { select: userSelect } },
        });

        newLiveKitToken = await generateLiveKitToken({
          roomId,
          userId: targetUserId,
          userName: targetUser.fullName || targetUser.username,
          userAvatar: targetUser.avatarUrl,
          role: 'SPEAKER',
        });

        emitToUsers([targetUserId], 'audio_room:role_promoted', {
          roomId,
          role: 'SPEAKER',
          token: newLiveKitToken,
        });
        emitToAudioRoom(roomId, 'audio_room:participant_updated', { participant: updatedParticipant });
        break;
      }

      case 'DEMOTE_TO_LISTENER': {
        updatedParticipant = await (prisma as any).audioRoomParticipant.update({
          where: { roomId_userId: { roomId, userId: targetUserId } },
          data: { role: 'LISTENER', isMuted: true },
          include: { user: { select: userSelect } },
        });

        newLiveKitToken = await generateLiveKitToken({
          roomId,
          userId: targetUserId,
          userName: targetUser.fullName || targetUser.username,
          userAvatar: targetUser.avatarUrl,
          role: 'LISTENER',
        });

        emitToUsers([targetUserId], 'audio_room:role_demoted', {
          roomId,
          role: 'LISTENER',
          token: newLiveKitToken,
        });
        emitToAudioRoom(roomId, 'audio_room:participant_updated', { participant: updatedParticipant });
        break;
      }

      case 'MAKE_CO_HOST': {
        if (!isHost) {
          return res.status(403).json({ error: 'Only the primary host can appoint co-hosts' });
        }

        updatedParticipant = await (prisma as any).audioRoomParticipant.update({
          where: { roomId_userId: { roomId, userId: targetUserId } },
          data: { role: 'CO_HOST' },
          include: { user: { select: userSelect } },
        });

        newLiveKitToken = await generateLiveKitToken({
          roomId,
          userId: targetUserId,
          userName: targetUser.fullName || targetUser.username,
          userAvatar: targetUser.avatarUrl,
          role: 'CO_HOST',
        });

        emitToUsers([targetUserId], 'audio_room:role_promoted', {
          roomId,
          role: 'CO_HOST',
          token: newLiveKitToken,
        });
        emitToAudioRoom(roomId, 'audio_room:participant_updated', { participant: updatedParticipant });
        break;
      }

      case 'REVOKE_CO_HOST': {
        if (!isHost) {
          return res.status(403).json({ error: 'Only the primary host can revoke co-host permissions' });
        }

        updatedParticipant = await (prisma as any).audioRoomParticipant.update({
          where: { roomId_userId: { roomId, userId: targetUserId } },
          data: { role: 'SPEAKER' },
          include: { user: { select: userSelect } },
        });

        newLiveKitToken = await generateLiveKitToken({
          roomId,
          userId: targetUserId,
          userName: targetUser.fullName || targetUser.username,
          userAvatar: targetUser.avatarUrl,
          role: 'SPEAKER',
        });

        emitToUsers([targetUserId], 'audio_room:role_demoted', {
          roomId,
          role: 'SPEAKER',
          token: newLiveKitToken,
        });
        emitToAudioRoom(roomId, 'audio_room:participant_updated', { participant: updatedParticipant });
        break;
      }

      case 'MAKE_MODERATOR': {
        if (!isHost && !isCoHost) {
          return res.status(403).json({ error: 'Only hosts or co-hosts can appoint moderators' });
        }

        updatedParticipant = await (prisma as any).audioRoomParticipant.update({
          where: { roomId_userId: { roomId, userId: targetUserId } },
          data: { role: 'MODERATOR' },
          include: { user: { select: userSelect } },
        });

        newLiveKitToken = await generateLiveKitToken({
          roomId,
          userId: targetUserId,
          userName: targetUser.fullName || targetUser.username,
          userAvatar: targetUser.avatarUrl,
          role: 'MODERATOR' as any,
        });

        emitToUsers([targetUserId], 'audio_room:role_promoted', {
          roomId,
          role: 'MODERATOR',
          token: newLiveKitToken,
        });
        emitToAudioRoom(roomId, 'audio_room:participant_updated', { participant: updatedParticipant });
        break;
      }

      case 'REVOKE_MODERATOR': {
        if (!isHost && !isCoHost) {
          return res.status(403).json({ error: 'Only hosts or co-hosts can revoke moderator permissions' });
        }

        updatedParticipant = await (prisma as any).audioRoomParticipant.update({
          where: { roomId_userId: { roomId, userId: targetUserId } },
          data: { role: 'LISTENER', isMuted: true },
          include: { user: { select: userSelect } },
        });

        newLiveKitToken = await generateLiveKitToken({
          roomId,
          userId: targetUserId,
          userName: targetUser.fullName || targetUser.username,
          userAvatar: targetUser.avatarUrl,
          role: 'LISTENER',
        });

        emitToUsers([targetUserId], 'audio_room:role_demoted', {
          roomId,
          role: 'LISTENER',
          token: newLiveKitToken,
        });
        emitToAudioRoom(roomId, 'audio_room:participant_updated', { participant: updatedParticipant });
        break;
      }

      case 'MUTE': {
        updatedParticipant = await (prisma as any).audioRoomParticipant.update({
          where: { roomId_userId: { roomId, userId: targetUserId } },
          data: { isMuted: true },
          include: { user: { select: userSelect } },
        });

        emitToUsers([targetUserId], 'audio_room:force_muted', { roomId });
        emitToAudioRoom(roomId, 'audio_room:participant_updated', { participant: updatedParticipant });
        break;
      }

      case 'KICK': {
        await (prisma as any).audioRoomParticipant.deleteMany({
          where: { roomId, userId: targetUserId },
        });

        await removeLiveKitParticipant(roomId, targetUserId);

        emitToUsers([targetUserId], 'audio_room:kicked', { roomId });
        emitToAudioRoom(roomId, 'audio_room:participant_left', { userId: targetUserId });
        break;
      }

      default:
        return res.status(400).json({ error: `Unsupported moderation action: ${action}` });
    }

    return res.json({
      success: true,
      action,
      participant: updatedParticipant,
    });
  } catch (error: any) {
    console.error('[AudioRooms] Moderation failed:', error);
    return res.status(500).json({ error: 'Moderation action failed', details: error.message });
  }
});

/**
 * POST /api/audio-rooms/:id/share
 * Share this Live Space to campus channels or invite direct friends.
 */
router.post('/:id/share', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.id;
    const roomId = req.params.id as string;
    const { channelIds = [], userIds = [], message } = req.body;

    const room = await (prisma as any).audioRoom.findUnique({
      where: { id: roomId },
      include: { host: { select: userSelect } },
    });

    if (!room) {
      return res.status(404).json({ error: 'Audio room not found' });
    }

    const sender = await prisma.user.findUnique({
      where: { id: userId },
      select: userSelect,
    });

    // Share to specified channels
    if (Array.isArray(channelIds) && channelIds.length > 0) {
      for (const channelId of channelIds) {
        try {
          const cardText = message?.trim() || `🎙️ ${sender?.fullName || 'A friend'} shared a Live Space: "${room.title}"! Tap to join.`;
          await prisma.chatMessage.create({
            data: {
              senderId: userId,
              channelId,
              text: cardText,
              type: 'text',
              reactions: JSON.stringify({
                _liveSpace: {
                  roomId: room.id,
                  title: room.title,
                  category: room.category,
                  hostName: room.host.fullName || room.host.username,
                  hostAvatar: room.host.avatarUrl,
                  isLive: room.status === 'LIVE',
                },
              }),
            },
          });
          emitToAll('channel:updated', { channelId, roomId: room.id });
        } catch (_) {}
      }
    }

    // Direct user invitations
    if (Array.isArray(userIds) && userIds.length > 0) {
      emitToUsers(userIds, 'audio_room:invitation', {
        roomId: room.id,
        title: room.title,
        host: room.host,
        category: room.category,
        isLive: room.status === 'LIVE',
        scheduledAt: room.scheduledAt,
      });
    }

    const shareUrl = `https://abuadapp.com.ng/spaces/${roomId}`;
    return res.json({
      success: true,
      shareUrl,
      message: 'Live Space shared successfully',
    });
  } catch (error: any) {
    console.error('[AudioRooms] Share failed:', error);
    return res.status(500).json({ error: 'Failed to share space', details: error.message });
  }
});

/**
 * GET /api/audio-rooms/:id/messages
 * Get recent live room messages.
 */
router.get('/:id/messages', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const roomId = req.params.id as string;

    const messages = await (prisma as any).audioRoomMessage.findMany({
      where: { roomId },
      take: 50,
      orderBy: { createdAt: 'asc' },
      include: { user: { select: userSelect } },
    });

    return res.json({ success: true, data: messages });
  } catch (error: any) {
    return res.status(500).json({ error: 'Failed to fetch messages' });
  }
});

/**
 * POST /api/audio-rooms/:id/messages
 * Send in-room text chat.
 */
router.post('/:id/messages', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.id;
    const roomId = req.params.id as string;
    const { message, isAnnouncement, isPinned } = req.body;

    if (!message || !message.trim()) {
      return res.status(400).json({ error: 'Message cannot be empty' });
    }

    const chatMsg = await (prisma as any).audioRoomMessage.create({
      data: {
        roomId,
        userId,
        message: message.trim(),
        isAnnouncement: !!isAnnouncement,
        isPinned: !!isPinned,
      },
      include: { user: { select: userSelect } },
    });

    emitToAudioRoom(roomId, 'audio_room:message', { message: chatMsg });

    return res.status(201).json({ success: true, data: chatMsg });
  } catch (error: any) {
    return res.status(500).json({ error: 'Failed to send message' });
  }
});

/**
 * POST /api/audio-rooms/:id/end
 * Host explicitly ends the live space for everyone.
 */
router.post('/:id/end', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.id;
    const roomId = req.params.id as string;

    const room = await (prisma as any).audioRoom.findUnique({
      where: { id: roomId },
    });

    if (!room) {
      return res.status(404).json({ error: 'Audio room not found' });
    }

    if (room.hostId !== userId) {
      return res.status(403).json({ error: 'Only the primary host can end this audio room' });
    }

    const updated = await terminateAudioRoom(roomId, 'HOST_ENDED');
    return res.json({ success: true, data: updated, message: 'Audio room ended' });
  } catch (error: any) {
    console.error('[AudioRooms] End room failed:', error);
    return res.status(500).json({ error: 'Failed to end audio room', details: error.message });
  }
});

export default router;
