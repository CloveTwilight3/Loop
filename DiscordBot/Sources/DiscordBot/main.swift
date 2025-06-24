import Foundation
import DiscordBM
import AsyncHTTPClient
import Logging

let logger = Logger(label: "DiscordBot")

// Bot configuration
struct BotConfig {
    static let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? ""
    static let guildId = ProcessInfo.processInfo.environment["DISCORD_GUILD_ID"] ?? ""
}

// Loop data structure
struct LoopData: Codable {
    let glucose: Double
    let trend: String
    let timestamp: Date
    let iob: Double
    let cob: Double
    let basalRate: Double
}

@main
struct DiscordBot {
    static func main() async throws {
        logger.info("Starting Loop Discord Bot...")
        
        guard !BotConfig.token.isEmpty else {
            logger.error("DISCORD_BOT_TOKEN environment variable not set")
            return
        }
        
        // Create HTTP client
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        
        // Create bot gateway manager (this is the correct syntax from examples)
        let bot = await BotGatewayManager(
            eventLoopGroup: httpClient.eventLoopGroup,
            httpClient: httpClient,
            token: BotConfig.token,
            presence: .init(
                activities: [.init(name: "Loop Health Data", type: .watching)],
                status: .online,
                afk: false
            ),
            intents: [.guildMessages, .messageContent]
        )
        
        logger.info("Bot configured, attempting to connect...")
        
        // Add event handlers (this is the correct syntax from official examples)
        await bot.addEventHandler { event in
            logger.info("Received event of type: \(type(of: event.data))")
            
            switch event.data {
            case .ready(let ready):
                logger.info("✅ Bot connected successfully as \(ready.user.username)!")
                
                // Register slash commands after connection
                Task {
                    await registerSlashCommands(bot: bot)
                }
                
            case .interactionCreate(let interaction):
                await handleSlashCommand(interaction: interaction, bot: bot)
                
            case .messageCreate(let message):
                // Handle regular messages for testing
                if message.content == "!ping" {
                    Task {
                        try? await bot.client.createMessage(
                            channelId: message.channel_id,
                            payload: .init(content: "🏓 Pong! Loop Bot is online!")
                        )
                    }
                }
                
            default:
                break
            }
        }
        
        // Connect to Discord
        await bot.connect()
        
        logger.info("🚀 Bot is now running... Use /glucose, /status, or /insulin commands!")
        
        // Keep running
        try await Task.sleep(nanoseconds: UInt64.max)
    }
}

// Register slash commands
func registerSlashCommands(bot: BotGatewayManager) async {
    let commands: [Payloads.ApplicationCommandCreate] = [
        .init(
            name: "glucose",
            description: "Get current blood glucose reading"
        ),
        .init(
            name: "status", 
            description: "Get full Loop status (BG, IOB, COB, basal)"
        ),
        .init(
            name: "insulin",
            description: "Get detailed insulin information"
        )
    ]
    
    for command in commands {
        do {
            if BotConfig.guildId.isEmpty {
                // Global commands
                try await bot.client.bulkSetGlobalApplicationCommands(payload: commands)
                logger.info("✅ Registered global slash commands")
                break
            } else {
                // Guild-specific commands (faster for testing)
                try await bot.client.bulkSetGuildApplicationCommands(
                    guildId: BotConfig.guildId,
                    payload: commands
                )
                logger.info("✅ Registered guild slash commands")
                break
            }
        } catch {
            logger.error("❌ Failed to register commands: \(error)")
        }
    }
}

// Handle slash commands
func handleSlashCommand(interaction: Interaction, bot: BotGatewayManager) async {
    guard case .applicationCommand(let data) = interaction.data else { return }
    
    let response: String
    switch data.name {
    case "glucose":
        response = "🩸 Current: 125 mg/dL ↗️ (2 min ago)"
    case "status":
        response = "📊 **Loop Status**\n🩸 BG: 125↗️\n💉 IOB: 2.3u\n🍞 COB: 15g\n⚡ Basal: 0.8u/h"
    case "insulin":
        response = "💉 **Insulin Status**\n📈 IOB: 2.3u\n💊 Last bolus: 1.5u (45 min ago)\n⚡ Current basal: 0.8u/h"
    default:
        response = "❓ Unknown command"
    }
    
    do {
        try await bot.client.createInteractionResponse(
            id: interaction.id,
            token: interaction.token,
            payload: .channelMessageWithSource(.init(content: response))
        )
        logger.info("✅ Responded to /\(data.name) command")
    } catch {
        logger.error("❌ Failed to respond to command: \(error)")
    }
}