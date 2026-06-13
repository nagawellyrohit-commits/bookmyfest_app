import prisma from '../config/db.js';

/**
 * Log an event/action in the audit logs table.
 * @param {string|null} actorId - ID of the User performing the action.
 * @param {string} action - Description of the action (e.g., 'CREATE_EVENT', 'DELETE_EVENT', 'UPDATE_EVENT').
 * @param {string} targetTable - Name of the DB table affected.
 * @param {string} targetId - Primary key ID of the row affected.
 * @param {object|null} oldData - Pre-action JSON state of the record.
 * @param {object|null} newData - Post-action JSON state of the record.
 */
export const logAudit = async (actorId, action, targetTable, targetId, oldData = null, newData = null) => {
  try {
    const auditRecord = await prisma.auditLog.create({
      data: {
        actorId,
        action,
        targetTable,
        targetId,
        oldData: oldData ? JSON.parse(JSON.stringify(oldData)) : null,
        newData: newData ? JSON.parse(JSON.stringify(newData)) : null,
      },
    });
    return auditRecord;
  } catch (error) {
    console.error('[Audit Log Failed]:', error.message);
    // Do not throw to avoid crashing the primary request
    return null;
  }
};
