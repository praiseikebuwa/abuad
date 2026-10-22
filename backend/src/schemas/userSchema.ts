import { z } from 'zod';

/**
 * Reusable validation primitives
 */
const urlOrEmptyString = z
  .string()
  .trim()
  .url({ message: 'Must be a valid URL' })
  .or(z.literal(''))
  .nullable()
  .optional();

export const emailSchema = z
  .string({ required_error: 'Email is required' })
  .trim()
  .toLowerCase()
  .email({ message: 'Please provide a valid email address' });

export const usernameSchema = z
  .string({ required_error: 'Username is required' })
  .trim()
  .toLowerCase()
  .min(3, { message: 'Username must be at least 3 characters long' })
  .max(30, { message: 'Username cannot exceed 30 characters' })
  .regex(/^[a-zA-Z0-9_]+$/, {
    message: 'Username can only contain letters, numbers, and underscores',
  });

export const fullNameSchema = z
  .string({ required_error: 'Full name is required' })
  .trim()
  .min(2, { message: 'Full name must be at least 2 characters long' })
  .max(100, { message: 'Full name cannot exceed 100 characters' });

export const bioSchema = z
  .string()
  .trim()
  .max(500, { message: 'Bio cannot exceed 500 characters' })
  .nullable()
  .optional();

export const departmentSchema = z
  .string()
  .trim()
  .max(100, { message: 'Department name is too long' })
  .nullable()
  .optional();

export const collegeSchema = z
  .string()
  .trim()
  .max(100, { message: 'College name is too long' })
  .nullable()
  .optional();

export const levelSchema = z
  .string()
  .trim()
  .max(20, { message: 'Level is too long' })
  .nullable()
  .optional();

export const phoneNumberSchema = z
  .string()
  .trim()
  .regex(/^(\+?[0-9\s\-()]{7,20})?$/, {
    message: 'Please provide a valid phone number',
  })
  .or(z.literal(''))
  .nullable()
  .optional();

export const roleSchema = z.enum(['STUDENT', 'STAFF', 'ADMIN'], {
  errorMap: () => ({ message: 'Role must be STUDENT, STAFF, or ADMIN' }),
});

export const statusSchema = z.enum(['online', 'offline', 'away'], {
  errorMap: () => ({ message: 'Status must be online, offline, or away' }),
});

export const verificationTypeSchema = z.enum(['NONE', 'BLUE', 'GOLD'], {
  errorMap: () => ({ message: 'Verification type must be NONE, BLUE, or GOLD' }),
});

export const passwordSchema = z
  .string({ required_error: 'Password is required' })
  .min(8, { message: 'Password must be at least 8 characters long' })
  .max(128, { message: 'Password cannot exceed 128 characters' });

/**
 * Complete User Entity Schema (Matching Prisma User Model)
 */
export const userSchema = z.object({
  id: z.string().uuid({ message: 'Invalid user ID format' }).optional(),
  email: emailSchema,
  username: usernameSchema,
  fullName: fullNameSchema,
  bio: bioSchema,
  department: departmentSchema,
  college: collegeSchema,
  level: levelSchema,
  phoneNumber: phoneNumberSchema,
  avatarUrl: urlOrEmptyString,
  bannerUrl: urlOrEmptyString,
  role: roleSchema.default('STUDENT'),
  isVerified: z.boolean().default(false),
  verificationType: verificationTypeSchema.default('NONE'),
  isBlocked: z.boolean().default(false),
  isEmailVerified: z.boolean().default(false),
  followersCount: z.number().int().nonnegative().default(0),
  followingCount: z.number().int().nonnegative().default(0),
  status: statusSchema.default('offline'),
  lastSeen: z.coerce.date().nullable().optional(),
  streakCount: z.number().int().nonnegative().default(0),
  lastSnapAt: z.coerce.date().nullable().optional(),
  latitude: z.number().min(-90).max(90).nullable().optional(),
  longitude: z.number().min(-180).max(180).nullable().optional(),

  // Social Links
  websiteUrl: urlOrEmptyString,
  facebookUrl: urlOrEmptyString,
  twitterUrl: urlOrEmptyString,
  instagramUrl: urlOrEmptyString,
  linkedinUrl: urlOrEmptyString,
  whatsappUrl: z.string().trim().max(100).nullable().optional(),
  tiktokUrl: urlOrEmptyString,
  youtubeUrl: urlOrEmptyString,
  snapchatUrl: z.string().trim().max(100).nullable().optional(),
  githubUrl: urlOrEmptyString,
  twitchUrl: urlOrEmptyString,
  isFollowingVisible: z.boolean().default(true),

  createdAt: z.coerce.date().optional(),
  updatedAt: z.coerce.date().optional(),
});

/**
 * Registration Validation Schema
 */
export const registerUserSchema = z.object({
  email: emailSchema,
  password: passwordSchema,
  fullName: fullNameSchema,
  username: usernameSchema,
  department: departmentSchema,
  college: collegeSchema,
  level: levelSchema,
  phoneNumber: phoneNumberSchema,
});

/**
 * Login Validation Schema
 */
export const loginUserSchema = z.object({
  emailOrUsername: z
    .string({ required_error: 'Email or username is required' })
    .trim()
    .min(1, { message: 'Email or username cannot be empty' }),
  password: z
    .string({ required_error: 'Password is required' })
    .min(1, { message: 'Password cannot be empty' }),
});

/**
 * Profile Update Schema (All fields optional, supports camelCase & snake_case)
 */
export const updateUserProfileSchema = z
  .object({
    fullName: fullNameSchema.optional(),
    display_name: fullNameSchema.optional(),
    bio: bioSchema,
    department: departmentSchema,
    college: collegeSchema,
    level: levelSchema,
    phoneNumber: phoneNumberSchema,
    phone_number: phoneNumberSchema,
    avatarUrl: urlOrEmptyString,
    avatar_url: urlOrEmptyString,
    bannerUrl: urlOrEmptyString,
    banner_url: urlOrEmptyString,
    websiteUrl: urlOrEmptyString,
    website_url: urlOrEmptyString,
    facebookUrl: urlOrEmptyString,
    facebook_url: urlOrEmptyString,
    twitterUrl: urlOrEmptyString,
    twitter_url: urlOrEmptyString,
    instagramUrl: urlOrEmptyString,
    instagram_url: urlOrEmptyString,
    linkedinUrl: urlOrEmptyString,
    linkedin_url: urlOrEmptyString,
    whatsappUrl: z.string().trim().max(100).nullable().optional(),
    whatsapp_url: z.string().trim().max(100).nullable().optional(),
    tiktokUrl: urlOrEmptyString,
    tiktok_url: urlOrEmptyString,
    youtubeUrl: urlOrEmptyString,
    youtube_url: urlOrEmptyString,
    snapchatUrl: z.string().trim().max(100).nullable().optional(),
    snapchat_url: z.string().trim().max(100).nullable().optional(),
    githubUrl: urlOrEmptyString,
    github_url: urlOrEmptyString,
    twitchUrl: urlOrEmptyString,
    twitch_url: urlOrEmptyString,
  })
  .strict();

/**
 * Status Update Schema
 */
export const updateUserStatusSchema = z.object({
  status: statusSchema,
});

/**
 * Inferred TypeScript Types
 */
export type UserSchemaType = z.infer<typeof userSchema>;
export type RegisterUserInput = z.infer<typeof registerUserSchema>;
export type LoginUserInput = z.infer<typeof loginUserSchema>;
export type UpdateUserProfileInput = z.infer<typeof updateUserProfileSchema>;
export type UpdateUserStatusInput = z.infer<typeof updateUserStatusSchema>;
