import { Router, Response } from 'express';
import { authenticateToken, AuthenticatedRequest } from '../middleware/auth';
import { prisma } from '../config/db';

const router = Router();

/**
 * GET /api/users - List all users (Admin/Authenticated)
 */
router.get('/', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const users = await prisma.user.findMany({
      take: 100,
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        email: true,
        username: true,
        fullName: true,
        bio: true,
        avatarUrl: true,
        bannerUrl: true,
        department: true,
        level: true,
        college: true,
        phoneNumber: true,
        role: true,
        isVerified: true,
        verificationType: true,
        isBlocked: true,
        followersCount: true,
        followingCount: true,
        status: true,
        lastSeen: true,
        streakCount: true,
        websiteUrl: true,
        facebookUrl: true,
        twitterUrl: true,
        instagramUrl: true,
        linkedinUrl: true,
        whatsappUrl: true,
        tiktokUrl: true,
        youtubeUrl: true,
        snapchatUrl: true,
        githubUrl: true,
        twitchUrl: true,
        createdAt: true,
        updatedAt: true,
      },
    });
    return res.json({ success: true, data: users });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to fetch users' });
  }
});

/**
 * GET /api/users/me - Current authenticated user's profile
 */
router.get('/me', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user!.id },
      select: {
        id: true,
        email: true,
        username: true,
        fullName: true,
        bio: true,
        avatarUrl: true,
        bannerUrl: true,
        department: true,
        level: true,
        college: true,
        phoneNumber: true,
        role: true,
        isVerified: true,
        verificationType: true,
        followersCount: true,
        followingCount: true,
        status: true,
        lastSeen: true,
        websiteUrl: true,
        createdAt: true,
      },
    });
    if (!user) return res.status(404).json({ error: 'User not found' });
    return res.json({ success: true, data: user });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to fetch profile' });
  }
});

/**
 * PUT /api/users/me - Update current user profile
 */
router.put('/me', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const {
      fullName, display_name, bio, avatarUrl, avatar_url, bannerUrl, banner_url, department, level, college,
      phoneNumber, phone_number, websiteUrl, website_url, facebookUrl, facebook_url, twitterUrl, twitter_url,
      instagramUrl, instagram_url, linkedinUrl, linkedin_url, whatsappUrl, whatsapp_url, tiktokUrl, tiktok_url, youtubeUrl, youtube_url,
      snapchatUrl, snapchat_url, githubUrl, github_url, twitchUrl, twitch_url,
    } = req.body;

    const updated = await prisma.user.update({
      where: { id: req.user!.id },
      data: {
        ...(fullName !== undefined && { fullName }),
        ...(display_name !== undefined && { fullName: display_name }),
        ...(bio !== undefined && { bio }),
        ...(avatarUrl !== undefined && { avatarUrl }),
        ...(avatar_url !== undefined && { avatarUrl: avatar_url }),
        ...(bannerUrl !== undefined && { bannerUrl }),
        ...(banner_url !== undefined && { bannerUrl: banner_url }),
        ...(department !== undefined && { department }),
        ...(level !== undefined && { level }),
        ...(college !== undefined && { college }),
        ...(phoneNumber !== undefined && { phoneNumber }),
        ...(phone_number !== undefined && { phoneNumber: phone_number }),
        ...(websiteUrl !== undefined && { websiteUrl }),
        ...(website_url !== undefined && { websiteUrl: website_url }),
        ...(facebookUrl !== undefined && { facebookUrl }),
        ...(facebook_url !== undefined && { facebookUrl: facebook_url }),
        ...(twitterUrl !== undefined && { twitterUrl }),
        ...(twitter_url !== undefined && { twitterUrl: twitter_url }),
        ...(instagramUrl !== undefined && { instagramUrl }),
        ...(instagram_url !== undefined && { instagramUrl: instagram_url }),
        ...(linkedinUrl !== undefined && { linkedinUrl }),
        ...(linkedin_url !== undefined && { linkedinUrl: linkedin_url }),
        ...(whatsappUrl !== undefined && { whatsappUrl }),
        ...(whatsapp_url !== undefined && { whatsappUrl: whatsapp_url }),
        ...(tiktokUrl !== undefined && { tiktokUrl }),
        ...(tiktok_url !== undefined && { tiktokUrl: tiktok_url }),
        ...(youtubeUrl !== undefined && { youtubeUrl }),
        ...(youtube_url !== undefined && { youtubeUrl: youtube_url }),
        ...(snapchatUrl !== undefined && { snapchatUrl }),
        ...(snapchat_url !== undefined && { snapchatUrl: snapchat_url }),
        ...(githubUrl !== undefined && { githubUrl }),
        ...(github_url !== undefined && { githubUrl: github_url }),
        ...(twitchUrl !== undefined && { twitchUrl }),
        ...(twitch_url !== undefined && { twitchUrl: twitch_url }),
      },
      select: {
        id: true,
        email: true,
        username: true,
        fullName: true,
        bio: true,
        avatarUrl: true,
        bannerUrl: true,
        department: true,
        college: true,
        phoneNumber: true,
        level: true,
        role: true,
        isVerified: true,
      },
    });
    return res.json({ success: true, data: updated });
  } catch (error) {
    console.error('Profile update error:', error);
    return res.status(500).json({ error: 'Failed to update profile' });
  }
});

/**
 * GET /api/users/search?q=
 */
router.get('/search', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const query = String(req.query.q || '');
    const users = await prisma.user.findMany({
      where: {
        OR: [
          { username: { contains: query } },
          { fullName: { contains: query } },
          { email: { contains: query } },
        ],
      },
      take: 20,
      select: {
        id: true,
        username: true,
        fullName: true,
        avatarUrl: true,
        department: true,
        level: true,
        isVerified: true,
      },
    });
    return res.json({ success: true, data: users });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to search users' });
  }
});

/**
 * GET /api/users/:id/followers
 */
router.get('/:id/followers', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const targetId = req.params.id === 'me' ? req.user!.id : String(req.params.id);
    const followers = await prisma.follower.findMany({
      where: { followedId: targetId },
      include: {
        follower: {
          select: { id: true, username: true, fullName: true, avatarUrl: true, isVerified: true },
        },
      },
      take: 100,
    });
    return res.json({ success: true, data: followers.map(f => f.follower) });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to fetch followers' });
  }
});

/**
 * GET /api/users/:id/following
 */
router.get('/:id/following', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const targetId = req.params.id === 'me' ? req.user!.id : String(req.params.id);
    const following = await prisma.follower.findMany({
      where: { followerId: targetId },
      include: {
        followed: {
          select: { id: true, username: true, fullName: true, avatarUrl: true, isVerified: true },
        },
      },
      take: 100,
    });
    return res.json({ success: true, data: following.map(f => f.followed) });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to fetch following' });
  }
});

/**
 * POST /api/users/:id/follow - Follow a user
 */
router.post('/:id/follow', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const followerId = req.user!.id;
    const followedId = String(req.params.id);

    if (followerId === followedId) {
      return res.status(400).json({ error: 'Cannot follow yourself' });
    }

    const existing = await prisma.follower.findUnique({
      where: { followerId_followedId: { followerId, followedId } },
    });

    if (existing) {
      return res.status(409).json({ error: 'Already following this user' });
    }

    await prisma.$transaction([
      prisma.follower.create({ data: { followerId, followedId } }),
      prisma.user.update({ where: { id: followerId }, data: { followingCount: { increment: 1 } } }),
      prisma.user.update({ where: { id: followedId }, data: { followersCount: { increment: 1 } } }),
    ]);

    return res.status(201).json({ success: true, isFollowing: true });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to follow user' });
  }
});

/**
 * DELETE /api/users/:id/follow - Unfollow a user
 */
router.delete('/:id/follow', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const followerId = req.user!.id;
    const followedId = String(req.params.id);

    const existing = await prisma.follower.findUnique({
      where: { followerId_followedId: { followerId, followedId } },
    });

    if (!existing) {
      return res.status(404).json({ error: 'Not following this user' });
    }

    await prisma.$transaction([
      prisma.follower.delete({ where: { id: existing.id } }),
      prisma.user.update({ where: { id: followerId }, data: { followingCount: { decrement: 1 } } }),
      prisma.user.update({ where: { id: followedId }, data: { followersCount: { decrement: 1 } } }),
    ]);

    return res.json({ success: true, isFollowing: false });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to unfollow user' });
  }
});

/**
 * GET /api/users/:id/is-following - Check if following a user
 */
router.get('/:id/is-following', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const existing = await prisma.follower.findUnique({
      where: { followerId_followedId: { followerId: req.user!.id, followedId: String(req.params.id) } },
    });
    return res.json({ success: true, isFollowing: !!existing });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to check follow status' });
  }
});

/**
 * PUT /api/users/:id/status - Update user online status
 */
router.put('/:id/status', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { status } = req.body;
    await prisma.user.update({
      where: { id: req.user!.id },
      data: {
        status: status || 'online',
        lastSeen: new Date(),
      },
    });
    return res.json({ success: true });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to update status' });
  }
});

/**
 * POST /api/users/block/:id - Block a user
 */
router.post('/block/:id', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const blockerId = req.user!.id;
    const blockedId = String(req.params.id);

    const existing = await prisma.blockedUser.findUnique({
      where: { blockerId_blockedId: { blockerId, blockedId } },
    });
    if (!existing) {
      await prisma.blockedUser.create({ data: { blockerId, blockedId } });
    }
    return res.json({ success: true });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to block user' });
  }
});

/**
 * DELETE /api/users/block/:id - Unblock a user
 */
router.delete('/block/:id', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const blockerId = req.user!.id;
    const blockedId = String(req.params.id);

    await prisma.blockedUser.deleteMany({ where: { blockerId, blockedId } });
    return res.json({ success: true });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to unblock user' });
  }
});

/**
 * ALL /api/users/:id - Get or update user attributes (verification, status, etc.)
 */
router.all('/:id', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  const targetId = String(req.params.id);

  if (req.method === 'GET') {
    try {
      const user = await prisma.user.findUnique({
        where: { id: targetId },
        select: {
          id: true,
          username: true,
          fullName: true,
          bio: true,
          avatarUrl: true,
          bannerUrl: true,
          department: true,
          level: true,
          college: true,
          role: true,
          isVerified: true,
          verificationType: true,
          followersCount: true,
          followingCount: true,
          status: true,
          lastSeen: true,
          websiteUrl: true,
          createdAt: true,
        },
      });
      if (!user) return res.status(404).json({ error: 'User not found' });
      return res.json({ success: true, data: user });
    } catch (error) {
      return res.status(500).json({ error: 'Failed to fetch user' });
    }
  }

  if (req.method === 'POST' || req.method === 'PUT') {
    try {
      const {
        verification_type, verificationType, is_verified, isVerified, status,
      } = req.body;

      const updateData: any = {};

      if (verification_type !== undefined || verificationType !== undefined || is_verified !== undefined || isVerified !== undefined) {
        const rawType = (verification_type || verificationType || (is_verified || isVerified ? 'blue' : 'none')).toString().toLowerCase();
        updateData.isVerified = rawType !== 'none';
        updateData.verificationType = rawType.toUpperCase();
      }

      if (status !== undefined) {
        updateData.status = status;
        if (status === 'banned') {
          updateData.isBlocked = true;
        } else if (status === 'offline' || status === 'online') {
          updateData.isBlocked = false;
        }
      }

      const updatedUser = await prisma.user.update({
        where: { id: targetId },
        data: updateData,
      });

      return res.json({ success: true, data: updatedUser });
    } catch (error) {
      console.error('Error updating user:', error);
      return res.status(500).json({ error: 'Failed to update user' });
    }
  }

  if (req.method === 'DELETE') {
    try {
      await prisma.user.delete({ where: { id: targetId } });
      return res.json({ success: true });
    } catch (error) {
      return res.status(500).json({ error: 'Failed to delete user' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
});

/**
 * POST/PUT /api/users/profile - Profile update handler alias
 */
router.all('/profile', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  if (req.method === 'GET') {
    const user = await prisma.user.findUnique({ where: { id: req.user!.id } });
    return res.json({ success: true, data: user });
  }
  
  try {
    const {
      display_name, fullName, bio, avatar_url, avatarUrl, banner_url, bannerUrl, department, level, college,
      phone_number, phoneNumber, websiteUrl, website_url, facebookUrl, facebook_url, twitterUrl, twitter_url,
      instagramUrl, instagram_url, linkedinUrl, linkedin_url, tiktokUrl, tiktok_url, youtubeUrl, youtube_url,
      snapchatUrl, snapchat_url, githubUrl, github_url, twitchUrl, twitch_url,
    } = req.body;

    const updated = await prisma.user.update({
      where: { id: req.user!.id },
      data: {
        ...(fullName !== undefined && { fullName }),
        ...(display_name !== undefined && { fullName: display_name }),
        ...(bio !== undefined && { bio }),
        ...(avatarUrl !== undefined && { avatarUrl }),
        ...(avatar_url !== undefined && { avatarUrl: avatar_url }),
        ...(bannerUrl !== undefined && { bannerUrl }),
        ...(banner_url !== undefined && { bannerUrl: banner_url }),
        ...(department !== undefined && { department }),
        ...(level !== undefined && { level }),
        ...(college !== undefined && { college }),
        ...(phoneNumber !== undefined && { phoneNumber }),
        ...(phone_number !== undefined && { phoneNumber: phone_number }),
        ...(websiteUrl !== undefined && { websiteUrl }),
        ...(website_url !== undefined && { websiteUrl: website_url }),
        ...(facebookUrl !== undefined && { facebookUrl }),
        ...(facebook_url !== undefined && { facebookUrl: facebook_url }),
        ...(twitterUrl !== undefined && { twitterUrl }),
        ...(twitter_url !== undefined && { twitterUrl: twitter_url }),
        ...(instagramUrl !== undefined && { instagramUrl }),
        ...(instagram_url !== undefined && { instagramUrl: instagram_url }),
        ...(linkedinUrl !== undefined && { linkedinUrl }),
        ...(linkedin_url !== undefined && { linkedinUrl: linkedin_url }),
        ...(tiktokUrl !== undefined && { tiktokUrl }),
        ...(tiktok_url !== undefined && { tiktokUrl: tiktok_url }),
        ...(youtubeUrl !== undefined && { youtubeUrl }),
        ...(youtube_url !== undefined && { youtubeUrl: youtube_url }),
        ...(snapchatUrl !== undefined && { snapchatUrl }),
        ...(snapchat_url !== undefined && { snapchatUrl: snapchat_url }),
        ...(githubUrl !== undefined && { githubUrl }),
        ...(github_url !== undefined && { githubUrl: github_url }),
        ...(twitchUrl !== undefined && { twitchUrl }),
        ...(twitch_url !== undefined && { twitchUrl: twitch_url }),
      },
    });

    return res.json({ success: true, data: updated });
  } catch (error) {
    console.error('Profile update error:', error);
    return res.status(500).json({ error: 'Failed to update user profile' });
  }
});

/**
 * GET /api/users/profile/:id - Profile by ID alias
 */
router.get('/profile/:id', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: String(req.params.id) },
    });
    if (!user) return res.status(404).json({ error: 'User not found' });
    return res.json({ success: true, data: user });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to fetch user' });
  }
});

export default router;

