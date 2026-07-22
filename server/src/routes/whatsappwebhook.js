import express from "express";
import prisma from "../config/db.js";
import { sendText, sendInteractiveList } from "../utils/whatsappservice.js";
import { sendEmailNotification } from "../utils/notifications.js";
import { logAudit } from "../utils/dbHelper.js";

const router = express.Router();

// In-memory state tracking for multi-step interactive prompts (e.g. College Support prompt)
const userSessionMap = new Map();

const setUserSession = (phone, state, data = {}) => {
    userSessionMap.set(phone, { state, data, timestamp: Date.now() });
};

const getUserSession = (phone) => {
    const session = userSessionMap.get(phone);
    if (!session) return null;
    // Auto-expire session after 15 minutes
    if (Date.now() - session.timestamp > 15 * 60 * 1000) {
        userSessionMap.delete(phone);
        return null;
    }
    return session;
};

const clearUserSession = (phone) => {
    userSessionMap.delete(phone);
};

// Step 3: Verify Webhook (Meta GET challenge verification)
router.get("/", (req, res) => {
    const VERIFY_TOKEN = process.env.WHATSAPP_VERIFY_TOKEN;

    const mode = req.query["hub.mode"];
    const token = req.query["hub.verify_token"];
    const challenge = req.query["hub.challenge"];

    if (mode === "subscribe" && token === VERIFY_TOKEN) {
        console.log("✅ WhatsApp Webhook Verified successfully!");
        return res.status(200).send(challenge);
    }

    console.warn("⚠️ WhatsApp Webhook Verification Failed: Token mismatch or missing mode");
    return res.sendStatus(403);
});

// Step 4-10: Receive and process incoming WhatsApp Messages
router.post("/", async (req, res) => {
    // Immediately respond 200 OK so Meta API receives immediate acknowledgment
    res.sendStatus(200);

    try {
        const entry = req.body.entry?.[0];
        const change = entry?.changes?.[0];
        const value = change?.value;
        const message = value?.messages?.[0];
        console.log("=================================");
        console.log(JSON.stringify(message, null, 2));
        console.log("=================================");

        if (!message) return;

        const fromPhone = message.from;
        const messageType = message.type;

        let textBody = "";
        let buttonId = "";

        if (messageType === "text") {
            textBody = message.text?.body?.trim() || "";
        } else if (messageType === "interactive") {
            buttonId = message.interactive?.button_reply?.id || message.interactive?.list_reply?.id || "";
            textBody = message.interactive?.button_reply?.title || message.interactive?.list_reply?.title || "";
        }

        console.log(`📩 Incoming WhatsApp message from [${fromPhone}]: "${textBody}" (Type: ${messageType}, Button ID: "${buttonId}")`);

        // Helper to send standard BookMyFest interactive main list menu
        const sendMainMenu = async () => {
            clearUserSession(fromPhone);
            await sendInteractiveList(
                fromPhone,
                "👋 Welcome to BookMyFest!\n\nYour one-stop platform for college events.\n\nPlease choose an option below:",
                "Choose Option 📋",
                [
                    {
                        title: "BookMyFest Options",
                        rows: [
                            { id: "register", title: "🎫 Event Register", description: "Register for college events & fests" },
                            { id: "my_registrations", title: "📅 My Registrations", description: "View your booked event tickets" },
                            { id: "certificate", title: "📜 Download Certificate", description: "Download your event certificates" },
                            { id: "payment", title: "💳 Payment Support", description: "Help with fees & payment reference" },
                            { id: "college_support", title: "🏫 College Support", description: "Support for colleges & coordinators" },
                            { id: "latest_events", title: "📢 Latest Events", description: "See recently published fests" },
                            { id: "contact_support", title: "☎️ Contact Support", description: "Get in touch with support team" },
                        ],
                    },
                ]
            );
        };

        const isEmail = (str) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(str.toLowerCase());

        // Check if user is in an active multi-step prompt session (e.g. College Support prompt)
        const activeSession = getUserSession(fromPhone);

        // If user tapped a new menu button, clear existing session
        if (buttonId) {
            clearUserSession(fromPhone);
        }

        // Handle College Support multi-step prompt: College Name input
        if (activeSession && activeSession.state === "AWAITING_COLLEGE_NAME" && messageType === "text" && !buttonId) {
            const collegeName = textBody;
            clearUserSession(fromPhone);

            console.log(`🚨 [COLLEGE SUPPORT TICKET LOGGED] Phone: +${fromPhone} | College Name: "${collegeName}"`);

            // Audit log in database
            await logAudit(null, "COLLEGE_SUPPORT_TICKET", "support_tickets", fromPhone, null, { phone: fromPhone, collegeName });

            // Send Email alert to support team
            const emailSubject = `🚨 [BookMyFest] New College Support Ticket - ${collegeName}`;
            const emailBody = `A new College Support ticket has been submitted via WhatsApp:\n\n📱 Student Phone: +${fromPhone}\n🏫 College Name: ${collegeName}\n📅 Timestamp: ${new Date().toLocaleString('en-IN')}\n\nPlease reach out within 24 working hours.`;
            sendEmailNotification("support@bookmyfest.co", emailSubject, emailBody).catch(err => console.error("Email Notify Error:", err.message));

            // Send WhatsApp alert to Admin Phone Number
            const adminPhone = process.env.SUPPORT_NOTIFICATION_PHONE || "919819289289";
            const ticketMsg = `🚨 *NEW COLLEGE SUPPORT TICKET*\n\n📱 *Student Phone:* +${fromPhone}\n🏫 *College Name:* ${collegeName}\n📅 *Time:* ${new Date().toLocaleString("en-IN")}\n\n👉 Please follow up with the college within 24 working hours.`;
            sendText(adminPhone, ticketMsg).catch(err => console.error("Admin WhatsApp Notify Error:", err.message));

            await sendText(
                fromPhone,
                `I have informed the college team. Respected *${collegeName}* team will get back to you within 24 working hours, or please email us at support@bookmyfest.co.`
            );
            return;
        }

        // 1. Handle Event Registration button or keyword
        if (buttonId === "register" || textBody.toLowerCase().includes("register")) {
            const events = await prisma.event.findMany({
                where: { isApproved: true, isPendingDeletion: false },
                orderBy: { eventDate: "asc" },
                take: 5,
            });

            if (events.length === 0) {
                await sendText(
                    fromPhone,
                    "🎫 *Upcoming Events*\n\nThere are currently no active events scheduled. Check back soon on BookMyFest!"
                );
            } else {
                let eventListMsg = "🎫 *Upcoming Events on BookMyFest*\n\n";
                events.forEach((ev, idx) => {
                    const dateStr = new Date(ev.eventDate).toLocaleDateString("en-IN", {
                        day: "numeric",
                        month: "short",
                        year: "numeric",
                    });
                    const fee = ev.isPaid ? `₹${ev.entryFee}` : "FREE";
                    eventListMsg += `${idx + 1}. *${ev.title}*\n📅 Date: ${dateStr}\n💰 Fee: ${fee}\n🏷️ Category: ${ev.category}\n\n`;
                });
                eventListMsg += "👉 Visit https://bookmyfest.co/events to register!";
                await sendText(fromPhone, eventListMsg);
            }
            return;
        }

        // 2. Handle Latest Events
        if (buttonId === "latest_events" || textBody.toLowerCase().includes("latest")) {
            const latestEvents = await prisma.event.findMany({
                where: { isApproved: true, isPendingDeletion: false },
                orderBy: { createdAt: "desc" },
                take: 5,
            });

            if (latestEvents.length === 0) {
                await sendText(fromPhone, "📢 *Latest Events*\n\nNo newly published events found right now. Stay tuned!");
            } else {
                let msg = "📢 *Recently Added Events on BookMyFest*\n\n";
                latestEvents.forEach((ev, idx) => {
                    const dateStr = new Date(ev.eventDate).toLocaleDateString("en-IN", {
                        day: "numeric",
                        month: "short",
                        year: "numeric",
                    });
                    msg += `${idx + 1}. *${ev.title}*\n📅 Event Date: ${dateStr}\n🏫 College: ${ev.branch || 'Open'}\n\n`;
                });
                msg += "👉 Explore all events: https://bookmyfest.co/events";
                await sendText(fromPhone, msg);
            }
            return;
        }

        // 3. Handle Certificate button or query
        if (buttonId === "certificate" || textBody.toLowerCase().includes("certificate")) {
            await sendText(
                fromPhone,
                "📜 Please enter your registered email address to check your certificate status."
            );
            return;
        }

        // 4. Handle Registrations button or query
        if (buttonId === "my_registrations" || textBody.toLowerCase().includes("registrations")) {
            await sendText(
                fromPhone,
                "📅 Please enter your registered email address to view your registered events."
            );
            return;
        }

        // 5. Handle Payment Support
        if (buttonId === "payment" || textBody.toLowerCase().includes("payment")) {
            await sendText(
                fromPhone,
                "💳 *Payment Support*\n\nPlease reply with your Registered Email Address or Payment Reference ID so our support team can verify your payment, or email us at support@bookmyfest.co."
            );
            return;
        }

        // 6. Handle College Support (Prompts for College Name)
        if (buttonId === "college_support" || textBody.toLowerCase().includes("college support")) {
            setUserSession(fromPhone, "AWAITING_COLLEGE_NAME");
            await sendText(fromPhone, "🏫 Please type your College Name.");
            return;
        }

        // 7. Handle Contact Support
        if (buttonId === "contact_support" || textBody.toLowerCase().includes("contact support") || textBody.toLowerCase().includes("contact")) {
            console.log(`🚨 [SUPPORT TICKET] General Contact Support requested by +${fromPhone}`);

            // Audit log in database
            await logAudit(null, "CONTACT_SUPPORT_TICKET", "support_tickets", fromPhone, null, { phone: fromPhone });

            // Send Email alert to support team
            const emailSubject = `🚨 [BookMyFest] New General Support Ticket`;
            const emailBody = `A new General Contact Support ticket has been submitted via WhatsApp:\n\n📱 Student Phone: +${fromPhone}\n📅 Timestamp: ${new Date().toLocaleString('en-IN')}\n\nPlease reach out within 24 working hours.`;
            sendEmailNotification("support@bookmyfest.co", emailSubject, emailBody).catch(err => console.error("Email Notify Error:", err.message));

            // Send WhatsApp alert to Admin Phone Number
            const adminPhone = process.env.SUPPORT_NOTIFICATION_PHONE || "919819289289";
            const ticketMsg = `🚨 *NEW GENERAL SUPPORT TICKET*\n\n📱 *Student Phone:* +${fromPhone}\n💬 *Request:* General Contact Support\n📅 *Time:* ${new Date().toLocaleString("en-IN")}\n\n👉 Please reach out to the student within 24 working hours.`;
            sendText(adminPhone, ticketMsg).catch(err => console.error("Admin WhatsApp Notify Error:", err.message));

            await sendText(
                fromPhone,
                "☎️ *Contact Support*\n\nThank you for reaching out! Our team will get in touch with you within 24 working hours, or please email us at support@bookmyfest.co."
            );
            return;
        }


        // Handle User Email input (Prisma DB lookup)
        if (isEmail(textBody)) {
            const email = textBody.toLowerCase();
            const user = await prisma.user.findUnique({
                where: { email },
                include: {
                    registrations: {
                        include: { event: true },
                    },
                    attendance: {
                        include: { event: true },
                    },
                },
            });

            if (!user) {
                await sendText(
                    fromPhone,
                    `❌ No student record found for *${email}*.\n\nPlease double check your email address or register on BookMyFest!`
                );
                return;
            }

            const attendedEvents = user.attendance.map((a) => a.event);
            const registeredEvents = user.registrations.map((r) => r.event);

            let replyMsg = `Hello *${user.fullName}*,\n\n`;

            if (attendedEvents.length > 0) {
                replyMsg += `🏆 *Your Certificate Status:*\nYour certificate for *${attendedEvents[0].title}* is ready.\n\n⬇ Download Certificate: https://bookmyfest.co/certificates\n\n`;
            }

            if (registeredEvents.length > 0) {
                replyMsg += `📋 *Your Registered Events:*\n`;
                registeredEvents.forEach((ev) => {
                    const dateStr = new Date(ev.eventDate).toLocaleDateString("en-IN", {
                        day: "numeric",
                        month: "short",
                        year: "numeric",
                    });
                    replyMsg += `• *${ev.title}* (${dateStr})\n`;
                });
            } else if (attendedEvents.length === 0) {
                replyMsg += `You have not registered for any events yet. Tap 🎫 Event Register or visit BookMyFest to explore!`;
            }

            await sendText(fromPhone, replyMsg);
            return;
        }

        // Default greeting / unrecognized message -> Show Main Interactive Menu
        await sendMainMenu();

    } catch (error) {
        console.error("❌ Error processing WhatsApp webhook payload:", error);
    }
});

export default router;