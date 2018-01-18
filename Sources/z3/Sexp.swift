//
//  Sexp.swift
//  z3PackageDescription
//
//  Created by Brandon Kase on 1/1/18.
//

import Foundation

struct Label {
    let v: String
    init(_ v: String) { self.v = v }
}

extension Label: Equatable {
    static func ==(lhs: Label, rhs: Label) -> Bool {
        return lhs.v == rhs.v
    }
}
extension Label: Hashable {
    var hashValue: Int {
        return v.hashValue
    }
}

indirect enum List<T> {
    case Nil
    case Cons(T, List<T>)
}

struct Sexp {
    let head: Label
    let metadata: [Label: String]
    let args: [Sexp]
    
    static let make: (Label) -> ([Label: String]) -> ([Sexp]) -> Sexp =
        { head in
            { metadata in
                { args in
                    Sexp(head: head, metadata: metadata, args: args) }}}
    
    static let parseSym: Parser<[Token], String> =
        Parsers.takeIf{
            if case let .sym(x) = $0 {
                return x
            } else { return nil }
        }
    
    static let parseHead: Parser<[Token], Label> =
        parseSym.map{ Label($0) }
    
    static let parseEquals: Parser<[Token], ()> =
        Parsers.takeIf{
            if case .equals = $0 {
                return ()
            } else {
                return nil
            }
        }
    
    static let parseMetaValue: Parser<[Token], String> =
        parseSym
    
    static let parseMetakv: Parser<[Token], (Label, String)> = {
        let makeTuple: (Label) -> (String) -> (Label, String) =
            { l in { s in (l, s) } }
        return Parser(result: makeTuple) <*> (parseHead <* parseEquals) <*> parseMetaValue
    }()
    
    static let parseMetadata: Parser<[Token], [Label: String]> = {
        let tuples: Parser<[Token], [(Label, String)]> =
            Parsers.rep(p: parseMetakv, separatedBy: Parsers.one(Token.space).ignore)
        return tuples.map{ Dictionary(uniqueKeysWithValues: $0) }
    }()
    
    static let parseArgs: Parser<[Token], [Sexp]> =
        Parser<[Token], Sexp>.loaded(name: "sexp").many
    
    static let parse: Parser<[Token], Sexp> =
        (Parser(result: make) <*>
            (Parsers.one(.openParen) *> parseHead) <*>
            (Parsers.one(.space) *> parseMetadata) <*>
            (parseArgs
                <* Parsers.one(Token.closeParen))).stored(name: "sexp")
}

struct KvPair {
    let key: Label
    let val: String
}

indirect enum KvSexp {
    case list(Label, [KvPair], [KvSexp])
}


enum Position {
    case File(String)
    case Line
}
struct Location {
    let file: Position
    let row: Int
    let col: Int
}
struct Metadata {
    let location: Location
    let range: (Location, Location)
}

indirect enum SwiftType {
    case int
    case tuple(SwiftType, SwiftType)
}

indirect enum Ast {
    case sourceFile([Ast])
    case funcDecl(signature: String, type: SwiftType)
}

