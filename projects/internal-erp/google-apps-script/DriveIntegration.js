/**
 * Google Drive Integration for Expertflow Internal ERP
 */

const LEGAL_ENTITY_PARENT_FOLDER_ID = '0AOGnfeqGDSLhUk9PVA';

/**
 * Webhook endpoint triggered by Directus Flow when a LegalEntity is created.
 * @param {Object} e - Event object containing the POST payload
 */
function doPost(e) {
  try {
    const payload = JSON.parse(e.postData.contents);
    const legalEntityId = payload.id;
    const legalEntityName = payload.name;
    
    if (!legalEntityId || !legalEntityName) {
      return ContentService.createTextOutput(JSON.stringify({ error: "Missing required fields: id or name" }))
        .setMimeType(ContentService.MimeType.JSON);
    }
    
    const folderDetails = _createOrGetLegalEntityFolder(legalEntityId, legalEntityName);
    
    return ContentService.createTextOutput(JSON.stringify({
      success: true,
      folderId: folderDetails.id,
      url: folderDetails.url
    })).setMimeType(ContentService.MimeType.JSON);
    
  } catch (error) {
    console.error('Webhook Error:', error);
    return ContentService.createTextOutput(JSON.stringify({ error: error.message }))
        .setMimeType(ContentService.MimeType.JSON);
  }
}

/**
 * Helper to create a folder if it doesn't exist, or return the existing one.
 * Uses the naming convention: "{id} - {name}"
 * @param {string|number} id - Legal Entity ID
 * @param {string} name - Legal Entity Name
 * @returns {Object} folder info
 */
function _createOrGetLegalEntityFolder(id, name) {
  const folderName = `${id} - ${name}`;
  const parentFolder = DriveApp.getFolderById(LEGAL_ENTITY_PARENT_FOLDER_ID);
  
  // Checking if folder already exists
  const existingFolders = parentFolder.searchFolders(`title='${folderName}'`);
  if (existingFolders.hasNext()) {
    const folder = existingFolders.next();
    return {
      id: folder.getId(),
      url: folder.getUrl()
    };
  }
  
  // Create a new restricted folder
  // Note: New folders inherit the sharing permissions of their parent.
  // We do not add "anyoneWithLink" sharing here, ensuring it remains as secure as the parent folder.
  const newFolder = parentFolder.createFolder(folderName);
  
  return {
    id: newFolder.getId(),
    url: newFolder.getUrl()
  };
}

/**
 * Utility function to be run manually from the Apps Script Editor.
 * This function will scan all LegalEntities without a DocumentFolder URL
 * and create folders for them, then automatically update the Postgres database.
 */
function bulkProcessLegalEntities() {
  const conn = getConnection();
  
  try {
    // 1. Fetch LegalEntities missing DocumentFolder
    const query = `SELECT id, "Name" FROM "${DB_CONFIG.schema}"."LegalEntity" WHERE "DocumentFolder" IS NULL OR "DocumentFolder" = ''`;
    const stmt = conn.prepareStatement(query);
    const rs = stmt.executeQuery();
    
    const entitiesToProcess = [];
    while (rs.next()) {
      entitiesToProcess.push({
        id: rs.getInt('id'),
        name: rs.getString('Name') || 'Unknown'
      });
    }
    rs.close();
    stmt.close();
    
    Logger.log(`Found ${entitiesToProcess.length} Legal Entities missing a Document Folder.`);
    
    // 2. Process each entity
    const updateStmt = conn.prepareStatement(`UPDATE "${DB_CONFIG.schema}"."LegalEntity" SET "DocumentFolder" = ? WHERE id = ?`);
    
    let processedCount = 0;
    
    for (const entity of entitiesToProcess) {
      Logger.log(`Processing ID ${entity.id}: ${entity.name}`);
      try {
        const folderDetails = _createOrGetLegalEntityFolder(entity.id, entity.name);
        
        updateStmt.setString(1, folderDetails.url);
        updateStmt.setInt(2, entity.id);
        updateStmt.addBatch();
        
        processedCount++;
      } catch (err) {
        Logger.log(`Error processing entity ${entity.id}: ${err.message}`);
      }
    }
    
    if (processedCount > 0) {
      const results = updateStmt.executeBatch();
      Logger.log(`Successfully updated ${results.length} records in the database.`);
    }
    
    updateStmt.close();
    
  } catch (e) {
    console.error('Bulk Processing Error:', e);
    throw e;
  } finally {
    if (conn) conn.close();
  }
}
