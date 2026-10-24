"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.updateUserStatusSchema = exports.updateUserProfileSchema = exports.loginUserSchema = exports.registerUserSchema = exports.userSchema = exports.passwordSchema = exports.verificationTypeSchema = exports.statusSchema = exports.roleSchema = exports.phoneNumberSchema = exports.levelSchema = exports.collegeSchema = exports.departmentSchema = exports.bioSchema = exports.fullNameSchema = exports.usernameSchema = exports.emailSchema = void 0;
const zod_1 = require("zod");
/**
 * Reusable validation primitives
 */
const urlOrEmptyString = zod_1.z
    .string()
    .trim()
    .url({ message: 'Must be a valid URL' })
    .or(zod_1.z.literal(''))
    .nullable()
    .optional();
exports.emailSchema = zod_1.z
    .string({ required_error: 'Email is required' })
    .trim()
    .toLowerCase()
    .email({ message: 'Please provide a valid email address' });
exports.usernameSchema = zod_1.z
    .string({ required_error: 'Username is required' })
    .trim()
    .toLowerCase()
    .min(3, { message: 'Username must be at least 3 characters long' })
    .max(30, { message: 'Username cannot exceed 30 characters' })
    .regex(/^[a-zA-Z0-9_]+$/, {
    message: 'Username can only contain letters, numbers, and underscores',
});
exports.fullNameSchema = zod_1.z
    .string({ required_error: 'Full name is required' })
    .trim()
    .min(2, { message: 'Full name must be at least 2 characters long' })
    .max(100, { message: 'Full name cannot exceed 100 characters' });
exports.bioSchema = zod_1.z
    .string()
    .trim()
    .max(500, { message: 'Bio cannot exceed 500 characters' })
    .nullable()
    .optional();
exports.departmentSchema = zod_1.z
    .string()
    .trim()
    .max(100, { message: 'Department name is too long' })
    .nullable()
    .optional();
exports.collegeSchema = zod_1.z
    .string()
    .trim()
    .max(100, { message: 'College name is too long' })
    .nullable()
    .optional();
exports.levelSchema = zod_1.z
    .string()
    .trim()
    .max(20, { message: 'Level is too long' })
    .nullable()
    .optional();
exports.phoneNumberSchema = zod_1.z
    .string()
    .trim()
    .regex(/^(\+?[0-9\s\-()]{7,20})?$/, {
    message: 'Please provide a valid phone number',
})
    .or(zod_1.z.literal(''))
    .nullable()
    .optional();
exports.roleSchema = zod_1.z.enum(['STUDENT', 'STAFF', 'ADMIN'], {
    errorMap: () => ({ message: 'Role must be STUDENT, STAFF, or ADMIN' }),
});
exports.statusSchema = zod_1.z.enum(['online', 'offline', 'away'], {
    errorMap: () => ({ message: 'Status must be online, offline, or away' }),
});
exports.verificationTypeSchema = zod_1.z.enum(['NONE', 'BLUE', 'GOLD'], {
    errorMap: () => ({ message: 'Verification type must be NONE, BLUE, or GOLD' }),
});
exports.passwordSchema = zod_1.z
    .string({ required_error: 'Password is required' })
    .min(8, { message: 'Password must be at least 8 characters long' })
    .max(128, { message: 'Password cannot exceed 128 characters' });
/**
 * Complete User Entity Schema (Matching Prisma User Model)
 */
exports.userSchema = zod_1.z.object({
    id: zod_1.z.string().uuid({ message: 'Invalid user ID format' }).optional(),
    email: exports.emailSchema,
    username: exports.usernameSchema,
    fullName: exports.fullNameSchema,
    bio: exports.bioSchema,
    department: exports.departmentSchema,
    college: exports.collegeSchema,
    level: exports.levelSchema,
    phoneNumber: exports.phoneNumberSchema,
    avatarUrl: urlOrEmptyString,
    bannerUrl: urlOrEmptyString,
    role: exports.roleSchema.default('STUDENT'),
    isVerified: zod_1.z.boolean().default(false),
    verificationType: exports.verificationTypeSchema.default('NONE'),
    isBlocked: zod_1.z.boolean().default(false),
    isEmailVerified: zod_1.z.boolean().default(false),
    followersCount: zod_1.z.number().int().nonnegative().default(0),
    followingCount: zod_1.z.number().int().nonnegative().default(0),
    status: exports.statusSchema.default('offline'),
    lastSeen: zod_1.z.coerce.date().nullable().optional(),
    streakCount: zod_1.z.number().int().nonnegative().default(0),
    lastSnapAt: zod_1.z.coerce.date().nullable().optional(),
    latitude: zod_1.z.number().min(-90).max(90).nullable().optional(),
    longitude: zod_1.z.number().min(-180).max(180).nullable().optional(),
    // Social Links
    websiteUrl: urlOrEmptyString,
    facebookUrl: urlOrEmptyString,
    twitterUrl: urlOrEmptyString,
    instagramUrl: urlOrEmptyString,
    linkedinUrl: urlOrEmptyString,
    whatsappUrl: zod_1.z.string().trim().max(100).nullable().optional(),
    tiktokUrl: urlOrEmptyString,
    youtubeUrl: urlOrEmptyString,
    snapchatUrl: zod_1.z.string().trim().max(100).nullable().optional(),
    githubUrl: urlOrEmptyString,
    twitchUrl: urlOrEmptyString,
    isFollowingVisible: zod_1.z.boolean().default(true),
    createdAt: zod_1.z.coerce.date().optional(),
    updatedAt: zod_1.z.coerce.date().optional(),
});
/**
 * Registration Validation Schema
 */
exports.registerUserSchema = zod_1.z.object({
    email: exports.emailSchema,
    password: exports.passwordSchema,
    fullName: exports.fullNameSchema,
    username: exports.usernameSchema,
    department: exports.departmentSchema,
    college: exports.collegeSchema,
    level: exports.levelSchema,
    phoneNumber: exports.phoneNumberSchema,
});
/**
 * Login Validation Schema
 */
exports.loginUserSchema = zod_1.z.object({
    emailOrUsername: zod_1.z
        .string({ required_error: 'Email or username is required' })
        .trim()
        .min(1, { message: 'Email or username cannot be empty' }),
    password: zod_1.z
        .string({ required_error: 'Password is required' })
        .min(1, { message: 'Password cannot be empty' }),
});
/**
 * Profile Update Schema (All fields optional, supports camelCase & snake_case)
 */
exports.updateUserProfileSchema = zod_1.z
    .object({
    fullName: exports.fullNameSchema.optional(),
    display_name: exports.fullNameSchema.optional(),
    bio: exports.bioSchema,
    department: exports.departmentSchema,
    college: exports.collegeSchema,
    level: exports.levelSchema,
    phoneNumber: exports.phoneNumberSchema,
    phone_number: exports.phoneNumberSchema,
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
    whatsappUrl: zod_1.z.string().trim().max(100).nullable().optional(),
    whatsapp_url: zod_1.z.string().trim().max(100).nullable().optional(),
    tiktokUrl: urlOrEmptyString,
    tiktok_url: urlOrEmptyString,
    youtubeUrl: urlOrEmptyString,
    youtube_url: urlOrEmptyString,
    snapchatUrl: zod_1.z.string().trim().max(100).nullable().optional(),
    snapchat_url: zod_1.z.string().trim().max(100).nullable().optional(),
    githubUrl: urlOrEmptyString,
    github_url: urlOrEmptyString,
    twitchUrl: urlOrEmptyString,
    twitch_url: urlOrEmptyString,
})
    .strict();
/**
 * Status Update Schema
 */
exports.updateUserStatusSchema = zod_1.z.object({
    status: exports.statusSchema,
});
