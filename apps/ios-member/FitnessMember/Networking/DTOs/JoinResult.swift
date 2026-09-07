import Foundation

struct JoinResult: Decodable, Equatable {
    let studioId: String
    let machineId: String?
    let joined: Bool
}

struct JoinByCodeRequest: Encodable { let code: String }
struct JoinByTagRequest: Encodable { let tagToken: String }
