const fs = require('fs');
const https = require('https');

const API_URL = 'https://bs4.expertflow.com';
const EMAIL = 'admin@expertflow.com';
const PASSWORD = 'SimplonBaracke21';

async function request(path, method, body, token = null) {
    return new Promise((resolve, reject) => {
        const url = new URL(API_URL + path);
        const options = {
            method: method,
            headers: {
                'Content-Type': 'application/json'
            }
        };
        if (token) {
            options.headers['Authorization'] = `Bearer ${token}`;
        }

        const req = https.request(url, options, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                try {
                    const parsed = JSON.parse(data);
                    if (res.statusCode >= 400) {
                        reject(new Error(`API Error ${res.statusCode}: ${JSON.stringify(parsed)}`));
                    } else {
                        resolve(parsed.data || parsed);
                    }
                } catch (e) {
                    if (res.statusCode >= 400) {
                        reject(new Error(`API Error ${res.statusCode}: ${data}`));
                    } else {
                        resolve(data);
                    }
                }
            });
        });

        req.on('error', reject);
        if (body) {
            req.write(JSON.stringify(body));
        }
        req.end();
    });
}

async function run() {
    try {
        const token = 'batch_update_token_123';
        console.log('Authentication successful (using static token).');

        console.log('Fetching unreconciled bank statements...');
        // Limit to 2000 to be safe, though there are around 930
        const items = await request('/items/BankStatement?limit=2000&filter[Transaction][_null]=true&fields=id,Amount,Date', 'GET', null, token);
        console.log(`Found ${items.length} items to update.`);

        const BATCH_SIZE = 50;
        let successCount = 0;
        let failCount = 0;

        for (let i = 0; i < items.length; i += BATCH_SIZE) {
            const batch = items.slice(i, i + BATCH_SIZE);
            console.log(`Sending batch ${Math.floor(i / BATCH_SIZE) + 1} of ${Math.ceil(items.length / BATCH_SIZE)}...`);
            
            await Promise.all(batch.map(async (item) => {
                const payload = { Amount: item.Amount, Date: item.Date };
                try {
                    await request(`/items/BankStatement/${item.id}`, 'PATCH', payload, token);
                    successCount++;
                } catch (err) {
                    console.error(`Failed to update item ${item.id}:`, err.message);
                    failCount++;
                }
            }));
        }

        console.log(`Complete. Triggered suggestions for ${successCount} items. Failed: ${failCount}`);
    } catch (e) {
        console.error('Fatal error:', e);
    }
}

run();
