
public struct EchoLanguageModel: LanguageModel {
    public let executorConfiguration: EchoExecutor.Configuration

    public typealias Executor = EchoExecutor

    public init(modelId: String, apiKey: String?) {
        self.executorConfiguration = .init(
            modelId: modelId,
            apiKey: apiKey
        )
    }

    public var capabilities: LanguageModelCapabilities {
        let modelId = executorConfiguration.modelId
        let baseCapabilities: [LanguageModelCapabilities.Capability] = [
            .toolCalling, .guidedGeneration, .reasoning,
        ]
        if modelId == "multi-modal" {
            return LanguageModelCapabilities(baseCapabilities + [.vision])
        } else {
            return LanguageModelCapabilities(baseCapabilities)
        }
    }

    // OS 27.2 +
    private let supportedBaseDataType: [UTType] = [.image, .text]

    public nonisolated(nonsending) func supportsDataEntryType(_ type: UTType)
        async throws -> Bool
    {
        supportedBaseDataType.map({ type.conforms(to: $0) }).contains(true)
    }

    public nonisolated(nonsending) func supportsDataAttachmentType(
        _ type: UTType
    ) async throws -> Bool {
        supportedBaseDataType.map({ type.conforms(to: $0) }).contains(true)
    }
}

// LanguageModelExecutor: the bridge between the framework types and
// the provider system that actually generates the tokens (response)
// Automatically created by the system once we define the executorConfiguration of the model
public struct EchoExecutor: LanguageModelExecutor {
    public typealias Model = EchoLanguageModel

    // Fields for making connection to the provider
    public struct Configuration: Hashable, Sendable {
        public let modelId: String
        public let apiKey: String?

        public init(modelId: String, apiKey: String?) {
            self.modelId = modelId
            self.apiKey = apiKey
        }
    }

    public init(configuration: Configuration) throws {
        // use this to as a chance to, for example, create HTTP client from the configuration
        // and store it in some local variable
        // there is no need to store configuration itself as it will be accessible from the model
    }

    public func prewarm(model: EchoLanguageModel, transcript: Transcript) {
        print("Prewarming...")
    }

    public func respond(
        to request: LanguageModelExecutorGenerationRequest,
        model: EchoLanguageModel,
        streamingInto channel: LanguageModelExecutorGenerationChannel
    ) async throws {
        let configuration = model.executorConfiguration

        print(
            """
            Processing Request:
            request Id: \(request.id)
            model ID: \(configuration.modelId)
            metadata: \(request.metadata)
            contextOptions: \(request.contextOptions)
            Enabled Tools: \(request.enabledToolDefinitions.map(\.name))
            Generation Options: \(request.generationOptions)
            Output schema: \(request.schema, default: "No structured output specified")
            transcript: \(request.transcript.map(\.description).joined(separator: "\n"))
            ----------
            """
        )

        await self.streamReasoning(
            "processing some requests...",
            into: channel,
        )
        guard
            let lastUserMessage = request.transcript.map(\.userPrompt).last(
                where: { $0 != nil }), let lastUserMessage
        else {
            await self.streamResponseText(
                "Let me know what you want me to echo",
                into: channel
            )
            return
        }

        for segment in lastUserMessage.segments {
            switch segment {
            case .text(let text):
                await self.streamResponseText(
                    "Echo text: \n\(text.content)",
                    into: channel
                )
            case .structure(let structure):
                await self.streamResponseText(
                    "Echo structure: \n\(structure.content.jsonString)",
                    into: channel
                )
            case .attachment(let attachment):
                switch attachment.content {
                case .image(let imageAttachment):
                    await self.streamResponseText(
                        "Echo image attachment:",
                        into: channel
                    )
                    await self.streamImage(
                        imageAttachment.cgImage,
                        into: channel
                    )

                // OS: 27.2 +
                case .data(let dataAttachment):
                    await self.streamResponseText(
                        "Echo data attachment:",
                        into: channel
                    )
                    await self.streamData(
                        dataAttachment.content,
                        contentType: dataAttachment.contentType,
                        into: channel
                    )
                @unknown default:
                    await self.streamResponseText(
                        "Encountering unknown attachment",
                        into: channel
                    )
                }
            @unknown default:
                await self.streamResponseText(
                    "Encountering unknown segment",
                    into: channel
                )
            }
        }
    }

    private func streamReasoning(
        _ text: String,
        into channel: LanguageModelExecutorGenerationChannel,
    ) async {
        await channel.send(
            .reasoning(
                action: .appendText(text, tokenCount: text.count)
            )
        )
    }

    private func streamResponseText(
        _ text: String,
        into channel: LanguageModelExecutorGenerationChannel,
    ) async {
        await channel.send(
            .response(action: .appendText(text, tokenCount: text.count))
        )
    }

    private func streamImage(
        _ cgImage: CGImage,
        into channel: LanguageModelExecutorGenerationChannel
    ) async {
        await channel.send(
            .response(
                action: .addAttachmentSegment(
                    .init(content: .image(.init(cgImage)))
                )
            )
        )
    }

    private func streamData(
        _ data: Data,
        contentType: UTType,
        into channel: LanguageModelExecutorGenerationChannel
    ) async {
        await channel.send(
            .response(
                action: .addAttachmentSegment(
                    .init(
                        content: .data(
                            .init(contentType: contentType, content: data)
                        )
                    )
                )
            )
        )
    }
}

nonisolated extension Transcript.Entry {
    var systemInstruction: Transcript.Instructions? {
        if case .instructions(let instruction) = self {
            return instruction
        }
        return nil
    }

    var userPrompt: Transcript.Prompt? {
        if case .prompt(let prompt) = self {
            return prompt
        }
        return nil
    }
}
