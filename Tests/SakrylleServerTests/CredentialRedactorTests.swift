import SakrylleShared
import XCTest
@testable import SakrylleServer

final class CredentialRedactorTests: XCTestCase {
    func testRedactsNestedCredentials() {
        let input: JSONValue = .object([
            "a": .object([
                "credentials": .object(["x": .number(1)])
            ]),
            "b": .array([
                .object(["credentials": .string("secret")])
            ])
        ])

        let redacted = CredentialRedactor.redact(input)
        XCTAssertEqual(redacted, .object([
            "a": .object([
                "credentials": .object(["redacted": .bool(true)])
            ]),
            "b": .array([
                .object(["credentials": .object(["redacted": .bool(true)])])
            ])
        ]))
    }
}
