//
//  Logger.swift
//  WalletConnectSwift
//
//  Created by Andrey Scherbovich on 17.07.20.
//  Copyright © 2020 Gnosis Ltd. All rights reserved.
//

import Foundation
import os.log

public enum LoggerLevel: Int {
    case none = 0
    case error = 100
    case info = 200
    case detailed = 300
    case verbose = 400
}

public protocol Logger {
    func error(_ message: String)
    func info(_ message: String)
    func detailed(_ message: String)
    func verbose(_ message: String)
}

public class ConsoleLogger: Logger {
    static var consoleLogger: OSLog = OSLog(subsystem: "com.walletconnect", category: "WalletConnectSwift")

    public func error(_ message: String) {
        log(message, level: .error)
    }

    public func info(_ message: String) {
        log(message, level: .info)
    }

    public func detailed(_ message: String) {
        log(message, level: .detailed)
    }

    public func verbose(_ message: String) {
        log(message, level: .verbose)
    }

    func log(_ message: String, level: LoggerLevel) {
#if DEBUG
        guard level.rawValue <= LogService.level.rawValue else { return }

        os_log(
            "%{private}@",
            log: ConsoleLogger.consoleLogger,
            type: OSLogType.debug,
            message
        )
#endif
    }
}

/// Determine the log level by changing the `level` property.
public class LogService {
    static var shared: Logger = ConsoleLogger()

    /// Defines which logs are presented. Defaults to ``LoggerLevel/verbose``
    /// - Note: Logs are only available in debug mode
    public static var level: LoggerLevel = .verbose
}
