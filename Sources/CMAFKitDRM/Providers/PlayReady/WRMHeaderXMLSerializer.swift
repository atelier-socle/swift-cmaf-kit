// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - WRMHeaderXMLSerializer
//
// Reference: Microsoft "PlayReady Header XML" public specification.
//
// Emits a WRMHEADER XML document in canonical form: ascending
// attribute order, no whitespace between elements, child order
// matches the spec (KID/KIDS, then DATA's CHECKSUM, then LA_URL,
// LUI_URL, DS_ID, CUSTOMATTRIBUTES, DECRYPTORSETUP). This yields
// byte-perfect round-trip for values CMAFKitDRM produces; in-the-
// wild inputs with a different child order re-encode to canonical
// form (semantic equivalence retained).

import Foundation

internal enum WRMHeaderXMLSerializer {

    static func serialize(_ header: PlayReadyInitData.WRMHeader) -> String {
        var xml = ""
        xml.append(
            "<WRMHEADER xmlns=\"http://schemas.microsoft.com/DRM/2007/03/PlayReadyHeader\" "
        )
        xml.append("version=\"\(header.version.rawValue)\">")
        xml.append("<DATA>")
        if header.version == .v4_0 {
            xml.append(emitV40KIDs(header.kids))
        } else {
            xml.append(emitV41PlusKIDs(header.kids))
        }
        if let checksum = header.checksum {
            xml.append("<CHECKSUM>\(checksum.base64EncodedString())</CHECKSUM>")
        }
        if let url = header.licenseAcquisitionURL {
            xml.append("<LA_URL>\(xmlEscape(url.absoluteString))</LA_URL>")
        }
        if let url = header.licenseUIURL {
            xml.append("<LUI_URL>\(xmlEscape(url.absoluteString))</LUI_URL>")
        }
        if let dsid = header.domainServiceID {
            xml.append("<DS_ID>\(xmlEscape(dsid))</DS_ID>")
        }
        if let custom = header.customAttributesXML {
            xml.append("<CUSTOMATTRIBUTES>\(custom)</CUSTOMATTRIBUTES>")
        }
        if let setup = header.decryptorSetup {
            xml.append("<DECRYPTORSETUP>\(xmlEscape(setup))</DECRYPTORSETUP>")
        }
        xml.append("</DATA>")
        xml.append("</WRMHEADER>")
        return xml
    }

    private static func emitV40KIDs(_ kids: [PlayReadyInitData.WRMHeader.KID]) -> String {
        // v4.0 carries a single <KID> element with the value either
        // in the element text or as the VALUE attribute.
        guard let kid = kids.first else { return "" }
        var attrs: [(String, String)] = []
        if let algo = kid.algorithmID {
            attrs.append(("ALGID", algo))
        }
        if let checksum = kid.checksum {
            attrs.append(("CHECKSUM", checksum.base64EncodedString()))
        }
        attrs.sort { $0.0 < $1.0 }
        let attrString = attrs.isEmpty ? "" : " " + attrs.map { "\($0.0)=\"\($0.1)\"" }.joined(separator: " ")
        return "<KID\(attrString)>\(kid.value.base64EncodedString())</KID>"
    }

    private static func emitV41PlusKIDs(_ kids: [PlayReadyInitData.WRMHeader.KID]) -> String {
        // v4.1+ carries one or more KID elements under <KIDS>; each
        // KID exposes its VALUE via the `VALUE` attribute.
        var inner = "<KIDS>"
        for kid in kids {
            var attrs: [(String, String)] = [
                ("VALUE", kid.value.base64EncodedString())
            ]
            if let algo = kid.algorithmID {
                attrs.append(("ALGID", algo))
            }
            if let checksum = kid.checksum {
                attrs.append(("CHECKSUM", checksum.base64EncodedString()))
            }
            if let type = kid.valueType {
                attrs.append(("TYPE", type))
            }
            attrs.sort { $0.0 < $1.0 }
            let attrString =
                attrs.map { "\($0.0)=\"\($0.1)\"" }.joined(separator: " ")
            inner.append("<KID \(attrString)></KID>")
        }
        inner.append("</KIDS>")
        return inner
    }

    private static func xmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
