import rateLimit from 'express-rate-limit';

/**
 * Strict Rate Limiter for Login and Sensitive Auth Endpoints
 */
export const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes window
  max: 5, // Limit each IP to 5 failed login attempts per windowMs
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    error: 'Too many authentication attempts from this IP, please try again after 15 minutes.',
  },
});

/**
 * Rate Limiter for Registration
 */
export const registerLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour window
  max: 10, // Limit each IP to 10 user registrations per hour
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    error: 'Too many accounts created from this IP, please try again later.',
  },
});

/**
 * Rate Limiter for password reset emails (protects SMTP quota from abuse)
 */
export const passwordResetLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    error: 'Too many password reset requests. Please try again in 15 minutes.',
  },
});
