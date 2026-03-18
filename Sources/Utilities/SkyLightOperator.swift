// SkyLightOperator.swift
// Adapted from https://github.com/Lakr233/SkyLightWindow (MIT License)
//
// Uses the private SkyLight framework to create a custom Space at an absolute
// level above regular user Spaces. Windows delegated to this space do NOT
// participate in the Space swipe animation — they stay pinned to the screen
// like the menu bar and Dock.

import AppKit

final class SkyLightOperator {
    static let shared = SkyLightOperator()

    private let connection: Int32
    private let space: Int32

    private typealias F_SLSMainConnectionID = @convention(c) () -> Int32
    private typealias F_SLSSpaceCreate = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias F_SLSSpaceSetAbsoluteLevel = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias F_SLSShowSpaces = @convention(c) (Int32, CFArray) -> Int32
    private typealias F_SLSSpaceAddWindowsAndRemoveFromSpaces = @convention(c) (Int32, Int32, CFArray, Int32) -> Int32

    private let _SLSMainConnectionID: F_SLSMainConnectionID
    private let _SLSSpaceCreate: F_SLSSpaceCreate
    private let _SLSSpaceSetAbsoluteLevel: F_SLSSpaceSetAbsoluteLevel
    private let _SLSShowSpaces: F_SLSShowSpaces
    private let _SLSSpaceAddWindowsAndRemoveFromSpaces: F_SLSSpaceAddWindowsAndRemoveFromSpaces

    private init() {
        let handler = dlopen(
            "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight",
            RTLD_NOW
        )

        _SLSMainConnectionID = unsafeBitCast(
            dlsym(handler, "SLSMainConnectionID"),
            to: F_SLSMainConnectionID.self
        )
        _SLSSpaceCreate = unsafeBitCast(
            dlsym(handler, "SLSSpaceCreate"),
            to: F_SLSSpaceCreate.self
        )
        _SLSSpaceSetAbsoluteLevel = unsafeBitCast(
            dlsym(handler, "SLSSpaceSetAbsoluteLevel"),
            to: F_SLSSpaceSetAbsoluteLevel.self
        )
        _SLSShowSpaces = unsafeBitCast(
            dlsym(handler, "SLSShowSpaces"),
            to: F_SLSShowSpaces.self
        )
        _SLSSpaceAddWindowsAndRemoveFromSpaces = unsafeBitCast(
            dlsym(handler, "SLSSpaceAddWindowsAndRemoveFromSpaces"),
            to: F_SLSSpaceAddWindowsAndRemoveFromSpaces.self
        )

        // Create a custom space at absolute level 100 (above regular spaces,
        // below screen lock). This space is exempt from Space swipe animations.
        connection = _SLSMainConnectionID()
        space = _SLSSpaceCreate(connection, 1, 0)
        _ = _SLSSpaceSetAbsoluteLevel(connection, space, 100)
        _ = _SLSShowSpaces(connection, [space] as CFArray)
    }

    /// Move a window into the custom system-level space so it stays stationary
    /// during Space swipe animations.
    func delegateWindow(_ window: NSWindow) {
        _ = _SLSSpaceAddWindowsAndRemoveFromSpaces(
            connection,
            space,
            [window.windowNumber] as CFArray,
            7
        )
    }
}
