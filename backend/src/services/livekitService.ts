import { AccessToken, RoomServiceClient } from 'livekit-server-sdk';

const LIVEKIT_URL = process.env.LIVEKIT_URL || 'wss://abuad-cgeux9e8.livekit.cloud';
const LIVEKIT_API_KEY = process.env.LIVEKIT_API_KEY || 'APIm3GQ6f4JbJ7a';
const LIVEKIT_API_SECRET = process.env.LIVEKIT_API_SECRET || 'ERcJJcvDFFfq2obQvqSjJ0pfUYViEffsfJfWn4gaTElM';

export interface TokenOptions {
  roomId: string;
  userId: string;
  userName: string;
  userAvatar?: string | null;
  role: 'HOST' | 'CO_HOST' | 'SPEAKER' | 'LISTENER';
}

export async function generateLiveKitToken(options: TokenOptions): Promise<string> {
  const isSpeaker = options.role === 'HOST' || options.role === 'CO_HOST' || options.role === 'SPEAKER';

  const token = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
    identity: options.userId,
    name: options.userName,
    metadata: JSON.stringify({
      avatarUrl: options.userAvatar || '',
      role: options.role,
    }),
    ttl: '24h',
  });

  token.addGrant({
    roomJoin: true,
    room: options.roomId,
    canPublish: isSpeaker,
    canPublishData: true,
    canSubscribe: true,
  });

  return await token.toJwt();
}

let roomService: RoomServiceClient | null = null;

export function getRoomServiceClient(): RoomServiceClient {
  if (!roomService) {
    // Transform wss:// to https:// for REST RoomServiceClient
    const httpUrl = LIVEKIT_URL.replace(/^wss:\/\//, 'https://').replace(/^ws:\/\//, 'http://');
    roomService = new RoomServiceClient(httpUrl, LIVEKIT_API_KEY, LIVEKIT_API_SECRET);
  }
  return roomService;
}

export async function endLiveKitRoom(roomId: string): Promise<void> {
  try {
    const client = getRoomServiceClient();
    await client.deleteRoom(roomId);
  } catch (error) {
    console.warn(`[LiveKit] Could not delete room ${roomId}:`, error);
  }
}

export async function removeLiveKitParticipant(roomId: string, userId: string): Promise<void> {
  try {
    const client = getRoomServiceClient();
    await client.removeParticipant(roomId, userId);
  } catch (error) {
    console.warn(`[LiveKit] Could not remove participant ${userId} from room ${roomId}:`, error);
  }
}

export async function muteLiveKitParticipantTrack(roomId: string, userId: string, trackSid: string): Promise<void> {
  try {
    const client = getRoomServiceClient();
    await client.mutePublishedTrack(roomId, userId, trackSid, true);
  } catch (error) {
    console.warn(`[LiveKit] Could not mute track for ${userId}:`, error);
  }
}

