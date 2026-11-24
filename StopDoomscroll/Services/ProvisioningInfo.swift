import Foundation

/// Reads the expiry date of the provisioning profile Xcode embedded in the app.
///
/// With a free Apple ID, apps installed from Xcode stop launching after 7 days. Knowing the
/// exact date lets the app remind you to re-run it from Xcode in time.
enum ProvisioningInfo {
    static let expirationDate: Date? = {
        guard
            let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
            let raw = try? Data(contentsOf: url),
            // The profile is a signed blob with an XML plist inside it.
            let text = String(data: raw, encoding: .isoLatin1),
            let start = text.range(of: "<?xml"),
            let end = text.range(of: "</plist>"),
            start.lowerBound < end.upperBound,
            let plistData = String(text[start.lowerBound..<end.upperBound]).data(using: .isoLatin1),
            let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil),
            let dictionary = plist as? [String: Any]
        else {
            return nil
        }
        return dictionary["ExpirationDate"] as? Date
    }()
}
