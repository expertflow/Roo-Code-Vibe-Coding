/**
 * Database connection and query execution for Expertflow Internal ERP
 */

// Database Configuration
// Uses public IP JDBC connection
const DB_CONFIG = {
  host: '213.55.244.201',
  port: 5432,
  database: 'bidstruct4',
  user: 'bs4_dev',
  password: '3(Ga;lhU=:l-Fe_)',
  schema: 'bs4_sandbox'
};

/**
 * Get a JDBC connection via public IP to Cloud SQL.
 * @returns {JdbcConnection} The active database connection
 */
function getConnection() {
  var url = 'jdbc:postgresql://' + DB_CONFIG.host + ':' + DB_CONFIG.port + '/' + DB_CONFIG.database + '?ssl=true';
  try {
    return Jdbc.getConnection(url, DB_CONFIG.user, DB_CONFIG.password);
  } catch (e) {
    console.error('DB Connection failed. URL: ' + url + ', User: ' + DB_CONFIG.user + ', Error: ' + e.message);
    throw new Error('Database connection failed: ' + e.message);
  }
}

/**
 * Fetch the internal Employee ID based on the user's Google Workspace email.
 * @param {string} email - The user's active email.
 * @returns {number|null} The Employee ID or null if not found.
 */
function getEmployeeId(email) {
  const conn = getConnection();
  let employeeId = null;

  try {
    const stmt = conn.prepareStatement(`SELECT id FROM "${DB_CONFIG.schema}"."Employee" WHERE email = ?`);
    stmt.setString(1, email);
    const rs = stmt.executeQuery();

    if (rs.next()) {
      employeeId = rs.getInt('id');
    }
    
    rs.close();
    stmt.close();
  } catch (e) {
    console.error('Error fetching employee ID:', e);
    throw e;
  } finally {
    if (conn) conn.close();
  }

  return employeeId;
}

/**
 * Fetch the top 5 most frequently used projects by the employee.
 * @param {number} employeeId - The current employee's ID.
 * @returns {Array<{id: number, name: string}>} List of projects.
 */
function getTopProjects(employeeId) {
  const conn = getConnection();
  const projects = [];

  try {
    const query = `
      SELECT p.id, p."Name"
      FROM "${DB_CONFIG.schema}"."TimeEntry" t
      JOIN "${DB_CONFIG.schema}"."Project" p ON t."Project" = p.id
      WHERE t."Employee" = ? AND p."Status" = 'Open'
      GROUP BY p.id, p."Name"
      ORDER BY COUNT(t.id) DESC
      LIMIT 5
    `;
    
    const stmt = conn.prepareStatement(query);
    stmt.setInt(1, employeeId);
    const rs = stmt.executeQuery();

    while (rs.next()) {
      projects.push({
        id: rs.getInt('id'),
        name: rs.getString('Name') || 'Unknown Project'
      });
    }

    rs.close();
    stmt.close();
  } catch (e) {
    console.error('Error fetching top projects:', e);
    throw e;
  } finally {
    if (conn) conn.close();
  }

  return projects;
}

/**
 * Search for active projects by name.
 * @param {string} searchQuery - The search term.
 * @returns {Array<{id: number, name: string}>} List of matching projects.
 */
function searchActiveProjects(searchQuery = '') {
  const conn = getConnection();
  const projects = [];

  try {
    let query = `
      SELECT id, "Name" 
      FROM "${DB_CONFIG.schema}"."Project" 
      WHERE "Status" = 'Open'
    `;
    
    if (searchQuery) {
      query += ` AND "Name" ILIKE ?`;
    }
    
    query += ` ORDER BY "Name" ASC LIMIT 50`;

    const stmt = conn.prepareStatement(query);
    
    if (searchQuery) {
      stmt.setString(1, '%' + searchQuery + '%');
    }

    const rs = stmt.executeQuery();

    while (rs.next()) {
      projects.push({
        id: rs.getInt('id'),
        name: rs.getString('Name') || 'Unknown Project'
      });
    }

    rs.close();
    stmt.close();
  } catch (e) {
    console.error('Error searching active projects:', e);
    throw e;
  } finally {
    if (conn) conn.close();
  }

  return projects;
}

/**
 * Insert a new TimeEntry directly into the database.
 * @param {Object} data - The time entry data.
 * @returns {boolean} True if successful.
 */
function insertTimeEntry(data) {
  const conn = getConnection();
  let success = false;

  try {
    const query = `
      INSERT INTO "${DB_CONFIG.schema}"."TimeEntry" 
      ("Description", "StartDateTime", "EndDateTime", "Employee", "Project", "HoursWorked") 
      VALUES (?, ?, ?, ?, ?, ?::interval)
    `;
    
    const stmt = conn.prepareStatement(query);
    
    stmt.setString(1, data.description || '');
    stmt.setString(2, data.startDateTime); 
    stmt.setString(3, data.endDateTime);
    stmt.setInt(4, data.employeeId);
    stmt.setInt(5, data.projectId);
    stmt.setString(6, data.hoursWorked); // Format: 'HH:MM:SS'
    
    const count = stmt.executeUpdate();
    success = count > 0;
    
    stmt.close();
  } catch (e) {
    console.error('Error inserting TimeEntry:', e);
    throw e;
  } finally {
    if (conn) conn.close();
  }

  return success;
}

/**
 * Utility: Convert MS difference to PostgreSQL Interval string
 */
function millisToIntervalString(millis) {
  const hours = Math.floor(millis / (1000 * 60 * 60));
  const minutes = Math.floor((millis % (1000 * 60 * 60)) / (1000 * 60));
  const seconds = Math.floor((millis % (1000 * 60)) / 1000);
  
  const pad = (num) => String(num).padStart(2, '0');
  
  return `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`;
}
