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

class LoopDiscordBot {
    private let bot: BotGatewayManager
    
    init() async {
        let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
        self.bot = await BotGatewayManager(
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
    }
    
    func start() async {
        logger.info("Starting Loop Discord Bot...")
        
        // Register slash commands
        await registerSlashCommands()
        
        // Set up event handlers
        await bot.addEventHandler { event in
            await self.handleEvent(event)
        }
        
        // Connect to Discord
        await bot.connect()
    }
    
    private func registerSlashCommands() async {
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
        
        // Register commands (you'll need to implement this)
        logger.info("Slash commands registered")
    }
    
    private func handleEvent(_ event: Gateway.Event) async {
        switch event.data {
        case .interactionCreate(let interaction):
            await handleSlashCommand(interaction)
        default:
            break
        }
    }
    
    private func handleSlashCommand(_ interaction: Interaction) async {
        guard let data = interaction.data?.asApplicationCommand else { return }
        
        let response: String
        switch data.name {
        case "glucose":
            response = "🩸 Current: 125 mg/dL ↗️ (2 min ago)"
        case "status":
            response = "📊 BG: 125↗️ | IOB: 2.3u | COB: 15g | Basal: 0.8u/h"
        case "insulin":
            response = "💉 IOB: 2.3u | Last bolus: 1.5u (45 min ago) | Basal: 0.8u/h"
        default:
            response = "Unknown command"
        }
        
        // Send response (you'll need to implement this)
        logger.info("Responding to command: \(data.name)")
    }
}

@main
struct DiscordBot {
    static func main() async {
        guard !BotConfig.token.isEmpty else {
            logger.error("DISCORD_BOT_TOKEN environment variable not set")
            return
        }
        
        let discordBot = await LoopDiscordBot()
        await discordBot.start()
        
        // Keep running
        try? await Task.sleep(nanoseconds: UInt64.max)
    }
}