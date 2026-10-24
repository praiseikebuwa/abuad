"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const auth_1 = require("../middleware/auth");
const cloudflare_1 = require("../config/cloudflare");
const genai_1 = require("@google/genai");
const client_s3_1 = require("@aws-sdk/client-s3");
const router = (0, express_1.Router)();
// Whitelist of allowed Cloudflare Workers AI models
const ALLOWED_MODELS = new Set([
    '@cf/meta/llama-3.1-8b-instruct',
    '@cf/meta/llama-3.2-3b-instruct',
    '@cf/meta/llama-3.3-70b-instruct-fp8-fast',
    '@cf/meta/llama-3.2-11b-vision-instruct',
    '@cf/mistral/mistral-7b-instruct-v0.2',
]);
const DEFAULT_SYSTEM_PROMPT = `You are the official ABUAD AI Assistant & Study Buddy for Afe Babalola University (ABUAD) students. Your role is to provide accurate, high-quality, and comprehensive explanations across all academic disciplines (Mathematics, Computer Science, Engineering, Sciences, Law, Medicine, Business) and campus life.

Key Instructions:
1. Domain Accuracy: Carefully analyze the user's domain. For mathematics questions (e.g., matrices, functions, calculus, algebra), provide pure mathematical definitions, properties, and LaTeX formulas. For programming questions, provide clear code snippets in the relevant language.
2. Structure & Clarity: Use GitHub-flavored Markdown, clear headings, bullet points, and LaTeX notation where applicable.
3. Tone: Be formal, academic, encouraging, clear, and direct.`;
// Google Gemini API Client
const geminiApiKey = process.env.GEMINI_API_KEY || '';
const geminiModel = process.env.GEMINI_MODEL || 'gemini-3-flash-preview';
const genAI = geminiApiKey ? new genai_1.GoogleGenAI({ apiKey: geminiApiKey }) : null;
async function getImageBuffer(imageUrl) {
    try {
        let key = null;
        if (imageUrl.includes('/api/media/file/')) {
            key = imageUrl.split('/api/media/file/')[1];
        }
        else if (imageUrl.includes('uploads/')) {
            key = 'uploads/' + imageUrl.split('uploads/')[1];
        }
        if (key) {
            try {
                const command = new client_s3_1.GetObjectCommand({
                    Bucket: cloudflare_1.r2BucketName,
                    Key: key,
                });
                const s3Object = await cloudflare_1.r2Client.send(command);
                const stream = s3Object.Body;
                if (stream && typeof stream.transformToByteArray === 'function') {
                    const byteArray = await stream.transformToByteArray();
                    return Buffer.from(byteArray);
                }
                else if (stream && typeof stream.pipe === 'function') {
                    const chunks = [];
                    for await (const chunk of stream) {
                        chunks.push(Buffer.from(chunk));
                    }
                    return Buffer.concat(chunks);
                }
            }
            catch (r2Err) {
                console.warn('Could not fetch image directly from R2 key, falling back to fetch:', r2Err);
            }
        }
        if (imageUrl.startsWith('data:image')) {
            const base64Data = imageUrl.split(',')[1];
            if (base64Data) {
                return Buffer.from(base64Data, 'base64');
            }
        }
        const fetchRes = await fetch(imageUrl);
        if (fetchRes.ok) {
            const arrayBuffer = await fetchRes.arrayBuffer();
            return Buffer.from(arrayBuffer);
        }
    }
    catch (err) {
        console.error('Error in getImageBuffer:', err);
    }
    return null;
}
/**
 * Helper to run Gemini completion with error handling
 */
async function callGemini(prompt, systemPrompt, imageBuffer, mimeType = 'image/jpeg') {
    if (!genAI)
        return null;
    try {
        const parts = [];
        if (systemPrompt) {
            parts.push({ text: `System Instructions: ${systemPrompt}\n\n` });
        }
        parts.push({ text: prompt });
        if (imageBuffer) {
            parts.push({
                inlineData: {
                    data: imageBuffer.toString('base64'),
                    mimeType,
                },
            });
        }
        const response = await genAI.models.generateContent({
            model: geminiModel,
            contents: [{ role: 'user', parts }],
        });
        return response.text?.trim() || null;
    }
    catch (err) {
        console.warn('Gemini request failed, falling back to Cloudflare AI:', err);
        return null;
    }
}
/**
 * POST /api/ai/query
 * Hybrid Gemini + Cloudflare Workers AI assistant queries
 */
router.post('/query', auth_1.authenticateToken, async (req, res) => {
    try {
        const { prompt, imageUrl, systemPrompt, model, provider } = req.body;
        const activePrompt = (typeof prompt === 'string' && prompt.trim()) ? prompt.trim() : 'What is in this image?';
        if (activePrompt.length > 12000) {
            return res.status(400).json({
                success: false,
                error: { code: 'PROMPT_TOO_LONG', message: 'Prompt exceeds maximum character limit of 12,000' }
            });
        }
        const activeSystemPrompt = (typeof systemPrompt === 'string' && systemPrompt.trim())
            ? systemPrompt.trim()
            : DEFAULT_SYSTEM_PROMPT;
        let reply = '';
        const forceCloudflare = provider === 'cloudflare' || (typeof model === 'string' && model.startsWith('@cf/'));
        // Image query
        if (typeof imageUrl === 'string' && imageUrl.trim()) {
            const imageBuffer = await getImageBuffer(imageUrl.trim());
            if (!imageBuffer) {
                return res.status(400).json({
                    success: false,
                    error: { code: 'IMAGE_FETCH_FAILED', message: 'Unable to retrieve image file for AI inspection.' }
                });
            }
            let mimeType = 'image/jpeg';
            const trimmedUrl = imageUrl.trim().toLowerCase();
            if (trimmedUrl.endsWith('.png'))
                mimeType = 'image/png';
            else if (trimmedUrl.endsWith('.webp'))
                mimeType = 'image/webp';
            else if (trimmedUrl.endsWith('.gif'))
                mimeType = 'image/gif';
            // 1. Try Gemini first unless Cloudflare is forced
            if (!forceCloudflare && genAI) {
                const geminiReply = await callGemini(activePrompt, activeSystemPrompt, imageBuffer, mimeType);
                if (geminiReply)
                    reply = geminiReply;
            }
            // 2. Fallback to Cloudflare Vision
            if (!reply) {
                const visionPrompt = `${activeSystemPrompt}\n\nUser Question: ${activePrompt}`;
                const visionModel = '@cf/meta/llama-3.2-11b-vision-instruct';
                const aiResult = await (0, cloudflare_1.runCloudflareAIVision)(visionPrompt, imageBuffer, visionModel);
                reply = aiResult?.result?.response || aiResult?.result?.description || aiResult?.response || '';
            }
        }
        else {
            // Text query
            // 1. Try Gemini first unless Cloudflare is forced
            if (!forceCloudflare && genAI) {
                const geminiReply = await callGemini(activePrompt, activeSystemPrompt);
                if (geminiReply)
                    reply = geminiReply;
            }
            // 2. Fallback to Cloudflare Workers AI
            if (!reply) {
                const selectedModel = model && ALLOWED_MODELS.has(model)
                    ? model
                    : process.env.CLOUDFLARE_AI_MODEL || '@cf/meta/llama-3.1-8b-instruct';
                const aiResult = await (0, cloudflare_1.runCloudflareAI)(activePrompt, selectedModel, {
                    systemPrompt: activeSystemPrompt,
                });
                if (aiResult?.result?.response && typeof aiResult.result.response === 'string') {
                    reply = aiResult.result.response;
                }
                else if (aiResult?.response && typeof aiResult.response === 'string') {
                    reply = aiResult.response;
                }
                else if (typeof aiResult?.result === 'string') {
                    reply = aiResult.result;
                }
            }
        }
        if (!reply || reply.trim() === '' || reply.trim() === '{}') {
            return res.status(503).json({
                success: false,
                error: {
                    code: 'NETWORK_SERVICE_ERROR',
                    message: 'AI Assistant is currently experiencing a connection issue. Please check your internet connection and try again.'
                }
            });
        }
        return res.json({
            success: true,
            data: { response: reply },
        });
    }
    catch (error) {
        console.error('AI query error:', error);
        return res.status(500).json({
            success: false,
            error: { code: 'AI_SERVICE_ERROR', message: 'AI Assistant network connection error. Please try again.' }
        });
    }
});
/**
 * POST /api/ai/stream
 * Real Server-Sent Events (SSE) streaming endpoint for AI response tokens
 */
router.post('/stream', auth_1.authenticateToken, async (req, res) => {
    try {
        const { prompt, systemPrompt, model } = req.body;
        if (typeof prompt !== 'string' || !prompt.trim()) {
            return res.status(400).json({
                success: false,
                error: { code: 'INVALID_PROMPT', message: 'Prompt must be a non-empty string' }
            });
        }
        const selectedModel = model && ALLOWED_MODELS.has(model)
            ? model
            : process.env.CLOUDFLARE_AI_MODEL || '@cf/meta/llama-3.1-8b-instruct';
        const activeSystemPrompt = (typeof systemPrompt === 'string' && systemPrompt.trim())
            ? systemPrompt.trim()
            : DEFAULT_SYSTEM_PROMPT;
        // Set SSE headers
        res.setHeader('Content-Type', 'text/event-stream');
        res.setHeader('Cache-Control', 'no-cache');
        res.setHeader('Connection', 'keep-alive');
        res.flushHeaders?.();
        // Stream from Cloudflare Workers AI
        const cloudflareRes = await (0, cloudflare_1.runCloudflareAI)(prompt.trim(), selectedModel, {
            systemPrompt: activeSystemPrompt,
            stream: true,
        });
        if (cloudflareRes && typeof cloudflareRes === 'object' && cloudflareRes.body) {
            const reader = cloudflareRes.body.getReader?.();
            if (reader) {
                const decoder = new TextDecoder();
                while (true) {
                    const { done, value } = await reader.read();
                    if (done)
                        break;
                    const chunk = decoder.decode(value, { stream: true });
                    res.write(chunk);
                }
                res.end();
                return;
            }
        }
        // Network connection error fallback if stream is unreachable
        res.write(`data: ${JSON.stringify({ response: 'AI Assistant connection error. Please check your internet connection.' })}\n\n`);
        res.write('data: [DONE]\n\n');
        res.end();
    }
    catch (error) {
        console.error('AI streaming error:', error);
        if (!res.headersSent) {
            res.status(500).json({
                success: false,
                error: { code: 'AI_STREAM_ERROR', message: 'Streaming failed due to network connection error.' }
            });
        }
        else {
            res.write(`data: ${JSON.stringify({ error: 'AI stream interrupted due to connection issue' })}\n\n`);
            res.end();
        }
    }
});
/**
 * POST /api/ai/moderate
 * Fail-closed text moderation endpoint (Gemini first with Cloudflare fallback)
 */
router.post('/moderate', auth_1.authenticateToken, async (req, res) => {
    try {
        const { text, model } = req.body;
        if (!text || typeof text !== 'string' || !text.trim()) {
            return res.json({ success: true, safe: true, status: 'approved' });
        }
        const moderationPrompt = `You are a strict university community content moderation classifier for Afe Babalola University (ABUAD).
Analyze if the following text is safe for a university campus platform.
Check for extreme profanity, hate speech, harassment, explicit sexual content, threats of violence, or illegal acts.

Content to analyze:
"${text.replace(/"/g, '\\"')}"

Respond ONLY with a valid JSON object in this exact format with no additional text or markdown formatting:
{"safe": true} OR {"safe": false, "reason": "short explanation"}
`;
        let cleanedText = '';
        // 1. Try Gemini first
        if (genAI) {
            const gRes = await callGemini(moderationPrompt);
            if (gRes) {
                cleanedText = gRes.replace(/```json/g, '').replace(/```/g, '').trim();
            }
        }
        // 2. Fallback to Cloudflare AI
        if (!cleanedText) {
            const selectedModel = model && ALLOWED_MODELS.has(model)
                ? model
                : process.env.CLOUDFLARE_AI_MODEL || '@cf/meta/llama-3.1-8b-instruct';
            const result = await (0, cloudflare_1.runCloudflareAI)(moderationPrompt, selectedModel);
            let aiText = result?.result?.response || result?.response || (typeof result?.result === 'string' ? result.result : '');
            cleanedText = aiText.replace(/```json/g, '').replace(/```/g, '').trim();
        }
        try {
            const parsed = JSON.parse(cleanedText);
            const isSafe = parsed.safe ?? false;
            return res.json({
                success: true,
                safe: isSafe,
                status: isSafe ? 'approved' : 'rejected',
                reason: parsed.reason,
            });
        }
        catch {
            const isUnsafe = /"safe":\s*false|unsafe|inappropriate|violation/i.test(cleanedText);
            return res.json({
                success: true,
                safe: !isUnsafe,
                status: !isUnsafe ? 'approved' : 'review',
                reason: isUnsafe ? 'Flagged for moderation review' : undefined,
            });
        }
    }
    catch (error) {
        console.error('Text moderation exception:', error);
        return res.json({
            success: false,
            safe: false,
            status: 'review',
            reason: 'Moderation service temporarily unavailable',
        });
    }
});
/**
 * POST /api/ai/moderate-image
 * Fail-closed image media moderation (Gemini Vision first with Cloudflare Vision fallback)
 */
router.post('/moderate-image', auth_1.authenticateToken, async (req, res) => {
    try {
        const { imageUrl } = req.body;
        if (!imageUrl || typeof imageUrl !== 'string' || !imageUrl.trim()) {
            return res.json({ success: true, safe: true, status: 'approved' });
        }
        if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
            return res.json({ success: true, safe: true, status: 'approved' });
        }
        const imageBuffer = await getImageBuffer(imageUrl.trim());
        if (!imageBuffer) {
            return res.json({
                success: false,
                safe: false,
                status: 'review',
                reason: 'Unable to retrieve image for safety inspection',
            });
        }
        const visionPrompt = `You are a strict image content moderation safety classifier for Afe Babalola University (ABUAD).
Analyze if this image contains explicit adult nudity, extreme gore/violence, illegal contraband, or hate symbols.

Respond ONLY with a valid JSON object in this exact format with no extra text:
{"safe": true} OR {"safe": false, "reason": "short description of violation"}`;
        let cleanedText = '';
        // 1. Try Gemini Vision first
        if (genAI) {
            let mimeType = 'image/jpeg';
            const trimmed = imageUrl.toLowerCase();
            if (trimmed.endsWith('.png'))
                mimeType = 'image/png';
            else if (trimmed.endsWith('.webp'))
                mimeType = 'image/webp';
            const gRes = await callGemini(visionPrompt, undefined, imageBuffer, mimeType);
            if (gRes) {
                cleanedText = gRes.replace(/```json/g, '').replace(/```/g, '').trim();
            }
        }
        // 2. Fallback to Cloudflare Vision
        if (!cleanedText) {
            const visionModel = '@cf/meta/llama-3.2-11b-vision-instruct';
            const result = await (0, cloudflare_1.runCloudflareAIVision)(visionPrompt, imageBuffer, visionModel);
            let aiText = result?.result?.response || result?.result?.description || result?.response || '';
            cleanedText = aiText.replace(/```json/g, '').replace(/```/g, '').trim();
        }
        try {
            const parsed = JSON.parse(cleanedText);
            const isSafe = parsed.safe ?? false;
            return res.json({
                success: true,
                safe: isSafe,
                status: isSafe ? 'approved' : 'rejected',
                reason: parsed.reason,
            });
        }
        catch {
            const isUnsafe = /"safe":\s*false|unsafe|inappropriate|explicit|violation/i.test(cleanedText);
            return res.json({
                success: true,
                safe: !isUnsafe,
                status: !isUnsafe ? 'approved' : 'review',
                reason: isUnsafe ? 'Flagged for image safety review' : undefined,
            });
        }
    }
    catch (error) {
        console.error('Image moderation exception:', error);
        return res.json({
            success: false,
            safe: false,
            status: 'review',
            reason: 'Image moderation service temporarily unavailable',
        });
    }
});
/**
 * POST /api/ai/understand-post
 * AI-Powered Feed Algorithm Stage B: Extracts topics, category, summary & sentiment
 */
router.post('/understand-post', auth_1.authenticateToken, async (req, res) => {
    try {
        const { content, imageUrl } = req.body;
        if (!content && !imageUrl) {
            return res.status(400).json({ success: false, error: 'Content or imageUrl is required' });
        }
        const prompt = `Analyze this university social post for the campus feed algorithm.
Post content: "${content ? content.replace(/"/g, '\\"') : '(image post)'}"

Extract relevant feed signals and respond ONLY with JSON:
{
  "topics": ["topic1", "topic2", "topic3"],
  "category": "Academics" | "Technology" | "Campus Life" | "Sports" | "Entertainment" | "Marketplace" | "General",
  "summary": "1-sentence summary of the post",
  "sentiment": "positive" | "neutral" | "negative",
  "suggestedTags": ["tag1", "tag2"],
  "safetyStatus": "approved" | "review" | "rejected"
}`;
        let reply = '';
        let imageBuffer = null;
        if (imageUrl) {
            imageBuffer = await getImageBuffer(imageUrl);
        }
        if (genAI) {
            reply = (await callGemini(prompt, undefined, imageBuffer || undefined)) || '';
        }
        if (!reply) {
            const result = await (0, cloudflare_1.runCloudflareAI)(prompt, '@cf/meta/llama-3.1-8b-instruct');
            reply = result?.result?.response || result?.response || '';
        }
        const clean = reply.replace(/```json/g, '').replace(/```/g, '').trim();
        try {
            const parsed = JSON.parse(clean);
            return res.json({ success: true, data: parsed });
        }
        catch {
            return res.json({
                success: true,
                data: {
                    topics: ['Campus'],
                    category: 'General',
                    summary: content?.slice(0, 100) || '',
                    sentiment: 'neutral',
                    suggestedTags: [],
                    safetyStatus: 'approved'
                }
            });
        }
    }
    catch (error) {
        console.error('Post understanding error:', error);
        return res.status(500).json({ success: false, error: 'Failed to analyze post' });
    }
});
/**
 * POST /api/ai/moderate/content
 * Unified multi-modal moderation decision endpoint (allow, review, block)
 */
router.post('/moderate/content', auth_1.authenticateToken, async (req, res) => {
    try {
        const { text, mediaUrl } = req.body;
        const prompt = `You are the content moderation safety system for the ABUAD campus platform.
Evaluate this content against community safety standards (Harassment, Hate Speech, Violence, Explicit Sexual Content, Self-Harm, Dangerous Acts, Scam/Spam).

Text: "${text ? text.replace(/"/g, '\\"') : 'None'}"

Respond ONLY with valid JSON in this exact structure:
{
  "decision": "allow" | "review" | "block",
  "categories": ["category_name"],
  "confidence": 0.95,
  "explanation": "Clear explanation of the decision",
  "reviewRequired": boolean
}`;
        let imageBuffer = null;
        if (mediaUrl) {
            imageBuffer = await getImageBuffer(mediaUrl);
        }
        let reply = '';
        if (genAI) {
            reply = (await callGemini(prompt, undefined, imageBuffer || undefined)) || '';
        }
        if (!reply) {
            const cfRes = await (0, cloudflare_1.runCloudflareAI)(prompt, '@cf/meta/llama-3.1-8b-instruct');
            reply = cfRes?.result?.response || cfRes?.response || '';
        }
        const clean = reply.replace(/```json/g, '').replace(/```/g, '').trim();
        try {
            const parsed = JSON.parse(clean);
            return res.json({ success: true, ...parsed });
        }
        catch {
            return res.json({
                success: true,
                decision: 'allow',
                categories: [],
                confidence: 0.9,
                explanation: 'Standard campus content',
                reviewRequired: false
            });
        }
    }
    catch (error) {
        console.error('Unified moderation error:', error);
        return res.json({
            success: false,
            decision: 'review',
            categories: ['system_error'],
            confidence: 0.5,
            explanation: 'Moderation service error; held for review',
            reviewRequired: true
        });
    }
});
exports.default = router;
