import Vapor

final class StreamingController: RouteCollection, @unchecked Sendable {
    private let storage: any FileStoring
    private let catalog: any VideoCataloging
    private let tools: any ToolProvisioning
    private let converter: any HLSConverting

    init(
        storage: any FileStoring,
        catalog: any VideoCataloging,
        tools: any ToolProvisioning,
        converter: any HLSConverting
    ) {
        self.storage = storage
        self.catalog = catalog
        self.tools = tools
        self.converter = converter
    }

    func boot(
        routes: any RoutesBuilder
    ) throws {
        let group = routes.grouped("streamings")
        group.get(use: index)
        group.on(
            .POST,
            "upload",
            body: .collect(maxSize: "2gb"),
            use: upload
        )
    }

    func index(
        _ req: Request
    ) async throws -> [VideoInfo] {
        catalog.listAll()
    }

    func upload(
        _ req: Request
    ) async throws -> VideoInfo {
        let dto = try req.content.decode(UploadDTO.self)
        let ext = (dto.file.filename as NSString).pathExtension
        let (id, inputURL) = try storage.saveUpload(
            data: dto.file.data,
            suggestedExt: ext
        )

        try tools.ensureFFmpeg()

        let paths = storage.hlsOutputPaths(for: id)
        try converter.convertToHLS(
            input: inputURL,
            outDir: paths.dir,
            m3u8: paths.m3u8,
            segmentPattern: paths.segmentPattern
        )

        return VideoInfo(
            id: id,
            videoURL: "/videos/\(id)/master.m3u8"
        )
    }
}
