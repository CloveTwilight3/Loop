import { Client, GatewayIntentBits, SlashCommandBuilder, REST, Routes, CommandInteraction } from 'discord.js';
import express from 'express';
import dotenv from 'dotenv';

dotenv.config();

// Configuration
const TOKEN = process.env.DISCORD_BOT_TOKEN!;
const CLIENT_ID = process.env.DISCORD_CLIENT_ID!;
const GUILD_ID = process.env.DISCORD_GUILD_ID; // Optional - for faster command updates
const PORT = parseInt(process.env.PORT || '3000');

// Loop data interface
interface LoopData {
  glucose: number;
  trend: string;
  timestamp: string;
  iob: number;
  cob: number;
  basalRate: number;
}

// Create Discord client
const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent
  ]
});

// Create Express server for webhooks
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
    .setDescription('Get detailed insulin information')
].map(command => command.toJSON());

// Register commands
async function registerCommands() {
  try {
    const rest = new REST().setToken(TOKEN);
    
    if (GUILD_ID) {
      // Register guild commands (instant updates for testing)
      await rest.put(Routes.applicationGuildCommands(CLIENT_ID, GUILD_ID), { body: commands });
      console.log('✅ Registered guild slash commands');
    } else {
      // Register global commands (takes up to 1 hour to update)
      await rest.put(Routes.applicationCommands(CLIENT_ID), { body: commands });
      console.log('✅ Registered global slash commands');
    }
  } catch (error) {
    console.error('❌ Error registering commands:', error);
  }
}

// Format Loop data for Discord
function formatLoopData(data: LoopData): string {
  const timestamp = new Date(data.timestamp).toLocaleString();
  return `🩸 **Loop Status Update**
**Glucose:** ${data.glucose} mg/dL ${data.trend}
**IOB:** ${data.iob}u
**COB:** ${data.cob}g  
**Basal:** ${data.basalRate}u/h
**Time:** ${timestamp}`;
}

// Bot event handlers
client.once('ready', async () => {
  console.log(`🚀 Bot logged in as ${client.user?.tag}!`);
  await registerCommands();
});

client.on('interactionCreate', async (interaction) => {
  if (!interaction.isChatInputCommand()) return;

  const { commandName } = interaction;
  
  let response: string;
  
  switch (commandName) {
    case 'glucose':
      response = '🩸 Current: 125 mg/dL ↗️ (2 min ago)';
      break;
    case 'status':
      response = '📊 **Loop Status**\n🩸 BG: 125↗️\n💉 IOB: 2.3u\n🍞 COB: 15g\n⚡ Basal: 0.8u/h';
      break;
    case 'insulin':
      response = '💉 **Insulin Status**\n📈 IOB: 2.3u\n💊 Last bolus: 1.5u (45 min ago)\n⚡ Current basal: 0.8u/h';
      break;
    default:
      response = '❓ Unknown command';
  }

  await interaction.reply(response);
  console.log(`✅ Responded to /${commandName} command`);
});

// Express routes for Loop integration
app.get('/health', (req, res) => {
  res.send('Loop Discord Bot is running!');
});

app.post('/loop-data', (req, res) => {
  try {
    const loopData: LoopData = req.body;
    const message = formatLoopData(loopData);
    
    // Send to Discord channel (you'll need to set a channel ID)
    const channelId = process.env.DISCORD_CHANNEL_ID;
    if (channelId) {
      const channel = client.channels.cache.get(channelId);
      if (channel?.isTextBased()) {
        channel.send(message);
      }
    }
    
    console.log('✅ Processed Loop data update');
    res.status(200).send('OK');
  } catch (error) {
    console.error('❌ Error processing Loop data:', error);
    res.status(400).send('Bad Request');
  }
});

app.get('/glucose', async (req, res) => {
  const mockData: LoopData = {
    glucose: 125.0,
    trend: '↗️',
    timestamp: new Date().toISOString(),
    iob: 2.3,
    cob: 15.0,
    basalRate: 0.8
  };

  const channelId = process.env.DISCORD_CHANNEL_ID;
  if (channelId) {
    const channel = client.channels.cache.get(channelId);
    if (channel?.isTextBased()) {
      await channel.send(formatLoopData(mockData));
    }
  }

  res.send('Glucose data sent to Discord!');
});

// Start the bot and server
app.listen(PORT, () => {
  console.log(`🌐 HTTP server running on port ${PORT}`);
});

client.login(TOKEN);