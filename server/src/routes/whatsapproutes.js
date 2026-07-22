import express from "express";
import { sendWhatsAppMessage } from "../utils/whatsappservice.js";

const router = express.Router();

router.get("/test", async (req, res) => {
    try {
        await sendWhatsAppMessage(
            "919867855572", // Replace with your own number (no +)
            "🚀 Hello from BookMyFest!\n\nYour WhatsApp integration is working successfully."
        );

        res.json({
            success: true,
            message: "WhatsApp message sent successfully.",
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.response?.data || error.message,
        });
    }
});

export default router;