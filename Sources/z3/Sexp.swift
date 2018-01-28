//
//  Sexp.swift
//  z3PackageDescription
//
//  Created by Brandon Kase on 1/1/18.
//

import Foundation

struct Label {
    let v: String
}
extension Label {
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

typealias MetaValue = [Token]
struct Sexp {
    let head: Label
    let metadata: [Label: MetaValue]
    let args: [Sexp]
    
    static let make: (Label) -> ([Label: MetaValue]) -> ([Sexp]) -> Sexp =
        { head in
            { metadata in
                { args in
                    Sexp(head: head, metadata: metadata, args: args) }}}
    
    static let parseRawSym: Parser<[Token], String> =
        Parsers.takeIf{
            if case let .sym(x) = $0 {
                return x
            } else { return nil }
        }
    
    static let parseRawLiteral: Parser<[Token], String> =
        Parsers.takeIf{
            if case let .literal(x) = $0 {
                return x
            } else { return nil }
        }
    
    static let parseHead: Parser<[Token], Label> =
        parseRawSym.map{ Label($0) }
    
    static let parseEquals: Parser<[Token], ()> =
        Parsers.takeIf{
            .equals == $0 ? () : nil
        }
    
    static let parseMetaValue: Parser<[Token], MetaValue> =
        Parsers.takeTilEmpty(lookaheadMax: 3) { (tok: Token, lookahead: [Token]) -> [Token] in
            print("Taking til empty", tok)
            if lookahead.count >= 2,
                let space = lookahead[0] as Token?,
                let functionRef = lookahead[1] as Token?,
                tok == .closeParen,
                space == .space,
                functionRef == .sym("function_ref") {
                print("Special case the stupid decls")
                return [tok]
            }
            if lookahead.count >= 2,
                let sym = lookahead[0] as Token?,
                let eq = lookahead[1] as Token?,
                case .sym(_) = sym,
                tok == .space,
                eq == .equals {
                print("The hard case", tok, sym, eq)
                return []
            } else if lookahead.count >= 3,
                let sym = lookahead[0] as Token?,
                let space = lookahead[1] as Token?,
                let openParen = lookahead[2] as Token?,
                tok == .space,
                case .sym(_) = sym,
                space == .space,
                openParen == .openParen {
                print("The ending in an implicit case")
                return []
            } else if lookahead.count >= 1,
                let spaceOrCloseParen = lookahead[0] as Token?,
                tok == .closeParen,
                spaceOrCloseParen == .space || spaceOrCloseParen == .closeParen {
                print("The ending of not-last recursive case")
                return []
            } else if lookahead.count >= 1,
                let openParen = lookahead[0] as Token?,
                openParen == .openParen,
                tok == .space {
                print("The next bunch of args case")
                return []
            } else if lookahead.count < 2 && (tok == .space || tok == .closeParen) {
                print("The space case", tok, lookahead)
                return []
            } else { return [tok] }
    }

    
    static let parseMetakv: Parser<[Token], (Label, MetaValue)> = {
        let makeTuple: (Label) -> (MetaValue) -> (Label, MetaValue) =
            { l in { s in (l, s) } }
        
        return (Parsers.takeIf{ print("starting", $0); return nil } <|> ((Parser(result: makeTuple) <*> (parseHead <* parseEquals) <*> parseMetaValue)) <|>
            ((parseRawSym <* Parsers.one(.equals)).map{ v in print("no val case", v); return (Label(v), []) }) <|>
            ((parseRawSym <|> parseRawLiteral).map{ v in print("gotcha", v); return (Label(v), [.sym(v)]) }))
            <|> Parsers.takeIf{ print("abandoned", $0); return nil }
    }()
    
    static let parseMetadata: Parser<[Token], [Label: MetaValue]> = {
        let tuples: Parser<[Token], [(Label, MetaValue)]> =
            (Parsers.one(.space) *> Parsers.rep(p: parseMetakv, separatedBy: Parsers.one(Token.space).ignore).map{ x in print("I'm done \(x)"); return x})
                <|> Parser(result: [])
        return tuples.map{ Dictionary($0, uniquingKeysWith: { x, _ in x }) }
    }()
    
    static let parseArgs: Parser<[Token], [Sexp]> =
        (Parsers.one(.space) *> Parser<[Token], Sexp>.loaded(name: "sexp")).many.map{ print("Made recursive", $0); return $0 }
    
    static let parse: Parser<[Token], Sexp> =
        (Parser(result: make) <*>
            (Parsers.one(.openParen) *> parseHead) <*>
            parseMetadata.map{ print("Got metadata", $0); return $0 } <*>
            (parseArgs
                <* Parsers.one(Token.closeParen))).stored(name: "sexp")
}

extension Sexp: Equatable {
    static func ==(lhs: Sexp, rhs: Sexp) -> Bool {
        let b1: Bool = lhs.head == rhs.head
        let leftMeta: [Label: String] = lhs.metadata.mapValues{ $0.map{ String(describing: $0) }.joined() }
        let rightMeta: [Label: String] =
            rhs.metadata.mapValues{ $0.map{ String(describing: $0) }.joined() }
        
        return b1 && (leftMeta == rightMeta) && zip(lhs.args, rhs.args).map{ lr in
                lr.0 == lr.1
            }.reduce(true, { $0 && $1 })
    }
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

