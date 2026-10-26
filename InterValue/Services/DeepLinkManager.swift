import Foundation

/// Handles encoding workouts into shareable URLs and decoding them on receipt.
///
/// URL format:  intervalue://import?data=<base64url-encoded-JSON>
///
/// The base64 payload is a JSON-encoded [WorkoutDTO] array.
/// URL-safe base64 is used (+ → -, / → _, no padding) so the URL
/// doesn't need percent-encoding for the data parameter.
enum DeepLinkManager {

    static let scheme = "intervalue"
    static let importHost = "import"

    // MARK: - Export

    /// Encodes the given workouts into a shareable `intervalue://import?data=…` URL.
    /// Returns nil if encoding fails (shouldn't happen in practice).
    static func exportURL(for workouts: [WorkoutDTO]) -> URL? {
        let dtos = workouts.map { $0 }
        guard
            let jsonData = try? JSONEncoder().encode(dtos),
            let base64 = base64URLEncode(jsonData),
            var components = URLComponents(string: "\(scheme)://\(importHost)")
        else { return nil }

        components.queryItems = [URLQueryItem(name: "data", value: base64)]
        return components.url
    }

    // MARK: - Import

    /// Parses an incoming deep-link URL and returns the decoded workout list.
    /// Returns nil if the URL is not a valid import link or decoding fails.
    static func parseImportURL(_ url: URL) -> [WorkoutDTO]? {
        guard
            url.scheme == scheme,
            url.host == importHost,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let dataParam = components.queryItems?.first(where: { $0.name == "data" })?.value,
            let jsonData = base64URLDecode(dataParam),
            let dtos = try? JSONDecoder().decode([WorkoutDTO].self, from: jsonData)
        else { return nil }

        return dtos
    }

    // MARK: - Base64 URL Helpers

    private static func base64URLEncode(_ data: Data) -> String? {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Re-add padding
        let remainder = base64.count % 4
        if remainder != 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: base64)
    }
}
