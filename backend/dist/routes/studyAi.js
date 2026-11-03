"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const auth_1 = require("../middleware/auth");
const studyAiService_1 = require("../services/studyAiService");
const router = (0, express_1.Router)();
/**
 * POST /api/study-ai/explain
 * Generate deep dive revision notes and concepts for a course/topic.
 */
router.post('/explain', auth_1.authenticateToken, async (req, res) => {
    try {
        const { courseCode, topic, level, faculty, depth } = req.body;
        if (!topic || !topic.trim()) {
            return res.status(400).json({ error: 'Topic is required' });
        }
        const result = await (0, studyAiService_1.explainStudyTopic)({
            courseCode: (courseCode || 'General Academic').trim(),
            topic: topic.trim(),
            level,
            faculty,
            depth,
        });
        return res.json({ success: true, data: result });
    }
    catch (error) {
        console.error('[StudyAI] Explain failed:', error);
        return res.status(500).json({ error: 'Failed to generate explanation', details: error.message });
    }
});
/**
 * POST /api/study-ai/quiz
 * Generate multiple-choice quiz questions for revision or CBT practice.
 * Supports grounding questions directly in an uploaded academic resource PDF.
 */
router.post('/quiz', auth_1.authenticateToken, async (req, res) => {
    try {
        const { courseCode, topic, count, resourceId, difficulty } = req.body;
        if (!topic && !resourceId) {
            return res.status(400).json({ error: 'Either topic or resourceId is required' });
        }
        const quiz = await (0, studyAiService_1.generateStudyQuiz)({
            courseCode: (courseCode || 'General Academic').trim(),
            topic: topic ? topic.trim() : undefined,
            count: typeof count === 'number' ? Math.min(20, Math.max(1, count)) : 4,
            resourceId: resourceId ? String(resourceId).trim() : undefined,
            difficulty: difficulty || 'MIXED',
        });
        return res.json({ success: true, data: quiz });
    }
    catch (error) {
        console.error('[StudyAI] Quiz failed:', error);
        if (error.code === 'RESOURCE_STILL_PROCESSING') {
            return res.status(202).json({
                success: false,
                code: 'RESOURCE_STILL_PROCESSING',
                status: error.status,
                progress: error.progress,
                message: error.message,
            });
        }
        if (error.code === 'RESOURCE_PROCESSING_FAILED' || error.code === 'RESOURCE_NO_TEXT') {
            return res.status(400).json({
                success: false,
                code: error.code,
                error: error.message,
            });
        }
        return res.status(500).json({ error: 'Failed to generate quiz', details: error.message });
    }
});
/**
 * POST /api/study-ai/audio-lecture
 * Generate conversational spoken lecture text with structured takeaways.
 */
router.post('/audio-lecture', auth_1.authenticateToken, async (req, res) => {
    try {
        const { courseCode, topic, durationMinutes, style } = req.body;
        if (!topic || !topic.trim()) {
            return res.status(400).json({ error: 'Topic is required' });
        }
        const lecture = await (0, studyAiService_1.generateAudioLecture)({
            courseCode: (courseCode || 'General Academic').trim(),
            topic: topic.trim(),
            durationMinutes: typeof durationMinutes === 'number' ? durationMinutes : 3,
            style,
        });
        return res.json({ success: true, data: lecture });
    }
    catch (error) {
        console.error('[StudyAI] Audio lecture failed:', error);
        return res.status(500).json({ error: 'Failed to generate audio lecture', details: error.message });
    }
});
exports.default = router;
