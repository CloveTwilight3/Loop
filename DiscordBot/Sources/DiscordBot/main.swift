import Foundation
import AsyncHTTPClient
import Logging
import Vapor

let logger = Logger(label: "DiscordBot")

// Configuration
struct BotConfig {
    static let discordWebhookURL = ProcessInfo.processInfo.environment["DISCORD_WEBHOOK_URL"] ?? ""
    static let port = Int(ProcessInfo.processInfo.environment["PORT"] ?? "8080") ?? 8080
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

// Discord webhook message
struct DiscordMessage: Codable {
    let content: String
}

class LoopBot {
    private let httpClient: HTTPClient
    
    init() {
        self.httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
    }
    
    func sendToDiscord(_ message: String) async throws {
        guard !BotConfig.discordWebhookURL.isEmpty else {
            logger.warning("Discord webhook URL not configured")
            return
        }
        
        let payload = DiscordMessage(content: message)
        let data = try JSONEncoder().encode(payload)
        
        var request = HTTPClientRequest(url: BotConfig.discordWebhookURL)
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")
        request.body = .bytes(data)
        
        let response = try await httpClient.execute(request, timeout: .seconds(10))
        logger.info("Discord message sent, status: \(response.status)")
    }
    
    func formatLoopData(_ data: LoopData) -> String {
        let trendArrow = data.trend
        let timestamp = DateFormatter().string(from: data.timestamp)
        
        return """
        🩸 **Loop Status Update**
        **Glucose:** \(data.glucose) mg/dL \(trendArrow)
        **IOB:** \(data.iob)u
        **COB:** \(data.cob)g  
        **Basal:** \(data.basalRate)u/h
        **Time:** \(timestamp)
        """
    }
}

@main
struct DiscordBot {
    static func main() async throws {
        let app = Application(.detect())
        defer { app.shutdown() }
        
        let bot = LoopBot()
        
        logger.info("Starting Loop Discord Bot on port \(BotConfig.port)")
        
        // Health check endpoint
        app.get("health") { req in
            return "Loop Discord Bot is running!"
        }
        
        // Webhook endpoint for Loop to send data
        app.post("loop-data") { req -> HTTPStatus in
            do {
                let loopData = try req.content.decode(LoopData.self)
                let message = bot.formatLoopData(loopData)
                try await bot.sendToDiscord(message)
                logger.info("Processed Loop data update")
                return .ok
            } catch {
                logger.error("Failed to process Loop data: \(error)")
                return .badRequest
            }
        }
        
        // Manual glucose check endpoint
        app.get("glucose") { req -> String in
            let mockData = LoopData(
                glucose: 125.0,
                trend: "↗️",
                timestamp: Date(),
                iob: 2.3,
                cob: 15.0,
                basalRate: 0.8
            )
            
            Task {
                try? await bot.sendToDiscord(bot.formatLoopData(mockData))
            }
            
            return "Glucose data sent to Discord!"
        }
        
        // Send startup message
        try await bot.sendToDiscord("🚀 Loop Discord Bot started and ready to monitor!")
        
        try await app.execute()
    }
}