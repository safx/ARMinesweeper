//
//  GameField.swift
//  ARMine
//
//  Created by safx on 2017/10/10.
//  Copyright © 2017 safx. All rights reserved.
//

import Foundation


enum PlayerStateOfCell: Int {
    case nonChecked = -1
    case bombFlag   = -2
    case bombCount0 = 0
    case bombCount1 = 1
    case bombCount2 = 2
    case bombCount3 = 3
    case bombCount4 = 4
    case bombCount5 = 5
    case bombCount6 = 6
    case bombCount7 = 7
    case bombCount8 = 8
}

class GameField {
    var mines: [(Int, Int)]
    var matrix: [[PlayerStateOfCell]]
    
    var height: Int {
        return matrix.count
    }
    
    var width: Int {
        return matrix[0].count
    }
    
    init(width: Int, height: Int) {
        mines = Array<(Int, Int)>()
        matrix = Array<Array<PlayerStateOfCell>>(repeating: Array<PlayerStateOfCell>(repeating: .nonChecked, count: width), count: height)
    }
    
    func resetField() {
        for y in 0..<height {
            for x in 0..<width {
                matrix[y][x] = .nonChecked
            }
        }
        mines.removeAll()
    }
    
    func placeBombs(count: Int) {
        for _ in 0..<count {
            let x = Int(arc4random_uniform(UInt32(width)))
            let y = Int(arc4random_uniform(UInt32(height)))
            mines.append((x, y))
        }
    }
    
    func isPlacedBombAt(_ x: Int, _ y: Int) -> Bool {
        let found = mines.index { (bx, by) in bx == x && by == y }
        return found != nil
    }
    
    func cellStateAt(_ x: Int, _ y: Int) -> PlayerStateOfCell {
        return matrix[y][x]
    }
    
    func isOpenedAt(_ x: Int, _ y: Int) -> Bool {
        let m = matrix[y][x]
        let isClosed = m == .nonChecked || m == .bombFlag
        return !isClosed
    }
    
    @discardableResult
    func openAt(_ x: Int, _ y: Int) -> Bool {
        guard !isPlacedBombAt(x, y) else { return false }
        
        let b1 = isPlacedBombAt(x - 1, y - 1) ? 1 : 0
        let b2 = isPlacedBombAt(x    , y - 1) ? 1 : 0
        let b3 = isPlacedBombAt(x + 1, y - 1) ? 1 : 0
        let b4 = isPlacedBombAt(x - 1, y    ) ? 1 : 0
        let b5 = isPlacedBombAt(x + 1, y    ) ? 1 : 0
        let b6 = isPlacedBombAt(x - 1, y + 1) ? 1 : 0
        let b7 = isPlacedBombAt(x    , y + 1) ? 1 : 0
        let b8 = isPlacedBombAt(x + 1, y + 1) ? 1 : 0
        let c = b1 + b2 + b3 + b4 + b5 + b6 + b7 + b8
        matrix[y][x] = PlayerStateOfCell(rawValue: c)!
        return true
    }
    
    func openAll() {
        for y in 0..<height {
            for x in 0..<width {
                openAt(x, y)
            }
        }
    }
}

extension GameField: CustomDebugStringConvertible {
    var debugDescription: String {
        var out = ""
        for y in 0..<height {
            for x in 0..<width {
                let b = isPlacedBombAt(x, y)
                let c = b ? "o" : cellStateAt(x, y).debugDescription
                out += c
            }
            out += "\n"
        }
        return out
    }
}

extension PlayerStateOfCell: CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case .nonChecked: return "."
        case .bombFlag  : return "!"
        case .bombCount0: return "0"
        case .bombCount1: return "1"
        case .bombCount2: return "2"
        case .bombCount3: return "3"
        case .bombCount4: return "4"
        case .bombCount5: return "5"
        case .bombCount6: return "6"
        case .bombCount7: return "7"
        case .bombCount8: return "8"
        }
    }
}


