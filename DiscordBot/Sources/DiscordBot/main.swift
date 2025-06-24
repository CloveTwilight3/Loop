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
    private let httpClient: HTTPClient
    
    init() async {
        self.httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
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
        
        // Set up event handlers
        await bot.addEventHandler(name: "interactionCreate") { event in
            await self.handleEvent(event)
        }
        
        // Connect to Discord
        await bot.connect()
        
        // Register slash commands after connection
        try? await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds
        await registerSlashCommands()
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
        
        for command in commands {
            do {
                let _ = try await bot.client.createGlobalApplicationCommand(payload: command)
                logger.info("Registered command: \(command.name)")
            } catch {
                logger.error("Failed to register command \(command.name): \(error)")
            }
        }
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
        guard case .applicationCommand(let data) = interaction.data else { return }
        
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
        
        let responsePayload = Payloads.InteractionResponse(
            type: .channelMessageWithSource,
            data: .init(content: response)
        )
        
        do {
            try await bot.client.createInteractionResponse(
                id: interaction.id,
                token: interaction.token,
                payload: responsePayload
            )
            logger.info("Responded to command: \(data.name)")
        } catch {
            logger.error("Failed to respond to command: \(error)")
        }
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