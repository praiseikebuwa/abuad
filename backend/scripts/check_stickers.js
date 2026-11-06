const https = require('https');
const fs = require('fs');

const env = fs.readFileSync('backend/.env', 'utf8');
let dbUrl = '';
for (const line of env.split('\n')) {
  if (line.startsWith('DATABASE_URL=')) {
    dbUrl = line.substring('DATABASE_URL='.length).trim().replace(/^["']|["']$/g, '');
    break;
  }
}

function queryNeon(sql) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({ query: sql });
    const req = https.request('https://ep-snowy-water-b5xasgwi-pooler.c-7.us-east-2.aws.neon.tech/sql', {
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
          resolve(JSON.parse(body));
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
  const countRes = await queryNeon('SELECT COUNT(*) FROM "Sticker";');
  console.log('Sticker count:', countRes);
  const sample = await queryNeon('SELECT id, name, "packId", "imageUrl", tags FROM "Sticker" LIMIT 5;');
  console.log('Sample stickers:', sample);
  const packs = await queryNeon('SELECT id, name, "isOfficial" FROM "StickerPack";');
  console.log('Sticker packs:', packs);
}

main().catch(console.error);
