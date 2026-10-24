"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.validateQuery = exports.validateBody = void 0;
const zod_1 = require("zod");
/**
 * Express middleware helper to validate req.body against a Zod schema.
 */
const validateBody = (schema) => {
    return async (req, res, next) => {
        try {
            req.body = await schema.parseAsync(req.body);
            next();
        }
        catch (error) {
            if (error instanceof zod_1.ZodError) {
                return res.status(400).json({
                    error: 'Validation failed',
                    details: error.errors.map((e) => ({
                        field: e.path.join('.'),
                        message: e.message,
                    })),
                });
            }
            return res.status(400).json({ error: 'Invalid request data' });
        }
    };
};
exports.validateBody = validateBody;
/**
 * Express middleware helper to validate req.query against a Zod schema.
 */
const validateQuery = (schema) => {
    return async (req, res, next) => {
        try {
            req.query = (await schema.parseAsync(req.query));
            next();
        }
        catch (error) {
            if (error instanceof zod_1.ZodError) {
                return res.status(400).json({
                    error: 'Query validation failed',
                    details: error.errors.map((e) => ({
                        field: e.path.join('.'),
                        message: e.message,
                    })),
                });
            }
            return res.status(400).json({ error: 'Invalid query parameters' });
        }
    };
};
exports.validateQuery = validateQuery;
