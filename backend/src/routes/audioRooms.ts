import { Router, Response } from 'express';
import { authenticateToken, AuthenticatedRequest } from '../middleware/auth';
import { prisma } from '../config/db';
import {
  generateLiveKitToken,
  endLiveKitRoom,
  removeLiveKitParticipant,
  TokenOptions,
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
          take: 6,
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
        title: title.trim(),
        description: description?.trim() || null,
        category: category.toUpperCase(),
        visibility: visibility.toUpperCase(),
        speakersPermission: speakersPermission.toUpperCase(),
        status: roomStatus,
        isRecording: !!isRecording,
        isChatEnabled: !!isChatEnabled,
        scheduledAt: scheduledAt ? new Date(scheduledAt) : null,
        startedAt: isScheduled ? null : new Date(),
        participants: isScheduled
          ? undefined
          : {
              create: {
                userId,
                role: 'HOST',
                isMuted: false,
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

    // Generate LiveKit token for the host if room is LIVE
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

    // Broadcast new live room to feed and active users
    if (!isScheduled) {
      emitToAll('audio_room:created', { room });
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

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: userSelect,
    });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Determine role
    let assignedRole: 'HOST' | 'CO_HOST' | 'SPEAKER' | 'LISTENER' = 'LISTENER';
    if (room.hostId === userId) {
      assignedRole = 'HOST';
    } else {
      // Check existing participation
      const existing = await (prisma as any).audioRoomParticipant.findUnique({
        where: { roomId_userId: { roomId, userId } },
      });
      if (existing) {
        assignedRole = existing.role;
      } else if (room.speakersPermission === 'EVERYONE') {
        assignedRole = 'SPEAKER';
      }
    }

    // Upsert participant record
    const participant = await (prisma as any).audioRoomParticipant.upsert({
      where: { roomId_userId: { roomId, userId } },
      update: {
        role: assignedRole,
        isMuted: assignedRole === 'LISTENER',
      },
      create: {
        roomId,
        userId,
        role: assignedRole,
        isMuted: assignedRole === 'LISTENER',
      },
      include: { user: { select: userSelect } },
    });

    // If room was scheduled and host joined, mark it LIVE
    if (room.status === 'SCHEDULED' && assignedRole === 'HOST') {
      await (prisma as any).audioRoom.update({
        where: { id: roomId },
        data: { status: 'LIVE', startedAt: new Date() },
      });
    }

    // Generate LiveKit token
    const token = await generateLiveKitToken({
      roomId,
      userId,
      userName: user.fullName || user.username,
      userAvatar: user.avatarUrl,
      role: assignedRole,
    });

    // Notify room of new participant
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
 * POST /api/audio-rooms/:id/leave
 * Leave the audio room.
 */
router.post('/:id/leave', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.id;
    const roomId = req.params.id as string;

    await (prisma as any).audioRoomParticipant.deleteMany({
      where: { roomId, userId },
    });

    // Also cancel any pending speak requests
    await (prisma as any).audioRoomRequest.deleteMany({
      where: { roomId, userId },
    });

    emitToAudioRoom(roomId, 'audio_room:participant_left', { userId });

    return res.json({ success: true, message: 'Left audio room' });
  } catch (error: any) {
    console.error('[AudioRooms] Leave failed:', error);
    return res.status(500).json({ error: 'Failed to leave audio room', details: error.message });
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

    const request = await (prisma as any).audioRoomRequest.upsert({
      where: { id: `${roomId}_${userId}` }, // or create new
      update: { status: 'PENDING', createdAt: new Date() },
      create: {
        roomId,
        userId,
        status: 'PENDING',
      },
      include: { user: { select: userSelect } },
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

    emitToAudioRoom(roomId, 'audio_room:hand_lowered', { userId: targetUserId });

    return res.json({ success: true, message: 'Hand lowered' });
  } catch (error: any) {
    console.error('[AudioRooms] Lower hand failed:', error);
    return res.status(500).json({ error: 'Failed to lower hand', details: error.message });
  }
});

/**
 * POST /api/audio-rooms/:id/moderate
 * Host/Co-host actions: APPROVE_SPEAKER, DEMOTE_TO_LISTENER, MAKE_CO_HOST, MUTE, KICK.
 */
router.post('/:id/moderate', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const callerId = req.user!.id;
    const roomId = req.params.id as string;
    const { targetUserId, action } = req.body;

    if (!targetUserId || !action) {
      return res.status(400).json({ error: 'targetUserId and action are required' });
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

    // Verify caller is HOST or CO_HOST
    const callerParticipant = room.participants.find((p: any) => p.userId === callerId);
    const isHost = room.hostId === callerId || callerParticipant?.role === 'HOST';
    const isCoHost = callerParticipant?.role === 'CO_HOST';

    if (!isHost && !isCoHost) {
      return res.status(403).json({ error: 'Only hosts or co-hosts can moderate this room' });
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
      case 'APPROVE_SPEAKER': {
        // Remove pending hand request
        await (prisma as any).audioRoomRequest.deleteMany({
          where: { roomId, userId: targetUserId },
        });

        updatedParticipant = await (prisma as any).audioRoomParticipant.upsert({
          where: { roomId_userId: { roomId, userId: targetUserId } },
          update: { role: 'SPEAKER', isMuted: false },
          create: { roomId, userId: targetUserId, role: 'SPEAKER', isMuted: false },
          include: { user: { select: userSelect } },
        });

        // Generate speaker token for target user
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
          return res.status(403).json({ error: 'Only the room host can appoint co-hosts' });
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
    const { message } = req.body;

    if (!message || !message.trim()) {
      return res.status(400).json({ error: 'Message cannot be empty' });
    }

    const chatMsg = await (prisma as any).audioRoomMessage.create({
      data: {
        roomId,
        userId,
        message: message.trim(),
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
 * Host ends the live space.
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
      return res.status(403).json({ error: 'Only the host can end this audio room' });
    }

    const updated = await (prisma as any).audioRoom.update({
      where: { id: roomId },
      data: {
        status: 'ENDED',
        endedAt: new Date(),
      },
    });

    // Close the LiveKit room session
    await endLiveKitRoom(roomId);

    emitToAudioRoom(roomId, 'audio_room:ended', { roomId });
    emitToAll('audio_room:ended', { roomId });

    return res.json({ success: true, data: updated, message: 'Audio room ended' });
  } catch (error: any) {
    console.error('[AudioRooms] End room failed:', error);
    return res.status(500).json({ error: 'Failed to end audio room', details: error.message });
  }
});

export default router;
