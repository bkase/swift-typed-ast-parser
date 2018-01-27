
import Foundation

/*protocol Nat {}
enum Z: Nat {}
enum S<N: Nat>: Nat {}

typealias _0 = Z
typealias _1 = S<_0>
typealias _2 = S<_1>
typealias _3 = S<_2>

enum Vector<N:Nat, T> {
    case _nil
    case _cons(T, Vector<Pred<N>, T>)
    
    static func empty() -> Vector<_0, T> {
        return ._nil
    }
    
    static func cons(_ head: T, _ rest: Vector) -> Vector<S<N>, T> {
        return ._cons(head, rest)
    }
    
}
*/


struct Parsed<A> {
    let lexed: [Token]
    let parsed: A?
}
extension Parsed where A: Equatable {
    func assert(equalTo a: A, message: String = "") {
        if self.parsed != a {
            fatalError("Expected \(a) but got \(String(describing: self.parsed))")
        } else {
            print("✅   \(message)")
        }
    }
}

extension Dictionary: Equatable {
    public static func ==(lhs: Dictionary, rhs: Dictionary) -> Bool {
        // close enough
        return "\(lhs)" == "\(rhs)"
    }
}

func lexAndParse<A>(s: String, parser: Parser<[Token], A>) -> Parsed<A> {
    var lexed = Token.lex(input: s).dropFirst(0).oneSpace()
    let before = lexed
    let result = parser.parse(&lexed)
    let after = lexed
    return Parsed(lexed: after, parsed: result)
}

func main() {
    let ast = "/Users/bkase/swift-typed-ast-parser/hello.ast"
    guard let contents = FileManager.default.contents(atPath: ast) else {
        fatalError("Can't read file")
    }
    guard let astString = String(data: contents, encoding: .utf8) else {
        fatalError("Can't unwrap utf8 string from data")
    }
    
    //print(Label.parser.run(string: "asbdasbd")!)
    //let p: Parser<Sexp> = Parser<()>.openingParen *>
    //    Parser(result: .atom(Label("a")))
    //    <* Parser<()>.closingParen

    
    //print(Sexp.parser.run(string: "(declref_expr type='Int' location=hello.swift:9:38 range=[hello.swift:9:38-line:9:38] decl=hello.(file).smart(accountA:accountB:amt:).amt@hello.swift:1:42 function_ref=unapplied)"))
    /*guard let sexp = Sexp.parser.run(string: "(a b (c d)) ") else {
        fatalError("Failed to parse \(astString)")
    }
    print("Successfully parsed \(sexp)")*/
    
    lexAndParse(s: "abc", parser: (Parsers.takeTilEmpty(lookaheadMax: 3) { tok, lookahead in [] } <|>
        (Parsers.takeTilEmpty(lookaheadMax: 3) { tok, lookahead in [] }) <|>
        Sexp.parseHead.map{ [$0] }).map{ $0[0] }).assert(equalTo: Label("abc"))
        
    lexAndParse(s: "(head x=a y=c)", parser: Sexp.parse).assert(equalTo: z3.Sexp(head: z3.Label(v: "head"), metadata: [z3.Label(v: "y"): [z3.Token.sym("c")], z3.Label(v: "x"): [z3.Token.sym("a")]], args: []))
   // lexAndParse(s: "head", parser: Sexp.parseHead)
   // lexAndParse(s: "x=a y=b z=c ", parser: Sexp.parseMetadata)
    func makeTuple(x: Label) -> ([Label: String]) -> (Label, [Label: String]) {
        return { s in (x, s) }
    }
    lexAndParse(s: "(head x=a y=c (head2 x=a))", parser: Sexp.parse).assert(equalTo:
        z3.Sexp(head: z3.Label(v: "head"), metadata: [z3.Label(v: "y"): [z3.Token.sym("c")], z3.Label(v: "x"): [z3.Token.sym("a")]], args: [z3.Sexp(head: z3.Label(v: "head2"), metadata: [z3.Label(v: "x"): [z3.Token.sym("a")]], args: [])]), message: "Simple with recursion")
    lexAndParse(s: "(x y=head.swift:9:0 q=z (foo re=x))", parser: Sexp.parse).assert(equalTo:
        z3.Sexp(head: z3.Label(v: "x"), metadata: [z3.Label(v: "q"): [z3.Token.sym("z")], z3.Label(v: "y"): [z3.Token.sym("head"), z3.Token.dot, z3.Token.sym("swift"), z3.Token.colon, z3.Token.number(9.0), z3.Token.colon, z3.Token.number(0.0)]], args: [z3.Sexp(head: z3.Label(v: "foo"), metadata: [z3.Label(v: "re"): [z3.Token.sym("x")]], args: [])]), message: "Complex meta value"
    )
    lexAndParse(s: "(declref_expr type='Int' location=hello.swift:9:38 range=[hello.swift:9:38-line:9:38] decl=hello.(file).smart(accountA:accountB:amt:).amt@hello.swift:1:42 function_ref=unapplied)", parser: Sexp.parse).assert(equalTo:
        z3.Sexp(head: z3.Label(v: "declref_expr"), metadata: [z3.Label(v: "range"): [z3.Token.openBracket, z3.Token.sym("hello"), z3.Token.dot, z3.Token.sym("swift"), z3.Token.colon, z3.Token.number(9.0), z3.Token.colon, z3.Token.number(38.0), z3.Token.char("-"), z3.Token.sym("line"), z3.Token.colon, z3.Token.number(9.0), z3.Token.colon, z3.Token.number(38.0), z3.Token.closeBracket], z3.Label(v: "location"): [z3.Token.sym("hello"), z3.Token.dot, z3.Token.sym("swift"), z3.Token.colon, z3.Token.number(9.0), z3.Token.colon, z3.Token.number(38.0)], z3.Label(v: "decl"): [z3.Token.sym("hello"), z3.Token.dot, z3.Token.openParen, z3.Token.sym("file"), z3.Token.closeParen, z3.Token.dot, z3.Token.sym("smart"), z3.Token.openParen, z3.Token.sym("accountA"), z3.Token.colon, z3.Token.sym("accountB"), z3.Token.colon, z3.Token.sym("amt"), z3.Token.colon, z3.Token.closeParen, z3.Token.dot, z3.Token.sym("amt"), z3.Token.char("@"), z3.Token.sym("hello"), z3.Token.dot, z3.Token.sym("swift"), z3.Token.colon, z3.Token.number(1.0), z3.Token.colon, z3.Token.number(42.0)], z3.Label(v: "type"): [z3.Token.literal("Int")], z3.Label(v: "function_ref"): [z3.Token.sym("unapplied")]], args: []), message: "very complex meta values"
    )
    let dummy = Sexp(head: Label(v: "test"), metadata: [:], args: [])
    
    lexAndParse(s: "(declref_expr implicit decl=Swift.(file).BinaryInteger.<= [with Int[Int: BinaryInteger module Swift]] x=y)", parser: Sexp.parse).assert(equalTo:z3.Sexp(head: z3.Label(v: "declref_expr"), metadata: [z3.Label(v: "x"): [z3.Token.sym("y")], z3.Label(v: "implicit"): [z3.Token.sym("implicit")], z3.Label(v: "decl"): [z3.Token.sym("Swift"), z3.Token.dot, z3.Token.openParen, z3.Token.sym("file"), z3.Token.closeParen, z3.Token.dot, z3.Token.sym("BinaryInteger"), z3.Token.dot, z3.Token.lessThan, z3.Token.equals, z3.Token.space, z3.Token.openBracket, z3.Token.sym("with"), z3.Token.space, z3.Token.sym("Int"), z3.Token.openBracket, z3.Token.sym("Int"), z3.Token.colon, z3.Token.space, z3.Token.sym("BinaryInteger"), z3.Token.space, z3.Token.sym("module"), z3.Token.space, z3.Token.sym("Swift"), z3.Token.closeBracket, z3.Token.closeBracket]], args: []), message: "Spaces in metavalues"
    )
    
    lexAndParse(s: "(dot_syntax_call_expr implicit type='(Int, Int) -> Int' location=hello.swift:9:20 range=[hello.swift:9:20 - line:9:20] nothrow (head2 foo=bar))", parser: Sexp.parse).assert(equalTo:
        z3.Sexp(head: z3.Label(v: "dot_syntax_call_expr"), metadata: [z3.Label(v: "range"): [z3.Token.openBracket, z3.Token.sym("hello"), z3.Token.dot, z3.Token.sym("swift"), z3.Token.colon, z3.Token.number(9.0), z3.Token.colon, z3.Token.number(20.0), z3.Token.space, z3.Token.char("-"), z3.Token.space, z3.Token.sym("line"), z3.Token.colon, z3.Token.number(9.0), z3.Token.colon, z3.Token.number(20.0), z3.Token.closeBracket], z3.Label(v: "nothrow"): [z3.Token.sym("nothrow")], z3.Label(v: "location"): [z3.Token.sym("hello"), z3.Token.dot, z3.Token.sym("swift"), z3.Token.colon, z3.Token.number(9.0), z3.Token.colon, z3.Token.number(20.0)], z3.Label(v: "type"): [z3.Token.literal("(Int, Int) -> Int")], z3.Label(v: "implicit"): [z3.Token.sym("implicit")]], args: [z3.Sexp(head: z3.Label(v: "head2"), metadata: [z3.Label(v: "foo"): [z3.Token.sym("bar")]], args: [])]), message: "Implicit k-v pairs at end"
    )
    
    lexAndParse(s: "(parameter_list (head x=y))", parser: Sexp.parse).assert(equalTo: z3.Sexp(head: z3.Label(v: "parameter_list"), metadata: [:], args: [z3.Sexp(head: z3.Label(v: "head"), metadata: [z3.Label(v: "x"): [z3.Token.sym("y")]], args: [])]), message: "No metadata at all")
    
    lexAndParse(s: "(parameter_list (head a=b) (head b=c))", parser: Sexp.parse).assert(equalTo: z3.Sexp(head: z3.Label(v: "parameter_list"), metadata: [:], args: [z3.Sexp(head: z3.Label(v: "head"), metadata: [z3.Label(v: "a"): [z3.Token.sym("b")]], args: []), z3.Sexp(head: z3.Label(v: "head"), metadata: [z3.Label(v: "b"): [z3.Token.sym("c")]], args: [])]))
    
    lexAndParse(s: "(func_decl \"smart(accountA:accountB:amt:)\" interface type='(Int, Int, Int) -> (accountA: Int, accountB: Int)' access=internal (parameter_list (parameter \"accountA\" apiName=accountA type='Int' interface type='Int') (parameter \"accountB\" apiName=accountB type='Int' interface type='Int') (parameter \"amt\" apiName=amt type='Int' interface type='Int')))", parser: Sexp.parse).assert(equalTo: z3.Sexp(head: z3.Label(v: "func_decl"), metadata: [z3.Label(v: "smart(accountA:accountB:amt:)"): [z3.Token.sym("smart(accountA:accountB:amt:)")], z3.Label(v: "interface"): [z3.Token.sym("interface")], z3.Label(v: "type"): [z3.Token.literal("(Int, Int, Int) -> (accountA: Int, accountB: Int)")], z3.Label(v: "access"): [z3.Token.sym("internal")]], args: [z3.Sexp(head: z3.Label(v: "parameter_list"), metadata: [:], args: [z3.Sexp(head: z3.Label(v: "parameter"), metadata: [z3.Label(v: "type"): [z3.Token.literal("Int"), z3.Token.space, z3.Token.sym("interface")], z3.Label(v: "accountA"): [z3.Token.sym("accountA")], z3.Label(v: "apiName"): [z3.Token.sym("accountA")]], args: []), z3.Sexp(head: z3.Label(v: "parameter"), metadata: [z3.Label(v: "type"): [z3.Token.literal("Int"), z3.Token.space, z3.Token.sym("interface")], z3.Label(v: "accountB"): [z3.Token.sym("accountB")], z3.Label(v: "apiName"): [z3.Token.sym("accountB")]], args: []), z3.Sexp(head: z3.Label(v: "parameter"), metadata: [z3.Label(v: "amt"): [z3.Token.sym("amt")], z3.Label(v: "type"): [z3.Token.literal("Int"), z3.Token.space, z3.Token.sym("interface")], z3.Label(v: "apiName"): [z3.Token.sym("amt")]], args: [])])]))
    
    lexAndParse(s: astString, parser: Sexp.parse).assert(equalTo: dummy)
}

main()
