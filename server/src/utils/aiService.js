import axios from 'axios';

// Default high-quality fallbacks in case OpenRouter fails or API key is missing
const fallbackTemplates = [
  {
    templateName: 'Modern Tech Gradient',
    primaryColor: '#6366F1', // Indigo
    secondaryColor: '#3B82F6', // Blue
    fontFamily: 'Inter',
    backgroundStyle: 'linear-gradient(135deg, #0f172a 0%, #1e1b4b 100%)',
    layoutDescription: 'Double thin neon borders, centered modern geometric badges, clean san-serif text.',
    aiJustification: 'This sleek dark gradient is perfect for technology-focused workshops and hackathons.'
  },
  {
    templateName: 'Classic Academic Gold',
    primaryColor: '#B45309', // Amber/Gold
    secondaryColor: '#1E293B', // Dark Slate
    fontFamily: 'Playfair Display',
    backgroundStyle: 'linear-gradient(135deg, #fafaf9 0%, #f5f5f4 100%)',
    layoutDescription: 'Ornate traditional borders, gothic calligraphy font elements, and custom college seal placeholders.',
    aiJustification: 'Fits academic convocations, papers, and traditional department seminars beautifully.'
  },
  {
    templateName: 'Nebula Creative Art',
    primaryColor: '#EC4899', // Pink
    secondaryColor: '#8B5CF6', // Purple
    fontFamily: 'Outfit',
    backgroundStyle: 'linear-gradient(135deg, #1e1b4b 0%, #4c1d95 100%)',
    layoutDescription: 'Vibrant organic shape overlays, left-aligned asymmetric modern text hierarchy, abstract art badges.',
    aiJustification: 'An expressive design well-suited for cultural fests, design marathons, and creative writing events.'
  }
];

/**
 * Connect to OpenRouter API to suggest certificate templates.
 * @param {string} title - Event Title
 * @param {string} description - Event Description
 * @param {string} collegeName - College Name
 */
export const getAiCertificateSuggestions = async (title, description, collegeName) => {
  const apiKey = process.env.OPENROUTER_API_KEY;
  const model = process.env.OPENROUTER_MODEL || 'meta-llama/llama-3-8b-instruct:free';

  // Fallback if no API key is set
  if (!apiKey || apiKey === 'your_api_key_here') {
    console.warn('[AI Service Warning]: OPENROUTER_API_KEY is not configured in .env. Returning high-quality fallback themes.');
    return fallbackTemplates;
  }

  try {
    const prompt = `Generate 3 creative, high-quality, professional certificate design themes customized for a college event.
The event details are:
Event Title: ${title}
Event Description: ${description || 'N/A'}
Organizing College: ${collegeName}

Respond ONLY with a valid, raw JSON array containing exactly 3 objects. Do NOT wrap it in markdown code blocks (\`\`\`json ... \`\`\`), and do NOT include any introductory or concluding text.

Each object must have these exact JSON keys (ensure all keys and string values are wrapped in double quotes):
- "templateName" (string, catchy theme name)
- "primaryColor" (string, hex color like #FFFFFF)
- "secondaryColor" (string, hex color like #000000)
- "fontFamily" (string, standard Google Font name like Inter, Playfair Display, Montserrat, Fira Code, Outfit)
- "backgroundStyle" (string, CSS style like a linear-gradient description or solid background color)
- "layoutDescription" (string, details about borders, seals, logo placements)
- "aiJustification" (string, 1-sentence reason why this matches the event topic)`;

    const response = await axios.post(
      'https://openrouter.ai/api/v1/chat/completions',
      {
        model: model,
        messages: [
          {
            role: 'system',
            content: 'You are an elite graphic designer and AI assistant specializing in certificate branding. You only output valid JSON arrays.'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.7,
        max_tokens: 800
      },
      {
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'HTTP-Referer': 'https://github.com/collegeconnect', // Optional OpenRouter tracking
          'X-Title': 'CollegeConnect Platform',
          'Content-Type': 'application/json'
        },
        timeout: 10000 // 10s timeout
      }
    );

    const content = response.data?.choices?.[0]?.message?.content?.trim();
    if (!content) {
      throw new Error('Empty response from AI completions');
    }

    // Strip markdown formatting if the model ignored instructions and wrapped it anyway
    let cleanedContent = content;
    if (cleanedContent.startsWith('```')) {
      cleanedContent = cleanedContent.replace(/^```(json)?/, '').replace(/```$/, '').trim();
    }

    const suggestions = JSON.parse(cleanedContent);
    if (Array.isArray(suggestions) && suggestions.length > 0) {
      return suggestions;
    }

    throw new Error('Invalid JSON format parsed from model response');
  } catch (error) {
    console.error('[OpenRouter API Error]:', error.message, '\nFalling back to default templates.');
    return fallbackTemplates;
  }
};
