const fs = require('fs');
const env = fs.readFileSync('backend/.env', 'utf8');
for (const line of env.split('\n')) {
  if (line.startsWith('DATABASE_URL=')) {
    const val = line.substring(13).trim().replace(/^["']|["']$/g, '');
    const u = new URL(val);
    console.log('Host:', u.host);
    console.log('Protocol:', u.protocol);
    console.log('Port:', u.port);
    console.log('Pathname:', u.pathname);
  }
}
