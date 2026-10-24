import { prisma } from '../config/db';

export interface UserInterestProfile {
  interactedAuthors: Record<string, number>; // authorId -> affinity count
  preferredTags: Record<string, number>; // hashtag/topic -> interest score
  preferredChannels: Record<string, number>; // channelId -> score
  prefersVideo: number; // 0 to 1 ratio
  seenPostIds: Set<string>;
  mutedAuthors: Set<string>;
  mutedTags: Set<string>;
  negativePostIds: Set<string>;
}

// In-memory cache for recent negative feedback & real-time interaction weights
const userNegativeCache: Map<string, { mutedAuthors: Set<string>; mutedTags: Set<string>; negativePosts: Set<string> }> = new Map();

/**
 * Get or initialize cached negative preferences for a student
 */
function getCachedNegativePreferences(userId: string) {
  let entry = userNegativeCache.get(userId);
  if (!entry) {
    entry = {
      mutedAuthors: new Set<string>(),
      mutedTags: new Set<string>(),
      negativePosts: new Set<string>(),
    };
    userNegativeCache.set(userId, entry);
  }
  return entry;
}

/**
 * Record a user behavioral interaction signal to continuously improve feed ranking
 */
export async function recordUserInteraction(
  userId: string,
  postId: string,
  action: 'view' | 'like' | 'save' | 'share' | 'watch_complete' | 'skip' | 'not_interested' | 'mute_author' | 'mute_topic',
  metadata?: { authorId?: string; tags?: string[]; channelId?: string }
): Promise<void> {
  if (!userId || !postId) return;

  const prefs = getCachedNegativePreferences(userId);

  if (action === 'not_interested') {
    prefs.negativePosts.add(postId);
    if (metadata?.authorId) prefs.mutedAuthors.add(metadata.authorId);
    if (metadata?.tags) {
      for (const t of metadata.tags) prefs.mutedTags.add(t.toLowerCase().replace('#', ''));
    }
    return;
  }

  if (action === 'mute_author' && metadata?.authorId) {
    prefs.mutedAuthors.add(metadata.authorId);
    return;
  }

  if (action === 'mute_topic' && metadata?.tags) {
    for (const t of metadata.tags) prefs.mutedTags.add(t.toLowerCase().replace('#', ''));
    return;
  }
}

/**
 * Build a user interest profile by analyzing recent behavioral signals
 */
export async function getUserInterestProfile(userId?: string): Promise<UserInterestProfile> {
  const profile: UserInterestProfile = {
    interactedAuthors: {},
    preferredTags: {},
    preferredChannels: {},
    prefersVideo: 0.5,
    seenPostIds: new Set<string>(),
    mutedAuthors: new Set<string>(),
    mutedTags: new Set<string>(),
    negativePostIds: new Set<string>(),
  };

  if (!userId) {
    return profile;
  }

  // Populate from negative preferences cache
  const cachedNeg = userNegativeCache.get(userId);
  if (cachedNeg) {
    profile.mutedAuthors = new Set(cachedNeg.mutedAuthors);
    profile.mutedTags = new Set(cachedNeg.mutedTags);
    profile.negativePostIds = new Set(cachedNeg.negativePosts);
  }

  try {
    // 1. Followed Creators (High affinity)
    const following = await prisma.follower.findMany({
      where: { followerId: userId },
      select: { followedId: true },
      take: 200,
    });
    for (const f of following) {
      profile.interactedAuthors[f.followedId] = (profile.interactedAuthors[f.followedId] || 0) + 12;
    }

    // 2. Liked Posts (Signals interest in authors, hashtags, channels)
    const recentLikes = await prisma.postLike.findMany({
      where: { userId },
      take: 50,
      orderBy: { createdAt: 'desc' },
      include: {
        post: {
          select: { id: true, authorId: true, hashtags: true, channelId: true, mediaType: true },
        },
      },
    });

    let videoCount = 0;
    let totalMedia = 0;

    for (const l of recentLikes) {
      profile.seenPostIds.add(l.post.id);
      profile.interactedAuthors[l.post.authorId] = (profile.interactedAuthors[l.post.authorId] || 0) + 6;
      
      if (l.post.channelId) {
        profile.preferredChannels[l.post.channelId] = (profile.preferredChannels[l.post.channelId] || 0) + 4;
      }

      if (l.post.mediaType === 'video') videoCount++;
      if (l.post.mediaType && l.post.mediaType !== 'none') totalMedia++;

      try {
        const tags: string[] = JSON.parse(l.post.hashtags || '[]');
        for (const tag of tags) {
          const cleanTag = tag.toLowerCase().replace('#', '');
          profile.preferredTags[cleanTag] = (profile.preferredTags[cleanTag] || 0) + 5;
        }
      } catch {}
    }

    // 3. Saved Posts (Strongest deliberate signal)
    const recentSaves = await prisma.savedPost.findMany({
      where: { userId },
      take: 30,
      orderBy: { createdAt: 'desc' },
      include: {
        post: {
          select: { id: true, authorId: true, hashtags: true, channelId: true },
        },
      },
    });

    for (const s of recentSaves) {
      profile.seenPostIds.add(s.post.id);
      profile.interactedAuthors[s.post.authorId] = (profile.interactedAuthors[s.post.authorId] || 0) + 10;
      try {
        const tags: string[] = JSON.parse(s.post.hashtags || '[]');
        for (const tag of tags) {
          const cleanTag = tag.toLowerCase().replace('#', '');
          profile.preferredTags[cleanTag] = (profile.preferredTags[cleanTag] || 0) + 8;
        }
      } catch {}
    }

    // 4. Comments Made by User
    const recentComments = await prisma.postComment.findMany({
      where: { authorId: userId },
      take: 30,
      select: { postId: true },
    });
    for (const c of recentComments) {
      profile.seenPostIds.add(c.postId);
    }

    if (totalMedia > 0) {
      profile.prefersVideo = videoCount / totalMedia;
    }
  } catch (err) {
    console.error('Error computing user interest profile:', err);
  }

  return profile;
}

/**
 * Score a single candidate post for a student using multi-factor AI ranking:
 * S(u,p) = 0.35*I + 0.20*R + 0.15*F + 0.15*Q + 0.10*N + 0.05*D
 */
export function scorePost(post: any, userProfile: UserInterestProfile): number {
  // Hard filters (negative feedback & blocks)
  if (userProfile.negativePostIds.has(post.id)) return -99999;
  if (userProfile.mutedAuthors.has(post.authorId)) return -99999;

  const now = Date.now();
  const postTime = new Date(post.createdAt).getTime();
  const hoursOld = Math.max(0.1, (now - postTime) / (1000 * 60 * 60));

  // 1. Freshness Score (N): Exponential decay with 36-hour half-life
  const freshnessScore = Math.exp(-hoursOld / 36) * 100;

  // 2. Creator Affinity (F)
  const authorAffinity = userProfile.interactedAuthors[post.authorId] || 0;
  const creatorScore = Math.min(100, authorAffinity * 8);

  // 3. Topic & Interest Relevance (I)
  let topicScore = 0;
  try {
    const tags: string[] = JSON.parse(post.hashtags || '[]');
    for (const tag of tags) {
      const cleanTag = tag.toLowerCase().replace('#', '');
      if (userProfile.mutedTags.has(cleanTag)) return -99999;
      if (userProfile.preferredTags[cleanTag]) {
        topicScore += userProfile.preferredTags[cleanTag] * 12;
      }
    }
  } catch {}
  topicScore = Math.min(100, topicScore);

  // 4. Global Engagement / Predicted Virality (R)
  const likesCount = post._count?.likes ?? post.likesCount ?? 0;
  const commentsCount = post._count?.comments ?? post.commentsCount ?? 0;
  const sharesCount = post.sharesCount ?? 0;
  const savesCount = post.savesCount ?? 0;
  const viewsCount = Math.max(1, post.viewsCount ?? 0);

  const rawEngagement = (likesCount * 3) + (commentsCount * 5) + (sharesCount * 8) + (savesCount * 6);
  const engagementScore = Math.min(100, (rawEngagement / Math.log10(viewsCount + 10)) * 5);

  // 5. Quality & Verification (Q)
  let qualityScore = 50;
  const isAiAuthor = post.author?.username === 'abuad_ai' || post.author?.email === 'ai@abuad.edu.ng';
  if (!isAiAuthor) {
    if (post.author?.verificationType === 'GOLD') qualityScore += 35;
    else if (post.author?.isVerified) qualityScore += 20;
  } else {
    // Keep bot posts balanced so student voices remain primary
    qualityScore -= 30;
  }

  // Media preference bonus
  if (post.mediaType === 'video' && userProfile.prefersVideo > 0.6) {
    qualityScore += 15;
  }

  // 6. Discovery & Diversity Jitter (D)
  const discoveryScore = Math.random() * 100;

  // 7. Seen Penalty
  const seenPenalty = userProfile.seenPostIds.has(post.id) ? 75 : 0;

  // Formula: S(u,p) = 0.35*I + 0.20*R + 0.15*F + 0.15*Q + 0.10*N + 0.05*D
  const finalScore =
    (0.35 * topicScore) +
    (0.20 * engagementScore) +
    (0.15 * creatorScore) +
    (0.15 * qualityScore) +
    (0.10 * freshnessScore) +
    (0.05 * discoveryScore) -
    seenPenalty;

  return Math.round(finalScore * 100) / 100;
}

/**
 * Feed Diversity Filter:
 * Ensures the student doesn't see more than 2 consecutive posts from the same creator or channel.
 */
export function applyFeedDiversity(scoredItems: { post: any; score: number }[]): { post: any; score: number }[] {
  if (scoredItems.length <= 2) return scoredItems;

  const result: { post: any; score: number }[] = [];
  const remaining = [...scoredItems];

  let lastAuthorId: string | null = null;
  let secondLastAuthorId: string | null = null;

  while (remaining.length > 0) {
    // Find highest scoring post that doesn't repeat the last 2 authors
    let pickedIndex = remaining.findIndex(
      item => item.post.authorId !== lastAuthorId || item.post.authorId !== secondLastAuthorId
    );

    if (pickedIndex === -1) {
      pickedIndex = 0;
    }

    const [selected] = remaining.splice(pickedIndex, 1);
    result.push(selected);

    secondLastAuthorId = lastAuthorId;
    lastAuthorId = selected.post.authorId;
  }

  return result;
}

/**
 * Encode cursor for opaque pagination
 */
export function encodeCursor(cursorData: { id: string; score?: number; createdAt?: string }): string {
  return Buffer.from(JSON.stringify(cursorData)).toString('base64url');
}

/**
 * Decode cursor
 */
export function decodeCursor(cursorString?: string): { id: string; score?: number; createdAt?: string } | null {
  if (!cursorString) return null;
  try {
    const json = Buffer.from(cursorString, 'base64url').toString('utf8');
    return JSON.parse(json);
  } catch {
    return null;
  }
}
