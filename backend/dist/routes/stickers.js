"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const auth_1 = require("../middleware/auth");
const db_1 = require("../config/db");
const router = (0, express_1.Router)();
const DEFAULT_STICKERS = [];
// In-memory fallback cache
const localStickersStore = [...DEFAULT_STICKERS];
const localSavedStickers = new Map(); // userId -> Set of stickerIds
/**
 * GET /api/stickers/trending
 * Fetch top trending stickers sorted by usage count
 */
router.get('/trending', auth_1.optionalAuth, async (req, res) => {
    try {
        const limit = parseInt(req.query.limit) || 20;
        try {
            const dbStickers = await db_1.prisma.sticker.findMany({
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
        }
        catch (_) {
            // Fallback to local store if DB table is unmigrated
        }
        const sorted = [...localStickersStore]
            .filter((s) => s.isPublic)
            .sort((a, b) => b.usageCount - a.usageCount)
            .slice(0, limit);
        return res.json({ success: true, data: sorted });
    }
    catch (error) {
        console.error('Error fetching trending stickers:', error);
        return res.status(500).json({ error: 'Failed to fetch trending stickers' });
    }
});
/**
 * GET /api/stickers/community
 * Browse public community stickers with search and category filtering
 */
router.get('/community', auth_1.optionalAuth, async (req, res) => {
    try {
        const category = req.query.category?.toUpperCase();
        const search = req.query.search?.toLowerCase();
        const limit = parseInt(req.query.limit) || 30;
        try {
            const where = { isPublic: true };
            if (category && category !== 'ALL') {
                where.category = category;
            }
            if (search) {
                where.OR = [
                    { title: { contains: search, mode: 'insensitive' } },
                    { tags: { has: search } },
                ];
            }
            const dbStickers = await db_1.prisma.sticker.findMany({
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
        }
        catch (_) { }
        let filtered = localStickersStore.filter((s) => s.isPublic);
        if (category && category !== 'ALL') {
            filtered = filtered.filter((s) => s.category.toUpperCase() === category);
        }
        if (search) {
            filtered = filtered.filter((s) => s.title.toLowerCase().includes(search) ||
                s.tags.some((t) => t.toLowerCase().includes(search)));
        }
        return res.json({ success: true, data: filtered.slice(0, limit) });
    }
    catch (error) {
        console.error('Error fetching community stickers:', error);
        return res.status(500).json({ error: 'Failed to fetch community stickers' });
    }
});
/**
 * GET /api/stickers/my
 * Get current user's created and saved stickers
 */
router.get('/my', auth_1.authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        try {
            const created = await db_1.prisma.sticker.findMany({
                where: { authorId: userId },
                orderBy: { createdAt: 'desc' },
            });
            const savedRecords = await db_1.prisma.userSavedSticker.findMany({
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
            const saved = savedRecords.map((r) => r.sticker);
            return res.json({
                success: true,
                data: {
                    created,
                    saved,
                },
            });
        }
        catch (_) { }
        // Fallback store
        const created = localStickersStore.filter((s) => s.authorId === userId);
        const savedIds = localSavedStickers.get(userId) || new Set();
        const saved = localStickersStore.filter((s) => savedIds.has(s.id));
        return res.json({
            success: true,
            data: {
                created,
                saved,
            },
        });
    }
    catch (error) {
        console.error('Error fetching user stickers:', error);
        return res.status(500).json({ error: 'Failed to fetch user stickers' });
    }
});
/**
 * POST /api/stickers
 * Create a new sticker (Drawing, Photo Cutout, or Animated Loop)
 */
router.post('/', auth_1.authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const { title, imageUrl, animatedUrl, type = 'STATIC', category = 'CAMPUS', tags = [], isPublic = true, } = req.body;
        if (!title || (!imageUrl && !animatedUrl)) {
            return res.status(400).json({ error: 'Title and image or animation are required' });
        }
        const cleanTags = Array.isArray(tags)
            ? tags.map((t) => String(t).trim().replace(/^#/, ''))
            : [];
        try {
            const created = await db_1.prisma.sticker.create({
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
        }
        catch (_) { }
        // Fallback memory insertion
        const localItem = {
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
            authorName: req.user?.username || req.user?.name || 'Student',
            createdAt: new Date().toISOString(),
        };
        localStickersStore.unshift(localItem);
        return res.status(201).json({ success: true, data: localItem });
    }
    catch (error) {
        console.error('Error creating sticker:', error);
        return res.status(500).json({ error: 'Failed to create sticker' });
    }
});
/**
 * POST /api/stickers/:id/use
 * Increment sticker usage count (boosts trending score)
 */
router.post('/:id/use', auth_1.optionalAuth, async (req, res) => {
    try {
        const id = String(req.params.id);
        try {
            const updated = await db_1.prisma.sticker.update({
                where: { id },
                data: { usageCount: { increment: 1 } },
            });
            return res.json({ success: true, usageCount: updated.usageCount });
        }
        catch (_) { }
        const local = localStickersStore.find((s) => s.id === id);
        if (local) {
            local.usageCount += 1;
            return res.json({ success: true, usageCount: local.usageCount });
        }
        return res.json({ success: true });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to record sticker usage' });
    }
});
/**
 * POST /api/stickers/:id/save
 * Save sticker to user's favorites tray
 */
router.post('/:id/save', auth_1.authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const stickerId = String(req.params.id);
        try {
            await db_1.prisma.userSavedSticker.upsert({
                where: {
                    userId_stickerId: { userId, stickerId },
                },
                create: { userId, stickerId },
                update: {},
            });
            return res.json({ success: true, message: 'Sticker saved to collection' });
        }
        catch (_) { }
        if (!localSavedStickers.has(userId)) {
            localSavedStickers.set(userId, new Set());
        }
        localSavedStickers.get(userId).add(stickerId);
        return res.json({ success: true, message: 'Sticker saved to collection' });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to save sticker' });
    }
});
/**
 * DELETE /api/stickers/:id/save
 * Remove sticker from user's favorites tray
 */
router.delete('/:id/save', auth_1.authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const stickerId = String(req.params.id);
        try {
            await db_1.prisma.userSavedSticker.deleteMany({
                where: { userId, stickerId },
            });
            return res.json({ success: true, message: 'Sticker removed from collection' });
        }
        catch (_) { }
        localSavedStickers.get(userId)?.delete(stickerId);
        return res.json({ success: true, message: 'Sticker removed from collection' });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to remove sticker' });
    }
});
/**
 * DELETE /api/stickers/:id
 * Delete a sticker (author only or admin)
 */
router.delete('/:id', auth_1.authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const userRole = req.user.role;
        const id = String(req.params.id);
        try {
            const sticker = await db_1.prisma.sticker.findUnique({ where: { id } });
            if (!sticker)
                return res.status(404).json({ error: 'Sticker not found' });
            if (sticker.authorId !== userId && userRole !== 'ADMIN') {
                return res.status(403).json({ error: 'Not authorized to delete this sticker' });
            }
            await db_1.prisma.sticker.delete({ where: { id } });
            return res.json({ success: true, message: 'Sticker deleted successfully' });
        }
        catch (_) { }
        const index = localStickersStore.findIndex((s) => s.id === id);
        if (index !== -1) {
            if (localStickersStore[index].authorId !== userId && userRole !== 'ADMIN') {
                return res.status(403).json({ error: 'Not authorized to delete this sticker' });
            }
            localStickersStore.splice(index, 1);
        }
        return res.json({ success: true, message: 'Sticker deleted successfully' });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to delete sticker' });
    }
});
exports.default = router;
