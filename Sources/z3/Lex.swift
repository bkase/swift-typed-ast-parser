//
//  Lex.swift
//  z3PackageDescription
//
//  Created by Brandon Kase on 1/1/18.
//

import Foundation


enum Token {
    case space
    case literal(String)
    case openParen
    case closeParen
    case comma
    case openBracket
    case closeBracket
    case number(Double)
    case equals
    case sym(String)
    case dot
    case colon
    case lessThan
    case greaterThan
    case char(Character)
    
    static let rules: [(String, (String) -> Token?)] = [
        ("\\(", { _ in .openParen }),
        ("\\)", { _ in .closeParen }),
        ("\\[", { _ in .openBracket }),
        ("\\]", { _ in .closeBracket }),
        ("=", { _ in .equals }),
        (",", { _ in .comma }),
        ("\\.", { _ in .dot }),
        ("\\:", { _ in .colon }),
        ("<", { _ in .lessThan }),
        (">", { _ in .greaterThan }),
        ("[ \t\n]", { _ in .space }),
        ("\".*?\"", { .literal(String($0.dropFirst().dropLast())) }),
        ("\'.*?\'", { .literal(String($0.dropFirst().dropLast())) }),
        ("[0-9.]+", { Double($0).map{ .number($0) } }),
        ("[a-zA-Z][_a-zA-Z0-9]*", { .sym($0) })
    ]
    
    // from: http://blog.matthewcheok.com/writing-a-lexer-in-swift/
    static func lex(input: String) -> [Token] {
        var tokens = [Token]()
        var content = input
        
        while (content.utf8.count > 0) {
            var matched = false
            
            for (pattern, generator) in rules {
                if let range = content.range(of: pattern, options: .regularExpression), range.lowerBound == content.startIndex {
                    let m = String(content[range])
                    if let t = generator(m) {
                        tokens.append(t)
                    }
                    
                    content.removeSubrange(range)
                    matched = true
                    break
                }
            }
            
            if !matched {
                let range: Range<String.Index> = Range(NSMakeRange(0, 1), in: content)!
                tokens.append(.char(Character(String(content[range]))))
                content.removeSubrange(range)
            }
        }
        return tokens
    }
}

extension Token: Equatable {
    static func ==(lhs: Token, rhs: Token) -> Bool {
        switch (lhs, rhs) {
        case (.space, .space),
            (.openParen, .openParen),
            (.closeParen, .closeParen),
            (.comma, .comma),
            (.openBracket, .openBracket),
            (.closeBracket, .closeBracket),
            (.equals, .equals),
            (.dot, .dot),
            (.colon, .colon),
            (.lessThan, .lessThan),
            (.greaterThan, .greaterThan):
            return true
        case let (.literal(x), .literal(y)): return x == y
        case let (.number(x), .number(y)): return x == y
        case let (.sym(x), .sym(y)): return x == y
        case let (.char(x), .char(y)): return x == y
        default:
            return false
        }
    }
}

extension Sequence where Iterator.Element == Token, SubSequence == Self {
    func oneSpace() -> [Token] {
        guard let head = (self.first{ _ in true }) else {
            return []
        }
        
        var acc: [Token] = [head]
        // TODO: Use the new good reduce
        for (prev, tok) in zip(self, self.dropFirst()) {
            if tok == .space && prev == tok {
                continue
            } else {
                acc.append(tok)
            }
        }
        return acc
    }
}
