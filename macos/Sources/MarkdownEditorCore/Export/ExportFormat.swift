public enum ExportFormat {
    case html
    case pdf

    public var fileExtension: String {
        switch self {
        case .html: return "html"
        case .pdf: return "pdf"
        }
    }
}
