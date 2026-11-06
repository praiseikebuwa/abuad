const path = require('path');
const fs = require('fs');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');

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

async function uploadFile(filePath, destKey, mimeType) {
  const fileBytes = fs.readFileSync(filePath);
  const command = new PutObjectCommand({
    Bucket: bucketName,
    Key: destKey,
    Body: fileBytes,
    ContentType: mimeType,
  });
  await r2Client.send(command);
  const publicUrl = `${publicDomain}/${destKey}`;
  return publicUrl;
}

if (process.argv.length >= 5) {
  const filePath = process.argv[2];
  const destKey = process.argv[3];
  const mimeType = process.argv[4];

  uploadFile(filePath, destKey, mimeType)
    .then((url) => {
      console.log(JSON.stringify({ success: true, url }));
      process.exit(0);
    })
    .catch((err) => {
      console.error(JSON.stringify({ success: false, error: err.message }));
      process.exit(1);
    });
} else {
  module.exports = { uploadFile };
}
