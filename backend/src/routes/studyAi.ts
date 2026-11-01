import { Router, Response } from 'express';
import { authenticateToken, AuthenticatedRequest } from '../middleware/auth';
import {
  explainStudyTopic,
  generateStudyQuiz,
  generateAudioLecture,
} from '../services/studyAiService';

const router = Router();

/**
 * POST /api/study-ai/explain
 * Generate deep dive revision notes and concepts for a course/topic.
 */
router.post('/explain', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { courseCode, topic, level, faculty, depth } = req.body;
    if (!topic || !topic.trim()) {
      return res.status(400).json({ error: 'Topic is required' });
    }

    const result = await explainStudyTopic({
      courseCode: (courseCode || 'General Academic').trim(),
      topic: topic.trim(),
      level,
      faculty,
      depth,
    });

    return res.json({ success: true, data: result });
  } catch (error: any) {
    console.error('[StudyAI] Explain failed:', error);
    return res.status(500).json({ error: 'Failed to generate explanation', details: error.message });
  }
});

/**
 * POST /api/study-ai/quiz
 * Generate multiple-choice quiz questions for revision.
 */
router.post('/quiz', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { courseCode, topic, count } = req.body;
    if (!topic || !topic.trim()) {
      return res.status(400).json({ error: 'Topic is required' });
    }

    const quiz = await generateStudyQuiz({
      courseCode: (courseCode || 'General Academic').trim(),
      topic: topic.trim(),
      count: typeof count === 'number' ? Math.min(10, Math.max(1, count)) : 4,
    });

    return res.json({ success: true, data: quiz });
  } catch (error: any) {
    console.error('[StudyAI] Quiz failed:', error);
    return res.status(500).json({ error: 'Failed to generate quiz', details: error.message });
  }
});

/**
 * POST /api/study-ai/audio-lecture
 * Generate conversational spoken lecture text with structured takeaways.
 */
router.post('/audio-lecture', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { courseCode, topic, durationMinutes, style } = req.body;
    if (!topic || !topic.trim()) {
      return res.status(400).json({ error: 'Topic is required' });
    }

    const lecture = await generateAudioLecture({
      courseCode: (courseCode || 'General Academic').trim(),
      topic: topic.trim(),
      durationMinutes: typeof durationMinutes === 'number' ? durationMinutes : 3,
      style,
    });

    return res.json({ success: true, data: lecture });
  } catch (error: any) {
    console.error('[StudyAI] Audio lecture failed:', error);
    return res.status(500).json({ error: 'Failed to generate audio lecture', details: error.message });
  }
});

export default router;

