const cron = require('node-cron');
const metaService = require('./metaService');

class SchedulerService {
  init() {
    console.log('Scheduler Initialized');
    // Run every 5 minutes
    cron.schedule('*/5 * * * *', () => {
      this.checkAndPublish();
    });
  }

  async checkAndPublish() {
    console.log('Checking for scheduled posts...');
    // Logic:
    // 1. Fetch approved posts from DB where scheduledAt <= now
    // 2. Loop through posts
    // 3. Update status to 'publishing'
    // 4. Call metaService.publishPost
    // 5. Update status to 'published' or 'failed'
  }
}

module.exports = new SchedulerService();
