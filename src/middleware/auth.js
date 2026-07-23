const jwt = require('jsonwebtoken');

/**
 * Middleware to verify JWT token in authorization header
 * Expected format: Authorization: Bearer <token>
 */
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Extract token from "Bearer <token>"

  if (!token) {
    return res.status(401).json({ 
      error: 'Access denied', 
      message: 'Authentication token is required in the Authorization header' 
    });
  }

  try {
    const tokenSecret = process.env.JWT_SECRET || 'fallback_secret';
    const decoded = jwt.verify(token, tokenSecret);
    req.user = decoded; // Attach authenticated user payload to req
    next(); // Pass control to next route handler
  } catch (error) {
    return res.status(403).json({ 
      error: 'Forbidden', 
      message: 'Invalid, expired, or malformed authentication token' 
    });
  }
}

module.exports = authenticateToken;
