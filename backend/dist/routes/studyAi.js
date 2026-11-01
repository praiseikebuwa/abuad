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
 * Generate multiple-choice quiz questions for revision.
 */
router.post('/quiz', auth_1.authenticateToken, async (req, res) => {
    try {
        const { courseCode, topic, count } = req.body;
        if (!topic || !topic.trim()) {
            return res.status(400).json({ error: 'Topic is required' });
        }
        const quiz = await (0, studyAiService_1.generateStudyQuiz)({
            courseCode: (courseCode || 'General Academic').trim(),
            topic: topic.trim(),
            count: typeof count === 'number' ? Math.min(10, Math.max(1, count)) : 4,
        });
        return res.json({ success: true, data: quiz });
    }
    catch (error) {
        console.error('[StudyAI] Quiz failed:', error);
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
