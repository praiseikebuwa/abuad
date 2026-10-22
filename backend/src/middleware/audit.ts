import { Response, NextFunction } from 'express';
import { prisma } from '../config/db';
import { AuthenticatedRequest } from './auth';

export interface AuditLogOptions {
  action?: string;
  details?: string | ((req: AuthenticatedRequest, res: Response) => string | object);
}

/**
 * Mask sensitive fields from body if present before storing in audit logs.
 */
function sanitizePayload(body: any): any {
  if (!body || typeof body !== 'object') return body;
  if (Array.isArray(body)) return body.map(sanitizePayload);

  const sanitized: Record<string, any> = { ...body };
  const sensitiveKeys = ['password', 'passwordHash', 'token', 'refreshToken', 'accessToken', 'secret'];

  for (const key of Object.keys(sanitized)) {
    if (sensitiveKeys.some((s) => key.toLowerCase().includes(s.toLowerCase()))) {
      sanitized[key] = '[REDACTED]';
    } else if (typeof sanitized[key] === 'object') {
      sanitized[key] = sanitizePayload(sanitized[key]);
    }
  }

  return sanitized;
}

/**
 * Programmatic helper to persist an audit log entry to the database.
 */
export async function logAdminAction(adminId: string, action: string, details: string | object) {
  try {
    const formattedDetails = typeof details === 'object' ? JSON.stringify(details) : String(details);
    return await prisma.auditLog.create({
      data: {
        adminId,
        action,
        details: formattedDetails,
      },
    });
  } catch (error) {
    console.error('Failed to create audit log entry:', error);
    return null;
  }
}

/**
 * Audit logging middleware for administrative actions.
 *
 * Usage examples:
 * 1. Specific action name:
 *    router.post('/users/:id/ban', authenticateToken, adminOnly, auditAction('BAN_USER'), handler);
 *
 * 2. Dynamic details customizer:
 *    router.post('/users/:id/role', authenticateToken, adminOnly, auditAction({
 *      action: 'UPDATE_ROLE',
 *      details: (req) => ({ targetId: req.params.id, newRole: req.body.role })
 *    }), handler);
 *
 * 3. Default automatic logging (captures method, route, params, sanitized body, and client IP):
 *    router.delete('/posts/:id', authenticateToken, adminOnly, auditAction(), handler);
 */
export function auditAction(actionNameOrOptions?: string | AuditLogOptions) {
  return (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    // Only capture actions once response finishes successfully (< 400)
    res.on('finish', async () => {
      const adminId = req.user?.id;
      if (!adminId || res.statusCode < 200 || res.statusCode >= 400) {
        return;
      }

      try {
        const options: AuditLogOptions =
          typeof actionNameOrOptions === 'string'
            ? { action: actionNameOrOptions }
            : actionNameOrOptions || {};

        const action =
          options.action ||
          `${req.method.toUpperCase()} ${req.baseUrl || ''}${req.route?.path || req.path}`;

        let details: string | object;
        if (typeof options.details === 'function') {
          details = options.details(req, res);
        } else if (options.details) {
          details = options.details;
        } else {
          details = {
            method: req.method,
            path: req.originalUrl || req.path,
            params: req.params,
            query: req.query,
            body: sanitizePayload(req.body),
            ip: req.ip || req.headers['x-forwarded-for'] || req.socket.remoteAddress,
            statusCode: res.statusCode,
          };
        }

        await logAdminAction(adminId, action, details);
      } catch (err) {
        console.error('Audit logging middleware error:', err);
      }
    });

    next();
  };
}
