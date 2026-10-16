import { Router, Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import { prisma } from '../config/db';
import { authenticateToken, AuthenticatedRequest } from '../middleware/auth';
import { loginLimiter, registerLimiter, passwordResetLimiter } from '../middleware/rateLimiter';
import { sendPasswordResetEmail } from '../services/emailService';
import {
  generateAccessToken,
  generateRefreshToken,
  verifyRefreshToken,
  hashToken,
  compareToken,
} from '../utils/jwt';

const router = Router();

const sha256 = (value: string) => crypto.createHash('sha256').update(value).digest('hex');
const PUBLIC_API_URL = () => (process.env.PUBLIC_API_URL || 'https://api.abuadapp.com.ng').replace(/\/$/, '');

// Helper to set HTTP-only refresh token cookie
function setRefreshTokenCookie(res: Response, refreshToken: string) {
  res.cookie('refreshToken', refreshToken, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
    maxAge: 7 * 24 * 60 * 60 * 1000, // 7 Days
  });
}

/**
 * POST /api/auth/register
 */
router.post('/register', registerLimiter, async (req: Request, res: Response) => {
  try {
    const { email, password, fullName, username, department, level, phoneNumber } = req.body;

    if (!email || !password || !fullName || !username) {
      return res.status(400).json({ error: 'Email, password, fullName, and username are required' });
    }

    const existingUser = await prisma.user.findFirst({
      where: {
        OR: [{ email }, { username }],
      },
    });

    if (existingUser) {
      return res.status(400).json({ error: 'Email or Username is already registered' });
    }

    const passwordHash = await bcrypt.hash(password, 12);
    const emailVerificationToken = crypto.randomBytes(32).toString('hex');

    const user = await prisma.user.create({
      data: {
        email,
        passwordHash,
        fullName,
        username,
        department,
        level,
        phoneNumber,
        emailVerificationToken,
      },
    });

    const payload = { userId: user.id, email: user.email, role: user.role };
    const accessToken = generateAccessToken(payload);
    const refreshToken = generateRefreshToken(payload);

    const refreshTokenHash = await hashToken(refreshToken);
    await prisma.user.update({
      where: { id: user.id },
      data: { refreshTokenHash },
    });

    setRefreshTokenCookie(res, refreshToken);

    return res.status(201).json({
      success: true,
      data: {
        accessToken,
        refreshToken,
        user: {
          id: user.id,
          email: user.email,
          fullName: user.fullName,
          username: user.username,
          role: user.role,
        },
      },
    });
  } catch (error) {
    console.error('Registration error:', error);
    return res.status(500).json({ error: 'Failed to register user' });
  }
});

/**
 * POST /api/auth/login
 */
router.post('/login', loginLimiter, async (req: Request, res: Response) => {
  try {
    const { emailOrUsername, password } = req.body;

    if (!emailOrUsername || !password) {
      return res.status(400).json({ error: 'Email/Username and password are required' });
    }

    const user = await prisma.user.findFirst({
      where: {
        OR: [{ email: emailOrUsername }, { username: emailOrUsername }],
      },
    });

    if (!user) {
      return res.status(401).json({ error: 'Invalid email/username or password' });
    }

    const isValidPassword = await bcrypt.compare(password, user.passwordHash);
    if (!isValidPassword) {
      return res.status(401).json({ error: 'Invalid email/username or password' });
    }

    if (user.isBlocked) {
      return res.status(403).json({ error: 'Account has been suspended' });
    }

    const payload = { userId: user.id, email: user.email, role: user.role };
    const accessToken = generateAccessToken(payload);
    const refreshToken = generateRefreshToken(payload);

    const refreshTokenHash = await hashToken(refreshToken);
    await prisma.user.update({
      where: { id: user.id },
      data: { refreshTokenHash },
    });

    setRefreshTokenCookie(res, refreshToken);

    return res.json({
      success: true,
      data: {
        accessToken,
        refreshToken, // Returned for mobile client storage if cookies are not used
        user: {
          id: user.id,
          email: user.email,
          fullName: user.fullName,
          username: user.username,
          role: user.role,
          avatarUrl: user.avatarUrl,
          college: user.college,
          department: user.department,
          phoneNumber: user.phoneNumber,
          bio: user.bio,
        },
      },
    });
  } catch (error) {
    console.error('Login error:', error);
    return res.status(500).json({ error: 'Failed to authenticate user' });
  }
});

/**
interface RotationCacheEntry {
  previousTokenHash: string;
  newAccessToken: string;
  newRefreshToken: string;
  expiresAt: number;
}
const rotationGraceCache = new Map<string, RotationCacheEntry>();

/**
 * POST /api/auth/refresh (Rotating Refresh Token with Concurrent Grace Window)
 */
router.post('/refresh', async (req: Request, res: Response) => {
  try {
    const rawRefreshToken = req.cookies?.refreshToken || req.body?.refreshToken;

    if (!rawRefreshToken) {
      return res.status(401).json({ error: 'Refresh token required' });
    }

    const payload = verifyRefreshToken(rawRefreshToken);
    const user = await prisma.user.findUnique({
      where: { id: payload.userId },
    });

    if (!user) {
      return res.status(401).json({ error: 'User not found' });
    }

    // 1. Check if this is a concurrent request within the 30s grace window
    const graceEntry = rotationGraceCache.get(user.id);
    if (graceEntry && graceEntry.expiresAt > Date.now()) {
      const matchesPrevious = await compareToken(rawRefreshToken, graceEntry.previousTokenHash);
      if (matchesPrevious) {
        setRefreshTokenCookie(res, graceEntry.newRefreshToken);
        return res.json({
          success: true,
          data: {
            accessToken: graceEntry.newAccessToken,
            refreshToken: graceEntry.newRefreshToken,
          },
        });
      }
    }

    if (!user.refreshTokenHash) {
      return res.status(401).json({ error: 'Invalid refresh token session' });
    }

    const isValid = await compareToken(rawRefreshToken, user.refreshTokenHash);
    if (!isValid) {
      return res.status(401).json({ error: 'Invalid or outdated refresh token' });
    }

    // Rotate tokens: Issue NEW access token and NEW refresh token
    const newPayload = { userId: user.id, email: user.email, role: user.role };
    const newAccessToken = generateAccessToken(newPayload);
    const newRefreshToken = generateRefreshToken(newPayload);

    const oldHash = user.refreshTokenHash;
    const newRefreshTokenHash = await hashToken(newRefreshToken);

    await prisma.user.update({
      where: { id: user.id },
      data: { refreshTokenHash: newRefreshTokenHash },
    });

    // Store in grace cache for 30 seconds
    rotationGraceCache.set(user.id, {
      previousTokenHash: oldHash,
      newAccessToken,
      newRefreshToken,
      expiresAt: Date.now() + 30 * 1000,
    });

    setRefreshTokenCookie(res, newRefreshToken);

    return res.json({
      success: true,
      data: {
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      },
    });
  } catch (error) {
    return res.status(401).json({ error: 'Invalid or expired refresh token' });
  }
});

/**
 * POST /api/auth/logout
 */
router.post('/logout', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    await prisma.user.update({
      where: { id: req.user!.id },
      data: { refreshTokenHash: null },
    });

    res.clearCookie('refreshToken');
    return res.json({ success: true, message: 'Successfully logged out' });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to logout' });
  }
});

/**
 * GET /api/auth/me
 */
router.get('/me', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user!.id },
      select: {
        id: true,
        email: true,
        fullName: true,
        username: true,
        bio: true,
        avatarUrl: true,
        bannerUrl: true,
        department: true,
        college: true,
        level: true,
        phoneNumber: true,
        role: true,
        isVerified: true,
        isEmailVerified: true,
        followersCount: true,
        followingCount: true,
        createdAt: true,
      },
    });
    return res.json({ success: true, data: user });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to fetch user profile' });
  }
});

/**
 * POST /api/auth/forgot-password
 */
router.post('/forgot-password', passwordResetLimiter, async (req: Request, res: Response) => {
  const genericResponse = { success: true, message: 'If an account exists for that email, a reset link has been sent.' };
  try {
    const email = String(req.body?.email || '').trim().toLowerCase();
    if (!email) return res.status(400).json({ error: 'Email is required' });

    const user = await prisma.user.findFirst({ where: { email: { equals: email, mode: 'insensitive' } } });
    if (!user) {
      // Do not reveal email existence for security
      return res.json(genericResponse);
    }

    const rawToken = crypto.randomBytes(32).toString('hex');
    const passwordResetExpires = new Date(Date.now() + 60 * 60 * 1000); // 1 hour

    // Only the hash is stored; the raw token lives only in the email link
    await prisma.user.update({
      where: { id: user.id },
      data: {
        passwordResetToken: sha256(rawToken),
        passwordResetExpires,
      },
    });

    const resetUrl = `${PUBLIC_API_URL()}/reset-password?token=${rawToken}`;
    console.log(`🔑 [PASSWORD_RESET] Generated reset link for ${user.email}: ${resetUrl}`);
    try {
      await sendPasswordResetEmail(user.email, user.fullName, resetUrl);
    } catch (mailError: any) {
      console.error('Password reset email failed:', mailError);
      return res.status(502).json({
        error: 'Could not deliver reset email. ' + (mailError?.message || 'Please check email service configuration.'),
      });
    }

    return res.json(genericResponse);
  } catch (error) {
    console.error('Forgot password error:', error);
    return res.status(500).json({ error: 'Failed to initiate password reset' });
  }
});

/**
 * POST /api/auth/reset-password
 */
router.post('/reset-password', async (req: Request, res: Response) => {
  try {
    const { resetToken, newPassword } = req.body;
    if (!resetToken || !newPassword) {
      return res.status(400).json({ error: 'Reset token and new password are required' });
    }
    if (typeof newPassword !== 'string' || newPassword.length < 8) {
      return res.status(400).json({ error: 'Password must be at least 8 characters' });
    }

    const user = await prisma.user.findFirst({
      where: {
        passwordResetToken: sha256(String(resetToken)),
        passwordResetExpires: { gt: new Date() },
      },
    });

    if (!user) {
      return res.status(400).json({ error: 'Invalid or expired password reset token' });
    }

    const passwordHash = await bcrypt.hash(newPassword, 12);

    await prisma.user.update({
      where: { id: user.id },
      data: {
        passwordHash,
        passwordResetToken: null,
        passwordResetExpires: null,
        refreshTokenHash: null, // Invalidate existing sessions
      },
    });

    return res.json({ success: true, message: 'Password successfully reset' });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to reset password' });
  }
});

/**
 * POST /api/auth/sync
 * Sync user presence/lifecycle status
 */
router.post('/sync', async (req: Request, res: Response) => {
  return res.json({ success: true });
});

export default router;

