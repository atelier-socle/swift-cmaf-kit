// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - WRMHeaderXMLParser
//
// Reference: Microsoft "PlayReady Header XML" public specification.
// Parses the WRMHEADER root element and its DATA / PROTECTINFO /
// KID(S) / LA_URL / LUI_URL / DS_ID / CUSTOMATTRIBUTES /
// DECRYPTORSETUP children into the typed
// ``PlayReadyInitData/WRMHeader`` structure.
//
// CMAFKitDRM uses Foundation `XMLParser` rather than depending on
// a third-party XML library — keeps the DRM target zero-deps.

import Foundation

#if canImport(FoundationXML)
    import FoundationXML
#endif

internal enum WRMHeaderXMLParser {

    /// Parse a UTF-8 representation of the WRMHEADER XML body into
    /// the typed structure. `originalUTF16String` carries the
    /// original UTF-16 string when available so the parser can
    /// recover sections that depend on byte-level encoding (rare).
    static func parse(
        _ utf8Data: Data,
        originalUTF16String: String
    ) throws -> PlayReadyInitData.WRMHeader {
        let parser = XMLParser(data: utf8Data)
        let delegate = WRMHeaderXMLParserDelegate()
        parser.delegate = delegate
        guard parser.parse() else {
            let underlying = parser.parserError.map { "\($0)" } ?? "unknown"
            throw DRMSystemError.malformedInitData(
                systemID: .playReady,
                reason: "WRMHEADER XML parse failed: \(underlying)"
            )
        }
        if let error = delegate.firstError {
            throw error
        }
        guard let versionString = delegate.headerVersion else {
            throw DRMSystemError.malformedInitData(
                systemID: .playReady,
                reason: "WRMHEADER root element missing `version` attribute"
            )
        }
        guard let version = PlayReadyInitData.WRMHeader.Version(rawValue: versionString)
        else {
            throw DRMSystemError.wireFormatVersionUnsupported(
                systemID: .playReady,
                version: numericVersion(versionString)
            )
        }
        let kids = delegate.kids
        let licenseAcquisitionURL: URL? = delegate.licenseAcquisitionURLString.flatMap {
            URL(string: $0)
        }
        let licenseUIURL: URL? = delegate.licenseUIURLString.flatMap { URL(string: $0) }
        return PlayReadyInitData.WRMHeader(
            version: version,
            kids: kids,
            checksum: delegate.documentChecksum,
            licenseAcquisitionURL: licenseAcquisitionURL,
            licenseUIURL: licenseUIURL,
            domainServiceID: delegate.domainServiceID,
            customAttributesXML: delegate.customAttributesXML,
            decryptorSetup: delegate.decryptorSetup
        )
    }

    private static func numericVersion(_ string: String) -> UInt32 {
        var hash: UInt32 = 0
        for byte in string.utf8 {
            hash = hash &* 31 &+ UInt32(byte)
        }
        return hash
    }
}

/// XMLParser delegate that walks WRMHEADER and accumulates typed
/// fields into properties.
private final class WRMHeaderXMLParserDelegate: NSObject, XMLParserDelegate {
    var headerVersion: String?
    var kids: [PlayReadyInitData.WRMHeader.KID] = []
    var licenseAcquisitionURLString: String?
    var licenseUIURLString: String?
    var domainServiceID: String?
    var customAttributesXML: String?
    var decryptorSetup: String?
    var documentChecksum: Data?
    var firstError: DRMSystemError?

    private var elementStack: [String] = []
    private var characterBuffer: String = ""

    private struct PendingKID {
        var algorithmID: String?
        var checksum: Data?
        var valueType: String?
        var value: Data?
    }
    private var pendingKID: PendingKID?
    private var inCustomAttributes = false
    private var customAttributesDepth = 0

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        elementStack.append(elementName)
        characterBuffer = ""
        let lower = elementName.lowercased()
        switch lower {
        case "wrmheader":
            headerVersion = attributeDict["version"]
        case "kid":
            // Per Microsoft spec the KID element carries its
            // attributes (ALGID, CHECKSUM, VALUE) and (in v4.1+) a
            // base64 KID payload inside the `VALUE` attribute, or
            // in the element text for the v4.0 form.
            var pending = PendingKID()
            pending.algorithmID = attributeDict["ALGID"]
            pending.valueType = attributeDict["TYPE"]
            if let checksum = attributeDict["CHECKSUM"],
                let bytes = Data(base64Encoded: checksum)
            {
                pending.checksum = bytes
            }
            if let value = attributeDict["VALUE"],
                let bytes = Data(base64Encoded: value), bytes.count == 16
            {
                pending.value = bytes
            }
            pendingKID = pending
        case "customattributes":
            inCustomAttributes = true
            customAttributesDepth = 1
            customAttributesXML = ""
        default:
            if inCustomAttributes {
                customAttributesDepth += 1
                customAttributesXML?.append(serialiseStartTag(elementName, attributes: attributeDict))
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        characterBuffer.append(string)
        if inCustomAttributes {
            customAttributesXML?.append(string)
        }
    }

    func parser(
        _ parser: XMLParser,
        foundCDATA CDATABlock: Data
    ) {
        let chunk = String(data: CDATABlock, encoding: .utf8) ?? ""
        characterBuffer.append(chunk)
        if inCustomAttributes {
            customAttributesXML?.append("<![CDATA[\(chunk)]]>")
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        defer { elementStack.removeLast() }
        let trimmed = characterBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = elementName.lowercased()
        switch lower {
        case "kid":
            guard var pending = pendingKID else { return }
            if pending.value == nil, !trimmed.isEmpty,
                let bytes = Data(base64Encoded: trimmed), bytes.count == 16
            {
                pending.value = bytes
            }
            if let value = pending.value {
                kids.append(
                    PlayReadyInitData.WRMHeader.KID(
                        value: value,
                        algorithmID: pending.algorithmID,
                        checksum: pending.checksum,
                        valueType: pending.valueType
                    )
                )
            } else {
                firstError =
                    firstError
                    ?? DRMSystemError.malformedInitData(
                        systemID: .playReady,
                        reason: "WRMHEADER KID element missing 16-byte VALUE"
                    )
            }
            pendingKID = nil
        case "kids":
            break
        case "checksum":
            if elementStack.count >= 2,
                elementStack[elementStack.count - 2].lowercased() == "data",
                !trimmed.isEmpty,
                let bytes = Data(base64Encoded: trimmed)
            {
                documentChecksum = bytes
            }
        case "la_url":
            licenseAcquisitionURLString = trimmed
        case "lui_url":
            licenseUIURLString = trimmed
        case "ds_id":
            domainServiceID = trimmed
        case "decryptorsetup":
            decryptorSetup = trimmed
        case "customattributes":
            inCustomAttributes = false
        default:
            if inCustomAttributes {
                customAttributesDepth -= 1
                customAttributesXML?.append("</\(elementName)>")
            }
        }
        characterBuffer = ""
    }

    private func serialiseStartTag(_ name: String, attributes: [String: String]) -> String {
        if attributes.isEmpty {
            return "<\(name)>"
        }
        let sortedAttributes = attributes.sorted(by: { $0.key < $1.key })
        let attrs = sortedAttributes.map { "\($0.key)=\"\($0.value)\"" }.joined(separator: " ")
        return "<\(name) \(attrs)>"
    }
}
