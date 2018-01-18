
import Foundation

func lexAndParse<A>(s: String, parser: Parser<[Token], A>) {
    var lexed = Token.lex(input: s).dropFirst(0).oneSpace()
    print(lexed)
    print(parser.parse(&lexed))
}

func main() {
    /*let ast = "/Users/bkase/z3/hello.ast"
    guard let contents = FileManager.default.contents(atPath: ast) else {
        fatalError("Can't read file")
    }
    guard let astString = String(data: contents, encoding: .utf8) else {
        fatalError("Can't unwrap utf8 string from data")
    }*/
    
    //print(Label.parser.run(string: "asbdasbd")!)
    //let p: Parser<Sexp> = Parser<()>.openingParen *>
    //    Parser(result: .atom(Label("a")))
    //    <* Parser<()>.closingParen

    
    //print(Sexp.parser.run(string: "(declref_expr type='Int' location=hello.swift:9:38 range=[hello.swift:9:38-line:9:38] decl=hello.(file).smart(accountA:accountB:amt:).amt@hello.swift:1:42 function_ref=unapplied)"))
    /*guard let sexp = Sexp.parser.run(string: "(a b (c d)) ") else {
        fatalError("Failed to parse \(astString)")
    }
    print("Successfully parsed \(sexp)")*/
    
   // lexAndParse(s: "(head x=a y=c )", parser: Sexp.parse)
   // lexAndParse(s: "head", parser: Sexp.parseHead)
   // lexAndParse(s: "x=a y=b z=c ", parser: Sexp.parseMetadata)
    func makeTuple(x: Label) -> ([Label: String]) -> (Label, [Label: String]) {
        return { s in (x, s) }
    }
    lexAndParse(s: "(head x=a y=c)", parser: Sexp.parse)
    lexAndParse(s: "(head x=a y=c (head2 x=a))", parser: Sexp.parseArgs)
}

main()
