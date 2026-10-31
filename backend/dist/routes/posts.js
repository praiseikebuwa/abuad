"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const auth_1 = require("../middleware/auth");
const db_1 = require("../config/db");
const aiBotService_1 = require("../services/aiBotService");
const recommendationService_1 = require("../services/recommendationService");
const router = (0, express_1.Router)();
function sanitizePost(post, userRole, currentUserId) {
    if (!post)
        return post;
    // Safely parse and enrich pollData
    let pollData = post.pollData;
    if (pollData) {
        try {
            if (typeof pollData === 'string') {
                pollData = JSON.parse(pollData);
            }
            if (pollData && typeof pollData === 'object') {
                pollData = { ...pollData };
                if (currentUserId && pollData.voters && pollData.voters[currentUserId] !== undefined) {
                    pollData.userVotedIndex = Number(pollData.voters[currentUserId]);
                }
                else {
                    delete pollData.userVotedIndex;
                }
            }
        }
        catch { }
    }
    const isAnon = post.isAnonymous === true || post.channelId === 'confessions';
    if (!isAnon || userRole === 'ADMIN') {
        return {
            ...post,
            pollData,
        };
    }
    return {
        ...post,
        pollData,
        authorId: 'anonymous',
        author: {
            id: 'anonymous',
            username: 'anonymous',
            fullName: 'Anonymous Student',
            avatarUrl: null,
            isVerified: false,
            verificationType: 'none',
        },
    };
}
const SEARCH_STOP_WORDS = new Set([
    'a', 'about', 'above', 'after', 'again', 'against', 'all', 'am', 'an', 'and', 'any', 'are', 'as', 'at',
    'be', 'because', 'been', 'before', 'being', 'below', 'between', 'both', 'but', 'by',
    'can', 'cannot', 'could', 'did', 'do', 'does', 'doing', 'down', 'during',
    'each', 'few', 'for', 'from', 'further',
    'had', 'has', 'have', 'having', 'he', 'her', 'here', 'hers', 'him', 'his', 'how',
    'i', 'if', 'in', 'into', 'is', 'it', 'its',
    'me', 'more', 'most', 'my',
    'no', 'nor', 'not', 'of', 'off', 'on', 'once', 'only', 'or', 'other', 'our', 'ours', 'out', 'over', 'own',
    'same', 'she', 'should', 'so', 'some', 'such',
    'than', 'that', 'the', 'their', 'theirs', 'them', 'then', 'there', 'these', 'they', 'this', 'those', 'through', 'to', 'too',
    'under', 'until', 'up', 'very',
    'was', 'we', 'were', 'what', 'when', 'where', 'which', 'while', 'who', 'whom', 'why', 'with', 'would', 'you', 'your', 'yours'
]);
/**
 * Smart notification grouping to avoid spam/fatigue for likes, comments, and reposts.
 * Groups events within a 24-hour window on the same post.
 */
async function sendOrGroupNotification(params) {
    const { userId, senderId, type, relatedId, senderName, commentSnippet } = params;
    if (!userId || !senderId || userId === senderId)
        return;
    try {
        const recentWindow = new Date(Date.now() - 24 * 60 * 60 * 1000); // 24h grouping window
        const existing = await db_1.prisma.notification.findFirst({
            where: {
                userId,
                relatedId,
                type,
                isRead: false,
                createdAt: { gte: recentWindow },
            },
            orderBy: { createdAt: 'desc' },
        });
        if (type === 'like') {
            const totalLikes = await db_1.prisma.postLike.count({ where: { postId: relatedId } });
            const title = totalLikes > 1 ? `${totalLikes} Likes ❤️` : 'New Like ❤️';
            const body = totalLikes > 1
                ? `${senderName} and ${totalLikes - 1} other${totalLikes - 1 > 1 ? 's' : ''} liked your post`
                : `${senderName} liked your post`;
            if (existing) {
                await db_1.prisma.notification.update({
                    where: { id: existing.id },
                    data: { senderId, title, body, createdAt: new Date() },
                });
            }
            else {
                await db_1.prisma.notification.create({
                    data: { userId, senderId, title, body, type, relatedId },
                });
            }
        }
        else if (type === 'comment') {
            const totalComments = await db_1.prisma.postComment.count({ where: { postId: relatedId } });
            const title = totalComments > 1 ? `${totalComments} Comments 💬` : 'New Comment 💬';
            const snippet = commentSnippet ? `"${commentSnippet.length > 50 ? commentSnippet.slice(0, 47) + '...' : commentSnippet}"` : '';
            const body = totalComments > 1
                ? `${senderName} and ${totalComments - 1} other${totalComments - 1 > 1 ? 's' : ''} commented on your post`
                : `${senderName} commented: ${snippet}`;
            if (existing) {
                await db_1.prisma.notification.update({
                    where: { id: existing.id },
                    data: { senderId, title, body, createdAt: new Date() },
                });
            }
            else {
                await db_1.prisma.notification.create({
                    data: { userId, senderId, title, body, type, relatedId },
                });
            }
        }
        else if (type === 'repost') {
            const targetPost = await db_1.prisma.post.findUnique({ where: { id: relatedId }, select: { repostCount: true } });
            const totalReposts = targetPost?.repostCount ?? 1;
            const title = totalReposts > 1 ? `${totalReposts} Reposts 🔄` : 'Post Reposted 🔄';
            const body = totalReposts > 1
                ? `${senderName} and ${totalReposts - 1} other${totalReposts - 1 > 1 ? 's' : ''} reposted your post`
                : `${senderName} reposted your post`;
            if (existing) {
                await db_1.prisma.notification.update({
                    where: { id: existing.id },
                    data: { senderId, title, body, createdAt: new Date() },
                });
            }
            else {
                await db_1.prisma.notification.create({
                    data: { userId, senderId, title, body, type, relatedId },
                });
            }
        }
    }
    catch (err) {
        console.error(`Failed to send/group notification (${type}):`, err);
    }
}
/**
 * GET /api/posts - Discovery / For You Feed with Personalized Ranking & Cursor Pagination
 */
router.get('/', auth_1.optionalAuth, async (req, res) => {
    try {
        const limit = Number(req.query.limit) || 15;
        const cursor = req.query.cursor ? String(req.query.cursor) : undefined;
        const feedType = req.query.feed ? String(req.query.feed).toLowerCase() : 'foryou';
        const channel = req.query.channel ? String(req.query.channel).toLowerCase() : undefined;
        const userId = req.user?.id;
        const decodedCursor = (0, recommendationService_1.decodeCursor)(cursor);
        let channelFilter = {};
        if (channel && channel !== 'all') {
            if (channel === 'reels') {
                channelFilter = {
                    OR: [
                        { mediaType: 'video' },
                        { mediaType: 'VIDEO' },
                        { mediaUrl: { contains: '.mp4' } },
                        { mediaUrl: { contains: '.mov' } },
                        { mediaUrl: { contains: '.webm' } },
                        { mediaUrl: { contains: '.m3u8' } },
                        { mediaUrl: { contains: '/videos/' } },
                        { hashtags: { contains: 'reel' } },
                        { hashtags: { contains: 'video' } },
                    ],
                };
            }
            else {
                channelFilter = {
                    OR: [
                        { channelId: { equals: channel } },
                        { hashtags: { contains: channel } },
                        { content: { contains: `#${channel}` } },
                    ],
                };
            }
        }
        // 1. If Following feed requested
        if (feedType === 'following') {
            if (!userId) {
                return res.json({ success: true, data: [], nextCursor: null, hasMore: false });
            }
            const following = await db_1.prisma.follower.findMany({
                where: { followerId: userId },
                select: { followedId: true },
            });
            const followedIds = following.map(f => f.followedId);
            if (followedIds.length === 0) {
                return res.json({ success: true, data: [], nextCursor: null, hasMore: false });
            }
            const posts = await db_1.prisma.post.findMany({
                where: {
                    authorId: { in: followedIds },
                    status: 'active',
                    ...channelFilter,
                    ...(decodedCursor?.createdAt ? { createdAt: { lt: new Date(decodedCursor.createdAt) } } : {}),
                },
                take: limit + 1,
                orderBy: { createdAt: 'desc' },
                include: {
                    author: {
                        select: {
                            id: true, username: true, fullName: true,
                            avatarUrl: true, isVerified: true, verificationType: true,
                        },
                    },
                    likes: { where: { userId }, select: { id: true } },
                    savedBy: { where: { userId }, select: { id: true } },
                    _count: { select: { comments: true, likes: true } },
                },
            });
            const hasMore = posts.length > limit;
            const resultPosts = hasMore ? posts.slice(0, limit) : posts;
            const formatted = resultPosts.map(p => {
                const { likes, savedBy, _count, ...rest } = p;
                return sanitizePost({
                    ...rest,
                    commentsCount: _count.comments,
                    likesCount: _count.likes,
                    isLiked: likes.length > 0,
                    isSaved: savedBy.length > 0,
                }, req.user?.role, userId);
            });
            const lastPost = formatted[formatted.length - 1];
            const nextCursor = hasMore && lastPost ? (0, recommendationService_1.encodeCursor)({ id: lastPost.id, createdAt: lastPost.createdAt.toISOString() }) : null;
            return res.json({ success: true, data: formatted, nextCursor, hasMore });
        }
        // 2. Personalized "For You" / Discovery Feed
        const userProfile = await (0, recommendationService_1.getUserInterestProfile)(userId);
        const aiPostingEnabled = await (0, aiBotService_1.isAiAutonomousPostingEnabled)();
        // Fetch candidate posts (take a larger candidate batch to rank and score)
        const candidatePosts = await db_1.prisma.post.findMany({
            where: {
                status: 'active',
                ...channelFilter,
                ...(!aiPostingEnabled ? { author: { username: { not: 'abuad_ai' } } } : {}),
                ...(decodedCursor?.createdAt ? { createdAt: { lt: new Date(decodedCursor.createdAt) } } : {}),
            },
            take: Math.max(limit * 3, 45),
            orderBy: { createdAt: 'desc' },
            include: {
                author: {
                    select: {
                        id: true, username: true, fullName: true,
                        avatarUrl: true, isVerified: true, verificationType: true,
                    },
                },
                likes: { where: { userId }, select: { id: true } },
                savedBy: { where: { userId }, select: { id: true } },
                _count: { select: { comments: true, likes: true } },
            },
        });
        // Score and rank candidates
        const scoredPosts = candidatePosts.map(p => {
            const score = (0, recommendationService_1.scorePost)(p, userProfile);
            return { post: p, score };
        });
        // Sort by recommendation score descending
        scoredPosts.sort((a, b) => b.score - a.score);
        // Exclude posts marked 'not interested' or from muted creators (score <= -9000)
        const validScored = scoredPosts.filter(s => s.score > -9000);
        // Apply feed diversity algorithm so no author/channel monopolizes consecutive cards
        const diversified = (0, recommendationService_1.applyFeedDiversity)(validScored);
        const hasMore = diversified.length > limit;
        const selected = (hasMore ? diversified.slice(0, limit) : diversified).map(s => s.post);
        const formatted = selected.map(p => {
            const { likes, savedBy, _count, ...rest } = p;
            return sanitizePost({
                ...rest,
                commentsCount: _count.comments,
                likesCount: _count.likes,
                isLiked: likes.length > 0,
                isSaved: savedBy.length > 0,
            }, req.user?.role, userId);
        });
        const lastPost = formatted[formatted.length - 1];
        const nextCursor = hasMore && lastPost ? (0, recommendationService_1.encodeCursor)({ id: lastPost.id, createdAt: lastPost.createdAt.toISOString() }) : null;
        return res.json({ success: true, data: formatted, nextCursor, hasMore });
    }
    catch (error) {
        console.error('Error in feed recommendation handler:', error);
        return res.status(500).json({ error: 'Failed to fetch personalized feed' });
    }
});
/**
 * GET /api/posts/videos - Video/Reel posts with personalized recommendation ranking and cursor pagination
 */
router.get('/videos', auth_1.optionalAuth, async (req, res) => {
    try {
        const limit = Number(req.query.limit) || 20;
        const cursor = req.query.cursor ? String(req.query.cursor) : undefined;
        const userId = req.user?.id;
        const decodedCursor = (0, recommendationService_1.decodeCursor)(cursor);
        const userProfile = await (0, recommendationService_1.getUserInterestProfile)(userId);
        const candidatePosts = await db_1.prisma.post.findMany({
            where: {
                OR: [
                    { mediaType: 'video' },
                    { mediaType: 'VIDEO' },
                    { mediaUrl: { contains: '.mp4' } },
                    { mediaUrl: { contains: '.mov' } },
                    { mediaUrl: { contains: '.webm' } },
                    { mediaUrl: { contains: '.m3u8' } },
                    { mediaUrl: { contains: '/videos/' } },
                ],
                status: 'active',
                ...(decodedCursor?.createdAt ? { createdAt: { lt: new Date(decodedCursor.createdAt) } } : {}),
            },
            take: Math.max(limit * 3, 50),
            orderBy: { createdAt: 'desc' },
            include: {
                author: {
                    select: { id: true, username: true, fullName: true, avatarUrl: true, isVerified: true, verificationType: true },
                },
                likes: userId ? { where: { userId }, select: { id: true } } : false,
                savedBy: userId ? { where: { userId }, select: { id: true } } : false,
                _count: { select: { comments: true, likes: true } },
            },
        });
        // Score candidates with recommendation engine
        const scored = candidatePosts.map(p => {
            const score = (0, recommendationService_1.scorePost)(p, userProfile);
            return { post: p, score };
        });
        scored.sort((a, b) => b.score - a.score);
        const validScored = scored.filter(s => s.score > -9000);
        const diversified = (0, recommendationService_1.applyFeedDiversity)(validScored);
        const hasMore = diversified.length > limit;
        const resultPosts = (hasMore ? diversified.slice(0, limit) : diversified).map(s => s.post);
        const formatted = resultPosts.map(p => {
            const { likes, savedBy, _count, ...rest } = p;
            return {
                ...rest,
                commentsCount: _count?.comments ?? 0,
                likesCount: _count?.likes ?? 0,
                isLiked: Array.isArray(likes) ? likes.length > 0 : false,
                isSaved: Array.isArray(savedBy) ? savedBy.length > 0 : false,
            };
        });
        const lastPost = formatted[formatted.length - 1];
        const nextCursor = hasMore && lastPost ? (0, recommendationService_1.encodeCursor)({ id: lastPost.id, createdAt: lastPost.createdAt.toISOString() }) : null;
        return res.json({ success: true, data: formatted, nextCursor, hasMore });
    }
    catch (error) {
        console.error('Error fetching video reels:', error);
        return res.status(500).json({ error: 'Failed to fetch video reels' });
    }
});
/**
 * GET /api/posts/following - Posts from followed users with cursor pagination
 */
router.get('/following', auth_1.authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const limit = Number(req.query.limit) || 20;
        const cursor = req.query.cursor ? String(req.query.cursor) : undefined;
        const decodedCursor = (0, recommendationService_1.decodeCursor)(cursor);
        const following = await db_1.prisma.follower.findMany({
            where: { followerId: userId },
            select: { followedId: true },
        });
        const followedIds = following.map(f => f.followedId);
        if (followedIds.length === 0) {
            return res.json({ success: true, data: [], nextCursor: null, hasMore: false });
        }
        const posts = await db_1.prisma.post.findMany({
            where: {
                authorId: { in: followedIds },
                status: 'active',
                ...(decodedCursor?.createdAt ? { createdAt: { lt: new Date(decodedCursor.createdAt) } } : {}),
            },
            take: limit + 1,
            orderBy: { createdAt: 'desc' },
            include: {
                author: {
                    select: { id: true, username: true, fullName: true, avatarUrl: true, isVerified: true, verificationType: true },
                },
                likes: { where: { userId }, select: { id: true } },
                savedBy: { where: { userId }, select: { id: true } },
                _count: { select: { comments: true, likes: true } },
            },
        });
        const hasMore = posts.length > limit;
        const resultPosts = hasMore ? posts.slice(0, limit) : posts;
        const formatted = resultPosts.map(p => {
            const { likes, savedBy, _count, ...rest } = p;
            return {
                ...rest,
                commentsCount: _count.comments,
                likesCount: _count.likes,
                isLiked: likes.length > 0,
                isSaved: savedBy.length > 0,
            };
        });
        const lastPost = formatted[formatted.length - 1];
        const nextCursor = hasMore && lastPost ? (0, recommendationService_1.encodeCursor)({ id: lastPost.id, createdAt: lastPost.createdAt.toISOString() }) : null;
        return res.json({ success: true, data: formatted, nextCursor, hasMore });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to fetch following feed' });
    }
});
/**
 * GET /api/posts/user/:userId - Posts by a specific user
 */
router.get('/user/:userId', auth_1.authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const posts = await db_1.prisma.post.findMany({
            where: { authorId: String(req.params.userId), status: 'active' },
            take: 50,
            orderBy: { createdAt: 'desc' },
            include: {
                author: {
                    select: {
                        id: true, username: true, fullName: true,
                        avatarUrl: true, isVerified: true, verificationType: true,
                    },
                },
                likes: { where: { userId }, select: { id: true } },
                savedBy: { where: { userId }, select: { id: true } },
                _count: { select: { comments: true, likes: true } },
            },
        });
        const formatted = posts.map(p => {
            const { likes, savedBy, _count, ...rest } = p;
            return {
                ...rest,
                commentsCount: _count.comments,
                likesCount: _count.likes,
                isLiked: likes.length > 0,
                isSaved: savedBy.length > 0,
            };
        });
        return res.json({ success: true, data: formatted });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to fetch user posts' });
    }
});
/**
 * GET /api/posts/user/:userId/likes - Posts liked by a specific user
 */
router.get('/user/:userId/likes', auth_1.authenticateToken, async (req, res) => {
    try {
        const currentUserId = req.user.id;
        const targetUserId = String(req.params.userId);
        const postLikes = await db_1.prisma.postLike.findMany({
            where: { userId: targetUserId, post: { status: 'active' } },
            take: 50,
            orderBy: { createdAt: 'desc' },
            include: {
                post: {
                    include: {
                        author: {
                            select: {
                                id: true, username: true, fullName: true,
                                avatarUrl: true, isVerified: true, verificationType: true,
                            },
                        },
                        likes: { where: { userId: currentUserId }, select: { id: true } },
                        savedBy: { where: { userId: currentUserId }, select: { id: true } },
                        _count: { select: { comments: true, likes: true } },
                    },
                },
            },
        });
        const formatted = postLikes.map(pl => {
            const { likes, savedBy, _count, ...rest } = pl.post;
            return {
                ...rest,
                commentsCount: _count.comments,
                likesCount: _count.likes,
                isLiked: likes.length > 0,
                isSaved: savedBy.length > 0,
            };
        });
        return res.json({ success: true, data: formatted });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to fetch user liked posts' });
    }
});
/**
 * GET /api/posts/user/:userId/replies - Replies and comments by a specific user
 */
router.get('/user/:userId/replies', auth_1.authenticateToken, async (req, res) => {
    try {
        const targetUserId = String(req.params.userId);
        const comments = await db_1.prisma.postComment.findMany({
            where: { authorId: targetUserId, post: { status: 'active' } },
            take: 40,
            orderBy: { createdAt: 'desc' },
            include: {
                post: {
                    select: {
                        id: true,
                        content: true,
                        author: { select: { id: true, username: true, fullName: true } }
                    }
                },
                author: {
                    select: { id: true, username: true, fullName: true, avatarUrl: true, isVerified: true, verificationType: true }
                }
            }
        });
        const replies = await db_1.prisma.commentReply.findMany({
            where: { authorId: targetUserId, comment: { post: { status: 'active' } } },
            take: 40,
            orderBy: { createdAt: 'desc' },
            include: {
                comment: {
                    select: {
                        postId: true,
                        content: true,
                        author: { select: { id: true, username: true, fullName: true } }
                    }
                },
                author: {
                    select: { id: true, username: true, fullName: true, avatarUrl: true, isVerified: true, verificationType: true }
                }
            }
        });
        const combined = [
            ...comments.map(c => ({
                id: c.id,
                postId: c.postId,
                content: c.content,
                authorId: c.authorId,
                authorName: c.author.fullName || c.author.username,
                authorHandle: c.author.username,
                authorAvatarUrl: c.author.avatarUrl,
                authorIsVerified: c.author.isVerified,
                authorVerificationType: c.author.verificationType,
                postContent: c.post?.content || '',
                postAuthorName: c.post?.author?.fullName || c.post?.author?.username || 'User',
                timestamp: new Date(c.createdAt).getTime(),
                createdAt: c.createdAt.toISOString(),
            })),
            ...replies.map(r => ({
                id: r.id,
                postId: r.comment.postId,
                content: r.content,
                authorId: r.authorId,
                authorName: r.author.fullName || r.author.username,
                authorHandle: r.author.username,
                authorAvatarUrl: r.author.avatarUrl,
                authorIsVerified: r.author.isVerified,
                authorVerificationType: r.author.verificationType,
                postContent: r.comment?.content || '',
                postAuthorName: r.comment?.author?.fullName || r.comment?.author?.username || 'User',
                timestamp: new Date(r.createdAt).getTime(),
                createdAt: r.createdAt.toISOString(),
            })),
        ];
        combined.sort((a, b) => b.timestamp - a.timestamp);
        return res.json({ success: true, data: combined });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to fetch user replies' });
    }
});
/**
 * GET /api/posts/user/:userId/media - Media posts by a specific user
 */
router.get('/user/:userId/media', auth_1.authenticateToken, async (req, res) => {
    try {
        const currentUserId = req.user.id;
        const targetUserId = String(req.params.userId);
        const posts = await db_1.prisma.post.findMany({
            where: {
                authorId: targetUserId,
                status: 'active',
                OR: [
                    { mediaUrl: { not: '' } },
                    { mediaType: { in: ['image', 'video', 'gif'] } },
                ],
            },
            take: 50,
            orderBy: { createdAt: 'desc' },
            include: {
                author: {
                    select: {
                        id: true, username: true, fullName: true,
                        avatarUrl: true, isVerified: true, verificationType: true,
                    },
                },
                likes: { where: { userId: currentUserId }, select: { id: true } },
                savedBy: { where: { userId: currentUserId }, select: { id: true } },
                _count: { select: { comments: true, likes: true } },
            },
        });
        const formatted = posts.map(p => {
            const { likes, savedBy, _count, ...rest } = p;
            return {
                ...rest,
                commentsCount: _count.comments,
                likesCount: _count.likes,
                isLiked: likes.length > 0,
                isSaved: savedBy.length > 0,
            };
        });
        return res.json({ success: true, data: formatted });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to fetch user media' });
    }
});
/**
 * GET /api/posts/saved - Saved posts for current user
 */
router.get('/saved', auth_1.authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const saved = await db_1.prisma.savedPost.findMany({
            where: { userId, post: { status: 'active' } },
            include: {
                post: {
                    include: {
                        author: {
                            select: {
                                id: true, username: true, fullName: true,
                                avatarUrl: true, isVerified: true, verificationType: true,
                            },
                        },
                        likes: { where: { userId }, select: { id: true } },
                        savedBy: { where: { userId }, select: { id: true } },
                        _count: { select: { comments: true, likes: true } },
                    },
                },
            },
            orderBy: { createdAt: 'desc' },
        });
        const formatted = saved.map(s => {
            const { likes, savedBy, _count, ...rest } = s.post;
            return {
                ...rest,
                commentsCount: _count.comments,
                likesCount: _count.likes,
                isLiked: likes.length > 0,
                isSaved: true,
            };
        });
        return res.json({ success: true, data: formatted });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to fetch saved posts' });
    }
});
/**
 * GET /api/posts/trending-tags - Aggregated trending hashtags and campus tags
 */
router.get('/trending-tags', auth_1.optionalAuth, async (req, res) => {
    try {
        const recentPosts = await db_1.prisma.post.findMany({
            where: { status: 'active' },
            take: 200,
            orderBy: { createdAt: 'desc' },
            select: {
                content: true,
                hashtags: true,
                likesCount: true,
                commentsCount: true,
            },
        });
        const tagCounts = {};
        for (const post of recentPosts) {
            if (post.hashtags) {
                try {
                    const parsed = JSON.parse(post.hashtags);
                    if (Array.isArray(parsed)) {
                        for (const tag of parsed) {
                            const cleaned = String(tag).trim().replace(/^#/, '');
                            if (cleaned.length > 1) {
                                const key = cleaned.toLowerCase();
                                tagCounts[key] = (tagCounts[key] || 0) + 2 + Math.floor((post.likesCount + post.commentsCount) / 3);
                            }
                        }
                    }
                }
                catch (_) {
                    const parts = String(post.hashtags).split(/[,\s]+/);
                    for (const p of parts) {
                        const cleaned = p.trim().replace(/^#/, '');
                        if (cleaned.length > 1) {
                            const key = cleaned.toLowerCase();
                            tagCounts[key] = (tagCounts[key] || 0) + 1;
                        }
                    }
                }
            }
            if (post.content) {
                const matches = post.content.match(/#([a-zA-Z0-9_]+)/g);
                if (matches) {
                    for (const m of matches) {
                        const cleaned = m.replace(/^#/, '');
                        if (cleaned.length > 1) {
                            const key = cleaned.toLowerCase();
                            tagCounts[key] = (tagCounts[key] || 0) + 1 + Math.floor((post.likesCount + post.commentsCount) / 5);
                        }
                    }
                }
            }
        }
        const defaultTags = ['ABUAD', 'Trending', 'CampusLife', 'Tech', 'Engineering', 'Law', 'Medicine', 'Sports', 'Events', 'News'];
        for (const dt of defaultTags) {
            const key = dt.toLowerCase();
            if (!tagCounts[key]) {
                tagCounts[key] = 1;
            }
        }
        const sortedTags = Object.entries(tagCounts)
            .map(([tag, count]) => ({
            tag: `#${tag}`,
            name: tag,
            count,
        }))
            .sort((a, b) => b.count - a.count)
            .slice(0, 15);
        return res.json({ success: true, data: sortedTags });
    }
    catch (error) {
        console.error('Error fetching trending tags:', error);
        return res.status(500).json({ error: 'Failed to fetch trending tags' });
    }
});
/**
 * POST /api/posts/hashtag/follow - Follow a hashtag
 */
router.post('/hashtag/follow', auth_1.authenticateToken, async (req, res) => {
    try {
        const rawTag = String(req.body.tag || '').replace(/^#/, '').toLowerCase().trim();
        if (!rawTag)
            return res.status(400).json({ error: 'Tag required' });
        const userId = req.user.id;
        // 1. Add userId to tag followers
        const tagKey = `hashtag_followers:${rawTag}`;
        const existingTagSetting = await db_1.prisma.systemSetting.findUnique({ where: { key: tagKey } });
        let followers = [];
        if (existingTagSetting && existingTagSetting.value) {
            try {
                followers = JSON.parse(existingTagSetting.value);
            }
            catch (_) { }
        }
        if (!followers.includes(userId)) {
            followers.push(userId);
            await db_1.prisma.systemSetting.upsert({
                where: { key: tagKey },
                update: { value: JSON.stringify(followers) },
                create: { key: tagKey, value: JSON.stringify(followers) },
            });
        }
        // 2. Add tag to user followed list
        const userKey = `user_followed_hashtags:${userId}`;
        const existingUserSetting = await db_1.prisma.systemSetting.findUnique({ where: { key: userKey } });
        let followedTags = [];
        if (existingUserSetting && existingUserSetting.value) {
            try {
                followedTags = JSON.parse(existingUserSetting.value);
            }
            catch (_) { }
        }
        if (!followedTags.includes(rawTag)) {
            followedTags.push(rawTag);
            await db_1.prisma.systemSetting.upsert({
                where: { key: userKey },
                update: { value: JSON.stringify(followedTags) },
                create: { key: userKey, value: JSON.stringify(followedTags) },
            });
        }
        return res.json({ success: true, isFollowing: true, tag: rawTag });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to follow hashtag' });
    }
});
/**
 * POST /api/posts/hashtag/unfollow - Unfollow a hashtag
 */
router.post('/hashtag/unfollow', auth_1.authenticateToken, async (req, res) => {
    try {
        const rawTag = String(req.body.tag || '').replace(/^#/, '').toLowerCase().trim();
        if (!rawTag)
            return res.status(400).json({ error: 'Tag required' });
        const userId = req.user.id;
        // 1. Remove userId from tag followers
        const tagKey = `hashtag_followers:${rawTag}`;
        const existingTagSetting = await db_1.prisma.systemSetting.findUnique({ where: { key: tagKey } });
        if (existingTagSetting && existingTagSetting.value) {
            try {
                let followers = JSON.parse(existingTagSetting.value);
                followers = followers.filter(id => id !== userId);
                await db_1.prisma.systemSetting.update({
                    where: { key: tagKey },
                    data: { value: JSON.stringify(followers) },
                });
            }
            catch (_) { }
        }
        // 2. Remove tag from user followed list
        const userKey = `user_followed_hashtags:${userId}`;
        const existingUserSetting = await db_1.prisma.systemSetting.findUnique({ where: { key: userKey } });
        if (existingUserSetting && existingUserSetting.value) {
            try {
                let followedTags = JSON.parse(existingUserSetting.value);
                followedTags = followedTags.filter(t => t !== rawTag);
                await db_1.prisma.systemSetting.update({
                    where: { key: userKey },
                    data: { value: JSON.stringify(followedTags) },
                });
            }
            catch (_) { }
        }
        return res.json({ success: true, isFollowing: false, tag: rawTag });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to unfollow hashtag' });
    }
});
/**
 * GET /api/posts/hashtag/following - Get followed hashtags for user
 */
router.get('/hashtag/following', auth_1.authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const userKey = `user_followed_hashtags:${userId}`;
        const existingUserSetting = await db_1.prisma.systemSetting.findUnique({ where: { key: userKey } });
        let followedTags = [];
        if (existingUserSetting && existingUserSetting.value) {
            try {
                followedTags = JSON.parse(existingUserSetting.value);
            }
            catch (_) { }
        }
        return res.json({ success: true, data: followedTags });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to get followed hashtags' });
    }
});
/**
 * GET /api/posts/search?q= - Search posts by content, hashtag, or author
 */
router.get('/search', auth_1.optionalAuth, async (req, res) => {
    try {
        const q = String(req.query.q || '').trim();
        const userId = req.user?.id;
        if (!q) {
            return res.json({ success: true, data: [] });
        }
        const rawTag = q.replace(/^#/, '');
        const cleanQuery = q.replace(/^[#@]/, '').trim();
        // Tokenize multi-word query into distinct keywords (ignore trivial stop words)
        const rawTokens = q
            .toLowerCase()
            .replace(/[^a-z0-9#@_\s]/g, ' ')
            .split(/\s+/)
            .map(t => t.trim())
            .filter(t => t.length >= 2);
        const filteredTokens = rawTokens.filter(t => !SEARCH_STOP_WORDS.has(t));
        const effectiveTokens = filteredTokens.length > 0 ? filteredTokens : rawTokens;
        const searchConditions = [
            { content: { contains: q, mode: 'insensitive' } },
            { hashtags: { contains: q, mode: 'insensitive' } },
            { author: { username: { contains: q, mode: 'insensitive' } } },
            { author: { fullName: { contains: q, mode: 'insensitive' } } },
        ];
        if (rawTag !== q && rawTag.length > 0) {
            searchConditions.push({ content: { contains: rawTag, mode: 'insensitive' } });
            searchConditions.push({ hashtags: { contains: rawTag, mode: 'insensitive' } });
        }
        if (cleanQuery !== q && cleanQuery.length > 0) {
            searchConditions.push({ author: { username: { contains: cleanQuery, mode: 'insensitive' } } });
            searchConditions.push({ author: { fullName: { contains: cleanQuery, mode: 'insensitive' } } });
        }
        // Add token matching for multi-word queries
        for (const token of effectiveTokens.slice(0, 6)) {
            const cleanToken = token.replace(/^[#@]/, '');
            if (!cleanToken)
                continue;
            searchConditions.push({ content: { contains: cleanToken, mode: 'insensitive' } });
            searchConditions.push({ hashtags: { contains: cleanToken, mode: 'insensitive' } });
            searchConditions.push({ author: { username: { contains: cleanToken, mode: 'insensitive' } } });
            searchConditions.push({ author: { fullName: { contains: cleanToken, mode: 'insensitive' } } });
        }
        const posts = await db_1.prisma.post.findMany({
            where: {
                status: 'active',
                OR: searchConditions,
            },
            take: 60,
            orderBy: { createdAt: 'desc' },
            include: {
                author: {
                    select: {
                        id: true,
                        username: true,
                        fullName: true,
                        avatarUrl: true,
                        isVerified: true,
                        verificationType: true,
                    },
                },
                likes: userId ? { where: { userId }, select: { id: true } } : false,
                savedBy: userId ? { where: { userId }, select: { id: true } } : false,
                _count: { select: { comments: true, likes: true } },
            },
        });
        // Check blocked users if user is authenticated
        const blockedUserIds = new Set();
        if (userId) {
            const blocks = await db_1.prisma.blockedUser.findMany({
                where: {
                    OR: [
                        { blockerId: userId },
                        { blockedId: userId },
                    ],
                },
                select: { blockerId: true, blockedId: true },
            });
            for (const b of blocks) {
                if (b.blockerId === userId)
                    blockedUserIds.add(b.blockedId);
                if (b.blockedId === userId)
                    blockedUserIds.add(b.blockerId);
            }
        }
        // Rank candidates by relevance
        const qLower = q.toLowerCase();
        const cleanLower = cleanQuery.toLowerCase();
        const scored = posts
            .filter(p => !blockedUserIds.has(p.authorId))
            .map(p => {
            let score = 0;
            const contentLower = (p.content || '').toLowerCase();
            const hashtagsLower = (p.hashtags || '').toLowerCase();
            const authorUserLower = (p.author?.username || '').toLowerCase();
            const authorFullLower = (p.author?.fullName || '').toLowerCase();
            // 1. Exact full query matches
            if (contentLower.includes(qLower))
                score += 50;
            if (hashtagsLower.includes(rawTag.toLowerCase()) || hashtagsLower.includes(qLower))
                score += 45;
            if (authorUserLower === cleanLower || authorFullLower === cleanLower)
                score += 60;
            else if (authorUserLower.includes(cleanLower) || authorFullLower.includes(cleanLower))
                score += 30;
            // 2. Multi-token keyword matches
            for (const token of effectiveTokens) {
                const cleanToken = token.replace(/^[#@]/, '');
                if (!cleanToken)
                    continue;
                if (hashtagsLower.includes(cleanToken))
                    score += 20;
                if (authorUserLower.includes(cleanToken) || authorFullLower.includes(cleanToken))
                    score += 15;
                if (contentLower.includes(cleanToken))
                    score += 10;
            }
            // 3. Creator verification boost
            if (p.author?.isVerified) {
                if (p.author?.verificationType === 'GOLD')
                    score += 15;
                else if (p.author?.verificationType === 'VIOLET')
                    score += 12;
                else
                    score += 8;
            }
            // 4. Social engagement & popularity
            const likes = p._count?.likes ?? 0;
            const comments = p._count?.comments ?? 0;
            score += Math.min(25, likes * 0.5 + comments * 1.0);
            // 5. Recency boost
            const ageHours = (Date.now() - new Date(p.createdAt).getTime()) / (1000 * 60 * 60);
            if (ageHours < 24)
                score += 15;
            else if (ageHours < 72)
                score += 10;
            else if (ageHours < 168)
                score += 5;
            return { post: p, score };
        });
        // Sort by computed relevance descending
        scored.sort((a, b) => b.score - a.score);
        const formatted = scored.slice(0, 40).map(({ post: p }) => {
            const { likes, savedBy, _count, ...rest } = p;
            return sanitizePost({
                ...rest,
                commentsCount: _count?.comments ?? 0,
                likesCount: _count?.likes ?? 0,
                isLiked: Array.isArray(likes) ? likes.length > 0 : false,
                isSaved: Array.isArray(savedBy) ? savedBy.length > 0 : false,
            }, req.user?.role, userId);
        });
        return res.json({ success: true, data: formatted });
    }
    catch (error) {
        console.error('Error searching posts:', error);
        return res.status(500).json({ error: 'Failed to search posts' });
    }
});
/**
 * GET /api/posts/:id - Single post
 */
router.get('/:id', auth_1.optionalAuth, async (req, res) => {
    try {
        const userId = req.user?.id;
        const postId = String(req.params.id);
        const post = await db_1.prisma.post.findUnique({
            where: { id: postId },
            include: {
                author: {
                    select: { id: true, username: true, fullName: true, avatarUrl: true, isVerified: true, verificationType: true },
                },
                likes: userId ? { where: { userId }, select: { id: true } } : false,
                savedBy: userId ? { where: { userId }, select: { id: true } } : false,
                _count: { select: { comments: true, likes: true } },
            },
        });
        if (!post)
            return res.status(404).json({ error: 'Post not found' });
        const { likes, savedBy, _count, ...rest } = post;
        const sanitized = sanitizePost({
            ...rest,
            commentsCount: _count?.comments ?? 0,
            likesCount: _count?.likes ?? 0,
            isLiked: Array.isArray(likes) ? likes.length > 0 : false,
            isSaved: Array.isArray(savedBy) ? savedBy.length > 0 : false,
        }, req.user?.role, userId);
        return res.json({
            success: true,
            data: sanitized,
        });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to fetch post' });
    }
});
/**
 * POST /api/posts - Create post
 */
router.post('/', auth_1.authenticateToken, async (req, res) => {
    try {
        const { content, mediaUrls, mediaUrl, mediaType, hashtags, mentions, visibility, channelId, isAnonymous, replyPermission, pollData } = req.body;
        if (!content && (!mediaUrls || mediaUrls.length === 0) && !mediaUrl) {
            return res.status(400).json({ error: 'Post must contain text content or media' });
        }
        // 1. AI Content Moderation Gate: Keyword and context check
        const checkMod = (0, aiBotService_1.isContentInappropriate)(content || '');
        if (checkMod.flagged) {
            return res.status(400).json({ error: checkMod.reason, code: 'CONTENT_MODERATION_BLOCKED' });
        }
        // Determine initial publication status (active vs held for review)
        let postStatus = 'active';
        const reviewTriggers = ['threat', 'suicide', 'harass', 'leak', 'bomb', 'weapon'];
        const lowerText = (content || '').toLowerCase();
        if (reviewTriggers.some(t => lowerText.includes(t))) {
            postStatus = 'review';
        }
        const effectiveIsAnonymous = isAnonymous === true || channelId === 'confessions';
        const rawTags = [];
        if (Array.isArray(hashtags)) {
            for (const h of hashtags) {
                if (typeof h === 'string') {
                    const clean = h.replace(/^#/, '').toLowerCase().trim();
                    if (clean && !rawTags.includes(clean))
                        rawTags.push(clean);
                }
            }
        }
        const hashMatches = (content || '').match(/#([a-zA-Z0-9_]+)/g);
        if (hashMatches) {
            for (const m of hashMatches) {
                const clean = m.replace(/^#/, '').toLowerCase().trim();
                if (clean && !rawTags.includes(clean))
                    rawTags.push(clean);
            }
        }
        const post = await db_1.prisma.post.create({
            data: {
                authorId: req.user.id,
                content: content || '',
                mediaUrl: mediaUrl || (mediaUrls && mediaUrls[0]) || '',
                mediaType: mediaType || 'none',
                mediaUrls: JSON.stringify(mediaUrls || (mediaUrl ? [mediaUrl] : [])),
                hashtags: JSON.stringify(rawTags),
                mentions: JSON.stringify(mentions || []),
                visibility: visibility || 'everyone',
                channelId: channelId || 'general',
                status: postStatus,
                isAnonymous: effectiveIsAnonymous,
                replyPermission: replyPermission || 'everyone',
                pollData: pollData ? JSON.stringify(pollData) : null,
            },
            include: {
                author: {
                    select: { id: true, username: true, fullName: true, avatarUrl: true, isVerified: true },
                },
            },
        });
        if ((0, aiBotService_1.containsAiMention)(post.content)) {
            (0, aiBotService_1.triggerAiPostReply)(post.id, post.content, post.mediaUrl, post.author.fullName || post.author.username);
        }
        // 1. Notify tagged / mentioned students (supports anonymous confession tagging!)
        const mentionedUsernames = [];
        if (Array.isArray(mentions)) {
            for (const m of mentions) {
                if (typeof m === 'string')
                    mentionedUsernames.push(m.replace(/^@/, '').toLowerCase().trim());
            }
        }
        const regexMatches = (content || '').match(/@([a-zA-Z0-9_]+)/g);
        if (regexMatches) {
            for (const m of regexMatches) {
                const u = m.replace(/^@/, '').toLowerCase().trim();
                if (!mentionedUsernames.includes(u))
                    mentionedUsernames.push(u);
            }
        }
        if (mentionedUsernames.length > 0) {
            const mentionedUsers = await db_1.prisma.user.findMany({
                where: {
                    username: { in: mentionedUsernames, mode: 'insensitive' },
                },
                select: { id: true, username: true },
            });
            const validRecipients = mentionedUsers.filter(u => u.id !== req.user.id);
            if (validRecipients.length > 0) {
                const preview = (content || '').trim();
                const snippet = preview.length > 60 ? preview.slice(0, 57) + '...' : preview;
                const notifData = validRecipients.map(u => ({
                    userId: u.id,
                    senderId: effectiveIsAnonymous ? null : req.user.id,
                    title: effectiveIsAnonymous ? 'Secret Confession 🎭' : 'Mentioned in a Post 💬',
                    body: effectiveIsAnonymous
                        ? `Someone secretly tagged you in Confessions: "${snippet}"`
                        : `${post.author.fullName || post.author.username} mentioned you: "${snippet}"`,
                    type: effectiveIsAnonymous ? 'confessionMention' : 'postMention',
                    relatedId: post.id,
                }));
                await db_1.prisma.notification.createMany({
                    data: notifData,
                }).catch((err) => console.error('Failed to notify mentioned users:', err));
            }
        }
        // 2. Notify followers about the new post (only if NOT anonymous)
        if (!effectiveIsAnonymous) {
            const followers = await db_1.prisma.follower.findMany({
                where: { followedId: req.user.id },
                select: { followerId: true },
            });
            const validFollowers = followers.filter(f => f.followerId && f.followerId !== req.user.id);
            if (validFollowers.length > 0) {
                const authorName = post.author.fullName || post.author.username || 'Someone you follow';
                const previewText = (post.content || (post.mediaUrl ? 'shared a photo/video' : 'posted an update')).trim();
                const truncated = previewText.length > 60 ? previewText.slice(0, 57) + '...' : previewText;
                const notifData = validFollowers.map(f => ({
                    userId: f.followerId,
                    senderId: req.user.id,
                    title: 'New Post',
                    body: `${authorName}: "${truncated}"`,
                    type: 'followingPost',
                    relatedId: post.id,
                }));
                await db_1.prisma.notification.createMany({
                    data: notifData,
                }).catch(() => { });
            }
        }
        // 3. Notify hashtag followers (case-insensitive)
        if (rawTags.length > 0) {
            const authorName = post.author.fullName || post.author.username || 'Student';
            const previewText = (post.content || (post.mediaUrl ? 'shared media' : 'posted an update')).trim();
            const snippet = previewText.length > 60 ? previewText.slice(0, 57) + '...' : previewText;
            const notifiedUserIds = new Set();
            notifiedUserIds.add(req.user.id);
            for (const tag of rawTags) {
                try {
                    const setting = await db_1.prisma.systemSetting.findUnique({
                        where: { key: `hashtag_followers:${tag}` },
                    });
                    if (setting && setting.value) {
                        const followerIds = JSON.parse(setting.value);
                        const recipients = followerIds.filter(id => !notifiedUserIds.has(id));
                        if (recipients.length > 0) {
                            const notifs = recipients.map(uid => {
                                notifiedUserIds.add(uid);
                                return {
                                    userId: uid,
                                    senderId: effectiveIsAnonymous ? null : req.user.id,
                                    title: `#${tag} update 🚀`,
                                    body: effectiveIsAnonymous
                                        ? `Someone posted in #${tag}: "${snippet}"`
                                        : `${authorName} posted in #${tag}: "${snippet}"`,
                                    type: 'hashtagPost',
                                    relatedId: post.id,
                                };
                            });
                            await db_1.prisma.notification.createMany({
                                data: notifs,
                            }).catch(() => { });
                        }
                    }
                }
                catch (_) { }
            }
        }
        return res.status(201).json({ success: true, data: sanitizePost(post, req.user?.role, req.user?.id) });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to create post' });
    }
});
/**
 * POST /api/posts/:id/interact
 * Records student behavioral interaction signals to train the feed personalization engine:
 * actions: 'view', 'like', 'save', 'share', 'watch_complete', 'skip', 'not_interested', 'mute_author', 'mute_topic'
 */
router.post('/:id/interact', auth_1.authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const postId = String(req.params.id);
        const { action } = req.body;
        if (!action) {
            return res.status(400).json({ error: 'Interaction action is required' });
        }
        const post = await db_1.prisma.post.findUnique({
            where: { id: postId },
            select: { authorId: true, hashtags: true, channelId: true },
        });
        if (post) {
            let tags = [];
            try {
                tags = JSON.parse(post.hashtags || '[]');
            }
            catch { }
            await (0, recommendationService_1.recordUserInteraction)(userId, postId, action, {
                authorId: post.authorId,
                tags,
                channelId: post.channelId,
            });
        }
        return res.json({ success: true, action, postId });
    }
    catch (error) {
        console.error('Error recording post interaction:', error);
        return res.status(500).json({ error: 'Failed to record interaction' });
    }
});
/**
 * GET /api/posts/:id - Get single post by ID
 */
router.get('/:id', auth_1.optionalAuth, async (req, res) => {
    try {
        const postId = String(req.params.id);
        const userId = req.user?.id;
        const post = await db_1.prisma.post.findUnique({
            where: { id: postId },
            include: {
                author: {
                    select: { id: true, username: true, fullName: true, avatarUrl: true, isVerified: true, verificationType: true },
                },
                likes: userId ? { where: { userId }, select: { id: true } } : false,
                savedBy: userId ? { where: { userId }, select: { id: true } } : false,
                _count: { select: { comments: true, likes: true } },
            },
        });
        if (!post) {
            return res.status(404).json({ error: 'Post not found' });
        }
        const { likes, savedBy, _count, ...rest } = post;
        const formatted = {
            ...rest,
            commentsCount: _count?.comments ?? 0,
            likesCount: _count?.likes ?? 0,
            isLiked: Array.isArray(likes) && likes.length > 0,
            isSaved: Array.isArray(savedBy) && savedBy.length > 0,
        };
        return res.json({ success: true, data: sanitizePost(formatted, req.user?.role, userId) });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to fetch post' });
    }
});
/**
 * DELETE /api/posts/:id - Delete post
 */
router.delete('/:id', auth_1.authenticateToken, async (req, res) => {
    try {
        const post = await db_1.prisma.post.findUnique({ where: { id: String(req.params.id) } });
        if (!post)
            return res.status(404).json({ error: 'Post not found' });
        if (post.authorId !== req.user.id && req.user.role !== 'ADMIN') {
            return res.status(403).json({ error: 'Not authorized to delete this post' });
        }
        await db_1.prisma.post.delete({ where: { id: String(req.params.id) } });
        return res.json({ success: true });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to delete post' });
    }
});
/**
 * POST /api/posts/:id/like - Like or unlike post
 */
router.post('/:id/like', auth_1.authenticateToken, async (req, res) => {
    try {
        const postId = String(req.params.id);
        const userId = req.user.id;
        const existingLike = await db_1.prisma.postLike.findUnique({
            where: { postId_userId: { postId, userId } },
        });
        if (existingLike) {
            await db_1.prisma.$transaction([
                db_1.prisma.postLike.delete({ where: { id: existingLike.id } }),
                db_1.prisma.post.update({ where: { id: postId }, data: { likesCount: { decrement: 1 } } }),
            ]);
            return res.json({ success: true, isLiked: false });
        }
        else {
            await db_1.prisma.$transaction([
                db_1.prisma.postLike.create({ data: { postId, userId } }),
                db_1.prisma.post.update({ where: { id: postId }, data: { likesCount: { increment: 1 } } }),
            ]);
            const post = await db_1.prisma.post.findUnique({ where: { id: postId }, select: { authorId: true } });
            if (post && post.authorId && post.authorId !== userId) {
                const liker = await db_1.prisma.user.findUnique({ where: { id: userId }, select: { fullName: true, username: true } });
                const senderName = liker?.fullName || liker?.username || 'Someone';
                sendOrGroupNotification({
                    userId: post.authorId,
                    senderId: userId,
                    type: 'like',
                    relatedId: postId,
                    senderName,
                });
            }
            return res.json({ success: true, isLiked: true });
        }
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to update post like status' });
    }
});
/**
 * GET /api/posts/:id/is-liked - Check if post is liked by current user
 */
router.get('/:id/is-liked', auth_1.authenticateToken, async (req, res) => {
    try {
        const existing = await db_1.prisma.postLike.findUnique({
            where: { postId_userId: { postId: String(req.params.id), userId: req.user.id } },
        });
        return res.json({ success: true, isLiked: !!existing });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to check like status' });
    }
});
/**
 * POST /api/posts/:id/save - Save or unsave post
 */
router.post('/:id/save', auth_1.authenticateToken, async (req, res) => {
    try {
        const postId = String(req.params.id);
        const userId = req.user.id;
        const existing = await db_1.prisma.savedPost.findUnique({ where: { userId_postId: { userId, postId } } });
        if (existing) {
            await db_1.prisma.$transaction([
                db_1.prisma.savedPost.delete({ where: { id: existing.id } }),
                db_1.prisma.post.update({ where: { id: postId }, data: { savesCount: { decrement: 1 } } }),
            ]);
            return res.json({ success: true, isSaved: false });
        }
        else {
            await db_1.prisma.$transaction([
                db_1.prisma.savedPost.create({ data: { userId, postId } }),
                db_1.prisma.post.update({ where: { id: postId }, data: { savesCount: { increment: 1 } } }),
            ]);
            return res.json({ success: true, isSaved: true });
        }
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to save/unsave post' });
    }
});
/**
 * POST /api/posts/:id/repost - Repost a post
 */
router.post('/:id/repost', auth_1.authenticateToken, async (req, res) => {
    try {
        const postId = String(req.params.id);
        const userId = req.user.id;
        const { content } = req.body;
        const originalPost = await db_1.prisma.post.findUnique({
            where: { id: postId },
            include: {
                author: {
                    select: { id: true, username: true, fullName: true, avatarUrl: true, isVerified: true },
                },
            },
        });
        if (!originalPost) {
            return res.status(404).json({ error: 'Original post not found' });
        }
        const repostPayload = {
            id: originalPost.id,
            author_id: originalPost.authorId,
            author_name: originalPost.author.fullName || originalPost.author.username,
            author_handle: originalPost.author.username,
            author_avatar_url: originalPost.author.avatarUrl,
            content: originalPost.content,
            media_url: originalPost.mediaUrl,
            media_type: originalPost.mediaType,
            timestamp: originalPost.createdAt.toISOString(),
            is_verified: originalPost.author.isVerified,
            is_anonymous: originalPost.isAnonymous,
        };
        const [createdRepost] = await db_1.prisma.$transaction([
            db_1.prisma.post.create({
                data: {
                    authorId: userId,
                    content: content || '',
                    channelId: originalPost.channelId,
                    repostData: JSON.stringify(repostPayload),
                },
                include: {
                    author: {
                        select: { id: true, username: true, fullName: true, avatarUrl: true, isVerified: true },
                    },
                },
            }),
            db_1.prisma.post.update({
                where: { id: postId },
                data: { repostCount: { increment: 1 } },
            }),
        ]);
        if (originalPost.authorId && originalPost.authorId !== userId) {
            const reposter = await db_1.prisma.user.findUnique({ where: { id: userId }, select: { fullName: true, username: true } });
            const senderName = reposter?.fullName || reposter?.username || 'Someone';
            sendOrGroupNotification({
                userId: originalPost.authorId,
                senderId: userId,
                type: 'repost',
                relatedId: postId,
                senderName,
            });
        }
        return res.status(201).json({ success: true, data: createdRepost });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to repost' });
    }
});
/**
 * POST /api/posts/:id/share - Increment share count
 */
router.post('/:id/share', auth_1.authenticateToken, async (req, res) => {
    try {
        await db_1.prisma.post.update({ where: { id: String(req.params.id) }, data: { sharesCount: { increment: 1 } } });
        return res.json({ success: true });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to record share' });
    }
});
/**
 * POST /api/posts/:id/view - Increment view count
 */
router.post('/:id/view', auth_1.authenticateToken, async (req, res) => {
    try {
        await db_1.prisma.post.update({ where: { id: String(req.params.id) }, data: { viewsCount: { increment: 1 } } });
        return res.json({ success: true });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to record view' });
    }
});
/**
 * POST /api/posts/:id/watch - Track reel/video watch metrics and update view counts
 */
router.post('/:id/watch', auth_1.authenticateToken, async (req, res) => {
    try {
        const postId = String(req.params.id);
        const { watchedMs, completed, replayCount } = req.body;
        await db_1.prisma.post.update({
            where: { id: postId },
            data: {
                viewsCount: { increment: (replayCount && Number(replayCount) > 0 ? Number(replayCount) + 1 : 1) },
            },
        }).catch(() => { });
        return res.json({ success: true });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to record watch metrics' });
    }
});
/**
 * GET /api/posts/:id/comments - Get comments sorted by creator priority, verification tier, and engagement
 */
router.get('/:id/comments', auth_1.optionalAuth, async (req, res) => {
    try {
        const postId = String(req.params.id);
        // Fetch post author and comments concurrently in parallel
        const [targetPost, comments] = await Promise.all([
            db_1.prisma.post.findUnique({
                where: { id: postId },
                select: { authorId: true },
            }),
            db_1.prisma.postComment.findMany({
                where: { postId },
                orderBy: { createdAt: 'desc' },
                take: 100,
                include: {
                    author: {
                        select: { id: true, username: true, fullName: true, avatarUrl: true, isVerified: true, verificationType: true },
                    },
                    replies: {
                        take: 20,
                        include: {
                            author: { select: { id: true, username: true, fullName: true, avatarUrl: true, isVerified: true, verificationType: true } },
                        },
                    },
                },
            }),
        ]);
        const postAuthorId = targetPost?.authorId;
        const getWeight = (comment) => {
            if (!comment || !comment.author)
                return 0;
            // 1. Post creator priority
            if (postAuthorId && comment.authorId === postAuthorId)
                return 10;
            // 2. Verified badges
            const vType = String(comment.author.verificationType || '').toUpperCase();
            if (vType === 'GOLD')
                return 4;
            if (vType === 'VIOLET')
                return 3;
            if (vType === 'BLUE' || comment.author.isVerified)
                return 2;
            return 1;
        };
        comments.sort((a, b) => {
            const weightA = getWeight(a);
            const weightB = getWeight(b);
            if (weightA !== weightB) {
                return weightB - weightA; // Creator (10) > Gold (4) > Violet (3) > Blue (2) > Student (1)
            }
            return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
        });
        // Also prioritize creator replies inside each reply thread
        for (const c of comments) {
            if (Array.isArray(c.replies) && c.replies.length > 1) {
                c.replies.sort((rA, rB) => {
                    const isCreatorA = postAuthorId && rA.authorId === postAuthorId ? 1 : 0;
                    const isCreatorB = postAuthorId && rB.authorId === postAuthorId ? 1 : 0;
                    if (isCreatorA !== isCreatorB)
                        return isCreatorB - isCreatorA;
                    return new Date(rA.createdAt).getTime() - new Date(rB.createdAt).getTime();
                });
            }
        }
        return res.json({ success: true, data: comments });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to fetch comments' });
    }
});
// Comment velocity tracker for anti-spam rate limiting
const userCommentTimestamps = new Map();
/**
 * POST /api/posts/:id/comment - Add a comment with toxicity & spam protection
 */
router.post('/:id/comment', auth_1.authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const { content, parentCommentId } = req.body;
        if (!content || !String(content).trim())
            return res.status(400).json({ error: 'Comment content is required' });
        // 1. Spam Velocity Rate Limit (max 6 comments per 15s)
        const now = Date.now();
        let timestamps = userCommentTimestamps.get(userId) || [];
        timestamps = timestamps.filter(t => now - t < 15000);
        if (timestamps.length >= 6) {
            return res.status(429).json({ error: 'You are commenting too quickly. Please wait a moment.' });
        }
        timestamps.push(now);
        userCommentTimestamps.set(userId, timestamps);
        // 2. Toxicity & Inappropriate Content Filter
        const checkMod = (0, aiBotService_1.isContentInappropriate)(content);
        if (checkMod.flagged) {
            return res.status(400).json({ error: checkMod.reason, code: 'COMMENT_SAFETY_VIOLATION' });
        }
        if (parentCommentId) {
            // It's a reply
            const reply = await db_1.prisma.commentReply.create({
                data: {
                    commentId: parentCommentId,
                    authorId: req.user.id,
                    content,
                },
                include: {
                    author: { select: { id: true, username: true, fullName: true, avatarUrl: true } },
                },
            });
            await db_1.prisma.postComment.update({
                where: { id: parentCommentId },
                data: { replyCount: { increment: 1 } },
            });
            if ((0, aiBotService_1.containsAiMention)(content)) {
                (0, aiBotService_1.triggerAiCommentReply)(String(req.params.id), content, parentCommentId, reply.author.fullName || reply.author.username);
            }
            return res.status(201).json({
                success: true,
                data: {
                    ...reply,
                    parentId: parentCommentId,
                    parentCommentId,
                    postId: String(req.params.id),
                },
            });
        }
        const comment = await db_1.prisma.postComment.create({
            data: {
                postId: String(req.params.id),
                authorId: req.user.id,
                content,
            },
            include: {
                author: { select: { id: true, username: true, fullName: true, avatarUrl: true } },
            },
        });
        await db_1.prisma.post.update({
            where: { id: String(req.params.id) },
            data: { commentsCount: { increment: 1 } },
        });
        if ((0, aiBotService_1.containsAiMention)(content)) {
            (0, aiBotService_1.triggerAiCommentReply)(String(req.params.id), content, undefined, comment.author.fullName || comment.author.username);
        }
        const targetPost = await db_1.prisma.post.findUnique({ where: { id: String(req.params.id) }, select: { authorId: true } });
        if (targetPost && targetPost.authorId && targetPost.authorId !== req.user.id) {
            const senderName = comment.author.fullName || comment.author.username || 'Someone';
            sendOrGroupNotification({
                userId: targetPost.authorId,
                senderId: req.user.id,
                type: 'comment',
                relatedId: String(req.params.id),
                senderName,
                commentSnippet: content,
            });
        }
        return res.status(201).json({ success: true, data: comment });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to add comment' });
    }
});
/**
 * DELETE /api/posts/:id/comment/:commentId
 */
router.delete('/:id/comment/:commentId', auth_1.authenticateToken, async (req, res) => {
    try {
        const comment = await db_1.prisma.postComment.findUnique({ where: { id: String(req.params.commentId) } });
        if (!comment)
            return res.status(404).json({ error: 'Comment not found' });
        if (comment.authorId !== req.user.id)
            return res.status(403).json({ error: 'Not authorized' });
        await db_1.prisma.postComment.delete({ where: { id: String(req.params.commentId) } });
        await db_1.prisma.post.update({ where: { id: String(req.params.id) }, data: { commentsCount: { decrement: 1 } } });
        return res.json({ success: true });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to delete comment' });
    }
});
/**
 * POST /api/posts/:id/poll-vote - Vote on a poll
 */
router.post('/:id/poll-vote', auth_1.authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const optionIndex = Number(req.body.optionIndex);
        const postId = String(req.params.id);
        const post = await db_1.prisma.post.findUnique({ where: { id: postId } });
        if (!post || !post.pollData)
            return res.status(404).json({ error: 'Poll not found' });
        let poll = {};
        if (typeof post.pollData === 'string') {
            try {
                poll = JSON.parse(post.pollData);
            }
            catch { }
        }
        else if (typeof post.pollData === 'object' && post.pollData !== null) {
            poll = post.pollData;
        }
        if (!Array.isArray(poll.options) || poll.options.length === 0) {
            return res.status(400).json({ error: 'Invalid poll data' });
        }
        if (isNaN(optionIndex) || optionIndex < 0 || optionIndex >= poll.options.length) {
            return res.status(400).json({ error: 'Invalid option index' });
        }
        // Check poll expiration if ends_at exists
        if (poll.ends_at) {
            const endsAt = new Date(poll.ends_at);
            if (Date.now() > endsAt.getTime()) {
                return res.status(400).json({ error: 'Poll has already ended' });
            }
        }
        // Ensure votes array exists and has correct length
        if (!Array.isArray(poll.votes) || poll.votes.length !== poll.options.length) {
            poll.votes = new Array(poll.options.length).fill(0);
        }
        else {
            poll.votes = poll.votes.map((v) => (typeof v === 'number' ? v : Number(v) || 0));
        }
        // Ensure voters map exists
        if (!poll.voters || typeof poll.voters !== 'object' || Array.isArray(poll.voters)) {
            poll.voters = {};
        }
        // Check if user already voted
        const previousVote = poll.voters[userId];
        if (previousVote !== undefined && previousVote !== null) {
            const prevIdx = Number(previousVote);
            if (prevIdx === optionIndex) {
                // Already voted for this option
                poll.userVotedIndex = optionIndex;
                return res.json({ success: true, data: poll, pollData: poll });
            }
            // If changing vote: decrement old option count
            if (prevIdx >= 0 && prevIdx < poll.votes.length) {
                poll.votes[prevIdx] = Math.max(0, (poll.votes[prevIdx] || 1) - 1);
            }
        }
        // Increment newly voted option
        poll.votes[optionIndex] = (poll.votes[optionIndex] || 0) + 1;
        poll.voters[userId] = optionIndex;
        // Crucial: remove userVotedIndex before saving to shared DB column so other users can vote!
        delete poll.userVotedIndex;
        await db_1.prisma.post.update({
            where: { id: postId },
            data: { pollData: JSON.stringify(poll) },
        });
        console.log(`🗳️ User ${userId} voted option ${optionIndex} on poll post ${postId}`);
        const clientPollData = { ...poll, userVotedIndex: optionIndex };
        return res.json({ success: true, data: clientPollData, pollData: clientPollData });
    }
    catch (error) {
        console.error('Error voting on poll:', error);
        return res.status(500).json({ error: 'Failed to vote on poll' });
    }
});
/**
 * POST /api/posts/:id/watch - Track reel / video watch metrics and update view counts
 */
router.post('/:id/watch', auth_1.authenticateToken, async (req, res) => {
    try {
        const postId = String(req.params.id);
        const { watchedMs, durationMs, completionRate, replayCount, completed, skippedQuickly, source } = req.body;
        const post = await db_1.prisma.post.findUnique({
            where: { id: postId },
            select: { id: true, viewsCount: true, authorId: true, hashtags: true },
        });
        if (!post) {
            return res.status(404).json({ error: 'Post not found' });
        }
        // Increment post views count
        const updated = await db_1.prisma.post.update({
            where: { id: postId },
            data: {
                viewsCount: { increment: 1 },
            },
            select: { id: true, viewsCount: true },
        });
        return res.json({
            success: true,
            viewsCount: updated.viewsCount,
            metrics: {
                watchedMs: watchedMs || durationMs || 0,
                completionRate: completionRate || 0,
                replayCount: replayCount || 0,
                completed: !!completed,
                skippedQuickly: !!skippedQuickly,
                source: source || 'reels',
            },
        });
    }
    catch (error) {
        console.error('Error tracking video watch metrics:', error);
        return res.status(500).json({ error: 'Failed to record watch metrics' });
    }
});
/**
 * POST /api/posts/:id/view - Increment post view count
 */
router.post('/:id/view', auth_1.authenticateToken, async (req, res) => {
    try {
        const postId = String(req.params.id);
        const updated = await db_1.prisma.post.update({
            where: { id: postId },
            data: {
                viewsCount: { increment: 1 },
            },
            select: { id: true, viewsCount: true },
        });
        return res.json({ success: true, viewsCount: updated.viewsCount });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to increment view count' });
    }
});
exports.default = router;
