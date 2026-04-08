/**
 * Google Drive integration via Service Account.
 * 
 * Uploads receipt images to a per-employee subfolder under the
 * Expertflow GDrive root folder (1sBCdcD6uFn5ifbWc_F_N78qevzdaaYNO).
 * 
 * Folder naming: firstname.lastname (derived from email prefix).
 */

const { google } = require('googleapis');
const path = require('path');
const stream = require('stream');

const SA_KEY_PATH = process.env.GDRIVE_SA_KEY_PATH || './sa-key.json';
const ROOT_FOLDER_ID = process.env.GDRIVE_ROOT_FOLDER_ID || '0AOGnfeqGDSLhUk9PVA';

let driveClient;

function getDrive() {
  if (driveClient) return driveClient;

  const authOptions = {
    scopes: ['https://www.googleapis.com/auth/drive.file', 'https://www.googleapis.com/auth/drive'],
  };

  // Use local key file if it exists, otherwise fall back to Cloud Run ADC
  const fs = require('fs');
  if (fs.existsSync(SA_KEY_PATH)) {
    authOptions.keyFile = SA_KEY_PATH;
  }

  const auth = new google.auth.GoogleAuth(authOptions);

  driveClient = google.drive({ version: 'v3', auth });
  return driveClient;
}

/**
 * Find a subfolder by name under the given parent. Returns its ID or null.
 */
async function findFolder(parentId, folderName) {
  const drive = getDrive();
  const res = await drive.files.list({
    q: `'${parentId}' in parents AND name = '${folderName}' AND mimeType = 'application/vnd.google-apps.folder' AND trashed = false`,
    fields: 'files(id, name)',
    spaces: 'drive',
  });
  return res.data.files.length > 0 ? res.data.files[0].id : null;
}

/**
 * Create a folder under the given parent. Returns the new folder ID.
 */
async function createFolder(parentId, folderName) {
  const drive = getDrive();
  const res = await drive.files.create({
    requestBody: {
      name: folderName,
      mimeType: 'application/vnd.google-apps.folder',
      parents: [parentId],
    },
    fields: 'id',
  });
  return res.data.id;
}

/**
 * Resolve the target GDrive folder for an employee.
 * Creates the subfolder if it doesn't exist.
 * 
 * @param {string} email — e.g. andreas.stuber@expertflow.com
 * @returns {Promise<string>} — GDrive folder ID
 */
async function resolveEmployeeFolder(email) {
  // firstname.lastname from email prefix
  const folderName = email.split('@')[0];
  
  let folderId = await findFolder(ROOT_FOLDER_ID, folderName);
  if (!folderId) {
    console.log(`Creating GDrive folder: ${folderName}`);
    folderId = await createFolder(ROOT_FOLDER_ID, folderName);
  }
  return folderId;
}

/**
 * Upload a file buffer to a specific GDrive folder.
 * 
 * @param {Buffer} fileBuffer — file content
 * @param {string} fileName — e.g. "2026-03-29_receipt_INV-123.jpg"
 * @param {string} mimeType — e.g. "image/jpeg"
 * @param {string} folderId — GDrive folder ID
 * @returns {Promise<{id: string, webViewLink: string}>}
 */
async function uploadFile(fileBuffer, fileName, mimeType, folderId) {
  const drive = getDrive();

  // Convert buffer to readable stream
  const bufferStream = new stream.PassThrough();
  bufferStream.end(fileBuffer);

  const res = await drive.files.create({
    requestBody: {
      name: fileName,
      parents: [folderId],
    },
    media: {
      mimeType,
      body: bufferStream,
    },
    fields: 'id, webViewLink, webContentLink',
  });

  return {
    id: res.data.id,
    webViewLink: res.data.webViewLink,
    webContentLink: res.data.webContentLink,
  };
}

module.exports = { resolveEmployeeFolder, uploadFile, findFolder, createFolder };
