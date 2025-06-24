import Foundation
import DiscordBM
import AsyncHTTPClient
import Logging

let logger = Logger(label: "DiscordBot")

// Bot configuration
struct BotConfig {
    static let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? ""
    static let appId = ProcessInfo.processInfo.environment["DISCORD_APP_ID"] ?? ""
}

// Loop data structure for future use
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
    static func main() async {
        logger.info("Starting Loop Discord Bot...")
        
        guard !BotConfig.token.isEmpty else {
            logger.error("DISCORD_BOT_TOKEN environment variable not set")
            logger.info("Please set your bot token in the .env file")
            return
        }
        
        // Create HTTP client
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        
        // Create bot gateway manager
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
        
        // Add event handler - this is the correct API
        await bot.addEventHandler { event in
            logger.info("Received event: \(event.data)")
            
            switch event.data {
            case .ready(let ready):
                logger.info("Bot connected successfully as \(ready.user.username)!")
                
            case .messageCreate(let message):
                logger.info("Message received: \(message.content ?? "No content")")
                
                // Simple ping/pong test
                if message.content == "!ping" {
                    Task {
                        do {
                            try await bot.client.createMessage(
                                channelId: message.channel_id,
                                payload: .init(content: "🏓 Pong! Loop Bot is online!")
                            )
                        } catch {
                            logger.error("Failed to send message: \(error)")
                        }
                    }
                }
                
                // Test glucose command
                if message.content == "!glucose" {
                    Task {
                        do {
                            try await bot.client.createMessage(
                                channelId: message.channel_id,
                                payload: .init(content: "🩸 Current: 125 mg/dL ↗️ (2 min ago)")
                            )
                        } catch {
                            logger.error("Failed to send message: \(error)")
                        }
                    }
                }
                
            default:
                break
            }
        }
        
        // Connect to Discord
        await bot.connect()
        
        logger.info("Bot is now running... Type !ping or !glucose in Discord to test")
        logger.info("Press Ctrl+C to stop")
        
        // Keep the bot running
        try? await Task.sleep(nanoseconds: UInt64.max)
    }
}