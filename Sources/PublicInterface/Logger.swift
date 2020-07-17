//
//  Logger.swift
//  WalletConnectSwift
//
//  Created by Andrey Scherbovich on 17.07.20.
//  Copyright © 2020 Gnosis Ltd. All rights reserved.
//

import Foundation

public protocol Logger {
    func log(_ message: String)
}

public class ConsoleLogger: Logger {
    public func log(_ message: String) {
        print(message)
    }
}

public class NullLooger: Logger {
    public func log(_ message: String) { /* ignore */ }
}

public class LogService {
    public static var shared: Logger = ConsoleLogger()
}
