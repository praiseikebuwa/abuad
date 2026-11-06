const path = require('path');
const fs = require('fs');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { PrismaClient } = require('@prisma/client');

const accountId = process.env.CLOUDFLARE_ACCOUNT_ID;
const accessKeyId = process.env.CLOUDFLARE_R2_ACCESS_KEY_ID;
const secretAccessKey = process.env.CLOUDFLARE_R2_SECRET_ACCESS_KEY;
const bucketName = process.env.CLOUDFLARE_R2_BUCKET_NAME || 'abuad';
const publicDomain = process.env.CLOUDFLARE_R2_PUBLIC_DOMAIN || 'https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev';

const r2Client = new S3Client({
  region: 'auto',
  endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
  credentials: { accessKeyId, secretAccessKey },
  forcePathStyle: true,
  maxAttempts: 3,
});

async function main() {
  const inputPath = path.join(__dirname, 'batch_input.json');
  if (!fs.existsSync(inputPath)) {
    throw new Error('batch_input.json not found');
  }

  const manifest = JSON.parse(fs.readFileSync(inputPath, 'utf8'));
  const results = [];

  // Seed usage counts nicely between 40 and 250 so they naturally rank in Trending
  let baseUsage = 250;

  for (const item of manifest) {
    const fileBytes = fs.readFileSync(item.local_path);
    const ext = path.extname(item.filename).toLowerCase() || (item.format === 'JPEG' ? '.jpg' : '.webp');
    const safeTitle = item.title.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
    const destKey = `uploads/stickers/${safeTitle}_${Date.now() % 100000}${ext}`;
    const mimeType = ext === '.jpg' || ext === '.jpeg' ? 'image/jpeg' : 'image/webp';

    const command = new PutObjectCommand({
      Bucket: bucketName,
      Key: destKey,
      Body: fileBytes,
      ContentType: mimeType,
    });

    await r2Client.send(command);
    const publicUrl = `${publicDomain}/${destKey}`;

    const stickerRecord = {
      id: `stk_${safeTitle}_${Math.random().toString(36).substring(2, 8)}`,
      title: item.title,
      imageUrl: publicUrl,
      animatedUrl: item.is_animated ? publicUrl : null,
      type: item.type,
      category: item.category,
      tags: item.tags,
      isPublic: true,
      usageCount: baseUsage,
      authorId: 'system_curated_stickers',
      authorName: 'ABUAD Campus Stickers',
      createdAt: new Date().toISOString(),
      constraints: item.constraints,
    };

    baseUsage = Math.max(15, baseUsage - 5);
    results.push(stickerRecord);
  }

  // Update backend/src/routes/stickers.ts DEFAULT_STICKERS so they are baked in
  try {
    const routesPath = path.join(__dirname, '..', 'src', 'routes', 'stickers.ts');
    let routesContent = fs.readFileSync(routesPath, 'utf8');

    const serializedStickers = JSON.stringify(
      results.map((s) => ({
        id: s.id,
        title: s.title,
        imageUrl: s.imageUrl,
        animatedUrl: s.animatedUrl || undefined,
        type: s.type,
        category: s.category,
        tags: s.tags,
        isPublic: s.isPublic,
        usageCount: s.usageCount,
        authorId: s.authorId,
        authorName: s.authorName,
        createdAt: s.createdAt,
      })),
      null,
      2
    );

    const regex = /const DEFAULT_STICKERS:\s*LocalSticker\[\]\s*=\s*\[[\s\S]*?\];/;
    if (regex.test(routesContent)) {
      routesContent = routesContent.replace(
        regex,
        `const DEFAULT_STICKERS: LocalSticker[] = ${serializedStickers};`
      );
      fs.writeFileSync(routesPath, routesContent, 'utf8');
    }
  } catch (err) {
    // Non-fatal
  }

  // Direct database insert via Neon HTTPS SQL API
  try {
    const dbUrl = process.env.DATABASE_URL;
    const neonHttpUrl = 'https://ep-snowy-water-b5xasgwi-pooler.c-7.us-east-2.aws.neon.tech/sql';
    const adminAuthorId = '99eddbe8-0295-498c-b6cf-b78b93c06537';

    for (const s of results) {
      try {
        const titleEscaped = s.title.replace(/'/g, "''");
        const animatedUrlVal = s.animatedUrl ? `'${s.animatedUrl}'` : 'NULL';
        const tagsSql = `ARRAY[${s.tags.map((t) => `'${t.replace(/'/g, "''")}'`).join(',')}]::text[]`;

        const sql = `
          INSERT INTO "Sticker" (
            id, title, "imageUrl", "animatedUrl", type, category, tags, "isPublic", "usageCount", "authorId", "createdAt", "updatedAt"
          ) VALUES (
            '${s.id}', '${titleEscaped}', '${s.imageUrl}', ${animatedUrlVal}, '${s.type}', '${s.category}', ${tagsSql}, true, ${s.usageCount}, '${adminAuthorId}', NOW(), NOW()
          )
          ON CONFLICT (id) DO UPDATE SET
            title = EXCLUDED.title,
            "imageUrl" = EXCLUDED."imageUrl",
            "animatedUrl" = EXCLUDED."animatedUrl",
            type = EXCLUDED.type,
            category = EXCLUDED.category,
            tags = EXCLUDED.tags,
            "usageCount" = EXCLUDED."usageCount",
            "updatedAt" = NOW();
        `;

        await fetch(neonHttpUrl, {
          method: 'POST',
          headers: {
            'Neon-Connection-String': dbUrl,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ query: sql }),
        });
      } catch (_) {}
    }
  } catch (err) {
    // Non-fatal
  }

  console.log(JSON.stringify(results));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
