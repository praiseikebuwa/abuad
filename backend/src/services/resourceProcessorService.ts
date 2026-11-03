import fs from 'fs';
import path from 'path';
import os from 'os';
import { spawn } from 'child_process';
import { prisma } from '../config/db';
import { r2Client, r2BucketName, extractR2Key } from '../config/cloudflare';
import { GetObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';

// Determine the best Python executable on the host
function getPythonExecutable(): string {
  if (process.env.PYTHON_PATH && fs.existsSync(process.env.PYTHON_PATH)) {
    return process.env.PYTHON_PATH;
  }
  
  // Standard Windows WindowsApps Python 3.12 path where PyMuPDF/pytesseract are installed
  const windowsAppsPython = path.join(
    process.env.LOCALAPPDATA || 'C:\\Users\\pikeb\\AppData\\Local',
    'Microsoft\\WindowsApps\\python.exe'
  );
  if (fs.existsSync(windowsAppsPython)) {
    return windowsAppsPython;
  }

  // Fallbacks
  return process.platform === 'win32' ? 'python.exe' : 'python3';
}

const activeJobIds = new Set<string>();
const jobQueue: { resourceId: string; fileBuffer?: Buffer; force?: boolean }[] = [];
let isQueueWorkerRunning = false;

/**
 * Enqueue a resource for asynchronous OCR and text processing
 */
export async function enqueueResourceProcessing(
  resourceId: string,
  fileBuffer?: Buffer,
  options?: { force?: boolean }
): Promise<void> {
  // Prevent duplicate queuing if already running or queued
  if (activeJobIds.has(resourceId)) {
    console.log(`[ResourceProcessor] Resource ${resourceId} is already actively processing.`);
    return;
  }

  // Update resource status in DB to PENDING
  try {
    await prisma.resource.update({
      where: { id: resourceId },
      data: {
        processingStatus: 'PENDING',
        processingProgress: 0,
        processingError: null,
      },
    });
  } catch (dbErr) {
    console.warn(`[ResourceProcessor] Failed to set PENDING status for ${resourceId}:`, dbErr);
  }

  jobQueue.push({ resourceId, fileBuffer, force: options?.force });
  triggerQueueWorker();
}

/**
 * Worker loop that processes jobs sequentially to manage server CPU/memory safely
 */
async function triggerQueueWorker() {
  if (isQueueWorkerRunning) return;
  isQueueWorkerRunning = true;

  try {
    while (jobQueue.length > 0) {
      const job = jobQueue.shift();
      if (!job) break;

      activeJobIds.add(job.resourceId);
      try {
        await executeProcessing(job.resourceId, job.fileBuffer, { force: job.force });
      } catch (err: any) {
        console.error(`[ResourceProcessor] Job failed for resource ${job.resourceId}:`, err);
        try {
          await prisma.resource.update({
            where: { id: job.resourceId },
            data: {
              processingStatus: 'FAILED',
              processingError: err.message || 'Background processing failed',
              processingProgress: 100,
            },
          });
        } catch (_) {}
      } finally {
        activeJobIds.delete(job.resourceId);
      }
    }
  } finally {
    isQueueWorkerRunning = false;
  }
}

/**
 * Execute the end-to-end PDF processing pipeline for a given resource
 */
async function executeProcessing(
  resourceId: string,
  fileBuffer?: Buffer,
  options?: { force?: boolean }
): Promise<void> {
  const resource = await prisma.resource.findUnique({
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
    await prisma.resource.update({
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

  const tmpDir = os.tmpdir();
  const inputPdfPath = path.join(tmpDir, `abuad_res_${resourceId}_${Date.now()}.pdf`);
  const outputJsonPath = path.join(tmpDir, `abuad_res_${resourceId}_${Date.now()}_out.json`);

  try {
    // Stage 1 & 2: Obtain PDF bytes
    if (fileBuffer && fileBuffer.length > 0) {
      fs.writeFileSync(inputPdfPath, fileBuffer);
    } else {
      // Download from R2 or URL
      await downloadPdfFile(resource.fileUrl, inputPdfPath);
    }

    // Stage 3: Update DB to EXTRACTING
    await prisma.resource.update({
      where: { id: resourceId },
      data: {
        processingStatus: 'EXTRACTING',
        processingProgress: 10,
        processingError: null,
      },
    });

    // Stage 4: Run python PDF & OCR script
    const scriptPath = path.resolve(__dirname, '../../scripts/pdf_processor.py');
    const pythonExe = getPythonExecutable();

    await runPythonProcessor(pythonExe, scriptPath, inputPdfPath, outputJsonPath, resourceId);

    // Stage 5: Read and parse output JSON
    if (!fs.existsSync(outputJsonPath)) {
      throw new Error('PDF processing worker produced no output.');
    }

    const rawJson = fs.readFileSync(outputJsonPath, 'utf-8');
    const output = JSON.parse(rawJson);

    if (!output.success) {
      await prisma.resource.update({
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
    let storageKey: string | null = null;

    // If text exceeds 80,000 chars, upload full text to Cloudflare R2
    if (fullText.length > 80000) {
      storageKey = `resources/extracted-text/${resourceId}.txt`;
      try {
        await r2Client.send(
          new PutObjectCommand({
            Bucket: r2BucketName,
            Key: storageKey,
            Body: Buffer.from(fullText, 'utf-8'),
            ContentType: 'text/plain; charset=utf-8',
          })
        );
        // Store truncated preview in Postgres to keep DB lean
        extractedTextToStore = fullText.slice(0, 50000) + `\n\n[... Text continues in full storage (${fullText.length} characters) ...]`;
      } catch (r2Err) {
        console.warn(`[ResourceProcessor] Could not save full text to R2 key ${storageKey}:`, r2Err);
        storageKey = null;
        extractedTextToStore = fullText.slice(0, 100000);
      }
    }

    // Stage 6: Update DB record with completed data
    await prisma.resource.update({
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
  } finally {
    // Safe cleanup of temporary files
    if (fs.existsSync(inputPdfPath)) {
      try { fs.unlinkSync(inputPdfPath); } catch (_) {}
    }
    if (fs.existsSync(outputJsonPath)) {
      try { fs.unlinkSync(outputJsonPath); } catch (_) {}
    }
  }
}

/**
 * Download PDF from Cloudflare R2 or HTTP URL to local path
 */
async function downloadPdfFile(fileUrl: string, destPath: string): Promise<void> {
  const r2Key = extractR2Key(fileUrl);
  if (r2Key) {
    try {
      const getCmd = new GetObjectCommand({
        Bucket: r2BucketName,
        Key: r2Key,
      });
      const response = await r2Client.send(getCmd);
      if (response.Body) {
        const stream = response.Body as any;
        const chunks: Buffer[] = [];
        for await (const chunk of stream) {
          chunks.push(typeof chunk === 'string' ? Buffer.from(chunk) : chunk);
        }
        fs.writeFileSync(destPath, Buffer.concat(chunks));
        return;
      }
    } catch (r2Err) {
      console.warn(`[ResourceProcessor] R2 GetObject failed for key ${r2Key}, falling back to HTTP fetch:`, r2Err);
    }
  }

  // Fallback to fetch from URL
  const res = await fetch(fileUrl);
  if (!res.ok) {
    throw new Error(`Failed to download PDF from URL: ${res.status} ${res.statusText}`);
  }
  const arrayBuffer = await res.arrayBuffer();
  fs.writeFileSync(destPath, Buffer.from(arrayBuffer));
}

/**
 * Spawn the Python processor script and stream progress back to DB
 */
function runPythonProcessor(
  pythonExe: string,
  scriptPath: string,
  inputPath: string,
  outputPath: string,
  resourceId: string
): Promise<void> {
  return new Promise((resolve, reject) => {
    const proc = spawn(pythonExe, [
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
              updateLiveProgress(resourceId, pData).catch(() => {});
            } catch (_) {}
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
      } else {
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
async function updateLiveProgress(
  resourceId: string,
  progress: { stage: string; page: number; totalPages: number; percent: number; extra?: string }
) {
  try {
    const updateData: any = {
      processingProgress: Math.min(99, Math.max(5, progress.percent)),
      processedPages: progress.page,
      totalPages: progress.totalPages,
    };

    if (progress.stage === 'RUNNING_OCR') {
      updateData.processingStatus = 'RUNNING_OCR';
    } else if (progress.stage === 'EXTRACTING') {
      updateData.processingStatus = 'EXTRACTING';
    }

    await prisma.resource.update({
      where: { id: resourceId },
      data: updateData,
    });
  } catch (_) {}
}

/**
 * Retrieve the full extracted text for a resource (resolves from R2 if stored separately)
 */
export async function getResourceExtractedText(resourceId: string): Promise<string | null> {
  const resource = await prisma.resource.findUnique({
    where: { id: resourceId },
    select: {
      extractedText: true,
      extractedTextStorageKey: true,
      processingStatus: true,
      processingError: true,
    },
  });

  if (!resource) return null;

  // If text is stored separately in R2
  if (resource.extractedTextStorageKey) {
    try {
      const response = await r2Client.send(
        new GetObjectCommand({
          Bucket: r2BucketName,
          Key: resource.extractedTextStorageKey,
        })
      );
      if (response.Body) {
        const stream = response.Body as any;
        const chunks: Buffer[] = [];
        for await (const chunk of stream) {
          chunks.push(typeof chunk === 'string' ? Buffer.from(chunk) : chunk);
        }
        return Buffer.concat(chunks).toString('utf-8');
      }
    } catch (r2Err) {
      console.warn(`[ResourceProcessor] Could not load text from R2 (${resource.extractedTextStorageKey}):`, r2Err);
    }
  }

  return resource.extractedText || null;
}
