const axios = require('axios');

class GeminiService {
  async generateCaption(imageUrl, language, tone, apiKey) {
    // In production, use @google/generative-ai package
    // This is a placeholder for the logic
    const prompt = `Generate a ${tone} Instagram caption and 5 hashtags in ${language} for this image: ${imageUrl}. Also provide alt text.`;

    // Simulate API call
    return {
      caption: "Experience the ultimate luxury. ✨",
      hashtags: "#luxury #premium #style",
      alt_text: "A beautiful luxury product in a premium setting."
    };
  }

  async generateEditPrompt(imageUrl, style, apiKey) {
    const prompt = `Describe how to edit this image ${imageUrl} to have a ${style} background while preserving the main product exactly.`;

    return {
      ai_edit_prompt: `High-end ${style} background, soft cinematic lighting, 8k resolution, professional photography.`
    };
  }
}

module.exports = new GeminiService();
