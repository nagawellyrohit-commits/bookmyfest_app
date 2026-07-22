import path from "path";

export const uploadPath = path.resolve(
  process.env.UPLOAD_PATH || "uploads"
);
