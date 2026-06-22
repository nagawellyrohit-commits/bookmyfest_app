import prisma from '../config/db.js';

/**
 * Fetch all sponsors.
 * Accessible publicly.
 */
export const getAllSponsors = async (req, res, next) => {
  try {
    const sponsors = await prisma.sponsor.findMany({
      orderBy: {
        createdAt: 'asc'
      }
    });

    res.status(200).json({
      success: true,
      data: sponsors
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Create a new sponsor.
 * Restricted to super_admin.
 */
export const createSponsor = async (req, res, next) => {
  try {
    const { name, subtitle, logoUrl } = req.body;

    const trimmedName = name ? name.trim() : '';
    const trimmedSubtitle = subtitle ? subtitle.trim() : null;
    const trimmedLogo = logoUrl ? logoUrl.trim() : '';

    if (!trimmedName && !trimmedSubtitle && !trimmedLogo) {
      return res.status(400).json({
        success: false,
        message: 'At least one sponsor detail (logo, typed name, or name image) is required.'
      });
    }

    const newSponsor = await prisma.sponsor.create({
      data: {
        name: trimmedName,
        subtitle: trimmedSubtitle,
        logoUrl: trimmedLogo
      }
    });

    res.status(201).json({
      success: true,
      message: 'Sponsor created successfully',
      data: newSponsor
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Update an existing sponsor.
 * Restricted to super_admin.
 */
export const updateSponsor = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { name, subtitle, logoUrl } = req.body;

    const existingSponsor = await prisma.sponsor.findUnique({
      where: { id }
    });

    if (!existingSponsor) {
      return res.status(404).json({
        success: false,
        message: 'Sponsor not found'
      });
    }

    const updatedSponsor = await prisma.sponsor.update({
      where: { id },
      data: {
        name: name !== undefined ? name.trim() : undefined,
        subtitle: subtitle !== undefined ? (subtitle ? subtitle.trim() : null) : undefined,
        logoUrl: logoUrl !== undefined ? logoUrl.trim() : undefined
      }
    });

    res.status(200).json({
      success: true,
      message: 'Sponsor updated successfully',
      data: updatedSponsor
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Delete a sponsor.
 * Restricted to super_admin.
 */
export const deleteSponsor = async (req, res, next) => {
  try {
    const { id } = req.params;

    const existingSponsor = await prisma.sponsor.findUnique({
      where: { id }
    });

    if (!existingSponsor) {
      return res.status(404).json({
        success: false,
        message: 'Sponsor not found'
      });
    }

    await prisma.sponsor.delete({
      where: { id }
    });

    res.status(200).json({
      success: true,
      message: 'Sponsor deleted successfully'
    });
  } catch (error) {
    next(error);
  }
};
