import { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import dotenv from 'dotenv';

dotenv.config();

const accountId = process.env.CLOUDFLARE_ACCOUNT_ID || '';
const accessKeyId = process.env.CLOUDFLARE_R2_ACCESS_KEY_ID || '';
const secretAccessKey = process.env.CLOUDFLARE_R2_SECRET_ACCESS_KEY || '';

export const r2BucketName = process.env.CLOUDFLARE_R2_BUCKET_NAME || 'abuad-media';
export const r2PublicDomain = process.env.CLOUDFLARE_R2_PUBLIC_DOMAIN || '';

// Configure AWS S3 Client targeting Cloudflare R2 endpoint
export const r2Client = new S3Client({
  region: 'auto',
  endpoint: accountId ? `https://${accountId}.r2.cloudflarestorage.com` : undefined,
  credentials: {
    accessKeyId,
    secretAccessKey,
  },
  maxAttempts: 2,
});

/**
 * Generate a pre-signed upload URL for Cloudflare R2 storage
 */
export async function generateR2UploadUrl(key: string, contentType: string, expiresInSeconds = 3600): Promise<string> {
  const command = new PutObjectCommand({
    Bucket: r2BucketName,
    Key: key,
    ContentType: contentType,
  });
  return getSignedUrl(r2Client, command, { expiresIn: expiresInSeconds });
}

/**
 * Generate a short-lived pre-signed download URL for Cloudflare R2 storage
 */
export async function generateR2GetUrl(key: string, expiresInSeconds = 3600): Promise<string> {
  const command = new GetObjectCommand({
    Bucket: r2BucketName,
    Key: key,
  });
  return getSignedUrl(r2Client, command, { expiresIn: expiresInSeconds });
}

/**
 * Extract the R2 object storage key from a full URL or storage path
 */
export function extractR2Key(urlOrKey: string): string | null {
  if (!urlOrKey || typeof urlOrKey !== 'string') return null;
  const trimmed = urlOrKey.trim();
  if (trimmed.startsWith('uploads/')) return trimmed;
  if (trimmed.includes('/uploads/')) {
    const parts = trimmed.split('/uploads/');
    if (parts.length > 1 && parts[1]) {
      return `uploads/${parts[1].split('?')[0]}`;
    }
  }
  return null;
}

/**
 * Permanently delete an object from Cloudflare R2 storage
 */
export async function deleteR2Object(key: string): Promise<boolean> {
  if (!key) return false;
  try {
    const command = new DeleteObjectCommand({
      Bucket: r2BucketName,
      Key: key,
    });
    await r2Client.send(command);
    return true;
  } catch (error) {
    console.error(`Failed to delete R2 object for key "${key}":`, error);
    return false;
  }
}


/**
 * Helper to call Cloudflare Workers AI REST API endpoint
 */
export async function runCloudflareAI(
  promptOrPayload: string | any,
  modelOverride?: string,
  options?: { systemPrompt?: string; stream?: boolean }
): Promise<any> {
  const token = process.env.CLOUDFLARE_AI_API_TOKEN;
  const accountIdEnv = process.env.CLOUDFLARE_ACCOUNT_ID || accountId;
  const model = modelOverride || process.env.CLOUDFLARE_AI_MODEL || '@cf/meta/llama-3.1-8b-instruct';

  if (!token || !accountIdEnv) {
    const promptText = typeof promptOrPayload === 'string' ? promptOrPayload : JSON.stringify(promptOrPayload);
    const isModeration = promptText.includes('content moderation classifier');

    return {
      success: true,
      result: {
        response: isModeration
          ? '{"safe": true}'
          : `[Cloudflare Workers AI Response for prompt: "${promptText}"]`
      }
    };
  }

  const url = `https://api.cloudflare.com/client/v4/accounts/${accountIdEnv}/ai/run/${model}`;

  let body: any;
  if (typeof promptOrPayload === 'string') {
    const messages: Array<{ role: string; content: string }> = [];
    if (options?.systemPrompt && options.systemPrompt.trim()) {
      messages.push({ role: 'system', content: options.systemPrompt.trim() });
    }
    messages.push({ role: 'user', content: promptOrPayload });

    body = {
      messages,
      ...(options?.stream ? { stream: true } : {}),
    };
  } else {
    body = {
      ...promptOrPayload,
      ...(options?.stream ? { stream: true } : {}),
    };
  }

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    if (options?.stream) {
      return response; // Return raw fetch response for streaming piping
    }

    const json = await response.json();
    if (process.env.NODE_ENV === 'development') {
      console.log('Cloudflare AI response:', JSON.stringify(json));
    }
    return json;
  } catch (error) {
    console.error('Cloudflare Workers AI fetch exception:', error);
    return {
      success: false,
      result: {
        response: 'Unable to reach Cloudflare AI. Please try again.'
      }
    };
  }
}

/**
 * Helper to call Cloudflare Workers AI Vision Model with image buffer
 */
export async function runCloudflareAIVision(
  prompt: string,
  imageBuffer: Buffer,
  modelOverride?: string
): Promise<any> {
  const token = process.env.CLOUDFLARE_AI_API_TOKEN;
  const accountIdEnv = process.env.CLOUDFLARE_ACCOUNT_ID || accountId;
  const model = modelOverride || '@cf/meta/llama-3.2-11b-vision-instruct';

  if (!token || !accountIdEnv) {
    const isModeration = prompt.includes('content moderation') || prompt.includes('safety classifier');
    return {
      success: true,
      result: {
        response: isModeration
          ? '{"safe": true}'
          : `[Cloudflare Vision AI Response for prompt: "${prompt}"]`
      }
    };
  }

  const url = `https://api.cloudflare.com/client/v4/accounts/${accountIdEnv}/ai/run/${model}`;
  
  // Convert Node Buffer to Uint8Array byte array required by Cloudflare Vision API
  const imageArray = Array.from(new Uint8Array(imageBuffer));
  const body = {
    prompt,
    image: imageArray,
  };

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    return await response.json();
  } catch (error) {
    console.error('Cloudflare Workers AI Vision exception:', error);
    return {
      success: false,
      error: 'Vision moderation service request failed'
    };
  }
}
