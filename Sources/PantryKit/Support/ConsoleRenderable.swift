public protocol ConsoleRenderable: Encodable {
    var command: String { get }
    var humanDescription: String { get }
}

public protocol CSVRenderable {
    var csvHeaders: [String] { get }
    var csvRows: [[String]] { get }
}

extension CSVRenderable {
    public var csvDescription: String {
        CSVOutput.render(headers: csvHeaders, rows: csvRows)
    }
}
