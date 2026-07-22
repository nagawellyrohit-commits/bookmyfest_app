import axios from "axios";

const getApiUrl = () => {
    const baseUrl = process.env.WHATSAPP_API_URL;
    const phoneId = process.env.WHATSAPP_PHONE_NUMBER_ID;
    return `${baseUrl}/${phoneId}/messages`;
};

const getHeaders = () => ({
    Authorization: `Bearer ${process.env.WHATSAPP_ACCESS_TOKEN}`,
    "Content-Type": "application/json",
});

const formatPhone = (to) => {
    if (!to) return "";
    let phone = to.toString().replace(/\D/g, "");
    if (phone.length === 10) {
        phone = `91${phone}`;
    }
    return phone;
};

/**
 * Send plain text message via WhatsApp Cloud API
 */
export const sendText = async (to, text) => {
    const phone = formatPhone(to);
    if (!phone) {
        throw new Error("Recipient phone number is missing or invalid.");
    }

    console.log(`\n======================================================`);
    console.log(`📱 [WhatsApp Outbound Text to +${phone}]:`);
    console.log(text);
    console.log(`======================================================\n`);

    try {
        const response = await axios.post(
            getApiUrl(),
            {
                messaging_product: "whatsapp",
                recipient_type: "individual",
                to: phone,
                type: "text",
                text: {
                    body: text,
                },
            },
            {
                headers: getHeaders(),
            }
        );

        return response.data;
    } catch (error) {
        const errData = error.response?.data?.error || error.response?.data || error.message;
        if (errData?.code === 190) {
            console.warn(`⚠️ [WhatsApp API Warning] Meta Access Token is expired or invalid (Error 190). Please update WHATSAPP_ACCESS_TOKEN in server/.env with a new token from Meta Developer Portal.`);
        } else {
            console.error("WhatsApp sendText Error:", errData);
        }
        return { success: false, error: errData, localSimulated: true };
    }
};

/**
 * Send interactive buttons via WhatsApp Cloud API
 * @param {string} to - Recipient phone number
 * @param {string} bodyText - Main text body
 * @param {Array<{id: string, title: string}>} buttons - Up to 3 button objects
 */
export const sendInteractiveButtons = async (to, bodyText, buttons) => {
    const phone = formatPhone(to);
    if (!phone) {
        throw new Error("Recipient phone number is missing or invalid.");
    }

    const formattedButtons = buttons.slice(0, 3).map((btn) => ({
        type: "reply",
        reply: {
            id: btn.id,
            title: btn.title.slice(0, 20), // WhatsApp max 20 chars limit for button titles
        },
    }));

    console.log(`\n======================================================`);
    console.log(`📱 [WhatsApp Outbound Interactive Buttons to +${phone}]:`);
    console.log(`Body: ${bodyText}`);
    console.log(`Buttons: ${buttons.map(b => `[${b.title} (ID: ${b.id})]`).join(' ')}`);
    console.log(`======================================================\n`);

    try {
        const response = await axios.post(
            getApiUrl(),
            {
                messaging_product: "whatsapp",
                recipient_type: "individual",
                to: phone,
                type: "interactive",
                interactive: {
                    type: "button",
                    body: {
                        text: bodyText,
                    },
                    action: {
                        buttons: formattedButtons,
                    },
                },
            },
            {
                headers: getHeaders(),
            }
        );

        return response.data;
    } catch (error) {
        const errData = error.response?.data?.error || error.response?.data || error.message;
        if (errData?.code === 190) {
            console.warn(`⚠️ [WhatsApp API Warning] Meta Access Token is expired or invalid (Error 190). Please update WHATSAPP_ACCESS_TOKEN in server/.env with a new token from Meta Developer Portal.`);
        } else {
            console.error("WhatsApp sendInteractiveButtons Error:", errData);
        }
        return { success: false, error: errData, localSimulated: true };
    }
};

/**
 * Send interactive list menu via WhatsApp Cloud API (supports up to 10 items)
 * @param {string} to - Recipient phone number
 * @param {string} bodyText - Main text body
 * @param {string} buttonTitle - Text for the list selection button
 * @param {Array<{title: string, rows: Array<{id: string, title: string, description?: string}>}>} sections
 */
export const sendInteractiveList = async (to, bodyText, buttonTitle = "Select Option 📋", sections = []) => {
    const phone = formatPhone(to);
    if (!phone) {
        throw new Error("Recipient phone number is missing or invalid.");
    }

    console.log(`\n======================================================`);
    console.log(`📱 [WhatsApp Outbound Interactive List to +${phone}]:`);
    console.log(`Body: ${bodyText}`);
    console.log(`Sections: ${JSON.stringify(sections, null, 2)}`);
    console.log(`======================================================\n`);

    try {
        const response = await axios.post(
            getApiUrl(),
            {
                messaging_product: "whatsapp",
                recipient_type: "individual",
                to: phone,
                type: "interactive",
                interactive: {
                    type: "list",
                    header: {
                        type: "text",
                        text: "BookMyFest Assistant",
                    },
                    body: {
                        text: bodyText,
                    },
                    footer: {
                        text: "BookMyFest • Official Companion",
                    },
                    action: {
                        button: buttonTitle.slice(0, 20),
                        sections: sections,
                    },
                },
            },
            {
                headers: getHeaders(),
            }
        );

        return response.data;
    } catch (error) {
        const errData = error.response?.data?.error || error.response?.data || error.message;
        console.error("WhatsApp sendInteractiveList Error:", errData);
        // Fallback to text message
        let fallbackText = `${bodyText}\n\n`;
        sections.forEach((sec) => {
            sec.rows.forEach((r, idx) => {
                fallbackText += `${idx + 1}️⃣ ${r.title}\n`;
            });
        });
        return sendText(to, fallbackText);
    }
};

/**
 * Send WhatsApp message - backwards compatible wrapper
 */
export const sendWhatsAppMessage = async (to, message) => {
    return sendText(to, message);
};