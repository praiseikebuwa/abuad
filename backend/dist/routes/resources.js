"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const auth_1 = require("../middleware/auth");
const db_1 = require("../config/db");
const cloudflare_1 = require("../config/cloudflare");
const client_s3_1 = require("@aws-sdk/client-s3");
const multer_1 = __importDefault(require("multer"));
const router = (0, express_1.Router)();
const upload = (0, multer_1.default)({
    storage: multer_1.default.memoryStorage(),
    limits: { fileSize: 100 * 1024 * 1024 }, // 100MB per file
});
function buildPublicUrl(req, key) {
    if (cloudflare_1.r2PublicDomain && cloudflare_1.r2PublicDomain.trim().length > 0) {
        const domain = cloudflare_1.r2PublicDomain.replace(/\/+$/, '');
        return `${domain}/${key}`;
    }
    const host = req.get('host') || 'localhost:5000';
    const isLocal = host.includes('localhost') || host.includes('127.0.0.1');
    const protocol = isLocal ? (req.protocol || 'http') : 'https';
    return `${protocol}://${host}/api/media/file/${key}`;
}
// Standard ABUAD academic courses across colleges
const DEFAULT_COURSES = [
    { code: 'GST 111', title: 'Use of English', level: '100', department: 'General Studies' },
    { code: 'GST 112', title: 'Logic, Philosophy & Human Existence', level: '100', department: 'General Studies' },
    { code: 'GST 113', title: 'Nigerian Peoples & Culture', level: '100', department: 'General Studies' },
    { code: 'GST 211', title: 'Peace & Conflict Resolution', level: '200', department: 'General Studies' },
    { code: 'GST 212', title: 'Philosophy, Logic & Human Existence II', level: '200', department: 'General Studies' },
    { code: 'MTH 101', title: 'Elementary Mathematics I', level: '100', department: 'Sciences' },
    { code: 'MTH 102', title: 'Elementary Mathematics II', level: '100', department: 'Sciences' },
    { code: 'CHM 101', title: 'General Chemistry I', level: '100', department: 'Sciences' },
    { code: 'CHM 102', title: 'General Chemistry II', level: '100', department: 'Sciences' },
    { code: 'PHY 101', title: 'General Physics I (Mechanics & Heat)', level: '100', department: 'Sciences' },
    { code: 'PHY 102', title: 'General Physics II (Electricity & Optics)', level: '100', department: 'Sciences' },
    { code: 'BIO 101', title: 'General Biology I', level: '100', department: 'Sciences' },
    { code: 'CSC 101', title: 'Introduction to Computer Science', level: '100', department: 'Computing' },
    { code: 'CSC 201', title: 'Computer Programming I', level: '200', department: 'Computing' },
    { code: 'CSC 205', title: 'Data Structures & Algorithms', level: '200', department: 'Computing' },
    { code: 'ENG 281', title: 'Engineering Mathematics I', level: '200', department: 'Engineering' },
    { code: 'ENG 284', title: 'Engineering Mechanics', level: '200', department: 'Engineering' },
    { code: 'LAW 101', title: 'Legal Method I', level: '100', department: 'Law' },
    { code: 'LAW 102', title: 'Nigerian Legal System', level: '100', department: 'Law' },
    { code: 'ANA 201', title: 'Gross Anatomy of Upper Limb', level: '200', department: 'Medicine' },
    { code: 'PHS 201', title: 'Introductory Physiology', level: '200', department: 'Medicine' },
];
/**
 * Format resource helper to extract course code, level, downloads, and metadata
 */
function formatResource(res) {
    let level = '100';
    let courseCode = res.category || 'General';
    let downloads = 0;
    let fileType = 'document';
    if (res.description) {
        try {
            if (res.description.startsWith('{')) {
                const meta = JSON.parse(res.description);
                if (meta.level)
                    level = String(meta.level);
                if (meta.courseCode)
                    courseCode = String(meta.courseCode);
                if (meta.downloads)
                    downloads = Number(meta.downloads);
                if (meta.fileType)
                    fileType = String(meta.fileType);
            }
            else {
                const lvlMatch = res.description.match(/level[:\s]+(\d+)/i);
                if (lvlMatch)
                    level = lvlMatch[1];
                const codeMatch = res.description.match(/course[:\s]+([A-Z]{3}\s*\d{3})/i);
                if (codeMatch)
                    courseCode = codeMatch[1].toUpperCase();
            }
        }
        catch (_) { }
    }
    const codeNumMatch = courseCode.match(/\b([1-5])\d{2}\b/);
    if (codeNumMatch) {
        level = `${codeNumMatch[1]}00`;
    }
    if (res.fileUrl) {
        const ext = res.fileUrl.split('.').pop()?.toLowerCase();
        if (ext === 'pdf')
            fileType = 'pdf';
        else if (['doc', 'docx'].includes(ext || ''))
            fileType = 'word';
        else if (['ppt', 'pptx'].includes(ext || ''))
            fileType = 'presentation';
        else if (['jpg', 'jpeg', 'png', 'webp'].includes(ext || ''))
            fileType = 'image';
    }
    return {
        id: res.id,
        title: res.title,
        description: res.description,
        category: courseCode,
        courseCode,
        level,
        fileUrl: res.fileUrl,
        url: res.fileUrl,
        fileType,
        downloads,
        uploaderId: res.uploaderId,
        uploaderName: res.uploader?.fullName || 'Admin',
        created_at: res.createdAt.toISOString(),
        timestamp: res.createdAt.toISOString(),
    };
}
/**
 * GET /api/resources
 * Fetch academic resources with optional filtering by level, category, search
 */
router.get('/', auth_1.optionalAuth, async (req, res) => {
    try {
        const { level, category, courseCode, search } = req.query;
        const where = {};
        if (category && category !== 'All') {
            where.category = { contains: String(category), mode: 'insensitive' };
        }
        if (courseCode && courseCode !== 'All') {
            where.category = { contains: String(courseCode), mode: 'insensitive' };
        }
        if (search && String(search).trim()) {
            where.OR = [
                { title: { contains: String(search).trim(), mode: 'insensitive' } },
                { description: { contains: String(search).trim(), mode: 'insensitive' } },
                { category: { contains: String(search).trim(), mode: 'insensitive' } },
            ];
        }
        const resources = await db_1.prisma.resource.findMany({
            where,
            orderBy: { createdAt: 'desc' },
            include: {
                uploader: {
                    select: { id: true, fullName: true, username: true, role: true },
                },
            },
            take: 200,
        });
        let formatted = resources.map(formatResource);
        if (level && level !== 'All') {
            const cleanLevel = String(level).replace(/L$/i, '').trim();
            formatted = formatted.filter((r) => r.level.startsWith(cleanLevel) || cleanLevel.startsWith(r.level));
        }
        return res.json({
            success: true,
            data: formatted,
            count: formatted.length,
        });
    }
    catch (error) {
        console.error('Error fetching resources:', error);
        return res.status(500).json({ success: false, error: 'Failed to fetch resources' });
    }
});
/**
 * GET /api/resources/courses
 * List all academic courses available for CBT & study, merging predefined courses and uploaded resources
 */
router.get('/courses', auth_1.optionalAuth, async (_req, res) => {
    try {
        const dbResources = await db_1.prisma.resource.findMany({
            select: { category: true, title: true, description: true },
        });
        const coursesMap = new Map();
        for (const c of DEFAULT_COURSES) {
            coursesMap.set(c.code.toUpperCase(), { ...c, resourceCount: 0 });
        }
        for (const r of dbResources) {
            const code = (r.category || '').toUpperCase().trim();
            if (code && code.length >= 6) {
                if (coursesMap.has(code)) {
                    const item = coursesMap.get(code);
                    item.resourceCount = (item.resourceCount || 0) + 1;
                }
                else {
                    coursesMap.set(code, {
                        code,
                        title: r.title,
                        level: '100',
                        department: 'General',
                        resourceCount: 1,
                    });
                }
            }
        }
        return res.json({
            success: true,
            data: Array.from(coursesMap.values()),
        });
    }
    catch (error) {
        console.error('Error fetching courses:', error);
        return res.json({ success: true, data: DEFAULT_COURSES });
    }
});
/**
 * POST /api/resources
 * Create a single resource (supports link or manual fileUrl)
 */
router.post('/', auth_1.authenticateToken, async (req, res) => {
    try {
        const { title, category, courseCode, fileUrl, url, level, description } = req.body;
        const activeUrl = fileUrl || url;
        if (!title || !activeUrl) {
            return res.status(400).json({ success: false, error: 'Title and fileUrl are required' });
        }
        const finalCategory = (courseCode || category || 'General').toUpperCase().trim();
        const metaObj = {
            level: level || '100',
            courseCode: finalCategory,
            downloads: 0,
            description: description || '',
        };
        const newResource = await db_1.prisma.resource.create({
            data: {
                title: String(title).trim(),
                category: finalCategory,
                fileUrl: String(activeUrl).trim(),
                description: JSON.stringify(metaObj),
                uploaderId: req.user.id,
            },
            include: {
                uploader: { select: { fullName: true, username: true } },
            },
        });
        return res.status(201).json({
            success: true,
            data: formatResource(newResource),
        });
    }
    catch (error) {
        console.error('Error creating resource:', error);
        return res.status(500).json({ success: false, error: 'Failed to create resource' });
    }
});
/**
 * POST /api/resources/upload-multiple
 * Upload one or multiple files directly to Cloudflare R2 and create resource entries
 */
router.post('/upload-multiple', auth_1.authenticateToken, upload.array('files', 15), async (req, res) => {
    try {
        const files = req.files;
        const { category, courseCode, level, description } = req.body;
        if (!files || files.length === 0) {
            return res.status(400).json({ success: false, error: 'No files uploaded. Provide files in form-data field "files".' });
        }
        const finalCategory = (courseCode || category || 'General').toUpperCase().trim();
        const finalLevel = level || '100';
        const uploadedResources = [];
        for (const file of files) {
            const safeName = file.originalname.replace(/[^a-zA-Z0-9._-]/g, '_');
            const key = `resources/${req.user.id}/${Date.now()}-${safeName}`;
            // Upload to Cloudflare R2
            await cloudflare_1.r2Client.send(new client_s3_1.PutObjectCommand({
                Bucket: cloudflare_1.r2BucketName,
                Key: key,
                Body: file.buffer,
                ContentType: file.mimetype || 'application/pdf',
            }));
            const publicUrl = buildPublicUrl(req, key);
            const cleanTitle = file.originalname.replace(/\.[^/.]+$/, '').replace(/[-_]/g, ' ');
            const metaObj = {
                level: finalLevel,
                courseCode: finalCategory,
                downloads: 0,
                description: description || '',
                fileSize: file.size,
                mimeType: file.mimetype,
            };
            const record = await db_1.prisma.resource.create({
                data: {
                    title: cleanTitle,
                    category: finalCategory,
                    fileUrl: publicUrl,
                    description: JSON.stringify(metaObj),
                    uploaderId: req.user.id,
                },
                include: {
                    uploader: { select: { fullName: true, username: true } },
                },
            });
            uploadedResources.push(formatResource(record));
        }
        return res.status(201).json({
            success: true,
            data: uploadedResources,
            count: uploadedResources.length,
            message: `Successfully uploaded and saved ${uploadedResources.length} resource${uploadedResources.length > 1 ? 's' : ''}.`,
        });
    }
    catch (error) {
        console.error('Error in upload-multiple resources:', error);
        return res.status(500).json({ success: false, error: 'Failed to upload resources: ' + error.message });
    }
});
/**
 * DELETE /api/resources/:id
 * Delete resource from database and storage
 */
router.delete('/:id', auth_1.authenticateToken, async (req, res) => {
    try {
        const { id } = req.params;
        const resource = await db_1.prisma.resource.findUnique({
            where: { id: String(id) },
        });
        if (!resource) {
            return res.status(404).json({ success: false, error: 'Resource not found' });
        }
        const isAdmin = req.user?.role?.toUpperCase() === 'ADMIN';
        if (!isAdmin && resource.uploaderId !== req.user.id) {
            return res.status(403).json({ success: false, error: 'Unauthorized to delete this resource' });
        }
        const key = (0, cloudflare_1.extractR2Key)(resource.fileUrl);
        if (key) {
            try {
                await cloudflare_1.r2Client.send(new client_s3_1.DeleteObjectCommand({
                    Bucket: cloudflare_1.r2BucketName,
                    Key: key,
                }));
            }
            catch (r2Err) {
                console.warn('Could not delete R2 object:', r2Err);
            }
        }
        await db_1.prisma.resource.delete({
            where: { id: String(id) },
        });
        return res.json({ success: true, message: 'Resource deleted successfully' });
    }
    catch (error) {
        console.error('Error deleting resource:', error);
        return res.status(500).json({ success: false, error: 'Failed to delete resource' });
    }
});
exports.default = router;
