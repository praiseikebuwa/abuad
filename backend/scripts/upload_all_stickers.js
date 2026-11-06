const path = require('path');
const fs = require('fs');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const crypto = require('crypto');

const accountId = process.env.CLOUDFLARE_ACCOUNT_ID;
const accessKeyId = process.env.CLOUDFLARE_R2_ACCESS_KEY_ID;
const secretAccessKey = process.env.CLOUDFLARE_R2_SECRET_ACCESS_KEY;
const bucketName = process.env.CLOUDFLARE_R2_BUCKET_NAME || 'abuad';
const publicDomain = process.env.CLOUDFLARE_R2_PUBLIC_DOMAIN || 'https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev';
const dbUrl = process.env.DATABASE_URL;
const neonHttpUrl = 'https://ep-snowy-water-b5xasgwi-pooler.c-7.us-east-2.aws.neon.tech/sql';
const adminAuthorId = '99eddbe8-0295-498c-b6cf-b78b93c06537';

const r2Client = new S3Client({
  region: 'auto',
  endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
  credentials: { accessKeyId, secretAccessKey },
  forcePathStyle: true,
  maxAttempts: 3,
});

async function queryNeon(sql) {
  const res = await fetch(neonHttpUrl, {
    method: 'POST',
    headers: {
      'Neon-Connection-String': dbUrl,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query: sql }),
  });
  const data = await res.json();
  if (data.message) throw new Error(data.message);
  return data;
}

const CATEGORIES = ['CAMPUS', 'MEME', 'REACTION', 'STUDY', 'TRENDING'];

async function putObjectWithRetry(params, maxRetries = 3) {
  for (let a = 0; a < maxRetries; a++) {
    try {
      await r2Client.send(new PutObjectCommand(params));
      return;
    } catch (err) {
      if (a === maxRetries - 1) throw err;
      await new Promise((r) => setTimeout(r, 200 * (a + 1)));
    }
  }
}

async function processFolder() {
  const folder = 'C:\\Users\\pikeb\\Desktop\\abuad\\sticker';
  const files = fs.readdirSync(folder).filter((f) => !f.startsWith('.'));
  console.log(`Found ${files.length} stickers to process from ${folder}`);

  const CONCURRENCY = 5;
  let completed = 0;
  const dbRecords = [];

  for (let i = 0; i < files.length; i += CONCURRENCY) {
    const chunk = files.slice(i, i + CONCURRENCY);
    await Promise.all(
      chunk.map(async (file, chunkIndex) => {
        try {
          const filePath = path.join(folder, file);
          const ext = path.extname(file).toLowerCase() || '.webp';
          const fileBytes = fs.readFileSync(filePath);
          const mimeType = ext === '.jpg' || ext === '.jpeg' ? 'image/jpeg' : 'image/webp';

          // Clean title
          let rawName = path.basename(file, ext);
          if (rawName.includes('~')) rawName = rawName.split('~')[0];
          let cleanTitle = rawName
            .replace(/[_-]+/g, ' ')
            .replace(/\s+/g, ' ')
            .trim();
          if (cleanTitle.toLowerCase().startsWith('sticker')) {
            cleanTitle = cleanTitle.replace(/^sticker\s*/i, 'Campus Vibe ');
          }
          cleanTitle = cleanTitle.charAt(0).toUpperCase() + cleanTitle.slice(1);
          if (cleanTitle.length > 35) cleanTitle = cleanTitle.substring(0, 35);

          const safeKeyName = file.replace(/[^a-zA-Z0-9._-]/g, '_');
          const destKey = `uploads/stickers/${safeKeyName}`;

          await putObjectWithRetry({
            Bucket: bucketName,
            Key: destKey,
            Body: fileBytes,
            ContentType: mimeType,
          });

          const publicUrl = `${publicDomain}/${destKey}`;
          const id = crypto.randomUUID();
          const category = CATEGORIES[(completed + chunkIndex) % CATEGORIES.length];
          const type = fileBytes.length > 50000 ? 'ANIMATED' : 'STATIC';
          const usageCount = Math.floor(Math.random() * 80) + 10;

          dbRecords.push({
            id,
            title: cleanTitle,
            imageUrl: publicUrl,
            animatedUrl: type === 'ANIMATED' ? publicUrl : null,
            type,
            category,
            tags: ['abuad', category.toLowerCase(), 'sticker'],
            usageCount,
          });

          completed++;
        } catch (e) {
          console.error(`Error uploading ${file}:`, e.message);
        }
      })
    );

    if (completed % 50 === 0 || completed === files.length) {
      console.log(`Uploaded ${completed}/${files.length} to R2...`);
    }
  }

  console.log(`R2 uploads finished: ${dbRecords.length} files. Inserting into Neon PostgreSQL...`);

  // Batch insert into DB in chunks of 50
  const DB_CHUNK_SIZE = 50;
  for (let j = 0; j < dbRecords.length; j += DB_CHUNK_SIZE) {
    const chunk = dbRecords.slice(j, j + DB_CHUNK_SIZE);
    const valueClauses = chunk
      .map((s) => {
        const titleEscaped = s.title.replace(/'/g, "''");
        const animSql = s.animatedUrl ? `'${s.animatedUrl}'` : 'NULL';
        const tagsSql = `ARRAY[${s.tags.map((t) => `'${t}'`).join(',')}]::text[]`;
        return `('${s.id}', '${titleEscaped}', '${s.imageUrl}', ${animSql}, '${s.type}', '${s.category}', ${tagsSql}, true, ${s.usageCount}, '${adminAuthorId}', NOW(), NOW())`;
      })
      .join(',\n');

    const sql = `
      INSERT INTO "Sticker" (
        id, title, "imageUrl", "animatedUrl", type, category, tags, "isPublic", "usageCount", "authorId", "createdAt", "updatedAt"
      ) VALUES
      ${valueClauses}
      ON CONFLICT (id) DO NOTHING;
    `;

    try {
      await queryNeon(sql);
      console.log(`Inserted DB chunk ${Math.floor(j / DB_CHUNK_SIZE) + 1} (${j + chunk.length}/${dbRecords.length}).`);
    } catch (e) {
      console.error(`DB Insert Chunk Error at index ${j}:`, e.message);
    }
  }

  const check = await queryNeon('SELECT count(*) FROM "Sticker";');
  console.log(`SUCCESS: Database now holds a total of ${check.rows[0].count} stickers!`);
}

processFolder().catch((e) => {
  console.error('Fatal execution error:', e);
  process.exit(1);
});
