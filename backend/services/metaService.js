const axios = require('axios');

class MetaService {
  async testConnection(instagramId, accessToken) {
    try {
      const response = await axios.get(`https://graph.facebook.com/v19.0/${instagramId}`, {
        params: { access_token: accessToken, fields: 'username,name' }
      });
      return response.data;
    } catch (error) {
      throw error.response ? error.response.data : error;
    }
  }

  async publishPost(instagramId, accessToken, imageUrl, caption) {
    try {
      // Step 1: Create Media Container
      const containerResponse = await axios.post(`https://graph.facebook.com/v19.0/${instagramId}/media`, {
        image_url: imageUrl,
        caption: caption,
        access_token: accessToken
      });

      const containerId = containerResponse.data.id;

      // Step 2: Publish Media
      const publishResponse = await axios.post(`https://graph.facebook.com/v19.0/${instagramId}/media_publish`, {
        creation_id: containerId,
        access_token: accessToken
      });

      return {
        containerId: containerId,
        publishId: publishResponse.data.id
      };
    } catch (error) {
      throw error.response ? error.response.data : error;
    }
  }
}

module.exports = new MetaService();
