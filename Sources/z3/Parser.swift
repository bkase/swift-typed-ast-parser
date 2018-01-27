//
//  Operators.swift
//  FastParsing
//
//  Created by Chris Eidhof on 26/12/2016.
//  Copyright © 2016 objc.io. All rights reserved.
//

// Chris confirmed that this is released under MIT
// Look at license.png in the PrettyErrors directory for screenshot of the email
infix operator <>: AdditionPrecedence
protocol Monoid {
    static var empty: Self { get }
    static func <>(lhs: Self, rhs: Self) -> Self
}
extension Array: Monoid {
    static var empty: Array {
        return []
    }
    static func <>(lhs: Array, rhs: Array) -> Array {
        return lhs + rhs
    }
}
protocol EmptyAwareness {
    var isEmpty: Bool { get }
}
extension Array: EmptyAwareness {
    var isEmpty: Bool {
        return self.count == 0
    }
}
import Foundation

var HACK_recursion_lookup_table: [String: Any] = [:]

struct Parser<Input, A> {
    let parse: (inout Input) -> A?
}
extension Parser {
    init(result: A) {
        self.parse = { _ in result }
    }
}
extension Parser {
    var many: Parser<Input, [A]> {
        return Parser<Input, [A]> { (input: inout Input) in
            var result: [A] = []
            while let x = self.parse(&input) {
                result.append(x)
            }
            return result
      }
    }
    
    func map<B>(_ f: @escaping (A) -> B) -> Parser<Input, B> {
        return Parser<Input, B> { (input: inout Input) in
            let backup = input
            if let a = self.parse(&input) {
                return f(a)
            } else {
                input = backup
                return nil
            }
        }
    }
    
    var ignore: Parser<Input, ()> {
        return self.map{ _ in () }
    }
    
    func stored(name: String) -> Parser {
        HACK_recursion_lookup_table[name] = self
        return self
    }
    static func loaded(name: String) -> Parser {
        return Parser { (input: inout Input) in
            (HACK_recursion_lookup_table[name]! as! Parser).parse(&input)
        }
    }
}

precedencegroup SequencePrecedence {
    associativity: left
    higherThan: ChoicePrecedence
}

precedencegroup ChoicePrecedence {
    associativity: left
    higherThan: BindPrecedence
}

precedencegroup BindPrecedence {
    associativity: left
    //    higherThan: LabelPrecedence
}


infix operator <^>: SequencePrecedence
infix operator <*>: SequencePrecedence
infix operator *>: SequencePrecedence
infix operator <*: SequencePrecedence

infix operator <|>: ChoicePrecedence

func *><Input, A,B>(p1: Parser<Input, A>, p2: Parser<Input, B>) -> Parser<Input, B> {
    return Parser(parse: { (s: inout Input) in
        let copy = s
        guard let _ = p1.parse(&s),
            let result = p2.parse(&s) else { s = copy; return nil }
        return result
    })
}

func <*<Input, A,B>(p1: Parser<Input, A>, p2: Parser<Input, B>) -> Parser<Input, A> {
    return Parser(parse: { (s: inout Input) -> A? in
        let copy = s
        guard let result = p1.parse(&s),
            let _ = p2.parse(&s) else { s = copy; return nil }
        return result
    })
    //return Parser<A>(lift: { x, _ in x }, p1, p2)
}

func <*><Input, A,B>(pf: Parser<Input, (A) -> B>, p: Parser<Input, A>) -> Parser<Input, B> {
    return Parser(parse: { (s: inout Input) -> B? in
        let copy = s
        guard let f = pf.parse(&s),
            let b = p.parse(&s) else {
                s = copy
                return nil
        }
        return f(b)
    })
}

func <^><Input, A,B>(f: @escaping (A) -> B, p2: Parser<Input, A>) -> Parser<Input, B> {
    return p2.map(f)
}

func <|><Input, A>(l: Parser<Input, A>, r: Parser<Input, A>) -> Parser<Input, A> {
    return Parser<Input, A>(parse: { (s: inout Input) -> A? in
        if let result = l.parse(&s) { return result }
        return r.parse(&s)
    })
}

enum Parsers {
    static func tapBefore<A, B>(_ msg: String) -> Parser<[A], B> {
        return takeIf{ print(msg, $0); return nil }
    }
    
    // tok, peek -> monoid
    static func takeTilEmpty<A, M: Monoid & EmptyAwareness>(lookaheadMax: Int, _ f: @escaping (A, [A]) -> M) -> Parser<[A], M> {
        return Parser { (input: inout [A]) -> M? in
            let snapshot = input
            let lookahead: [A] = ({
                if lookaheadMax == 0 {
                    return []
                }
                var lookaheadLeft = lookaheadMax
                
                if let second = snapshot.dropFirst().first {
                    var seq = snapshot.dropFirst()
                    lookaheadLeft = lookaheadLeft - 1
                    return Array(sequence(first: second, next: { _ in
                        if lookaheadLeft <= 0 {
                            return nil
                        } else {
                            lookaheadLeft = lookaheadLeft - 1
                            seq = seq.dropFirst()
                            return seq.first
                        }
                    }))
                } else {
                    return []
                }
            })()
            
            if let head = input.first,
                let b = f(head, lookahead) as M?,
                !b.isEmpty {
                let _ = input.removeFirst()
                // not tail-recursive, but :shrug: should be good enough
                return b <> (takeTilEmpty(lookaheadMax: lookaheadMax, f).parse(&input) ?? M.empty)
            } else {
                return nil
            }
        }
    }
    
    static func takeIf<A, B>(_ f: @escaping (A) -> B?) -> Parser<[A], B> {        
        return Parser { (input: inout [A]) -> B? in
            if let head = input.first,
                let b: B = f(head) {
                let _ = input.removeFirst()
                return b
            } else {
                return nil
            }
        }

    }
    static func one<A>(_ tok: A) -> Parser<[A], A> where A: Equatable {
        return takeIf { $0 == tok ? tok : nil }
    }
    
    /// Make a parser that wraps this parser with two characters
    /// Note: Make sure you don't greedily parse the endingWith character in `self`
    static func wrapped<A>(p: Parser<[A], [A]>, startingWith: A, endingWith: A) -> Parser<[A], [A]> where A: Equatable {
        
        func make3arr(begin: A) -> ([A]) -> (A) -> [A] {
            return { middle in { end in [begin] + middle + [end] }}
        }
        
        return Parser(result: make3arr) <*>
            Parsers.one(startingWith) <*>
            p <*>
            Parsers.one(endingWith)
    }
    
    /// Make a parser that looks for data repeated separated by `separatedBy`
    /// and return all the data (excluding the separatedBy bit)
    /// Note: Make sure you don't greedily parse the `separatedBy` character in `self`
    static func rep<A, B>(p: Parser<[A], B>, separatedBy: Parser<[A], ()>) -> Parser<[A], [B]> {
        
        func makeMany(begin: B) -> ([B]) -> [B] {
            return { rest in [begin] + rest }
        }
        
        return Parser(result: makeMany) <*>
            p <*>
            (separatedBy *> p).many
    }
}

/*
extension Character {
    var isSpace: Bool { // stolen from SwiftParsec
        switch self {
        case " ", "\t", "\n", "\r", "\r\n": return true
        case "\u{000B}", "\u{000C}": return true // Form Feed, vertical tab
        default: return false
        }
    }
}

// Some quick benchmarks (not at all scientific, just a larger file):
//
// Using a CharacterView is fast (0.6s). Using a CharacterView with a `position` property (and only mutating the position property) is a bit faster (0.5).
// Using an Array is a lot faster (0.4). An ArraySlice (without a position) has similar performance.

struct Remainder { // This is basically an ArraySlice, but I'm not sure if ArraySlices will ever change...
    let original: [Character]
    var position: Int
    let endIndex: Int // todo: not sure if we need to cache this?
}


extension Remainder: Collection {
    func string() -> String {
        return String(original)
    }
    
    
    mutating func next() -> Character? {
        guard position < endIndex else { return nil }
        let character = original[position]
        position = original.index(after: position)
        return character
    }
    
    init(_ string: String) {
        original = Array(string.characters)
        position = original.startIndex
        endIndex = original.endIndex
    }
    
    typealias Index = Int
    
    var startIndex: Index { return position }
    
    subscript(index: Index) -> Character {
        return original[index]
    }
    
    func index(after i: Index) -> Index {
        return original.index(after: i)
    }
}

extension Remainder {
    mutating func scanCharacter() -> Character? {
        return scanCharacter(condition: { _ in true })
    }
    
    mutating func peek() -> Character? {
        guard position < endIndex else { return nil }
        return original[position]
    }
    
    mutating func scanCharacter(condition: (Character) -> Bool) -> Character? {
        guard position < endIndex else { return nil }
        let character = original[position]
        guard condition(character) else {
            return nil
        }
        position = index(after: position)
        return character
    }
    
    
}

struct Parser<A> {
    let parse: (inout Remainder) -> A?
}

struct MyCharacterSet {
    var characters: Set<Character>
}

extension Parser {
    func run(string: String) -> A? {
        var substring = Remainder(string)
        let result = parse(&substring)
        guard substring.isEmpty else {
            // fatalError("Not empty: \(substring.string()). Parsed \(result)")
            // print("Only parsed \(result)")
            return nil
        }
        return result
    }
}

extension Parser where A: Equatable {
    func test(string: String, value: A) {
        guard let result = run(string: string) else {
            fatalError("Expected \(value), got nil (\(string))")
        }
        assert(result == value)
    }
}

extension Parser {
    
    init(lazy parser: @escaping() -> Parser) {
        parse = { (state: inout Remainder) in
            parser().parse(&state)
        }
    }
    
    static var fail: Parser<A> {
        return Parser { _ in nil }
    }
    
    static func character(condition: @escaping (Character) -> Bool) -> Parser<Character> {
        return Parser<Character> { (input: inout Remainder) in
            return input.scanCharacter(condition: condition)
        }
    }
    
    static func character(_ character: Character) -> Parser<Character> {
        return Parser.character(condition: { $0 == character })
    }
    
    var many: Parser<[A]> {
        return Parser<[A]> { (input: inout Remainder) in
            var result: [A] = []
            while let x = self.parse(&input) {
                result.append(x)
            }
            return result
        }
    }
    
    func manyTill<B>(_ end: Parser<B>) -> Parser<[A]> {
        return Parser<[A]> { (input: inout Remainder) in
            var result: [A] = []
            while !input.isEmpty {
                if let _ = end.parse(&input) {
                    return result
                } else if let value = self.parse(&input) {
                    result.append(value)
                }
            }
            // else
            return nil
        }
    }
    
    var many1: Parser<[A]> {
        return Parser<[A]> { (input: inout Remainder) in
            guard let value = self.parse(&input) else { return nil }
            return self.many.parse(&input).map { [value] + $0 }
        }
    }
    
    func map<B>(_ f: @escaping (A) -> B) -> Parser<B> {
        return Parser<B> { (input: inout Remainder) in
            return self.parse(&input).map(f)
        }
    }
    
    func flatMap<B>(_ f: @escaping (A) -> Parser<B>) -> Parser<B> {
        return Parser<B> { (input: inout Remainder) in
            if let result = self.parse(&input) {
                return f(result).parse(&input)
            }
            return nil
        }
    }
    
    func flatMap<B>(_ f: @escaping (A) -> B?) -> Parser<B> {
        return Parser<B> { (input: inout Remainder) in
            if let result = self.parse(&input) {
                return f(result)
            }
            return nil
        }
    }
    
    // Backtracks if parsing fails
    var attempt: Parser<A> {
        return Parser<A>(parse: { (input: inout Remainder) in
            let original = input.position
            if let result = self.parse(&input) { return result }
            input.position = original
            return nil
        })
    }
    
    // Succeeds if parsing fails
    var noOccurence: Parser<()> {
        return Parser<()>(parse: { (input: inout Remainder) in
            var copy = input
            if self.parse(&copy) == nil {
                return ()
            } else {
                return nil
            }
        })
    }
    
    func onlyIf(peek f: @escaping (Character) -> Bool) -> Parser<A> {
        return Parser<A>(parse: { (input: inout Remainder) in
            guard let c = input.peek(), f(c) else { return nil }
            return self.parse(&input)
        })
    }
    
    init(result: A) {
        self.parse = { _ in return result }
    }
    
    public func otherwise(_ result: A) -> Parser<A> {
        return self <|> Parser(result: result)
    }
    
    var optional: Parser<A?> {
        return map { .some($0) }.otherwise(nil)
    }
    
    static var any: Parser<Character> {
        return character { _ in true }
    }
    
    func between<P1,P2>(_ p1: Parser<P1>, _ p2: Parser<P2>) -> Parser<A> {
        return Parser { (s: inout Remainder) in
            return (p1 *> self <* p2).parse(&s)
        }
    }
    
    static func surrounded(by character: Character) -> Parser<String> {
        return surrounded(by: character, and: character)
    }
    
    static func surrounded(by character: Character, and character2: Character) -> Parser<String> {
        let delimiter1 = P.character(character)
        let delimiter2 = P.character(character2)
        return delimiter1 *> ({ String($0) } <^> P.any.manyTill(delimiter2))
    }
    
    static func choice(_ parsers: [Parser<A>]) -> Parser<A> {
        return parsers.reduce(Parser.fail, <|>)
        
    }
    
}

func <|><A>(l: Parser<A>, r: Parser<A>) -> Parser<A> {
    return Parser(parse: { (s: inout Remainder) -> A? in
        if let result = l.parse(&s) { return result }
        return r.parse(&s)
    })
}

typealias P = Parser<()> // Useful for static methods

extension Parser {
    init<P1, P2>(lift f: @escaping (P1, P2) -> A, _ p1: Parser<P1>, _ p2: Parser<P2>) {
        self.parse = { (input: inout Remainder) in
            guard let x = p1.parse(&input),
                let y = p2.parse(&input) else { return nil }
            return f(x,y)
        }
    }
    
    init<P1, P2, P3>(lift f: @escaping (P1, P2, P3) -> A, _ p1: Parser<P1>, _ p2: Parser<P2>, _ p3: Parser<P3>) {
        self.parse = { (input: inout Remainder) in
            p1.parse(&input).flatMap { x in
                p2.parse(&input).flatMap { y in
                    p3.parse(&input).flatMap { z in
                        f(x,y,z)
                    }
                }
            }
        }
    }
    
    init<P1, P2, P3, P4>(lift f: @escaping (P1, P2, P3, P4) -> A, _ p1: Parser<P1>, _ p2: Parser<P2>, _ p3: Parser<P3>, _ p4: Parser<P4>) {
        self.parse = { (input: inout Remainder) in
            p1.parse(&input).flatMap { x in
                p2.parse(&input).flatMap { y in
                    p3.parse(&input).flatMap { z in
                        p4.parse(&input).flatMap { a in
                            f(x,y,z,a)
                        }
                    }
                }
            }
        }
    }
    
    init<P1, P2, P3, P4, P5>(lift f: @escaping (P1, P2, P3, P4, P5) -> A, _ p1: Parser<P1>, _ p2: Parser<P2>, _ p3: Parser<P3>, _ p4: Parser<P4>, _ p5: Parser<P5>) {
        self.parse = { (input: inout Remainder) in
            p1.parse(&input).flatMap { x in
                p2.parse(&input).flatMap { y in
                    p3.parse(&input).flatMap { z in
                        p4.parse(&input).flatMap { a in
                            p5.parse(&input).flatMap { b in
                                f(x,y,z,a,b)
                            }
                        }
                    }
                }
            }
        }
    }
    
}

precedencegroup SequencePrecedence {
    associativity: left
    higherThan: ChoicePrecedence
}

precedencegroup ChoicePrecedence {
    associativity: left
    higherThan: BindPrecedence
}

precedencegroup BindPrecedence {
    associativity: left
    //    higherThan: LabelPrecedence
}


infix operator <^>: SequencePrecedence
infix operator <*>: SequencePrecedence
infix operator *>: SequencePrecedence
infix operator <*: SequencePrecedence

infix operator <|>: ChoicePrecedence

func *><A,B>(p1: Parser<A>, p2: Parser<B>) -> Parser<B> {
    return Parser(parse: { (s: inout Remainder) in
        guard let _ = p1.parse(&s),
            let result = p2.parse(&s) else { return nil }
        return result
    })
}

func <*<A,B>(p1: Parser<A>, p2: Parser<B>) -> Parser<A> {
    return Parser(parse: { (s: inout Remainder) -> A? in
        guard let result = p1.parse(&s),
            let _ = p2.parse(&s) else { return nil }
        return result
    })
    //return Parser<A>(lift: { x, _ in x }, p1, p2)
}

func <*><A,B>(pf: Parser<(A) -> B>, p: Parser<A>) -> Parser<B> {
    return Parser(parse: { (s: inout Remainder) -> B? in
        guard let f = pf.parse(&s),
            let b = p.parse(&s) else { return nil }
        return f(b)
    })
}

func <^><A,B>(f: @escaping (A) -> B, p2: Parser<A>) -> Parser<B> {
    return p2.map(f)
}

// Foundation-only
import Foundation


extension CharacterSet {
    func contains(_ char: Character) -> Bool {
        let scalars = String(char).unicodeScalars
        guard scalars.count == 1 else { return false }
        return contains(scalars.first!)
    }
    
    var parse: Parser<Character> {
        return P.character(condition: self.contains)
    }
}

extension Parser {
    static var digit: Parser<Character> {
        return CharacterSet.decimalDigits.parse
    }
    
    static var alphaNumeric: Parser<Character> {
        return CharacterSet.alphanumerics.parse
    }
    
    static var tab: Parser<Character> {
        return P.character("\t")
    }
    
    static var space: Parser<Character> {
        return P.character { $0.isSpace }
    }
    
    static var eof: Parser<()> {
        return Parser<()>{ (stream: inout Remainder) in
            if stream.isEmpty {
                return ()
            } else {
                return nil
            }
        }
    }
    
    static var newLine: Parser<Character> {
        return character("\n")
    }
    
    static var openingParen: Parser<Character> {
        return character("(")
    }
    
    static var closingParen: Parser<Character> {
        return character(")")
    }
    
    static func oneOf<C: Collection>(_ collection: C) -> Parser<Character> where C.Iterator.Element == Character {
        return character { collection.contains($0) }
    }
}

extension Parser where A == String {
    static func string(_ s: String) -> Parser {
        return Parser { (remainder: inout Remainder) in
            for c in s.characters {
                if remainder.scanCharacter(condition: { $0 == c }) == nil {
                    return nil
                }
            }
            return s
        }
        
    }
}
*/
