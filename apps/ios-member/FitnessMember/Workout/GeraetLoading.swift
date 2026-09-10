import Foundation

/// Was der Geraete-Screen vom Netz braucht.
///
/// Eigene schmale Fassade statt einer generischen Abstraktion -- dieselbe
/// Begruendung wie bei BootstrapLoading: APIClient ist bewusst ein actor
/// ohne Router, und ein Protokoll je Aufrufkontext bleibt testbar, ohne
/// den Client aufzublaehen.
protocol GeraetLoading: Sendable {
    func tagContext(token: String) async throws(APIError) -> TagContextResponse
    func machineContext(machineId: String) async throws(APIError) -> TagContextResponse
    func recordCalibration(_ body: CalibrationWrite) async throws(APIError) -> RecordedCalibration
    func completeSession(sessionId: UUID) async throws(APIError) -> CompletedSession
}

extension APIClient: GeraetLoading {}
