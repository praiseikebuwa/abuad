"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.explainStudyTopic = explainStudyTopic;
exports.generateStudyQuiz = generateStudyQuiz;
exports.generateAudioLecture = generateAudioLecture;
const genai_1 = require("@google/genai");
const cloudflare_1 = require("../config/cloudflare");
const geminiApiKey = process.env.GEMINI_API_KEY || '';
const geminiModel = process.env.GEMINI_MODEL || 'gemini-3-flash-preview';
const genAI = geminiApiKey ? new genai_1.GoogleGenAI({ apiKey: geminiApiKey }) : null;
async function getCompletion(prompt, systemPrompt) {
    if (genAI) {
        try {
            const response = await genAI.models.generateContent({
                model: geminiModel,
                contents: [
                    {
                        role: 'user',
                        parts: [
                            { text: `System Instructions: ${systemPrompt}\n\n` },
                            { text: prompt },
                        ],
                    },
                ],
            });
            const txt = response.text?.trim();
            if (txt)
                return txt;
        }
        catch (e) {
            console.warn('[StudyAiService] Gemini API call failed, falling back to Cloudflare:', e);
        }
    }
    // Fallback to Cloudflare AI
    try {
        const cf = await (0, cloudflare_1.runCloudflareAI)([
            { role: 'system', content: systemPrompt },
            { role: 'user', content: prompt },
        ]);
        if (cf && typeof cf === 'string')
            return cf.trim();
        if (cf && typeof cf === 'object' && cf.response)
            return cf.response.trim();
    }
    catch (cfErr) {
        console.error('[StudyAiService] Cloudflare fallback failed:', cfErr);
    }
    throw new Error('AI Service is temporarily unavailable. Please try again in a moment.');
}
async function explainStudyTopic(params) {
    const { courseCode, topic, level = 'Undergraduate', faculty = '', depth = 'detailed' } = params;
    const systemPrompt = `You are ABUAD AI, the elite academic study assistant for Afe Babalola University (ABUAD).
You specialize in curriculum-aligned tertiary education across Engineering, Law, Sciences, Medicine, Social Sciences, and Computing.
Format your response strictly as valid JSON matching this schema:
{
  "summary": "Concise 2-3 sentence overview of the concept",
  "detailedNotes": "In-depth explanation with markdown headers, bullet points, and LaTeX formulas ($...$ for inline, $$...$$ for block)",
  "keyTakeaways": ["Key bullet 1", "Key bullet 2", "Key bullet 3", "Key bullet 4"],
  "examTips": ["Common mistake to avoid", "High-yield exam revision tip", "Formula or case law to remember"]
}
Do not include any outer text or markdown code fences other than the raw JSON object.`;
    const userPrompt = `Course Code: ${courseCode}
Topic: ${topic}
Academic Level: ${level}
Faculty: ${faculty}
Depth: ${depth}

Explain this topic thoroughly for an ABUAD student preparing for lectures or continuous assessment/exams.`;
    const raw = await getCompletion(userPrompt, systemPrompt);
    try {
        const cleanJson = raw.replace(/```json/g, '').replace(/```/g, '').trim();
        const parsed = JSON.parse(cleanJson);
        return {
            courseCode,
            topic,
            summary: parsed.summary || 'Summary unavailable',
            detailedNotes: parsed.detailedNotes || raw,
            keyTakeaways: Array.isArray(parsed.keyTakeaways) ? parsed.keyTakeaways : [],
            examTips: Array.isArray(parsed.examTips) ? parsed.examTips : [],
        };
    }
    catch (_) {
        return {
            courseCode,
            topic,
            summary: `Revision guide for ${courseCode} - ${topic}`,
            detailedNotes: raw,
            keyTakeaways: ['Review core principles', 'Practice past test problems', 'Consult lecturer handouts'],
            examTips: ['Focus on fundamental definitions and step-by-step working.'],
        };
    }
}
async function generateStudyQuiz(params) {
    const { courseCode, topic, count = 4 } = params;
    const systemPrompt = `You are ABUAD AI, an exam question creator for university courses.
Generate exactly ${count} realistic multiple-choice questions for the specified course and topic.
Output strictly a JSON array without markdown backticks:
[
  {
    "id": "q1",
    "question": "Question text here?",
    "options": ["Option A text", "Option B text", "Option C text", "Option D text"],
    "correctIndex": 0,
    "explanation": "Clear explanation of why this answer is correct."
  }
]`;
    const userPrompt = `Generate a ${count}-question quiz for course "${courseCode}", topic "${topic}". Include plausible distractors and thorough explanations.`;
    const raw = await getCompletion(userPrompt, systemPrompt);
    try {
        const cleanJson = raw.replace(/```json/g, '').replace(/```/g, '').trim();
        const parsed = JSON.parse(cleanJson);
        if (Array.isArray(parsed)) {
            return parsed.map((item, idx) => ({
                id: item.id || `q_${idx + 1}`,
                question: item.question || `Question ${idx + 1}`,
                options: Array.isArray(item.options) ? item.options.map(String) : ['Option A', 'Option B', 'Option C', 'Option D'],
                correctIndex: typeof item.correctIndex === 'number' ? item.correctIndex : 0,
                explanation: item.explanation || 'Review course materials for more context.',
            }));
        }
    }
    catch (e) {
        console.error('[StudyAiService] Quiz JSON parse failed:', e);
    }
    // Fallback single question
    return [
        {
            id: 'q_default',
            question: `What is a primary principle of ${topic} in ${courseCode}?`,
            options: [
                'Fundamental conceptual understanding and systemic analysis',
                'Arbitrary memorization without context',
                'Ignoring prerequisites and foundational theory',
                'None of the above',
            ],
            correctIndex: 0,
            explanation: `${topic} builds upon rigorous theoretical foundations and analytical reasoning.`,
        },
    ];
}
async function generateAudioLecture(params) {
    const { courseCode, topic, durationMinutes = 3, style = 'conversational_tutor' } = params;
    const systemPrompt = `You are ABUAD AI, a charismatic, world-class university tutor hosting an audio study session for Afe Babalola University students.
You talk directly to the listener as if speaking over a microphone in a live audio study lounge.
Tone: Warm, engaging, intellectually sharp, easy to listen to without visual slides.
Use conversational verbal cues like "Notice how...", "Here is the key takeaway...", "Let us break this down...".
Output strictly a JSON object:
{
  "title": "Engaging Audio Session Title",
  "spokenScript": "Full conversational spoken script for the tutor to read aloud (approximately 300 to 500 words).",
  "bulletPoints": ["Takeaway 1", "Takeaway 2", "Takeaway 3"],
  "suggestedQuestions": ["What is...?", "Can you explain how...?", "How does this apply to...?"]
}`;
    const userPrompt = `Create an audio lecture for:
Course: ${courseCode}
Topic: ${topic}
Style: ${style}
Target Duration: approximately ${durationMinutes} minutes.`;
    const raw = await getCompletion(userPrompt, systemPrompt);
    try {
        const cleanJson = raw.replace(/```json/g, '').replace(/```/g, '').trim();
        const parsed = JSON.parse(cleanJson);
        const spoken = parsed.spokenScript || raw;
        const words = spoken.split(/\s+/).length;
        // Average speech rate: ~140 words per minute
        const estimatedSeconds = Math.max(30, Math.round((words / 140) * 60));
        return {
            title: parsed.title || `${courseCode}: ${topic} Audio Breakdown`,
            courseCode,
            topic,
            spokenScript: spoken,
            bulletPoints: Array.isArray(parsed.bulletPoints) ? parsed.bulletPoints : [],
            suggestedQuestions: Array.isArray(parsed.suggestedQuestions) ? parsed.suggestedQuestions : [],
            estimatedDurationSeconds: estimatedSeconds,
        };
    }
    catch (_) {
        return {
            title: `${courseCode}: ${topic} Overview`,
            courseCode,
            topic,
            spokenScript: raw,
            bulletPoints: ['Core definitions', 'Worked illustration', 'Exam review advice'],
            suggestedQuestions: ['Can you provide a practice example?', 'What are typical exam pitfalls?'],
            estimatedDurationSeconds: 180,
        };
    }
}
