import { Router, Response } from 'express';
import { authenticateToken, AuthenticatedRequest } from '../middleware/auth';
import { prisma } from '../config/db';

const router = Router();

function formatStory(s: any) {
  let viewers: string[] = [];
  let likes: string[] = [];
  let mentions: string[] = [];

  try {
    viewers = typeof s.viewers === 'string' ? JSON.parse(s.viewers || '[]') : (s.viewers || []);
  } catch (_) {}
  try {
    likes = typeof s.likes === 'string' ? JSON.parse(s.likes || '[]') : (s.likes || []);
  } catch (_) {}
  try {
    mentions = typeof s.mentions === 'string' ? JSON.parse(s.mentions || '[]') : (s.mentions || []);
  } catch (_) {}

  let audioUrl: string | null = null;
  let musicTitle: string | null = null;
  let musicArtist: string | null = null;
  let linkUrl = s.linkUrl;

  if (s.linkUrl && typeof s.linkUrl === 'string' && s.linkUrl.startsWith('{') && s.linkUrl.includes('"audioUrl"')) {
    try {
      const musicData = JSON.parse(s.linkUrl);
      audioUrl = musicData.audioUrl || null;
      musicTitle = musicData.musicTitle || null;
      musicArtist = musicData.musicArtist || null;
      linkUrl = musicData.linkUrl || null;
    } catch (_) {}
  }

  const mediaType = (s.mediaType || 'image').toLowerCase();

  return {
    ...s,
    content: s.mediaUrl,
    mediaUrl: s.mediaUrl,
    mediaType,
    type: mediaType,
    viewers,
    likes,
    mentions,
    audioUrl,
    musicTitle,
    musicArtist,
    linkUrl,
    userName: s.author?.fullName || s.author?.username || '',
    userAvatar: s.author?.avatarUrl || '',
  };
}

/**
 * GET /api/stories - Get active 24h stories
 */
router.get('/', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const now = new Date();
    const stories = await prisma.story.findMany({
      where: {
        expiresAt: { gt: now },
      },
      orderBy: { createdAt: 'desc' },
      include: {
        author: {
          select: {
            id: true,
            username: true,
            fullName: true,
            avatarUrl: true,
          },
        },
      },
    });

    const parsedStories = stories.map(formatStory);
    return res.json({ success: true, data: parsedStories });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to fetch stories' });
  }
});

/**
 * POST /api/stories
 */
router.post('/', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { mediaUrl, content, mediaType, type, caption, linkUrl, mentions, audioUrl, musicTitle, musicArtist } = req.body;
    const finalMediaUrl = mediaUrl || content || (type === 'text' || mediaType === 'text' ? 'text' : '');
    if (!finalMediaUrl && type !== 'text' && mediaType !== 'text') {
      return res.status(400).json({ error: 'Media URL is required for story' });
    }

    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 Hours duration
    const mentionsJson = Array.isArray(mentions) ? JSON.stringify(mentions) : (typeof mentions === 'string' ? mentions : '[]');

    let finalLinkUrl = linkUrl || null;
    if (audioUrl) {
      finalLinkUrl = JSON.stringify({
        audioUrl,
        musicTitle: musicTitle || '',
        musicArtist: musicArtist || '',
        linkUrl: linkUrl || null,
      });
    }

    const story = await prisma.story.create({
      data: {
        authorId: req.user!.id,
        mediaUrl: finalMediaUrl || 'text',
        mediaType: (mediaType || type || 'image').toUpperCase(),
        caption: caption || null,
        linkUrl: finalLinkUrl,
        mentions: mentionsJson,
        expiresAt,
      },
      include: {
        author: {
          select: {
            id: true,
            username: true,
            fullName: true,
            avatarUrl: true,
          },
        },
      },
    });

    return res.status(201).json({
      success: true,
      data: formatStory(story),
    });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to post story' });
  }
});

/**
 * POST /api/stories/:id/view - Record a view on story
 */
router.post('/:id/view', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const id = String(req.params.id);
    const userId = req.user!.id;

    const story = await prisma.story.findUnique({ where: { id } });
    if (!story) {
      return res.status(404).json({ error: 'Story not found' });
    }

    let viewers: string[] = [];
    try {
      viewers = typeof story.viewers === 'string' ? JSON.parse(story.viewers || '[]') : (story.viewers || []);
    } catch (_) {}

    if (!viewers.includes(userId)) {
      viewers.push(userId);
      await prisma.story.update({
        where: { id },
        data: {
          viewers: JSON.stringify(viewers),
          viewersCount: viewers.length,
        },
      });
    }

    return res.json({ success: true, viewersCount: viewers.length });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to record story view' });
  }
});

/**
 * POST /api/stories/:id/like - Toggle like on story
 */
router.post('/:id/like', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const id = String(req.params.id);
    const userId = req.user!.id;
    const { isLiking } = req.body;

    const story = await prisma.story.findUnique({ where: { id } });
    if (!story) {
      return res.status(404).json({ error: 'Story not found' });
    }

    let likes: string[] = [];
    try {
      likes = typeof story.likes === 'string' ? JSON.parse(story.likes || '[]') : (story.likes || []);
    } catch (_) {}

    if (isLiking === true) {
      if (!likes.includes(userId)) likes.push(userId);
    } else if (isLiking === false) {
      likes = likes.filter((uid) => uid !== userId);
    } else {
      if (likes.includes(userId)) {
        likes = likes.filter((uid) => uid !== userId);
      } else {
        likes.push(userId);
      }
    }

    await prisma.story.update({
      where: { id },
      data: {
        likes: JSON.stringify(likes),
        likesCount: likes.length,
      },
    });

    return res.json({ success: true, likesCount: likes.length, hasLiked: likes.includes(userId) });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to update story like' });
  }
});

/**
 * DELETE /api/stories/:id - Delete a story
 */
router.delete('/:id', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const id = String(req.params.id);
    const userId = req.user!.id;

    const story = await prisma.story.findUnique({ where: { id } });
    if (!story) {
      return res.status(404).json({ error: 'Story not found' });
    }

    if (story.authorId !== userId) {
      return res.status(403).json({ error: 'Unauthorized to delete this story' });
    }

    await prisma.story.delete({ where: { id } });

    return res.json({ success: true, message: 'Story deleted successfully' });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to delete story' });
  }
});

export default router;

