import { Router, Response } from 'express';
import { authenticateToken, requireRole, AuthenticatedRequest } from '../middleware/auth';
import { auditAction } from '../middleware/audit';
import { prisma } from '../config/db';

const router = Router();

const adminOnly = (req: AuthenticatedRequest, res: Response, next: Function) => {
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
router.post(['/', '/reports'], authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { targetId, targetType, reason, details } = req.body;
    if (!targetId || !targetType || !reason) {
      return res.status(400).json({ error: 'targetId, targetType, and reason are required' });
    }

    const fullReason = details ? `${reason}: ${details}` : String(reason);

    const report = await prisma.report.create({
      data: {
        reporterId: req.user!.id,
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
  } catch (error: any) {
    console.error('Error creating report:', error);
    return res.status(500).json({ error: 'Failed to create report' });
  }
});

/**
 * GET /api/admin/reports or /api/reports
 * Admin only: list reports with enriched preview info & filters
 */
router.get(['/', '/reports'], authenticateToken, adminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { status, targetType } = req.query;

    const where: any = {};
    if (status && status !== 'ALL') {
      where.status = String(status).toUpperCase();
    }
    if (targetType && targetType !== 'ALL') {
      where.targetType = String(targetType).toLowerCase();
    }

    const reports = await prisma.report.findMany({
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
    const enriched = await Promise.all(
      reports.map(async (r) => {
        let targetPreview: any = null;
        try {
          if (r.targetType === 'post') {
            const post = await prisma.post.findUnique({
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
          } else if (r.targetType === 'comment') {
            const comment = await prisma.postComment.findUnique({
              where: { id: r.targetId },
              select: {
                id: true,
                content: true,
                authorId: true,
                author: { select: { id: true, username: true, fullName: true, avatarUrl: true } },
              },
            });
            targetPreview = comment;
          } else if (r.targetType === 'user') {
            const user = await prisma.user.findUnique({
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
        } catch (_) {}

        return {
          ...r,
          targetPreview,
        };
      })
    );

    return res.json({ success: true, data: enriched });
  } catch (error) {
    console.error('Failed to fetch reports:', error);
    return res.status(500).json({ error: 'Failed to fetch reports' });
  }
});

/**
 * PATCH /api/admin/reports/:id
 * Admin only: update report status
 */
router.patch('/reports/:id', authenticateToken, adminOnly, auditAction('UPDATE_REPORT_STATUS'), async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { status } = req.body;
    if (!status) return res.status(400).json({ error: 'status is required' });

    const reportId = String(req.params.id);
    const updated = await prisma.report.update({
      where: { id: reportId },
      data: { status: String(status).toUpperCase() },
    });

    return res.json({ success: true, data: updated });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to update report status' });
  }
});

/**
 * POST /api/admin/reports/:id/action
 * Admin moderation actions: DELETE_CONTENT, BAN_USER, UNBAN_USER, WARN_USER, DISMISS
 */
router.post('/reports/:id/action', authenticateToken, adminOnly, auditAction('REPORT_MODERATION_ACTION'), async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { action, notes } = req.body;
    const reportId = String(req.params.id);
    const report = await prisma.report.findUnique({ where: { id: reportId } });
    if (!report) return res.status(404).json({ error: 'Report not found' });

    let message = 'Action executed successfully';

    if (action === 'DELETE_CONTENT') {
      if (report.targetType === 'post') {
        await prisma.post.deleteMany({ where: { id: report.targetId } });
        message = 'Reported post has been deleted';
      } else if (report.targetType === 'comment') {
        await prisma.postComment.deleteMany({ where: { id: report.targetId } });
        message = 'Reported comment has been deleted';
      }
      await prisma.report.update({
        where: { id: report.id },
        data: { status: 'RESOLVED' },
      });
    } else if (action === 'BAN_USER') {
      let targetUserId = report.targetId;
      if (report.targetType === 'post') {
        const post = await prisma.post.findUnique({ where: { id: report.targetId } });
        if (post) targetUserId = post.authorId;
      } else if (report.targetType === 'comment') {
        const comment = await prisma.postComment.findUnique({ where: { id: report.targetId } });
        if (comment) targetUserId = comment.authorId;
      }

      await prisma.user.update({
        where: { id: targetUserId },
        data: { isBlocked: true },
      });

      await prisma.report.update({
        where: { id: report.id },
        data: { status: 'RESOLVED' },
      });
      message = 'Author / user has been banned';
    } else if (action === 'UNBAN_USER') {
      await prisma.user.update({
        where: { id: report.targetId },
        data: { isBlocked: false },
      });
      message = 'User has been unbanned';
    } else if (action === 'WARN_USER') {
      let targetUserId = report.targetId;
      if (report.targetType === 'post') {
        const post = await prisma.post.findUnique({ where: { id: report.targetId } });
        if (post) targetUserId = post.authorId;
      }

      await prisma.notification.create({
        data: {
          userId: targetUserId,
          title: '⚠️ Moderation Warning',
          body: notes || 'Your recent activity was reported for violating ABUAD community rules. Please adhere to campus safety policies.',
          type: 'system',
        },
      });

      await prisma.report.update({
        where: { id: report.id },
        data: { status: 'REVIEWED' },
      });
      message = 'Official warning delivered to user';
    } else if (action === 'DISMISS') {
      await prisma.report.update({
        where: { id: report.id },
        data: { status: 'DISMISSED' },
      });
      message = 'Report dismissed';
    } else if (action === 'RESOLVE') {
      await prisma.report.update({
        where: { id: report.id },
        data: { status: 'RESOLVED' },
      });
      message = 'Report marked resolved';
    }

    return res.json({ success: true, message });
  } catch (error: any) {
    console.error('Error executing report action:', error);
    return res.status(500).json({ error: error.message || 'Failed to execute moderation action' });
  }
});

/**
 * GET /api/admin/metrics
 * System dashboard metrics: reports, users, posts, confessions
 */
router.get('/metrics', authenticateToken, adminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const [
      totalUsers,
      bannedUsers,
      verifiedUsers,
      adminCount,
      totalPosts,
      pendingReports,
      resolvedReports,
      confessionsCount,
      totalAnnouncements,
    ] = await Promise.all([
      prisma.user.count(),
      prisma.user.count({ where: { isBlocked: true } }),
      prisma.user.count({ where: { isVerified: true } }),
      prisma.user.count({ where: { role: 'ADMIN' } }),
      prisma.post.count(),
      prisma.report.count({ where: { status: 'PENDING' } }),
      prisma.report.count({ where: { status: { in: ['RESOLVED', 'REVIEWED', 'DISMISSED'] } } }),
      prisma.post.count({ where: { channelId: 'confessions' } }),
      prisma.announcement.count(),
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
  } catch (error) {
    console.error('Error fetching admin metrics:', error);
    return res.status(500).json({ error: 'Failed to fetch metrics' });
  }
});

/**
 * GET /api/admin/users
 * User directory with search & filters
 */
router.get('/users', authenticateToken, adminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { q, filter } = req.query;

    const where: any = {};
    if (q) {
      const search = String(q).trim();
      where.OR = [
        { username: { contains: search, mode: 'insensitive' } },
        { fullName: { contains: search, mode: 'insensitive' } },
        { email: { contains: search, mode: 'insensitive' } },
      ];
    }

    if (filter === 'banned') where.isBlocked = true;
    if (filter === 'verified') where.isVerified = true;
    if (filter === 'admins') where.role = 'ADMIN';

    const users = await prisma.user.findMany({
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
  } catch (error) {
    console.error('Error fetching users:', error);
    return res.status(500).json({ error: 'Failed to fetch users' });
  }
});

/**
 * POST /api/admin/users/:id/ban
 * Ban or unban a user
 */
router.post('/users/:id/ban', authenticateToken, adminOnly, auditAction('BAN_USER'), async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { isBanned } = req.body;
    const targetId = String(req.params.id);

    if (targetId === req.user!.id) {
      return res.status(400).json({ error: 'Cannot ban your own admin account' });
    }

    const updated = await prisma.user.update({
      where: { id: targetId },
      data: { isBlocked: isBanned === true },
      select: { id: true, username: true, fullName: true, isBlocked: true },
    });

    return res.json({ success: true, data: updated, message: isBanned ? 'User has been banned' : 'User unbanned' });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to update user ban status' });
  }
});

/**
 * POST /api/admin/users/:id/verify
 * Grant or revoke user verification badge
 */
router.post('/users/:id/verify', authenticateToken, adminOnly, auditAction('VERIFY_USER'), async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { isVerified, verificationType } = req.body;
    const targetId = String(req.params.id);
    const updated = await prisma.user.update({
      where: { id: targetId },
      data: {
        isVerified: isVerified === true,
        verificationType: isVerified ? (verificationType || 'BLUE') : 'NONE',
      },
      select: { id: true, username: true, isVerified: true, verificationType: true },
    });

    return res.json({ success: true, data: updated, message: 'Verification updated' });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to update verification' });
  }
});

/**
 * POST /api/admin/users/:id/role
 * Change user role
 */
router.post('/users/:id/role', authenticateToken, adminOnly, auditAction('CHANGE_USER_ROLE'), async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { role } = req.body;
    if (!['STUDENT', 'STAFF', 'ADMIN'].includes(String(role).toUpperCase())) {
      return res.status(400).json({ error: 'Invalid role' });
    }

    const targetId = String(req.params.id);
    const updated = await prisma.user.update({
      where: { id: targetId },
      data: { role: String(role).toUpperCase() },
      select: { id: true, username: true, role: true },
    });

    return res.json({ success: true, data: updated, message: 'User role updated' });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to update user role' });
  }
});

/**
 * GET /api/admin/confessions
 * Admin only: inspect all confessions unmasked
 */
router.get('/confessions', authenticateToken, adminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const confessions = await prisma.post.findMany({
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
  } catch (error) {
    return res.status(500).json({ error: 'Failed to fetch confessions' });
  }
});

/**
 * DELETE /api/admin/posts/:id
 * Direct admin deletion of any post
 */
router.delete('/posts/:id', authenticateToken, adminOnly, auditAction('DELETE_POST'), async (req: AuthenticatedRequest, res: Response) => {
  try {
    const postId = String(req.params.id);
    await prisma.post.delete({ where: { id: postId } });
    return res.json({ success: true, message: 'Post permanently deleted by admin' });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to delete post' });
  }
});

/**
 * POST /api/admin/broadcast
 * Send a campus announcement + system notification to everyone
 */
router.post('/broadcast', authenticateToken, adminOnly, auditAction('BROADCAST_ANNOUNCEMENT'), async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { title, body, target } = req.body;
    if (!title || !body) return res.status(400).json({ error: 'Title and body are required' });

    const announcement = await prisma.announcement.create({
      data: {
        title,
        body,
        target: target || 'everyone',
      },
    });

    // Notify all active users asynchronously
    const users = await prisma.user.findMany({ select: { id: true }, take: 2000 });
    const notificationsData = users.map((u) => ({
      userId: u.id,
      title: `📢 ${title}`,
      body,
      type: 'system',
    }));

    await prisma.notification.createMany({
      data: notificationsData,
      skipDuplicates: true,
    });

    return res.status(201).json({ success: true, data: announcement, message: 'Broadcast published to campus' });
  } catch (error) {
    console.error('Error broadcasting announcement:', error);
    return res.status(500).json({ error: 'Failed to broadcast announcement' });
  }
});

/**
 * Legacy routes for system config, announcements, audit logs
 */
router.get(['/config', '/system/config'], authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const settings = await prisma.systemSetting.findMany();
    const configMap: Record<string, any> = {};
    settings.forEach((s) => {
      try {
        configMap[s.key] = JSON.parse(s.value);
      } catch {
        configMap[s.key] = s.value;
      }
    });
    return res.json({ success: true, data: configMap });
  } catch (error) {
    return res.json({ success: true, data: { maintenanceMode: false, appVersion: '1.0.0' } });
  }
});

router.post(['/config', '/system/config'], authenticateToken, adminOnly, auditAction('UPDATE_SYSTEM_CONFIG'), async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { key, value } = req.body;
    if (!key) return res.status(400).json({ error: 'Key is required' });
    const strVal = typeof value === 'object' ? JSON.stringify(value) : String(value);
    const setting = await prisma.systemSetting.upsert({
      where: { key },
      update: { value: strVal },
      create: { key, value: strVal },
    });
    return res.json({ success: true, data: setting });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to save config' });
  }
});

router.get('/announcements', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const announcements = await prisma.announcement.findMany({ orderBy: { createdAt: 'desc' } });
    return res.json({ success: true, data: announcements });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to fetch announcements' });
  }
});

router.post('/announcements', authenticateToken, adminOnly, auditAction('CREATE_ANNOUNCEMENT'), async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { title, body, target } = req.body;
    const item = await prisma.announcement.create({
      data: {
        title: title || 'System Announcement',
        body: body || '',
        target: target || 'everyone',
      },
    });
    return res.status(201).json({ success: true, data: item });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to create announcement' });
  }
});

router.get('/audit-logs', authenticateToken, adminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const logs = await prisma.auditLog.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    return res.json({ success: true, data: logs });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to fetch audit logs' });
  }
});

/**
 * GET /api/admin/settings/ai-posting
 * Check whether autonomous ABUAD AI posting to the feed is active
 */
router.get(['/settings/ai-posting', '/ai-posting'], authenticateToken, adminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const setting = await prisma.systemSetting.findUnique({
      where: { key: 'ai_autonomous_posting' },
    });
    const enabled = setting ? (setting.value === 'true' || setting.value === '1') : false;
    return res.json({ success: true, enabled });
  } catch (error) {
    console.error('Error fetching AI posting setting:', error);
    return res.status(500).json({ error: 'Failed to fetch setting' });
  }
});

/**
 * POST /api/admin/settings/ai-posting
 * Toggle autonomous ABUAD AI posting to the feed ON or OFF
 */
router.post(['/settings/ai-posting', '/ai-posting'], authenticateToken, adminOnly, auditAction('TOGGLE_AI_POSTING'), async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { enabled } = req.body;
    const isEnabled = enabled === true || enabled === 'true' || enabled === 1 || enabled === '1';
    const strVal = isEnabled ? 'true' : 'false';

    await prisma.systemSetting.upsert({
      where: { key: 'ai_autonomous_posting' },
      update: { value: strVal },
      create: { key: 'ai_autonomous_posting', value: strVal },
    });

    console.log(`🔧 Admin ${(req.user as any)?.username || req.user?.id} set ABUAD AI autonomous posting to: ${strVal}`);
    return res.json({ success: true, enabled: isEnabled, message: `ABUAD AI autonomous posting is now ${isEnabled ? 'ENABLED' : 'DISABLED'}` });
  } catch (error) {
    console.error('Error updating AI posting setting:', error);
    return res.status(500).json({ error: 'Failed to update setting' });
  }
});

/**
 * POST /api/admin/ai-posts/clean
 * Clean up existing autonomous ABUAD AI posts from the feed
 */
router.post('/ai-posts/clean', authenticateToken, adminOnly, auditAction('CLEAN_AI_POSTS'), async (req: AuthenticatedRequest, res: Response) => {
  try {
    const aiUser = await prisma.user.findFirst({
      where: {
        OR: [{ username: 'abuad_ai' }, { email: 'ai@abuad.edu.ng' }]
      }
    });

    if (!aiUser) {
      return res.json({ success: true, count: 0, message: 'No AI bot user found' });
    }

    const deleteResult = await prisma.post.deleteMany({
      where: { authorId: aiUser.id }
    });

    console.log(`🧹 Admin cleaned up ${deleteResult.count} autonomous ABUAD AI posts`);
    return res.json({
      success: true,
      count: deleteResult.count,
      message: `Successfully removed ${deleteResult.count} ABUAD AI posts from the feed`
    });
  } catch (error) {
    console.error('Error cleaning AI posts:', error);
    return res.status(500).json({ error: 'Failed to clean AI posts' });
  }
});

export default router;
