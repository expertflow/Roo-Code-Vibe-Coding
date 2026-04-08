/**
 * Google ID-token verification.
 * Validates the Bearer token from the mobile app's Google Sign-In.
 * Domain-restricted to @expertflow.com.
 */

const { OAuth2Client } = require('google-auth-library');

const CLIENT_ID = process.env.GOOGLE_CLIENT_ID;
const client = new OAuth2Client(CLIENT_ID);

/**
 * Express middleware — verifies Google id_token from Authorization header.
 * Sets req.user = { email, name, picture }
 */
async function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing Authorization header' });
  }

  const token = authHeader.slice(7);
  try {
    const ticket = await client.verifyIdToken({
      idToken: token,
      audience: CLIENT_ID,
    });
    const payload = ticket.getPayload();

    // Domain restriction — expertflow.com only
    if (!payload.email || !payload.email.endsWith('@expertflow.com')) {
      return res.status(403).json({ error: 'Only @expertflow.com accounts are allowed' });
    }

    if (!payload.email_verified) {
      return res.status(403).json({ error: 'Email not verified by Google' });
    }

    req.user = {
      email: payload.email,
      name: payload.name || payload.email.split('@')[0],
      picture: payload.picture,
    };
    next();
  } catch (err) {
    console.error('Token verification failed:', err.message);
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

module.exports = { requireAuth };
