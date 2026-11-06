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
  const allStickers = await queryNeon('SELECT id, title, category, "isPublic", "authorId" FROM "Sticker";');
  console.log('Total stickers in DB:', allStickers.rows.length);
  console.log('Categories:', allStickers.rows.map(r => r.category).reduce((acc, c) => { acc[c] = (acc[c]||0)+1; return acc; }, {}));
  console.log('isPublic:', allStickers.rows.map(r => r.isPublic).reduce((acc, c) => { acc[c] = (acc[c]||0)+1; return acc; }, {}));
  const sample = allStickers.rows.slice(0, 10);
  console.log('Sample rows:', sample);
}

main().catch(console.error);
