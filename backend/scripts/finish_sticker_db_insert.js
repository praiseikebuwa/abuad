const dns = require('dns');
dns.setServers(['8.8.8.8', '1.1.1.1', '8.8.4.4']);

const path = require('path');
const fs = require('fs');
const https = require('https');
const crypto = require('crypto');

const env = fs.readFileSync('backend/.env', 'utf8');
let dbUrl = '';
for (const line of env.split('\n')) {
  if (line.startsWith('DATABASE_URL=')) {
    dbUrl = line.substring('DATABASE_URL='.length).trim().replace(/^["']|["']$/g, '');
    break;
  }
}

const publicDomain = 'https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev';
const neonHttpUrl = 'https://ep-snowy-water-b5xasgwi-pooler.c-7.us-east-2.aws.neon.tech/sql';
const adminAuthorId = '99eddbe8-0295-498c-b6cf-b78b93c06537';
const CATEGORIES = ['CAMPUS', 'MEME', 'REACTION', 'STUDY', 'TRENDING'];

function queryNeon(sql) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({ query: sql });
    const req = https.request(neonHttpUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Neon-Connection-String': dbUrl,
      }
    }, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(body);
          if (json.message) reject(new Error(json.message));
          else resolve(json);
        } catch(e) {
          reject(new Error(body));
        }
      });
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

async function main() {
  const existingRes = await queryNeon('SELECT "imageUrl" FROM "Sticker";');
  const existingUrls = new Set(existingRes.rows.map(r => r.imageUrl));
  console.log(`Already in DB: ${existingUrls.size} stickers.`);

  const folder = 'C:\\Users\\pikeb\\Desktop\\abuad\\sticker';
  const files = fs.readdirSync(folder).filter(f => !f.startsWith('.'));
  console.log(`Total files in sticker folder: ${files.length}`);

  const toInsert = [];
  for (let i = 0; i < files.length; i++) {
    const file = files[i];
    const safeKeyName = file.replace(/[^a-zA-Z0-9._-]/g, '_');
    const destKey = `uploads/stickers/${safeKeyName}`;
    const publicUrl = `${publicDomain}/${destKey}`;

    if (existingUrls.has(publicUrl)) {
      continue;
    }

    const filePath = path.join(folder, file);
    const ext = path.extname(file).toLowerCase() || '.webp';
    const stat = fs.statSync(filePath);

    let rawName = path.basename(file, ext);
    if (rawName.includes('~')) rawName = rawName.split('~')[0];
    let cleanTitle = rawName.replace(/[_-]+/g, ' ').replace(/\s+/g, ' ').trim();
    if (cleanTitle.toLowerCase().startsWith('sticker')) {
      cleanTitle = cleanTitle.replace(/^sticker\s*/i, 'Campus Vibe ');
    }
    cleanTitle = cleanTitle.charAt(0).toUpperCase() + cleanTitle.slice(1);
    if (cleanTitle.length > 35) cleanTitle = cleanTitle.substring(0, 35);
    if (!cleanTitle) cleanTitle = 'Campus Sticker';

    const id = crypto.randomUUID();
    const category = CATEGORIES[i % CATEGORIES.length];
    const type = stat.size > 50000 ? 'ANIMATED' : 'STATIC';
    const usageCount = Math.floor(Math.random() * 80) + 10;

    toInsert.push({
      id,
      title: cleanTitle,
      imageUrl: publicUrl,
      animatedUrl: type === 'ANIMATED' ? publicUrl : null,
      type,
      category,
      tags: ['abuad', category.toLowerCase(), 'sticker'],
      usageCount,
    });
  }

  console.log(`Found ${toInsert.length} stickers remaining to insert into DB.`);
  if (toInsert.length === 0) {
    console.log('All stickers are already in DB!');
    return;
  }

  const BATCH = 30;
  for (let b = 0; b < toInsert.length; b += BATCH) {
    const chunk = toInsert.slice(b, b + BATCH);
    const valueClauses = chunk.map(s => {
      const titleEscaped = s.title.replace(/'/g, "''");
      const animSql = s.animatedUrl ? `'${s.animatedUrl}'` : 'NULL';
      const tagsSql = `ARRAY[${s.tags.map(t => `'${t}'`).join(',')}]::text[]`;
      return `('${s.id}', '${titleEscaped}', '${s.imageUrl}', ${animSql}, '${s.type}', '${s.category}', ${tagsSql}, true, ${s.usageCount}, '${adminAuthorId}', NOW(), NOW())`;
    }).join(',\n');

    const sql = `
      INSERT INTO "Sticker" (
        id, title, "imageUrl", "animatedUrl", type, category, tags, "isPublic", "usageCount", "authorId", "createdAt", "updatedAt"
      ) VALUES
      ${valueClauses}
      ON CONFLICT (id) DO NOTHING;
    `;

    await queryNeon(sql);
    console.log(`Inserted batch ${b + chunk.length} / ${toInsert.length}`);
  }

  const finalRes = await queryNeon('SELECT COUNT(*) FROM "Sticker";');
  console.log(`DONE! Total stickers in DB: ${finalRes.rows[0].count}`);
}

main().catch(console.error);
