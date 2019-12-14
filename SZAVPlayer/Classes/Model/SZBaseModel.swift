//
//  SZBaseModel.swift
//  SZAVPlayer
//
//  Created by CaiSanze on 2019/12/13.
//

import UIKit

protocol SZBaseModel: Codable {
    static var tableName: String { get }
    static func deserialize(data: Any) -> Self?
}

extension SZBaseModel {

    static func deserialize(data: Any) -> Self? {
        if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: []),
            let info = try? JSONDecoder().decode(Self.self, from: jsonData)
        {
            return info
        }

        return nil
    }

}
