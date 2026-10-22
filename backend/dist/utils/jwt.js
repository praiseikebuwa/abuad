"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateAccessToken = generateAccessToken;
exports.generateRefreshToken = generateRefreshToken;
exports.verifyAccessToken = verifyAccessToken;
exports.verifyRefreshToken = verifyRefreshToken;
exports.hashToken = hashToken;
exports.compareToken = compareToken;
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const bcryptjs_1 = __importDefault(require("bcryptjs"));
const ACCESS_SECRET = process.env.JWT_ACCESS_SECRET || 'fallback-access-secret';
const REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'fallback-refresh-secret';
/**
 * Generate Access Token (long-lived e.g. 30 days for persistent campus app session)
 */
function generateAccessToken(payload) {
    return jsonwebtoken_1.default.sign(payload, ACCESS_SECRET, { expiresIn: '30d' });
}
/**
 * Generate Refresh Token (long-lived e.g. 180 days)
 */
function generateRefreshToken(payload) {
    return jsonwebtoken_1.default.sign(payload, REFRESH_SECRET, { expiresIn: '180d' });
}
/**
 * Verify Access Token
 */
function verifyAccessToken(token) {
    return jsonwebtoken_1.default.verify(token, ACCESS_SECRET);
}
/**
 * Verify Refresh Token
 */
function verifyRefreshToken(token) {
    return jsonwebtoken_1.default.verify(token, REFRESH_SECRET);
}
/**
 * Hash raw token for secure DB storage
 */
async function hashToken(token) {
    return bcryptjs_1.default.hash(token, 10);
}
/**
 * Compare raw token against hashed token
 */
async function compareToken(rawToken, hashedToken) {
    return bcryptjs_1.default.compare(rawToken, hashedToken);
}
