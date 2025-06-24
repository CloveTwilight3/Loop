import Foundation
import DiscordBM
import AsyncHTTPClient
import Logging

let logger = Logger(label: "DiscordBot")

// Simple bot configuration
struct BotConfig {
    static let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? ""
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
        
        // Simple event handling - just log what we receive
        await bot.addEventHandler(name: "ready") { event in
            logger.info("Bot connected successfully!")
            logger.info("Event received: \(event)")
        }
        
        await bot.addEventHandler(name: "messageCreate") { event in
            logger.info("Message event received: \(event)")
        }
        
        // Connect to Discord
        await bot.connect()
        
        logger.info("Bot is now running... Press Ctrl+C to stop")
        
        // Keep the bot running
        try? await Task.sleep(nanoseconds: UInt64.max)
    }
}