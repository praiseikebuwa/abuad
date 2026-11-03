"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.explainStudyTopic = explainStudyTopic;
exports.generateStudyQuiz = generateStudyQuiz;
exports.generateAudioLecture = generateAudioLecture;
const genai_1 = require("@google/genai");
const cloudflare_1 = require("../config/cloudflare");
const db_1 = require("../config/db");
const resourceProcessorService_1 = require("./resourceProcessorService");
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
    const { courseCode, topic, count = 4, resourceId, difficulty = 'MIXED' } = params;
    let documentContext = '';
    let sourceDocTitle = '';
    let isGrounded = false;
    if (resourceId) {
        const resource = await db_1.prisma.resource.findUnique({
            where: { id: resourceId },
        });
        if (!resource) {
            const err = new Error(`Resource with ID "${resourceId}" not found.`);
            err.code = 'RESOURCE_NOT_FOUND';
            throw err;
        }
        sourceDocTitle = resource.title;
        if (resource.processingStatus === 'PENDING' ||
            resource.processingStatus === 'EXTRACTING' ||
            resource.processingStatus === 'RUNNING_OCR') {
            const err = new Error(`Document "${resource.title}" is still processing (Status: ${resource.processingStatus}, Progress: ${resource.processingProgress}%). Please wait for OCR extraction to finish.`);
            err.code = 'RESOURCE_STILL_PROCESSING';
            err.status = resource.processingStatus;
            err.progress = resource.processingProgress;
            throw err;
        }
        if (resource.processingStatus === 'FAILED') {
            const err = new Error(`Document "${resource.title}" processing failed: ${resource.processingError || 'Unreadable text'}. Please retry OCR processing.`);
            err.code = 'RESOURCE_PROCESSING_FAILED';
            throw err;
        }
        const fullText = await (0, resourceProcessorService_1.getResourceExtractedText)(resource.id);
        if (fullText && fullText.trim().length > 50) {
            documentContext = fullText.slice(0, 35000); // Take rich context window
            isGrounded = true;
        }
        else {
            const err = new Error(`Resource "${resource.title}" contains no extracted text to generate CBT questions from.`);
            err.code = 'RESOURCE_NO_TEXT';
            throw err;
        }
    }
    const systemPrompt = isGrounded
        ? `You are ABUAD AI, the official examination and CBT question creator for Afe Babalola University.
You are generating rigorous academic CBT examination questions GROUNDED STRICTLY IN THE PROVIDED EXTRACTED DOCUMENT TEXT.
Rules:
1. Every question must be factual and directly verifiable from the provided source text.
2. DO NOT make up facts or invent details that are not in the text.
3. Provide 4 distinct options with exactly one correct option.
4. Include a comprehensive explanation citing the specific page number or section where the concept was extracted (e.g. "Page 2", "Page 4 [OCR]").
5. Include a "difficulty" property for each question ("EASY", "MEDIUM", "HARD").
6. Generate exactly ${count} multiple-choice questions.

Output strictly a JSON array without markdown backticks:
[
  {
    "id": "q1",
    "question": "Question based directly on text?",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correctIndex": 0,
    "explanation": "Detailed explanation grounded in the text...",
    "difficulty": "MEDIUM",
    "pageReference": "Page 1"
  }
]`
        : `You are ABUAD AI, an exam question creator for university courses.
Generate exactly ${count} realistic multiple-choice questions for the specified course and topic.
Output strictly a JSON array without markdown backticks:
[
  {
    "id": "q1",
    "question": "Question text here?",
    "options": ["Option A text", "Option B text", "Option C text", "Option D text"],
    "correctIndex": 0,
    "explanation": "Clear explanation of why this answer is correct.",
    "difficulty": "MEDIUM",
    "pageReference": "General Curriculum"
  }
]`;
    const userPrompt = isGrounded
        ? `Course: ${courseCode}
Topic/Document: ${topic || sourceDocTitle}
Target Question Count: ${count}
Requested Difficulty: ${difficulty}

=== SOURCE DOCUMENT EXTRACTED TEXT (GROUND TRUTH) ===
${documentContext}
=== END SOURCE TEXT ===

Generate ${count} CBT questions directly testing mastery of the above material.`
        : `Generate a ${count}-question quiz for course "${courseCode}", topic "${topic}". Include plausible distractors and thorough explanations.`;
    const raw = await getCompletion(userPrompt, systemPrompt);
    try {
        const cleanJson = raw.replace(/```json/g, '').replace(/```/g, '').trim();
        const parsed = JSON.parse(cleanJson);
        if (Array.isArray(parsed)) {
            const questions = parsed.map((item, idx) => ({
                id: item.id || `q_${idx + 1}`,
                question: item.question || `Question ${idx + 1}`,
                options: Array.isArray(item.options) ? item.options.map(String) : ['Option A', 'Option B', 'Option C', 'Option D'],
                correctIndex: typeof item.correctIndex === 'number' ? item.correctIndex : 0,
                explanation: item.explanation || 'Review course materials for more context.',
                difficulty: item.difficulty || 'MEDIUM',
                pageReference: item.pageReference || (isGrounded ? 'Extracted Text' : 'Curriculum'),
                sourceSection: item.sourceSection || undefined,
            }));
            return { questions, sourceDocument: sourceDocTitle || undefined, grounded: isGrounded };
        }
    }
    catch (e) {
        console.error('[StudyAiService] Quiz JSON parse failed:', e);
    }
    // Fallback questions
    return {
        questions: [
            {
                id: 'q_default',
                question: `What is a primary principle discussed in ${topic || sourceDocTitle || courseCode}?`,
                options: [
                    'Fundamental conceptual understanding and systemic analysis',
                    'Arbitrary memorization without context',
                    'Ignoring prerequisites and foundational theory',
                    'None of the above',
                ],
                correctIndex: 0,
                explanation: `Academic mastery in ${courseCode} builds upon rigorous theoretical foundations.`,
                difficulty: 'MEDIUM',
                pageReference: isGrounded ? 'Page 1' : 'Curriculum',
            },
        ],
        sourceDocument: sourceDocTitle || undefined,
        grounded: isGrounded,
    };
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
