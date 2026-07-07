const crypto = require('crypto');
const fs = require('fs');
const https = require('https');

// Read configurations from environment variables
const serviceAccountJson = process.env.SERVICE_ACCOUNT_JSON;
const csvPath = process.env.CSV_PATH || './play_store/data_safety.csv';
const packageName = process.env.PACKAGE_NAME || 'com.mweastwood.nothing_ever_happens';

if (!serviceAccountJson) {
  console.error('ERROR: SERVICE_ACCOUNT_JSON environment variable is missing.');
  process.exit(1);
}

if (!fs.existsSync(csvPath)) {
  console.error(`ERROR: Data Safety CSV file not found at path: ${csvPath}`);
  process.exit(1);
}

let serviceAccount;
try {
  serviceAccount = JSON.parse(serviceAccountJson);
} catch (e) {
  console.error('ERROR: SERVICE_ACCOUNT_JSON is not a valid JSON string.');
  process.exit(1);
}

const csvContent = fs.readFileSync(csvPath, 'utf8');

// 1. Generate JWT for OAuth Authentication (RS256)
console.log('Generating JWT token for Google Play Developer API authorization...');
const header = Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT' })).toString('base64url');
const iat = Math.floor(Date.now() / 1000);
const exp = iat + 3600;
const payload = Buffer.from(JSON.stringify({
  iss: serviceAccount.client_email,
  scope: 'https://www.googleapis.com/auth/androidpublisher',
  aud: serviceAccount.token_uri || 'https://oauth2.googleapis.com/token',
  exp: exp,
  iat: iat
})).toString('base64url');

let jwt;
try {
  const sign = crypto.createSign('RSA-SHA256');
  sign.update(`${header}.${payload}`);
  const signature = sign.sign(serviceAccount.private_key, 'base64url');
  jwt = `${header}.${payload}.${signature}`;
} catch (e) {
  console.error('ERROR: Failed to sign JWT. Check if private_key in your service account is valid.', e);
  process.exit(1);
}

// 2. Exchange JWT for access token
console.log('Exchanging JWT for Google Play access token...');
const postData = `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`;

const tokenReq = https.request(serviceAccount.token_uri || 'https://oauth2.googleapis.com/token', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/x-www-form-urlencoded',
    'Content-Length': Buffer.byteLength(postData)
  }
}, (res) => {
  let body = '';
  res.on('data', chunk => body += chunk);
  res.on('end', () => {
    let tokenRes;
    try {
      tokenRes = JSON.parse(body);
    } catch (e) {
      console.error('ERROR: Failed to parse Google Play OAuth response:', body);
      process.exit(1);
    }

    if (!tokenRes.access_token) {
      console.error('ERROR: Access token not found in Google Play OAuth response:', tokenRes);
      process.exit(1);
    }

    uploadDataSafety(tokenRes.access_token);
  });
});

tokenReq.on('error', (e) => {
  console.error('Token request error:', e);
  process.exit(1);
});

tokenReq.write(postData);
tokenReq.end();

// 3. Upload Data Safety CSV via REST API
function uploadDataSafety(accessToken) {
  console.log(`Uploading Data Safety Questionnaire for package "${packageName}"...`);
  
  const data = JSON.stringify({
    safetyLabels: csvContent
  });
  
  const uploadReq = https.request(`https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/dataSafety`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(data)
    }
  }, (res) => {
    let body = '';
    res.on('data', chunk => body += chunk);
    res.on('end', () => {
      if (res.statusCode >= 200 && res.statusCode < 300) {
        console.log('SUCCESS: Google Play Data Safety Questionnaire updated successfully!');
      } else {
        console.error(`ERROR: Failed to update Data Safety Questionnaire (Status: ${res.statusCode})`);
        console.error('Response Body:', body);
        process.exit(1);
      }
    });
  });
  
  uploadReq.on('error', (e) => {
    console.error('Upload request error:', e);
    process.exit(1);
  });
  
  uploadReq.write(data);
  uploadReq.end();
}
