const { Client, GatewayIntentBits, SlashCommandBuilder, REST, Routes } = require('discord.js');
const express = require('express');
require('dotenv').config();

// Configuration
const TOKEN = process.env.DISCORD_BOT_TOKEN;
const CLIENT_ID = process.env.DISCORD_CLIENT_ID;
const GUILD_ID = process.env.DISCORD_GUILD_ID;
const PORT = parseInt(process.env.PORT || '3000');

// In-memory storage for latest Loop data
let currentLoopData = null;
let lastUpdateTime = null;

// Create Discord client
const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent
  ]
});

// Create Express server
const app = express();
app.use(express.json());

// Slash commands
const commands = [
  new SlashCommandBuilder()
    .setName('glucose')
    .setDescription('Get current blood glucose reading'),
  
  new SlashCommandBuilder()
    .setName('status')
    .setDescription('Get full Loop status (BG, IOB, COB, basal)'),
    
  new SlashCommandBuilder()
    .setName('insulin')
    .setDescription('Get detailed insulin information'),

  new SlashCommandBuilder()
    .setName('loop')
    .setDescription('Get Loop system status and last update time'),

  new SlashCommandBuilder()
    .setName('alert')
    .setDescription('Check if there are any alerts or issues')
].map(command => command.toJSON());

// Register commands
async function registerCommands() {
  try {
    const rest = new REST().setToken(TOKEN);
    
    if (GUILD_ID) {
      await rest.put(Routes.applicationGuildCommands(CLIENT_ID, GUILD_ID), { body: commands });
      console.log('✅ Registered guild slash commands');
    } else {
      await rest.put(Routes.applicationCommands(CLIENT_ID), { body: commands });
      console.log('✅ Registered global slash commands');
    }
  } catch (error) {
    console.error('❌ Error registering commands:', error);
  }
}

// Format data functions
function formatGlucoseData(data) {
  const timeSince = getTimeSinceUpdate();
  return `🩸 **Current Glucose**
**Reading:** ${data.glucose} mg/dL ${data.trend}
**Last Update:** ${timeSince}`;
}

function formatFullStatus(data) {
  const timeSince = getTimeSinceUpdate();
  const batteryInfo = data.batteryLevel ? `\n🔋 **Battery:** ${data.batteryLevel}%` : '';
  const insulinInfo = data.insulinRemaining ? `\n💧 **Insulin:** ${data.insulinRemaining}u remaining` : '';
  
  return `📊 **Complete Loop Status**
🩸 **Glucose:** ${data.glucose} mg/dL ${data.trend}
💉 **IOB:** ${data.iob}u
🍞 **COB:** ${data.cob}g
⚡ **Basal:** ${data.basalRate}u/h
🔄 **Loop:** ${data.loopStatus.toUpperCase()}${batteryInfo}${insulinInfo}
⏰ **Last Update:** ${timeSince}`;
}

function formatInsulinData(data) {
  const timeSince = getTimeSinceUpdate();
  let bolusInfo = '';
  
  if (data.lastBolus) {
    const bolusTime = new Date(data.lastBolus.timestamp);
    const bolusMinutesAgo = Math.round((Date.now() - bolusTime.getTime()) / (1000 * 60));
    bolusInfo = `\n💊 **Last Bolus:** ${data.lastBolus.amount}u (${bolusMinutesAgo}m ago)`;
  }

  return `💉 **Insulin Status**
📈 **IOB:** ${data.iob}u
⚡ **Current Basal:** ${data.basalRate}u/h${bolusInfo}
⏰ **Last Update:** ${timeSince}`;
}

function formatLoopStatus(data) {
  const timeSince = getTimeSinceUpdate();
  const statusEmoji = data.loopStatus === 'closed' ? '✅' : data.loopStatus === 'open' ? '⚠️' : '🛑';
  
  return `🔄 **Loop System Status**
${statusEmoji} **Status:** ${data.loopStatus.toUpperCase()}
📱 **Last Communication:** ${timeSince}
🔋 **Battery:** ${data.batteryLevel || 'Unknown'}%
💧 **Insulin Remaining:** ${data.insulinRemaining || 'Unknown'}u`;
}

function getTimeSinceUpdate() {
  if (!lastUpdateTime) return 'Never';
  
  const minutesAgo = Math.round((Date.now() - lastUpdateTime.getTime()) / (1000 * 60));
  if (minutesAgo < 1) return 'Just now';
  if (minutesAgo === 1) return '1 minute ago';
  if (minutesAgo < 60) return `${minutesAgo} minutes ago`;
  
  const hoursAgo = Math.round(minutesAgo / 60);
  if (hoursAgo === 1) return '1 hour ago';
  return `${hoursAgo} hours ago`;
}

function checkForAlerts(data) {
  const alerts = [];
  
  // Glucose alerts
  if (data.glucose > 180) alerts.push('🔴 High glucose');
  if (data.glucose < 70) alerts.push('🟡 Low glucose');
  if (data.glucose < 55) alerts.push('🚨 CRITICAL LOW glucose');
  
  // System alerts
  if (data.loopStatus !== 'closed') alerts.push(`⚠️ Loop is ${data.loopStatus}`);
  if (data.batteryLevel && data.batteryLevel < 20) alerts.push('🔋 Low battery');
  if (data.insulinRemaining && data.insulinRemaining < 10) alerts.push('💧 Low insulin');
  
  // Stale data alert
  const minutesSinceUpdate = lastUpdateTime ? Math.round((Date.now() - lastUpdateTime.getTime()) / (1000 * 60)) : 999;
  if (minutesSinceUpdate > 15) alerts.push('📡 No recent data updates');
  
  if (alerts.length === 0) {
    return '✅ **All Clear!** No alerts at this time.';
  }
  
  return `🚨 **Active Alerts:**\n${alerts.map(alert => `• ${alert}`).join('\n')}`;
}

// Helper function to send message to Discord channel
async function sendToDiscordChannel(message) {
  const channelId = process.env.DISCORD_CHANNEL_ID;
  if (channelId) {
    const channel = client.channels.cache.get(channelId);
    if (channel && channel.isTextBased()) {
      await channel.send(message);
    }
  }
}

// Bot event handlers
client.once('ready', async () => {
  console.log(`🚀 Bot logged in as ${client.user?.tag}!`);
  await registerCommands();
  await sendToDiscordChannel('🚀 Loop Discord Bot connected and ready to monitor!');
});

client.on('interactionCreate', async (interaction) => {
  if (!interaction.isChatInputCommand()) return;

  const { commandName } = interaction;
  
  if (!currentLoopData) {
    await interaction.reply('❌ No Loop data available yet. Make sure your Loop app is sending data to the bot.');
    return;
  }
  
  let response;
  
  switch (commandName) {
    case 'glucose':
      response = formatGlucoseData(currentLoopData);
      break;
    case 'status':
      response = formatFullStatus(currentLoopData);
      break;
    case 'insulin':
      response = formatInsulinData(currentLoopData);
      break;
    case 'loop':
      response = formatLoopStatus(currentLoopData);
      break;
    case 'alert':
      response = checkForAlerts(currentLoopData);
      break;
    default:
      response = '❓ Unknown command';
  }

  await interaction.reply(response);
  console.log(`✅ Responded to /${commandName} command`);
});

// Express routes
app.get('/health', (req, res) => {
  const status = {
    bot: 'running',
    lastUpdate: lastUpdateTime?.toISOString() || 'never',
    hasData: !!currentLoopData
  };
  res.json(status);
});

app.post('/loop-data', (req, res) => {
  try {
    const loopData = req.body;
    
    // Validate required fields
    if (!loopData.glucose || !loopData.timestamp) {
      return res.status(400).json({ error: 'Missing required fields: glucose, timestamp' });
    }
    
    // Store the data
    currentLoopData = loopData;
    lastUpdateTime = new Date();
    
    console.log(`✅ Received Loop data: ${loopData.glucose} mg/dL ${loopData.trend}`);
    
    // Send automatic alerts for critical values
    if (loopData.glucose > 250 || loopData.glucose < 60) {
      sendToDiscordChannel(`🚨 **CRITICAL ALERT** 🚨\n${formatGlucoseData(loopData)}`);
    }
    
    res.status(200).json({ message: 'Data received successfully' });
  } catch (error) {
    console.error('❌ Error processing Loop data:', error);
    res.status(400).json({ error: 'Invalid data format' });
  }
});

// Test endpoint
app.get('/test-glucose', (req, res) => {
  try {
    const mockData = {
      glucose: 145.0,
      trend: '↗️',
      timestamp: new Date().toISOString(),
      iob: 2.1,
      cob: 12.0,
      basalRate: 0.85,
      lastBolus: {
        amount: 3.5,
        timestamp: new Date(Date.now() - 45 * 60 * 1000).toISOString()
      },
      loopStatus: 'closed',
      batteryLevel: 78,
      insulinRemaining: 45.2
    };

    currentLoopData = mockData;
    lastUpdateTime = new Date();

    sendToDiscordChannel(formatFullStatus(mockData));
    res.json({ message: 'Test data sent to Discord!', data: mockData });
  } catch (error) {
    console.error('❌ Error sending test data:', error);
    res.status(500).json({ error: 'Error sending data' });
  }
});

// Start the server
app.listen(PORT, () => {
  console.log(`🌐 HTTP server running on port ${PORT}`);
  console.log(`📡 Ready to receive Loop data at http://localhost:${PORT}/loop-data`);
});

client.login(TOKEN);