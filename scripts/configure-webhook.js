const { Octokit } = require('@octokit/rest');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

// GitHub configuration
const config = {
  owner: 'Sourabh-Tomar',
  repo: 'demo-app',
  jenkins_url: process.env.JENKINS_URL || 'YOUR_JENKINS_URL',
  github_token: process.env.GITHUB_TOKEN,
  webhook_secret: process.env.WEBHOOK_SECRET
};

async function configureWebhook() {
  if (!config.github_token) {
    console.error('Error: GITHUB_TOKEN environment variable is required');
    process.exit(1);
  }

  const octokit = new Octokit({
    auth: config.github_token
  });

  try {
    // Create webhook configuration
    const webhookConfig = {
      owner: config.owner,
      repo: config.repo,
      config: {
        url: `${config.jenkins_url}/github-webhook/`,
        content_type: 'json',
        secret: config.webhook_secret,
        insecure_ssl: '0'
      },
      events: ['push'],
      active: true
    };

    // Create the webhook
    const response = await octokit.repos.createWebhook(webhookConfig);

    if (response.status === 201) {
      console.log('Webhook created successfully!');
      console.log(`Webhook ID: ${response.data.id}`);
    }
  } catch (error) {
    if (error.status === 422) {
      console.log('Webhook already exists. Updating configuration...');
      try {
        // List existing webhooks
        const hooks = await octokit.repos.listWebhooks({
          owner: config.owner,
          repo: config.repo
        });

        // Find Jenkins webhook
        const jenkinsHook = hooks.data.find(hook => 
          hook.config.url.includes('github-webhook'));

        if (jenkinsHook) {
          // Update existing webhook
          await octokit.repos.updateWebhook({
            owner: config.owner,
            repo: config.repo,
            hook_id: jenkinsHook.id,
            config: webhookConfig.config,
            events: webhookConfig.events,
            active: webhookConfig.active
          });
          console.log('Webhook updated successfully!');
        }
      } catch (updateError) {
        console.error('Error updating webhook:', updateError);
      }
    } else {
      console.error('Error creating webhook:', error);
    }
  }
}

// Execute the configuration
configureWebhook();