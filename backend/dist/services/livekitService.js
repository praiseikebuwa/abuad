"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateLiveKitToken = generateLiveKitToken;
exports.getRoomServiceClient = getRoomServiceClient;
exports.endLiveKitRoom = endLiveKitRoom;
exports.removeLiveKitParticipant = removeLiveKitParticipant;
exports.muteLiveKitParticipantTrack = muteLiveKitParticipantTrack;
const livekit_server_sdk_1 = require("livekit-server-sdk");
const LIVEKIT_URL = process.env.LIVEKIT_URL || 'wss://abuad-cgeux9e8.livekit.cloud';
const LIVEKIT_API_KEY = process.env.LIVEKIT_API_KEY || 'APIm3GQ6f4JbJ7a';
const LIVEKIT_API_SECRET = process.env.LIVEKIT_API_SECRET || 'ERcJJcvDFFfq2obQvqSjJ0pfUYViEffsfJfWn4gaTElM';
async function generateLiveKitToken(options) {
    const isSpeaker = options.role === 'HOST' || options.role === 'CO_HOST' || options.role === 'SPEAKER' || options.role === 'MODERATOR';
    const token = new livekit_server_sdk_1.AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
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
let roomService = null;
function getRoomServiceClient() {
    if (!roomService) {
        // Transform wss:// to https:// for REST RoomServiceClient
        const httpUrl = LIVEKIT_URL.replace(/^wss:\/\//, 'https://').replace(/^ws:\/\//, 'http://');
        roomService = new livekit_server_sdk_1.RoomServiceClient(httpUrl, LIVEKIT_API_KEY, LIVEKIT_API_SECRET);
    }
    return roomService;
}
async function endLiveKitRoom(roomId) {
    try {
        const client = getRoomServiceClient();
        await client.deleteRoom(roomId);
    }
    catch (error) {
        console.warn(`[LiveKit] Could not delete room ${roomId}:`, error);
    }
}
async function removeLiveKitParticipant(roomId, userId) {
    try {
        const client = getRoomServiceClient();
        await client.removeParticipant(roomId, userId);
    }
    catch (error) {
        console.warn(`[LiveKit] Could not remove participant ${userId} from room ${roomId}:`, error);
    }
}
async function muteLiveKitParticipantTrack(roomId, userId, trackSid) {
    try {
        const client = getRoomServiceClient();
        await client.mutePublishedTrack(roomId, userId, trackSid, true);
    }
    catch (error) {
        console.warn(`[LiveKit] Could not mute track for ${userId}:`, error);
    }
}
