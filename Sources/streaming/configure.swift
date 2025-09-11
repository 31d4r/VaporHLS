import Vapor

public func configure(_ app: Application) throws {
    app.middleware.use(
        FileMiddleware(
            publicDirectory: app.directory.publicDirectory
        )
    )
    app.routes.defaultMaxBodySize = "2gb"

    let logger = app.logger
    let runner = ProcessRunner(
        logger: logger
    )
    let os = OSDetector()

    let storage = FileStorageService(
        publicDirectory: app.directory.publicDirectory
    )
    let catalog = VideoCatalogService(
        publicDirectory: app.directory.publicDirectory
    )
    let tools = FFmpegProvisioner(
        runner: runner,
        os: os,
        logger: logger
    )
    let conv = HLSConversionService(
        runner: runner,
        logger: logger
    )

    let streamingController = StreamingController(
        storage: storage,
        catalog: catalog,
        tools: tools,
        converter: conv
    )
    try app.register(
        collection: streamingController
    )

    try routes(app)
}
