import { Router, Request, Response } from 'express';
import { authenticateToken, optionalAuth, AuthenticatedRequest } from '../middleware/auth';
import { prisma } from '../config/db';

const router = Router();

// Fallback in-memory store if DB table sync is pending
interface LocalSticker {
  id: string;
  title: string;
  imageUrl: string;
  animatedUrl?: string;
  type: string; // STATIC, ANIMATED, DOODLE, PHOTO_CUT
  category: string;
  tags: string[];
  isPublic: boolean;
  usageCount: number;
  authorId: string;
  authorName?: string;
  createdAt: string;
}

const DEFAULT_STICKERS: LocalSticker[] = [
  {
    id: 'stk_abuad_law',
    title: 'ABUAD Law ⚖️',
    imageUrl: 'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=300&auto=format&fit=crop&q=80',
    type: 'STATIC',
    category: 'CAMPUS',
    tags: ['abuad', 'law', 'college', 'justice'],
    isPublic: true,
    usageCount: 1420,
    authorId: 'system',
    authorName: 'ABUAD Campus',
    createdAt: new Date().toISOString(),
  },
  {
    id: 'stk_talent_cafe',
    title: 'Talent Cafe 🍗',
    imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=300&auto=format&fit=crop&q=80',
    type: 'STATIC',
    category: 'CAMPUS',
    tags: ['food', 'talent', 'cafeteria', 'chicken'],
    isPublic: true,
    usageCount: 980,
    authorId: 'system',
    authorName: 'ABUAD Campus',
    createdAt: new Date().toISOString(),
  },
  {
    id: 'stk_75_percent',
    title: '75% Attendance 🎓',
    imageUrl: 'https://images.unsplash.com/photo-1523240795612-9a054b0db644?w=300&auto=format&fit=crop&q=80',
    type: 'STATIC',
    category: 'STUDY',
    tags: ['attendance', 'exams', 'lecture', 'degree'],
    isPublic: true,
    usageCount: 890,
    authorId: 'system',
    authorName: 'ABUAD Campus',
    createdAt: new Date().toISOString(),
  },
  {
    id: 'stk_curfew_run',
    title: 'Curfew Dash 🏃‍♂️💨',
    imageUrl: 'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=300&auto=format&fit=crop&q=80',
    type: 'ANIMATED',
    animatedUrl: 'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=300&auto=format&fit=crop&q=80',
    category: 'CAMPUS',
    tags: ['curfew', 'hostel', 'run', 'sprint'],
    isPublic: true,
    usageCount: 740,
    authorId: 'system',
    authorName: 'ABUAD Campus',
    createdAt: new Date().toISOString(),
  },
  {
    id: 'stk_sunday_chapel',
    title: 'Sunday Chapel 🙏',
    imageUrl: 'https://images.unsplash.com/photo-1544427920-c49ccfb85579?w=300&auto=format&fit=crop&q=80',
    type: 'STATIC',
    category: 'CAMPUS',
    tags: ['chapel', 'sunday', 'worship', 'blessed'],
    isPublic: true,
    usageCount: 650,
    authorId: 'system',
    authorName: 'ABUAD Campus',
    createdAt: new Date().toISOString(),
  },
  {
    id: 'stk_exam_cram',
    title: 'Exam Mode 😭📚',
    imageUrl: 'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?w=300&auto=format&fit=crop&q=80',
    type: 'MEME',
    category: 'MEME',
    tags: ['exams', 'stress', 'nightclass', 'coffee'],
    isPublic: true,
    usageCount: 1250,
    authorId: 'system',
    authorName: 'ABUAD Campus',
    createdAt: new Date().toISOString(),
  },
];

// In-memory fallback cache
const localStickersStore: LocalSticker[] = [...DEFAULT_STICKERS];
const localSavedStickers = new Map<string, Set<string>>(); // userId -> Set of stickerIds

/**
 * GET /api/stickers/trending
 * Fetch top trending stickers sorted by usage count
 */
router.get('/trending', optionalAuth, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const limit = parseInt(req.query.limit as string) || 20;

    try {
      const dbStickers = await (prisma as any).sticker.findMany({
        where: { isPublic: true },
        orderBy: { usageCount: 'desc' },
        take: limit,
        include: {
          author: {
            select: { id: true, username: true, fullName: true, avatarUrl: true },
          },
        },
      });

      if (dbStickers && dbStickers.length > 0) {
        return res.json({ success: true, data: dbStickers });
      }
    } catch (_) {
      // Fallback to local store if DB table is unmigrated
    }

    const sorted = [...localStickersStore]
      .filter((s) => s.isPublic)
      .sort((a, b) => b.usageCount - a.usageCount)
      .slice(0, limit);

    return res.json({ success: true, data: sorted });
  } catch (error: any) {
    console.error('Error fetching trending stickers:', error);
    return res.status(500).json({ error: 'Failed to fetch trending stickers' });
  }
});

/**
 * GET /api/stickers/community
 * Browse public community stickers with search and category filtering
 */
router.get('/community', optionalAuth, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const category = (req.query.category as string)?.toUpperCase();
    const search = (req.query.search as string)?.toLowerCase();
    const limit = parseInt(req.query.limit as string) || 30;

    try {
      const where: any = { isPublic: true };
      if (category && category !== 'ALL') {
        where.category = category;
      }
      if (search) {
        where.OR = [
          { title: { contains: search, mode: 'insensitive' } },
          { tags: { has: search } },
        ];
      }

      const dbStickers = await (prisma as any).sticker.findMany({
        where,
        orderBy: [{ usageCount: 'desc' }, { createdAt: 'desc' }],
        take: limit,
        include: {
          author: {
            select: { id: true, username: true, fullName: true, avatarUrl: true },
          },
        },
      });

      if (dbStickers && dbStickers.length > 0) {
        return res.json({ success: true, data: dbStickers });
      }
    } catch (_) {}

    let filtered = localStickersStore.filter((s) => s.isPublic);

    if (category && category !== 'ALL') {
      filtered = filtered.filter((s) => s.category.toUpperCase() === category);
    }

    if (search) {
      filtered = filtered.filter(
        (s) =>
          s.title.toLowerCase().includes(search) ||
          s.tags.some((t) => t.toLowerCase().includes(search))
      );
    }

    return res.json({ success: true, data: filtered.slice(0, limit) });
  } catch (error: any) {
    console.error('Error fetching community stickers:', error);
    return res.status(500).json({ error: 'Failed to fetch community stickers' });
  }
});

/**
 * GET /api/stickers/my
 * Get current user's created and saved stickers
 */
router.get('/my', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.id;

    try {
      const created = await (prisma as any).sticker.findMany({
        where: { authorId: userId },
        orderBy: { createdAt: 'desc' },
      });

      const savedRecords = await (prisma as any).userSavedSticker.findMany({
        where: { userId },
        include: {
          sticker: {
            include: {
              author: {
                select: { id: true, username: true, fullName: true, avatarUrl: true },
              },
            },
          },
        },
      });

      const saved = savedRecords.map((r: any) => r.sticker);

      return res.json({
        success: true,
        data: {
          created,
          saved,
        },
      });
    } catch (_) {}

    // Fallback store
    const created = localStickersStore.filter((s) => s.authorId === userId);
    const savedIds = localSavedStickers.get(userId) || new Set<string>();
    const saved = localStickersStore.filter((s) => savedIds.has(s.id));

    return res.json({
      success: true,
      data: {
        created,
        saved,
      },
    });
  } catch (error: any) {
    console.error('Error fetching user stickers:', error);
    return res.status(500).json({ error: 'Failed to fetch user stickers' });
  }
});

/**
 * POST /api/stickers
 * Create a new sticker (Drawing, Photo Cutout, or Animated Loop)
 */
router.post('/', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.id;
    const {
      title,
      imageUrl,
      animatedUrl,
      type = 'STATIC',
      category = 'CAMPUS',
      tags = [],
      isPublic = true,
    } = req.body;

    if (!title || (!imageUrl && !animatedUrl)) {
      return res.status(400).json({ error: 'Title and image or animation are required' });
    }

    const cleanTags = Array.isArray(tags)
      ? tags.map((t: string) => String(t).trim().replace(/^#/, ''))
      : [];

    try {
      const created = await (prisma as any).sticker.create({
        data: {
          title: String(title).trim(),
          imageUrl: String(imageUrl || animatedUrl),
          animatedUrl: animatedUrl ? String(animatedUrl) : null,
          type: String(type).toUpperCase(),
          category: String(category).toUpperCase(),
          tags: cleanTags,
          isPublic: Boolean(isPublic),
          authorId: userId,
        },
        include: {
          author: {
            select: { id: true, username: true, fullName: true, avatarUrl: true },
          },
        },
      });

      return res.status(201).json({ success: true, data: created });
    } catch (_) {}

    // Fallback memory insertion
    const localItem: LocalSticker = {
      id: `stk_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      title: String(title).trim(),
      imageUrl: String(imageUrl || animatedUrl),
      animatedUrl: animatedUrl ? String(animatedUrl) : undefined,
      type: String(type).toUpperCase(),
      category: String(category).toUpperCase(),
      tags: cleanTags,
      isPublic: Boolean(isPublic),
      usageCount: 1,
      authorId: userId,
      authorName: (req.user as any)?.username || (req.user as any)?.name || 'Student',
      createdAt: new Date().toISOString(),
    };

    localStickersStore.unshift(localItem);

    return res.status(201).json({ success: true, data: localItem });
  } catch (error: any) {
    console.error('Error creating sticker:', error);
    return res.status(500).json({ error: 'Failed to create sticker' });
  }
});

/**
 * POST /api/stickers/:id/use
 * Increment sticker usage count (boosts trending score)
 */
router.post('/:id/use', optionalAuth, async (req: Request, res: Response) => {
  try {
    const id = String(req.params.id);

    try {
      const updated = await (prisma as any).sticker.update({
        where: { id },
        data: { usageCount: { increment: 1 } },
      });
      return res.json({ success: true, usageCount: updated.usageCount });
    } catch (_) {}

    const local = localStickersStore.find((s) => s.id === id);
    if (local) {
      local.usageCount += 1;
      return res.json({ success: true, usageCount: local.usageCount });
    }

    return res.json({ success: true });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to record sticker usage' });
  }
});

/**
 * POST /api/stickers/:id/save
 * Save sticker to user's favorites tray
 */
router.post('/:id/save', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.id;
    const stickerId = String(req.params.id);

    try {
      await (prisma as any).userSavedSticker.upsert({
        where: {
          userId_stickerId: { userId, stickerId },
        },
        create: { userId, stickerId },
        update: {},
      });
      return res.json({ success: true, message: 'Sticker saved to collection' });
    } catch (_) {}

    if (!localSavedStickers.has(userId)) {
      localSavedStickers.set(userId, new Set());
    }
    localSavedStickers.get(userId)!.add(stickerId);

    return res.json({ success: true, message: 'Sticker saved to collection' });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to save sticker' });
  }
});

/**
 * DELETE /api/stickers/:id/save
 * Remove sticker from user's favorites tray
 */
router.delete('/:id/save', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.id;
    const stickerId = String(req.params.id);

    try {
      await (prisma as any).userSavedSticker.deleteMany({
        where: { userId, stickerId },
      });
      return res.json({ success: true, message: 'Sticker removed from collection' });
    } catch (_) {}

    localSavedStickers.get(userId)?.delete(stickerId);
    return res.json({ success: true, message: 'Sticker removed from collection' });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to remove sticker' });
  }
});

/**
 * DELETE /api/stickers/:id
 * Delete a sticker (author only or admin)
 */
router.delete('/:id', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.id;
    const userRole = req.user!.role;
    const id = String(req.params.id);

    try {
      const sticker = await (prisma as any).sticker.findUnique({ where: { id } });
      if (!sticker) return res.status(404).json({ error: 'Sticker not found' });

      if (sticker.authorId !== userId && userRole !== 'ADMIN') {
        return res.status(403).json({ error: 'Not authorized to delete this sticker' });
      }

      await (prisma as any).sticker.delete({ where: { id } });
      return res.json({ success: true, message: 'Sticker deleted successfully' });
    } catch (_) {}

    const index = localStickersStore.findIndex((s) => s.id === id);
    if (index !== -1) {
      if (localStickersStore[index].authorId !== userId && userRole !== 'ADMIN') {
        return res.status(403).json({ error: 'Not authorized to delete this sticker' });
      }
      localStickersStore.splice(index, 1);
    }

    return res.json({ success: true, message: 'Sticker deleted successfully' });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to delete sticker' });
  }
});

export default router;
