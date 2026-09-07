import Foundation

enum CatalogLoadState: Equatable {
    case idle
    case loading
    case loaded(hasStudio: Bool)
    case failed
}
