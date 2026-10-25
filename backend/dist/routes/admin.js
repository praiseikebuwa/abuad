"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const auth_1 = require("../middleware/auth");
const audit_1 = require("../middleware/audit");
const db_1 = require("../config/db");
const socket_1 = require("../realtime/socket");
const router = (0, express_1.Router)();
const adminOnly = (req, res, next) => {
    const role = req.user?.role?.toUpperCase();
    if (role !== 'ADMIN') {
        return res.status(403).json({ error: 'Forbidden: Admin access required' });
    }
    next();
};
/**
 * POST /api/admin/reports or /api/reports
 * Any authenticated user can submit a report
 */
router.post(['/', '/reports'], auth_1.authenticateToken, async (req, res) => {
    try {
        const { targetId, targetType, reason, details } = req.body;
        if (!targetId || !targetType || !reason) {
            return res.status(400).json({ error: 'targetId, targetType, and reason are required' });
        }
        const fullReason = details ? `${reason}: ${details}` : String(reason);
        const report = await db_1.prisma.report.create({
            data: {
                reporterId: req.user.id,
                targetId: String(targetId),
                targetType: String(targetType).toLowerCase(),
                reason: fullReason,
                status: 'PENDING',
            },
            include: {
                reporter: {
                    select: { id: true, username: true, fullName: true, email: true, avatarUrl: true },
                },
            },
        });
        return res.status(201).json({ success: true, data: report });
    }
    catch (error) {
        console.error('Error creating report:', error);
        return res.status(500).json({ error: 'Failed to create report' });
    }
});
/**
 * GET /api/admin/reports or /api/reports
 * Admin only: list reports with enriched preview info & filters
 */
router.get(['/', '/reports'], auth_1.authenticateToken, adminOnly, async (req, res) => {
    try {
        const { status, targetType } = req.query;
        const where = {};
        if (status && status !== 'ALL') {
            where.status = String(status).toUpperCase();
        }
        if (targetType && targetType !== 'ALL') {
            where.targetType = String(targetType).toLowerCase();
        }
        const reports = await db_1.prisma.report.findMany({
            where,
            orderBy: { createdAt: 'desc' },
            include: {
                reporter: {
                    select: { id: true, username: true, fullName: true, email: true, avatarUrl: true },
                },
            },
            take: 100,
        });
        // Enrich reports with preview of the reported target
        const enriched = await Promise.all(reports.map(async (r) => {
            let targetPreview = null;
            try {
                if (r.targetType === 'post') {
                    const post = await db_1.prisma.post.findUnique({
                        where: { id: r.targetId },
                        select: {
                            id: true,
                            content: true,
                            mediaUrl: true,
                            channelId: true,
                            authorId: true,
                            isAnonymous: true,
                            author: { select: { fullName: true, username: true, avatarUrl: true } },
                        },
                    });
                    targetPreview = post;
                }
                else if (r.targetType === 'comment') {
                    const comment = await db_1.prisma.postComment.findUnique({
                        where: { id: r.targetId },
                        select: {
                            id: true,
                            content: true,
                            authorId: true,
                            author: { select: { id: true, username: true, fullName: true, avatarUrl: true } },
                        },
                    });
                    targetPreview = comment;
                }
                else if (r.targetType === 'user') {
                    const user = await db_1.prisma.user.findUnique({
                        where: { id: r.targetId },
                        select: {
                            id: true,
                            username: true,
                            fullName: true,
                            avatarUrl: true,
                            isBlocked: true,
                            department: true,
                            role: true,
                        },
                    });
                    targetPreview = user;
                }
            }
            catch (_) { }
            return {
                ...r,
                targetPreview,
            };
        }));
        return res.json({ success: true, data: enriched });
    }
    catch (error) {
        console.error('Failed to fetch reports:', error);
        return res.status(500).json({ error: 'Failed to fetch reports' });
    }
});
/**
 * PATCH /api/admin/reports/:id
 * Admin only: update report status
 */
router.patch('/reports/:id', auth_1.authenticateToken, adminOnly, (0, audit_1.auditAction)('UPDATE_REPORT_STATUS'), async (req, res) => {
    try {
        const { status } = req.body;
        if (!status)
            return res.status(400).json({ error: 'status is required' });
        const reportId = String(req.params.id);
        const updated = await db_1.prisma.report.update({
            where: { id: reportId },
            data: { status: String(status).toUpperCase() },
        });
        return res.json({ success: true, data: updated });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to update report status' });
    }
});
/**
 * POST /api/admin/reports/:id/action
 * Admin moderation actions: DELETE_CONTENT, BAN_USER, UNBAN_USER, WARN_USER, DISMISS
 */
router.post('/reports/:id/action', auth_1.authenticateToken, adminOnly, (0, audit_1.auditAction)('REPORT_MODERATION_ACTION'), async (req, res) => {
    try {
        const { action, notes } = req.body;
        const reportId = String(req.params.id);
        const report = await db_1.prisma.report.findUnique({ where: { id: reportId } });
        if (!report)
            return res.status(404).json({ error: 'Report not found' });
        let message = 'Action executed successfully';
        if (action === 'DELETE_CONTENT') {
            if (report.targetType === 'post') {
                await db_1.prisma.post.deleteMany({ where: { id: report.targetId } });
                message = 'Reported post has been deleted';
            }
            else if (report.targetType === 'comment') {
                await db_1.prisma.postComment.deleteMany({ where: { id: report.targetId } });
                message = 'Reported comment has been deleted';
            }
            await db_1.prisma.report.update({
                where: { id: report.id },
                data: { status: 'RESOLVED' },
            });
        }
        else if (action === 'BAN_USER') {
            let targetUserId = report.targetId;
            if (report.targetType === 'post') {
                const post = await db_1.prisma.post.findUnique({ where: { id: report.targetId } });
                if (post)
                    targetUserId = post.authorId;
            }
            else if (report.targetType === 'comment') {
                const comment = await db_1.prisma.postComment.findUnique({ where: { id: report.targetId } });
                if (comment)
                    targetUserId = comment.authorId;
            }
            await db_1.prisma.user.update({
                where: { id: targetUserId },
                data: { isBlocked: true },
            });
            await db_1.prisma.report.update({
                where: { id: report.id },
                data: { status: 'RESOLVED' },
            });
            message = 'Author / user has been banned';
        }
        else if (action === 'UNBAN_USER') {
            await db_1.prisma.user.update({
                where: { id: report.targetId },
                data: { isBlocked: false },
            });
            message = 'User has been unbanned';
        }
        else if (action === 'WARN_USER') {
            let targetUserId = report.targetId;
            if (report.targetType === 'post') {
                const post = await db_1.prisma.post.findUnique({ where: { id: report.targetId } });
                if (post)
                    targetUserId = post.authorId;
            }
            await db_1.prisma.notification.create({
                data: {
                    userId: targetUserId,
                    title: '⚠️ Moderation Warning',
                    body: notes || 'Your recent activity was reported for violating ABUAD community rules. Please adhere to campus safety policies.',
                    type: 'system',
                },
            });
            await db_1.prisma.report.update({
                where: { id: report.id },
                data: { status: 'REVIEWED' },
            });
            message = 'Official warning delivered to user';
        }
        else if (action === 'DISMISS') {
            await db_1.prisma.report.update({
                where: { id: report.id },
                data: { status: 'DISMISSED' },
            });
            message = 'Report dismissed';
        }
        else if (action === 'RESOLVE') {
            await db_1.prisma.report.update({
                where: { id: report.id },
                data: { status: 'RESOLVED' },
            });
            message = 'Report marked resolved';
        }
        return res.json({ success: true, message });
    }
    catch (error) {
        console.error('Error executing report action:', error);
        return res.status(500).json({ error: error.message || 'Failed to execute moderation action' });
    }
});
/**
 * GET /api/admin/metrics
 * System dashboard metrics: reports, users, posts, confessions
 */
router.get('/metrics', auth_1.authenticateToken, adminOnly, async (req, res) => {
    try {
        const [totalUsers, bannedUsers, verifiedUsers, adminCount, totalPosts, pendingReports, resolvedReports, confessionsCount, totalAnnouncements,] = await Promise.all([
            db_1.prisma.user.count(),
            db_1.prisma.user.count({ where: { isBlocked: true } }),
            db_1.prisma.user.count({ where: { isVerified: true } }),
            db_1.prisma.user.count({ where: { role: 'ADMIN' } }),
            db_1.prisma.post.count(),
            db_1.prisma.report.count({ where: { status: 'PENDING' } }),
            db_1.prisma.report.count({ where: { status: { in: ['RESOLVED', 'REVIEWED', 'DISMISSED'] } } }),
            db_1.prisma.post.count({ where: { channelId: 'confessions' } }),
            db_1.prisma.announcement.count(),
        ]);
        return res.json({
            success: true,
            data: {
                totalUsers,
                bannedUsers,
                verifiedUsers,
                adminCount,
                totalPosts,
                pendingReports,
                resolvedReports,
                confessionsCount,
                totalAnnouncements,
            },
        });
    }
    catch (error) {
        console.error('Error fetching admin metrics:', error);
        return res.status(500).json({ error: 'Failed to fetch metrics' });
    }
});
/**
 * GET /api/admin/users
 * User directory with search & filters
 */
router.get('/users', auth_1.authenticateToken, adminOnly, async (req, res) => {
    try {
        const { q, filter } = req.query;
        const where = {};
        if (q) {
            const search = String(q).trim();
            where.OR = [
                { username: { contains: search, mode: 'insensitive' } },
                { fullName: { contains: search, mode: 'insensitive' } },
                { email: { contains: search, mode: 'insensitive' } },
            ];
        }
        if (filter === 'banned')
            where.isBlocked = true;
        if (filter === 'verified')
            where.isVerified = true;
        if (filter === 'admins')
            where.role = 'ADMIN';
        const users = await db_1.prisma.user.findMany({
            where,
            orderBy: { createdAt: 'desc' },
            take: 50,
            select: {
                id: true,
                email: true,
                username: true,
                fullName: true,
                avatarUrl: true,
                role: true,
                isVerified: true,
                verificationType: true,
                isBlocked: true,
                department: true,
                level: true,
                createdAt: true,
                followersCount: true,
                followingCount: true,
            },
        });
        return res.json({ success: true, data: users });
    }
    catch (error) {
        console.error('Error fetching users:', error);
        return res.status(500).json({ error: 'Failed to fetch users' });
    }
});
/**
 * POST /api/admin/users/:id/ban
 * Ban or unban a user
 */
router.post('/users/:id/ban', auth_1.authenticateToken, adminOnly, (0, audit_1.auditAction)('BAN_USER'), async (req, res) => {
    try {
        const { isBanned } = req.body;
        const targetId = String(req.params.id);
        if (targetId === req.user.id) {
            return res.status(400).json({ error: 'Cannot ban your own admin account' });
        }
        const updated = await db_1.prisma.user.update({
            where: { id: targetId },
            data: { isBlocked: isBanned === true },
            select: { id: true, username: true, fullName: true, isBlocked: true },
        });
        return res.json({ success: true, data: updated, message: isBanned ? 'User has been banned' : 'User unbanned' });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to update user ban status' });
    }
});
/**
 * POST /api/admin/users/:id/verify
 * Grant or revoke user verification badge
 */
router.post('/users/:id/verify', auth_1.authenticateToken, adminOnly, (0, audit_1.auditAction)('VERIFY_USER'), async (req, res) => {
    try {
        const { isVerified, verificationType } = req.body;
        const targetId = String(req.params.id);
        const updated = await db_1.prisma.user.update({
            where: { id: targetId },
            data: {
                isVerified: isVerified === true,
                verificationType: isVerified ? (verificationType || 'BLUE') : 'NONE',
            },
            select: { id: true, username: true, isVerified: true, verificationType: true },
        });
        return res.json({ success: true, data: updated, message: 'Verification updated' });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to update verification' });
    }
});
/**
 * POST /api/admin/users/:id/role
 * Change user role
 */
router.post('/users/:id/role', auth_1.authenticateToken, adminOnly, (0, audit_1.auditAction)('CHANGE_USER_ROLE'), async (req, res) => {
    try {
        const { role } = req.body;
        if (!['STUDENT', 'STAFF', 'ADMIN'].includes(String(role).toUpperCase())) {
            return res.status(400).json({ error: 'Invalid role' });
        }
        const targetId = String(req.params.id);
        const updated = await db_1.prisma.user.update({
            where: { id: targetId },
            data: { role: String(role).toUpperCase() },
            select: { id: true, username: true, role: true },
        });
        return res.json({ success: true, data: updated, message: 'User role updated' });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to update user role' });
    }
});
/**
 * GET /api/admin/confessions
 * Admin only: inspect all confessions unmasked
 */
router.get('/confessions', auth_1.authenticateToken, adminOnly, async (req, res) => {
    try {
        const confessions = await db_1.prisma.post.findMany({
            where: { channelId: 'confessions' },
            orderBy: { createdAt: 'desc' },
            take: 50,
            include: {
                author: {
                    select: { id: true, username: true, fullName: true, email: true, isBlocked: true },
                },
            },
        });
        return res.json({ success: true, data: confessions });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to fetch confessions' });
    }
});
/**
 * DELETE /api/admin/posts/:id
 * Direct admin deletion of any post
 */
router.delete('/posts/:id', auth_1.authenticateToken, adminOnly, (0, audit_1.auditAction)('DELETE_POST'), async (req, res) => {
    try {
        const postId = String(req.params.id);
        await db_1.prisma.post.delete({ where: { id: postId } });
        return res.json({ success: true, message: 'Post permanently deleted by admin' });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to delete post' });
    }
});
/**
 * POST /api/admin/broadcast
 * Send a campus announcement + system notification to everyone
 */
router.post('/broadcast', auth_1.authenticateToken, adminOnly, (0, audit_1.auditAction)('BROADCAST_ANNOUNCEMENT'), async (req, res) => {
    try {
        const { title, body, target } = req.body;
        if (!title || !body)
            return res.status(400).json({ error: 'Title and body are required' });
        const announcement = await db_1.prisma.announcement.create({
            data: {
                title,
                body,
                target: target || 'everyone',
            },
        });
        // Notify all active users asynchronously
        const users = await db_1.prisma.user.findMany({ select: { id: true }, take: 2000 });
        const notificationsData = users.map((u) => ({
            userId: u.id,
            title: `📢 ${title}`,
            body,
            type: 'system',
        }));
        await db_1.prisma.notification.createMany({
            data: notificationsData,
            skipDuplicates: true,
        });
        // Realtime live broadcast push to all active connections
        (0, socket_1.emitToAll)('broadcast:new', announcement);
        (0, socket_1.emitToAll)('notification:new', {
            id: announcement.id,
            title: `📢 ${title}`,
            body,
            type: 'system',
            createdAt: announcement.createdAt,
        });
        return res.status(201).json({ success: true, data: announcement, message: 'Broadcast published to campus' });
    }
    catch (error) {
        console.error('Error broadcasting announcement:', error);
        return res.status(500).json({ error: 'Failed to broadcast announcement' });
    }
});
/**
 * POST /api/admin/users/:userId/notify
 * Send a direct notification / administrative message to a specific user
 */
router.post('/users/:userId/notify', auth_1.authenticateToken, adminOnly, (0, audit_1.auditAction)('NOTIFY_USER'), async (req, res) => {
    try {
        const { userId } = req.params;
        const { title, body, type = 'admin_message', relatedId } = req.body;
        if (!title || !body) {
            return res.status(400).json({ error: 'Title and body are required' });
        }
        const targetUser = await db_1.prisma.user.findUnique({
            where: { id: String(userId) },
            select: { id: true, fullName: true, username: true },
        });
        if (!targetUser) {
            return res.status(404).json({ error: 'Target user not found' });
        }
        const notification = await db_1.prisma.notification.create({
            data: {
                userId: targetUser.id,
                senderId: req.user.id,
                title: title.trim(),
                body: body.trim(),
                type: type || 'admin_message',
                relatedId: relatedId || null,
            },
        });
        const enriched = {
            ...notification,
            senderName: req.user?.fullName || req.user?.email || 'ABUAD Administration',
            senderRole: 'ADMIN',
        };
        // Emit live realtime event to the user's socket room
        (0, socket_1.emitToUsers)([targetUser.id], 'notification:new', enriched);
        return res.status(201).json({
            success: true,
            data: enriched,
            message: `Notification sent successfully to ${targetUser.fullName || targetUser.username}`,
        });
    }
    catch (error) {
        console.error('Error sending user notification:', error);
        return res.status(500).json({ error: 'Failed to send notification to user' });
    }
});
/**
 * Legacy routes for system config, announcements, audit logs
 */
router.get(['/config', '/system/config'], auth_1.authenticateToken, async (req, res) => {
    try {
        const settings = await db_1.prisma.systemSetting.findMany();
        const configMap = {};
        settings.forEach((s) => {
            try {
                configMap[s.key] = JSON.parse(s.value);
            }
            catch {
                configMap[s.key] = s.value;
            }
        });
        return res.json({ success: true, data: configMap });
    }
    catch (error) {
        return res.json({ success: true, data: { maintenanceMode: false, appVersion: '1.0.0' } });
    }
});
router.post(['/config', '/system/config'], auth_1.authenticateToken, adminOnly, (0, audit_1.auditAction)('UPDATE_SYSTEM_CONFIG'), async (req, res) => {
    try {
        const { key, value } = req.body;
        if (!key)
            return res.status(400).json({ error: 'Key is required' });
        const strVal = typeof value === 'object' ? JSON.stringify(value) : String(value);
        const setting = await db_1.prisma.systemSetting.upsert({
            where: { key },
            update: { value: strVal },
            create: { key, value: strVal },
        });
        return res.json({ success: true, data: setting });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to save config' });
    }
});
router.get('/announcements', auth_1.authenticateToken, async (req, res) => {
    try {
        const announcements = await db_1.prisma.announcement.findMany({ orderBy: { createdAt: 'desc' } });
        return res.json({ success: true, data: announcements });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to fetch announcements' });
    }
});
router.post('/announcements', auth_1.authenticateToken, adminOnly, (0, audit_1.auditAction)('CREATE_ANNOUNCEMENT'), async (req, res) => {
    try {
        const { title, body, target } = req.body;
        const item = await db_1.prisma.announcement.create({
            data: {
                title: title || 'System Announcement',
                body: body || '',
                target: target || 'everyone',
            },
        });
        return res.status(201).json({ success: true, data: item });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to create announcement' });
    }
});
router.get('/audit-logs', auth_1.authenticateToken, adminOnly, async (req, res) => {
    try {
        const logs = await db_1.prisma.auditLog.findMany({
            orderBy: { createdAt: 'desc' },
            take: 100,
        });
        return res.json({ success: true, data: logs });
    }
    catch (error) {
        return res.status(500).json({ error: 'Failed to fetch audit logs' });
    }
});
/**
 * GET /api/admin/settings/ai-posting
 * Check whether autonomous ABUAD AI posting to the feed is active
 */
router.get(['/settings/ai-posting', '/ai-posting'], auth_1.authenticateToken, adminOnly, async (req, res) => {
    try {
        const setting = await db_1.prisma.systemSetting.findUnique({
            where: { key: 'ai_autonomous_posting' },
        });
        const enabled = setting ? (setting.value === 'true' || setting.value === '1') : false;
        return res.json({ success: true, enabled });
    }
    catch (error) {
        console.error('Error fetching AI posting setting:', error);
        return res.status(500).json({ error: 'Failed to fetch setting' });
    }
});
/**
 * POST /api/admin/settings/ai-posting
 * Toggle autonomous ABUAD AI posting to the feed ON or OFF
 */
router.post(['/settings/ai-posting', '/ai-posting'], auth_1.authenticateToken, adminOnly, (0, audit_1.auditAction)('TOGGLE_AI_POSTING'), async (req, res) => {
    try {
        const { enabled } = req.body;
        const isEnabled = enabled === true || enabled === 'true' || enabled === 1 || enabled === '1';
        const strVal = isEnabled ? 'true' : 'false';
        await db_1.prisma.systemSetting.upsert({
            where: { key: 'ai_autonomous_posting' },
            update: { value: strVal },
            create: { key: 'ai_autonomous_posting', value: strVal },
        });
        console.log(`🔧 Admin ${req.user?.username || req.user?.id} set ABUAD AI autonomous posting to: ${strVal}`);
        return res.json({ success: true, enabled: isEnabled, message: `ABUAD AI autonomous posting is now ${isEnabled ? 'ENABLED' : 'DISABLED'}` });
    }
    catch (error) {
        console.error('Error updating AI posting setting:', error);
        return res.status(500).json({ error: 'Failed to update setting' });
    }
});
/**
 * POST /api/admin/ai-posts/clean
 * Clean up existing autonomous ABUAD AI posts from the feed
 */
router.post('/ai-posts/clean', auth_1.authenticateToken, adminOnly, (0, audit_1.auditAction)('CLEAN_AI_POSTS'), async (req, res) => {
    try {
        const aiUser = await db_1.prisma.user.findFirst({
            where: {
                OR: [{ username: 'abuad_ai' }, { email: 'ai@abuad.edu.ng' }]
            }
        });
        if (!aiUser) {
            return res.json({ success: true, count: 0, message: 'No AI bot user found' });
        }
        const deleteResult = await db_1.prisma.post.deleteMany({
            where: { authorId: aiUser.id }
        });
        console.log(`🧹 Admin cleaned up ${deleteResult.count} autonomous ABUAD AI posts`);
        return res.json({
            success: true,
            count: deleteResult.count,
            message: `Successfully removed ${deleteResult.count} ABUAD AI posts from the feed`
        });
    }
    catch (error) {
        console.error('Error cleaning AI posts:', error);
        return res.status(500).json({ error: 'Failed to clean AI posts' });
    }
});
exports.default = router;
