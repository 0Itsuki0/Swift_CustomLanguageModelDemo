# Swift_CustomLanguageModelDemo
A demo of implementing a custom language model to be used with the Foundation Models framework.

This repository demos how we can conform to LanguageModel protocol to bring custom models to the Foundation Models framework, 
including
- processing request parameters
- streaming responses

Sample Usage
```swift
let session = LanguageModelSession(
    model: EchoLanguageModel(
        modelId: "multi-modal",
        apiKey: nil,
    )
)
let response = try await session.respond(to: "hello.")
print(response.content)
```



For more details, please refer to my blog [Swift: Bring Custom Models To FoundationModels](https://medium.com/@itsuki.enjoy/swift-bring-custom-models-to-foundationmodels-18392e297cc6)
