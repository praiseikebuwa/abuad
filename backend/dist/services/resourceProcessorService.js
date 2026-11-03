"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.startBackgroundProcessor = startBackgroundProcessor;
exports.processAllPendingResources = processAllPendingResources;
exports.enqueueResourceProcessing = enqueueResourceProcessing;
exports.getResourceExtractedText = getResourceExtractedText;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const os_1 = __importDefault(require("os"));
const child_process_1 = require("child_process");
const db_1 = require("../config/db");
const cloudflare_1 = require("../config/cloudflare");
const client_s3_1 = require("@aws-sdk/client-s3");
// Determine the best Python executable on the host
function getPythonExecutable() {
    if (process.env.PYTHON_PATH && fs_1.default.existsSync(process.env.PYTHON_PATH)) {
        return process.env.PYTHON_PATH;
    }
    if (process.platform === 'win32') {
        const windowsAppsPython = path_1.default.join(process.env.LOCALAPPDATA || 'C:\\Users\\pikeb\\AppData\\Local', 'Microsoft\\WindowsApps\\python.exe');
        if (fs_1.default.existsSync(windowsAppsPython)) {
            return windowsAppsPython;
        }
        return 'python.exe';
    }
    // Linux / macOS candidate paths
    const linuxCandidates = ['/usr/bin/python3', '/usr/local/bin/python3', 'python3', 'python'];
    for (const c of linuxCandidates) {
        if (fs_1.default.existsSync(c))
            return c;
    }
    return 'python3';
}
function getScriptPath() {
    const candidates = [
        path_1.default.resolve(__dirname, '../../scripts/pdf_processor.py'),
        path_1.default.resolve(__dirname, '../scripts/pdf_processor.py'),
        path_1.default.resolve(process.cwd(), 'scripts/pdf_processor.py'),
        path_1.default.resolve(process.cwd(), 'backend/scripts/pdf_processor.py'),
    ];
    for (const c of candidates) {
        if (fs_1.default.existsSync(c))
            return c;
    }
    return path_1.default.resolve(__dirname, '../../scripts/pdf_processor.py');
}
const activeJobIds = new Set();
const jobQueue = [];
let isQueueWorkerRunning = false;
let backgroundPollerStarted = false;
/**
 * Start background worker loop that automatically polls DB for pending jobs
 */
function startBackgroundProcessor() {
    if (backgroundPollerStarted)
        return;
    backgroundPollerStarted = true;
    console.log('[ResourceProcessor] Initializing background document processing worker...');
    // Run initial scan 4 seconds after server boot
    setTimeout(() => {
        processAllPendingResources(true).catch((err) => {
            console.warn('[ResourceProcessor] Startup pending resources scan error:', err);
        });
    }, 4000);
    // Periodic check every 20 seconds to pick up any newly queued, orphaned, or failed jobs
    setInterval(() => {
        if (!isQueueWorkerRunning && jobQueue.length === 0) {
            processAllPendingResources(true).catch(() => { });
        }
    }, 20000);
}
/**
 * Enqueue all pending or unextracted resources from the database
 */
async function processAllPendingResources(includeFailed = true) {
    try {
        const statuses = includeFailed
            ? ['PENDING', 'EXTRACTING', 'RUNNING_OCR', 'FAILED']
            : ['PENDING', 'EXTRACTING', 'RUNNING_OCR'];
        const pendingResources = await db_1.prisma.resource.findMany({
            where: {
                processingStatus: {
                    in: statuses,
                },
            },
            select: { id: true, title: true, fileUrl: true, processingStatus: true, extractedText: true },
            orderBy: { createdAt: 'desc' },
            take: 50,
        });
        let enqueued = 0;
        for (const r of pendingResources) {
            // If document already has meaningful text extracted, mark as COMPLETED
            if (r.extractedText && r.extractedText.trim().length > 60) {
                await db_1.prisma.resource.update({
                    where: { id: r.id },
                    data: {
                        processingStatus: 'COMPLETED',
                        processingProgress: 100,
                    },
                }).catch(() => { });
                continue;
            }
            // Check if it's a PDF
            const url = (r.fileUrl || '').toLowerCase();
            const isPdf = url.includes('.pdf') || url.includes('/resources/');
            if (!isPdf) {
                // Non-PDF documents don't need OCR, mark COMPLETED
                await db_1.prisma.resource.update({
                    where: { id: r.id },
                    data: {
                        processingStatus: 'COMPLETED',
                        extractionMethod: 'DIGITAL_TEXT',
                        processingProgress: 100,
                        processedAt: new Date(),
                    },
                }).catch(() => { });
                continue;
            }
            if (!activeJobIds.has(r.id) && !jobQueue.some(j => j.resourceId === r.id)) {
                // Reset status to PENDING so UI shows it's queued
                await db_1.prisma.resource.update({
                    where: { id: r.id },
                    data: {
                        processingStatus: 'PENDING',
                        processingProgress: 0,
                        processingError: null,
                    },
                }).catch(() => { });
                jobQueue.push({ resourceId: r.id, force: true });
                enqueued++;
            }
        }
        if (enqueued > 0) {
            console.log(`[ResourceProcessor] Enqueued ${enqueued} resource(s) for background OCR processing.`);
            triggerQueueWorker();
        }
        return enqueued;
    }
    catch (err) {
        console.error('[ResourceProcessor] Error querying pending resources from DB:', err);
        return 0;
    }
}
/**
 * Enqueue a resource for asynchronous OCR and text processing
 */
async function enqueueResourceProcessing(resourceId, fileBuffer, options) {
    // Prevent duplicate queuing if already running or queued
    if (activeJobIds.has(resourceId)) {
        console.log(`[ResourceProcessor] Resource ${resourceId} is already actively processing.`);
        return;
    }
    // Update resource status in DB to PENDING
    try {
        await db_1.prisma.resource.update({
            where: { id: resourceId },
            data: {
                processingStatus: 'PENDING',
                processingProgress: 0,
                processingError: null,
            },
        });
    }
    catch (dbErr) {
        console.warn(`[ResourceProcessor] Failed to set PENDING status for ${resourceId}:`, dbErr);
    }
    jobQueue.push({ resourceId, fileBuffer, force: options?.force });
    triggerQueueWorker();
}
/**
 * Worker loop that processes jobs sequentially to manage server CPU/memory safely
 */
async function triggerQueueWorker() {
    if (isQueueWorkerRunning)
        return;
    isQueueWorkerRunning = true;
    try {
        while (jobQueue.length > 0) {
            const job = jobQueue.shift();
            if (!job)
                break;
            activeJobIds.add(job.resourceId);
            try {
                await executeProcessing(job.resourceId, job.fileBuffer, { force: job.force });
            }
            catch (err) {
                console.error(`[ResourceProcessor] Job failed for resource ${job.resourceId}:`, err);
                try {
                    await db_1.prisma.resource.update({
                        where: { id: job.resourceId },
                        data: {
                            processingStatus: 'FAILED',
                            processingError: err.message || 'Background processing failed',
                            processingProgress: 100,
                        },
                    });
                }
                catch (_) { }
            }
            finally {
                activeJobIds.delete(job.resourceId);
            }
        }
    }
    finally {
        isQueueWorkerRunning = false;
    }
}
/**
 * Execute the end-to-end PDF processing pipeline for a given resource
 */
async function executeProcessing(resourceId, fileBuffer, options) {
    const resource = await db_1.prisma.resource.findUnique({
        where: { id: resourceId },
    });
    if (!resource) {
        throw new Error(`Resource ${resourceId} not found in database`);
    }
    // If already completed and not forced, skip
    if (resource.processingStatus === 'COMPLETED' && !options?.force) {
        console.log(`[ResourceProcessor] Resource ${resourceId} is already completed. Skipping.`);
        return;
    }
    // Check file extension: Only PDF files undergo PDF OCR pipeline
    const fileUrl = resource.fileUrl.toLowerCase();
    const isPdf = fileUrl.includes('.pdf') || (resource.description && resource.description.includes('application/pdf'));
    if (!isPdf) {
        console.log(`[ResourceProcessor] Resource ${resourceId} is not a PDF. Marking as COMPLETED with DIGITAL_TEXT.`);
        await db_1.prisma.resource.update({
            where: { id: resourceId },
            data: {
                processingStatus: 'COMPLETED',
                extractionMethod: 'DIGITAL_TEXT',
                totalPages: 1,
                processedPages: 1,
                processingProgress: 100,
                processedAt: new Date(),
                processingMetadata: JSON.stringify({ note: 'Non-PDF document, metadata stored.' }),
            },
        });
        return;
    }
    const tmpDir = os_1.default.tmpdir();
    const inputPdfPath = path_1.default.join(tmpDir, `abuad_res_${resourceId}_${Date.now()}.pdf`);
    const outputJsonPath = path_1.default.join(tmpDir, `abuad_res_${resourceId}_${Date.now()}_out.json`);
    try {
        // Stage 1 & 2: Obtain PDF bytes
        if (fileBuffer && fileBuffer.length > 0) {
            fs_1.default.writeFileSync(inputPdfPath, fileBuffer);
        }
        else {
            // Download from R2 or URL
            await downloadPdfFile(resource.fileUrl, inputPdfPath);
        }
        // Stage 3: Update DB to EXTRACTING
        await db_1.prisma.resource.update({
            where: { id: resourceId },
            data: {
                processingStatus: 'EXTRACTING',
                processingProgress: 10,
                processingError: null,
            },
        });
        // Stage 4: Run python PDF & OCR script
        const scriptPath = getScriptPath();
        const pythonExe = getPythonExecutable();
        await runPythonProcessor(pythonExe, scriptPath, inputPdfPath, outputJsonPath, resourceId);
        // Stage 5: Read and parse output JSON
        if (!fs_1.default.existsSync(outputJsonPath)) {
            throw new Error('PDF processing worker produced no output.');
        }
        const rawJson = fs_1.default.readFileSync(outputJsonPath, 'utf-8');
        const output = JSON.parse(rawJson);
        if (!output.success) {
            await db_1.prisma.resource.update({
                where: { id: resourceId },
                data: {
                    processingStatus: 'FAILED',
                    processingError: output.error || 'Failed to extract readable text from document',
                    processingProgress: 100,
                    totalPages: output.totalPages || 0,
                    processedPages: output.processedPages || 0,
                    extractionMethod: output.extractionMethod || 'NONE',
                    processingMetadata: JSON.stringify(output.metadata || {}),
                    processedAt: new Date(),
                },
            });
            return;
        }
        const fullText = (output.text || '').trim();
        let extractedTextToStore = fullText;
        let storageKey = null;
        // If text exceeds 80,000 chars, upload full text to Cloudflare R2
        if (fullText.length > 80000) {
            storageKey = `resources/extracted-text/${resourceId}.txt`;
            try {
                await cloudflare_1.r2Client.send(new client_s3_1.PutObjectCommand({
                    Bucket: cloudflare_1.r2BucketName,
                    Key: storageKey,
                    Body: Buffer.from(fullText, 'utf-8'),
                    ContentType: 'text/plain; charset=utf-8',
                }));
                // Store truncated preview in Postgres to keep DB lean
                extractedTextToStore = fullText.slice(0, 50000) + `\n\n[... Text continues in full storage (${fullText.length} characters) ...]`;
            }
            catch (r2Err) {
                console.warn(`[ResourceProcessor] Could not save full text to R2 key ${storageKey}:`, r2Err);
                storageKey = null;
                extractedTextToStore = fullText.slice(0, 100000);
            }
        }
        // Stage 6: Update DB record with completed data
        await db_1.prisma.resource.update({
            where: { id: resourceId },
            data: {
                processingStatus: 'COMPLETED',
                extractionMethod: output.extractionMethod,
                extractedText: extractedTextToStore,
                extractedTextStorageKey: storageKey,
                totalPages: output.totalPages || 0,
                processedPages: output.processedPages || 0,
                processingProgress: 100,
                processingError: null,
                processedAt: new Date(),
                processingMetadata: JSON.stringify(output.metadata || {}),
            },
        });
        console.log(`[ResourceProcessor] Successfully processed resource ${resourceId}: method=${output.extractionMethod}, words=${output.metadata?.wordCount}`);
    }
    finally {
        // Safe cleanup of temporary files
        if (fs_1.default.existsSync(inputPdfPath)) {
            try {
                fs_1.default.unlinkSync(inputPdfPath);
            }
            catch (_) { }
        }
        if (fs_1.default.existsSync(outputJsonPath)) {
            try {
                fs_1.default.unlinkSync(outputJsonPath);
            }
            catch (_) { }
        }
    }
}
/**
 * Download PDF from Cloudflare R2 or HTTP URL to local path
 */
async function downloadPdfFile(fileUrl, destPath) {
    const r2Key = (0, cloudflare_1.extractR2Key)(fileUrl);
    if (r2Key) {
        try {
            const getCmd = new client_s3_1.GetObjectCommand({
                Bucket: cloudflare_1.r2BucketName,
                Key: r2Key,
            });
            const response = await cloudflare_1.r2Client.send(getCmd);
            if (response.Body) {
                const stream = response.Body;
                const chunks = [];
                for await (const chunk of stream) {
                    chunks.push(typeof chunk === 'string' ? Buffer.from(chunk) : chunk);
                }
                fs_1.default.writeFileSync(destPath, Buffer.concat(chunks));
                return;
            }
        }
        catch (r2Err) {
            console.warn(`[ResourceProcessor] R2 GetObject failed for key ${r2Key}, falling back to HTTP fetch:`, r2Err);
        }
    }
    // Fallback to fetch from URL
    const res = await fetch(fileUrl);
    if (!res.ok) {
        throw new Error(`Failed to download PDF from URL: ${res.status} ${res.statusText}`);
    }
    const arrayBuffer = await res.arrayBuffer();
    fs_1.default.writeFileSync(destPath, Buffer.from(arrayBuffer));
}
/**
 * Spawn the Python processor script and stream progress back to DB
 */
function runPythonProcessor(pythonExe, scriptPath, inputPath, outputPath, resourceId) {
    return new Promise((resolve, reject) => {
        const proc = (0, child_process_1.spawn)(pythonExe, [
            scriptPath,
            '--input', inputPath,
            '--output', outputPath,
        ]);
        let stderrBuffer = '';
        proc.stdout.on('data', (data) => {
            const lines = data.toString().split('\n');
            for (const line of lines) {
                if (line.includes('__PROGRESS__')) {
                    const match = line.match(/__PROGRESS__(.*?)__PROGRESS__/);
                    if (match && match[1]) {
                        try {
                            const pData = JSON.parse(match[1]);
                            updateLiveProgress(resourceId, pData).catch(() => { });
                        }
                        catch (_) { }
                    }
                }
            }
        });
        proc.stderr.on('data', (data) => {
            stderrBuffer += data.toString();
        });
        proc.on('close', (code) => {
            if (code === 0) {
                resolve();
            }
            else {
                reject(new Error(`Python PDF processor exited with code ${code}: ${stderrBuffer}`));
            }
        });
        proc.on('error', (err) => {
            reject(new Error(`Failed to start Python PDF processor: ${err.message}`));
        });
    });
}
/**
 * Incrementally update progress in DB
 */
async function updateLiveProgress(resourceId, progress) {
    try {
        const updateData = {
            processingProgress: Math.min(99, Math.max(5, progress.percent)),
            processedPages: progress.page,
            totalPages: progress.totalPages,
        };
        if (progress.stage === 'RUNNING_OCR') {
            updateData.processingStatus = 'RUNNING_OCR';
        }
        else if (progress.stage === 'EXTRACTING') {
            updateData.processingStatus = 'EXTRACTING';
        }
        await db_1.prisma.resource.update({
            where: { id: resourceId },
            data: updateData,
        });
    }
    catch (_) { }
}
/**
 * Retrieve the full extracted text for a resource (resolves from R2 if stored separately)
 */
async function getResourceExtractedText(resourceId) {
    const resource = await db_1.prisma.resource.findUnique({
        where: { id: resourceId },
        select: {
            extractedText: true,
            extractedTextStorageKey: true,
            processingStatus: true,
            processingError: true,
        },
    });
    if (!resource)
        return null;
    // If text is stored separately in R2
    if (resource.extractedTextStorageKey) {
        try {
            const response = await cloudflare_1.r2Client.send(new client_s3_1.GetObjectCommand({
                Bucket: cloudflare_1.r2BucketName,
                Key: resource.extractedTextStorageKey,
            }));
            if (response.Body) {
                const stream = response.Body;
                const chunks = [];
                for await (const chunk of stream) {
                    chunks.push(typeof chunk === 'string' ? Buffer.from(chunk) : chunk);
                }
                return Buffer.concat(chunks).toString('utf-8');
            }
        }
        catch (r2Err) {
            console.warn(`[ResourceProcessor] Could not load text from R2 (${resource.extractedTextStorageKey}):`, r2Err);
        }
    }
    return resource.extractedText || null;
}
