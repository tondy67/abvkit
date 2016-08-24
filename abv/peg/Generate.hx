package abv.peg;

import abv.peg.ParserBase.Source;

//**********************************************************************
//
// Generate
//
//-----------------------------------------------------------------------------
//
// Generate parser from Parsing Expression Grammar.
// Optionally, generate skeleton for the corresponding semantics class.
//
// The <arguments> are specified as options according to POSIX syntax:
//
// -G <filename>
// Identifies the file containing the grammar. Mandatory.
// The <filename> need not be a complete path, just enough to identify
// the file in current environment. Should include file extension,if any.
//
// -D <directory>
// Identifies target directory to receive the generated file(s).
// Optional. If omitted, files are generated in current work directory.
// The <directory> need not be a complete path, just enough to identify
// the directory in current environment. The directory must exist.
//
//-P <parser>
// Specifies name of the parser to be generated. Mandatory.
// Must be an unqualified class name.
// The tool generates a file named "<parser>.hx" in target directory.
// The file contains definition of Haxe class <parser>.
// If target directory already contains a file "<parser>.hx",
// the file is replaced without a warning,
//
//-p <package>
// Generate parser as member of package <package>.
// The semantics class, if specified, is assumed to belong to the same package.
// Optional. If not specified, both classes belong to unnamed package.
// The specified package need not correspond to the target directory.
//
//-s Generate skeleton of semantics class. Optional.
// If target directory already contains a file "<semantics>.hx",
// the tool is not executed.
//
//-M Generate memoizing version of the parser.
//
//-T Generate instrumented ('test') version of the parser.
//
// (Options -M and -T are mutually exclusive.)
//
//
//----------------------------------------------------------------------------
// TestPEG
//----------------------------------------------------------------------------
// Check the grammar without generating parser. (without -P option)
//
// -A Display the grammar. Optional.
// Shows the rules and subexpressions together with their attributes
// according to Ford.
//
// -C Display the grammar in compact form: without duplicate subexpressions.
// Optional.
//
// -R Display only the rules. Optional.
//
//**********************************************************************
using StringTools;

class Generate {
//---------------------------------------------------------------------------
//Input
//---------------------------------------------------------------------------
	var gramName:String; // Grammar file name
	var gramPath:String; // Full path to grammar file
	var parsName:String; // Parser name
	var semName:String;// Semantics name
	var semFile:String; // Semantics file
	var dirName:String;// Output directory
	var packName:String; // Package name
	var memo:Bool;// Generate memo version?
	var test:Bool;// Generate test version?
	var skel:Bool;// Generate semantics skeleton?

//---------------------------------------------------------------------------
//Output.
//---------------------------------------------------------------------------
	public var out:LineWriter;

//---------------------------------------------------------------------------
//Parsed grammar.
//---------------------------------------------------------------------------
	var peg:PEG = null;

//---------------------------------------------------------------------------
//Date stamp.
//---------------------------------------------------------------------------
	var date:String;

//---------------------------------------------------------------------------
// Cache name (or nothing) to be generated.
//---------------------------------------------------------------------------
	public var cache = "";

//---------------------------------------------------------------------------
// Visitors.
//---------------------------------------------------------------------------
	public var procVisitor:ProcVisitor;
	public var refVisitor:RefVisitor;
	public var inliVisitor:InliVisitor;
	public var termVisitor:TermVisitor;

//---------------------------------------------------------------------------
// The subexpressions that will have procedures.
// They have names consisting of the name of the containing Rule,
// followed by underscore and number within the Rule.
// Their procedures are created immediately after that for the Rule
// by procedure 'createSubs'; 'done' counts the elements of 'subs'
// that already have procedures created.
//---------------------------------------------------------------------------
	public var subs = new Array<Expr>();
	public var exprName:String; // Name of containing Rule
	public var procName:String; // Name of procedure being generated
	public var exprNum:Int; // Number within containing Rule
	var done = 0;// Count of created procedures

	public var reject:String;
	var cmd:CommandArgs;
	
	public function new() 
	{ 
		 procVisitor = new ProcVisitor(this);
		 refVisitor  = new RefVisitor(this);
		 inliVisitor = new InliVisitor(this);
		 termVisitor = new TermVisitor(this);
	}// new()

	public static function main()
	{
		var gen = new Generate();
		gen.run();
	}


	function getPEG(name:String)
	{
		var s = AP.open(name);
		if (s == null) return null;
		var src = new Source(s); 
		return new PEG(src); 
	}// getPEG()
	
//----------------------------------------------------------------------
// Do the job
//----------------------------------------------------------------------
	function run()
	{
		var errors = false;
//----------------------------------------------------------------------
// Parse arguments.
//----------------------------------------------------------------------
		cmd = new CommandArgs(Sys.args(), // arguments to parse
								"MTCARs",// options without argument
								"GPDp", // options with argument
								 0,0);// no positional arguments
		if (cmd.nErrors() > 0) return;

//----------------------------------------------------------------------
// Get options.
//----------------------------------------------------------------------
		gramName = cmd.optArg('G'); 
		parsName = cmd.optArg('P');
		dirName = cmd.optArg('D');
		packName = cmd.optArg('p');
		test = cmd.opt('T');
		memo = cmd.opt('M');
		skel = cmd.opt('s');

		if (gramName == null){
			Sys.println("Specify -G grammar name.");
			errors = true;
		}
/*
 * Test PEG
 */
		if (parsName == null){
			peg = getPEG(gramName);
			if (peg == null) return;
			if (peg.errors > 0) return;
			if (peg.notWF == 0) Sys.println("The grammar is well-formed.");

			if (cmd.opt('C')){
				peg.compact();
				peg.showAll();
			}else if (cmd.opt('A')){
				peg.showAll();
			}else if (cmd.opt('R')){
				peg.showRules();
			}		
			return;
		}

		semName = parsName + "Semantics";

		if (dirName == null) dirName = "";
		else dirName = AP.addSlash(dirName);

		semFile = dirName + semName + ".hx";
		if (skel) {
			if (AP.isFile(semFile)){
				Sys.println("File '" + semFile + "' already exists.");
				Sys.println("Remove the file or the -s option.");
				errors = true;
			}
		}

		if (memo && test){
			Sys.println("Options -M and -T are mutually exclusive.");
			errors = true;
		}

		if (errors) return;

//----------------------------------------------------------------------
//Parse the grammar and eliminate duplicate expressions.
//----------------------------------------------------------------------
		peg = getPEG(gramName);
		if (peg == null) return;
		if (peg.errors > 0) return;
		if (peg.notWF > 0) return;
		peg.compact();

//----------------------------------------------------------------------
//Get full path to grammar file, ready to include in comment.
//----------------------------------------------------------------------
		gramPath = Convert.toComment(AP.fullPath(gramName));

//----------------------------------------------------------------------
// Get date stamp.
//----------------------------------------------------------------------
		date = AP.utc() + "";

//----------------------------------------------------------------------
// Generate parser.
//----------------------------------------------------------------------
		generate();

//----------------------------------------------------------------------
// If requested, generate semantics skeleton.
//----------------------------------------------------------------------
		if (skel || !AP.isFile(semFile)) genSkel();

/*
 * Copy ParserBase.hx (ParserTest)
 */ 		
		genPBase();
	}// run()

	function genPBase()
	{
		var err = false;
		var b = haxe.Resource.getString("base");
		if (b == null)  err = true;
		var t = haxe.Resource.getString("test");
		if (t == null) err = true;
		var m = haxe.Resource.getString("matrix");
		if (m == null) err = true;
		if (err) return;
		var p = "package abv.peg;";
		var n = "package " + packName + ";";
		b = b.replace(p,n);
		AP.save(dirName + "ParserBase.hx", b);
		t = t.replace(p,n);
		AP.save(dirName + "ParserTest.hx", t);
		m = m.replace(p,n);
		AP.save(dirName + "BitMatrix.hx", m);
		p = "AbvkitParser";
		t = n + "\n\nclass " + p + " extends " + parsName +
			"Parser{\n\tpublic function new()\n{\n\t\tsuper();\n\t}\n}";
		AP.save(dirName + p + ".hx", t);
	}
	
//----------------------------------------------------------------------
// Generate the parser
//----------------------------------------------------------------------
	function generate()
	{
//----------------------------------------------------------------------
// Set up output.
//----------------------------------------------------------------------
		out = new LineWriter(dirName + parsName + "Parser.hx");

//----------------------------------------------------------------------
// Assign names to terminals.
//----------------------------------------------------------------------
		for (i in 0 ... peg.terms.length){
			peg.terms[i].name = "_Term_" + i;
		}

//----------------------------------------------------------------------
// Create header.
//----------------------------------------------------------------------
		var basePars = "ParserBase";
		var kind = "norm";
		if (memo){
			kind = "memo";
		}else if (test){
			basePars = "ParserTest";
			kind = "test";
		}
		
		out.BOX("This file was generated by abvkit at " +
			date + " GMT\nfrom grammar '" + gramPath + "'.");
		out.line("");

		if ( packName == null) packName = "";
		out.line("package " + packName + ";");
		out.line("");
		out.line("import ParserBase.Source;");
		if (memo) out.line("import ParserBase.Cache;");
		if (test) out.line("import ParserTest.TCache;");

		out.line("");
		out.line("class " + parsName + "Parser extends " + basePars + "{");
		out.line("");

		out.indent();
		out.line("public var sem(default,null):" + semName + ";");
		out.line("public var version(default,never) = " + AP.utc2ver() + ";");
		out.line("public var kind(default,never) = \"" + kind + "\";");
		out.line("public var grammar(default,never) = \"" + AP.basename(gramName) + "\";");
		out.line("");
		out.line("public function new()");
		out.line("{");
		out.indent();
		out.line("super();");
		out.line("sem = new " + semName + "();");
		out.line("sem.rule = this;");
		if (memo || test) out.line("initCache();");
		out.undent();
		out.line("}");
		out.line("");

		out.line("public override function setTrace(s:String)");
		out.line("{");
		out.indent();
		out.line("super.setTrace(s);");
		out.line("sem.trc = s;");
		out.undent();
		out.line("}");

		out.box("Run the parser");
		out.line("public function parse(src:Source)");
		out.line("{");
		out.indent();
		out.line("init(src);");
		out.line("sem.init();");
		out.line("var result = " + peg.rules[0].name + "();");
		out.line("closeParser(result);");
		out.line("return result;");
		out.undent();
		out.line("}");
		out.line("");

		out.BOX("Parsing procedures");

//----------------------------------------------------------------------
// Create parsing procedures for Rules.
//----------------------------------------------------------------------
//		out.indent();
		for (rule in peg.rules){ 
			exprName = rule.name;
			procName = rule.name;
			exprNum = 0;

			out.Box(Convert.toComment(rule.asString)); 
			out.line("function " + rule.name + "()");
			out.line("{");
			out.indent();
			if (memo || test){
				out.line("if (saved(_" + rule.name + "_)) return reuse();");
				if (test) cache = "_" + rule.name + "_";
			}else if (rule.diagName == null){
				out.line("begin(\"" + rule.name + "\");");
			}else{
				out.line("begin(\"" + rule.name + "\",\""
				 + Convert.toStringLit(rule.diagName) + "\");");
			}
//-------------------------------------------------------------
// Special case: single expression on right-hand side
// and no 'onFail' action.
//-------------------------------------------------------------
			if ( (rule.rhs.length == 1) && (rule.onFail[0] == null)){
				var e = rule.rhs[0];
				var act:Action = rule.onSucc[0]; 
				inLine(e,"reject(" + cache + ")");
				if (act == null){
					out.line("return accept(" + cache + ");");
				}else if (act.and){ 
					out.line("if (sem." + act.name + "()) return accept(" + cache + ");");
					out.line("return reject(" + cache + ");");
				}else{ 
					out.line("sem." + act.name + "();");
					out.line("return accept(" + cache + ");");
				}
//-------------------------------------------------------------
// General case.
//-------------------------------------------------------------
			}else{
				for (i in 0...rule.rhs.length){
					var succ = rule.onSucc[i];
					var fail = rule.onFail[i];

					if (succ == null){
						out.line("if (" + ref(rule.rhs[i]) + ") return accept(" + cache + ");");
					}else if (succ.and){
						out.line("if (" + ref(rule.rhs[i]) + ")");
						out.line("{ if (sem." + succ.name + "()) return accept(" + cache + "); }");
					}else{
						out.line("if (" + ref(rule.rhs[i]) + ")");
						out.line("{ sem." + succ.name + "(); return accept(" + cache + "); }");
					}

					if (fail != null) out.line("sem." + fail.name + "();");

				}
				out.line("return reject(" + cache + ");");
			}

			out.undent();
			out.line("}");
			out.line("");

			createSubs();
		}
//		out.undent();

//----------------------------------------------------------------------
// If memo or test version:
// create Cache objects for rules and inner.
//----------------------------------------------------------------------
		if (memo || test) {
			var cname = test ? "TCache" : "Cache";
			out.BOX(cname+" objects");
			out.line("");
			for (expr in peg.rules)out.line("var _" + expr.name + "_:"+cname+";");
			for (expr in subs)out.line("var _" + expr.name + "_:"+cname+";");
			if (test){
				out.line("");
				for (expr in peg.terms)out.line("var _" + expr.name + "_:"+cname+";");
			}
			out.line("");
			out.line("function initCache()");
			out.line("{");
			out.indent();
			for (rule in peg.rules){
				out.line("_" + rule.name + "_ = new "+cname+"(\""
				+ rule.name + "\",\""
				+ Convert.toStringLit(diagName(rule)) + "\");") ;
			}
			out.line("");

			for (expr in subs){
				if (isPred(expr)){
					out.line("_" + expr.name + "_ = new "+cname+"(\""
					+ expr.name + "\",\""
					+ Convert.toStringLit(diagPred(expr)) + "\"); // "
					+ Convert.toComment(expr.asString) );
				}else{
					out.line("_" + expr.name + "_ = new "+cname+"(\""
					+ Convert.toStringLit(expr.name) + "\"); // "
					+ Convert.toComment(expr.asString) );
				}
			}
//----------------------------------------------------------------------
// If test version:
// create Cache objects for terminals.
//----------------------------------------------------------------------
			if (test){
				out.line("");
				for (expr in peg.terms){//trace(expr);
					out.line("_" + expr.name + "_ = new "+cname+"(\""
					+ Convert.toStringLit(expr.asString) + "\");") ;
				}
			}

			out.line("");
			out.line("caches = [");
			out.indent();
			for (expr in peg.rules)out.line("_" + expr.name + "_,");
			for (expr in subs)out.line("_" + expr.name + "_,");
			if (test){
				out.line("");
				for (expr in peg.terms)out.line("_" + expr.name + "_,");
			}
			out.undent();
			out.line("];");
			out.undent();
			out.line("};");
		}


//----------------------------------------------------------------------
// Terminate the parser and close output.
//----------------------------------------------------------------------
		out.undent();
		out.line("}");
		out.close();

		Sys.println(peg.rules.length + " rules");
		Sys.println(subs.length+ " unnamed");
		Sys.println(peg.terms.length + " terminals");

	}// generate()


// == == == == == == == == ==
//
// Generate semantics skeleton
//
// == == == == == == == == ==

	function genSkel()
	{
//----------------------------------------------------------------------
// Set up output.
//----------------------------------------------------------------------
		out = new LineWriter(semFile);

//----------------------------------------------------------------------
// Create header.
//----------------------------------------------------------------------
		out.BOX("This skeleton was generated by abvkit at " + date + " GMT\n" +
			"from grammar '" + gramPath + "'.");
		out.line("");

		if ( packName != null){
			out.line("package " + packName + ";");
			out.line("");
		}

		out.line("class " + semName + " extends ParserBase.SemanticsBase {");
		out.line("");
		out.indent();
		out.line("public function new()");
		out.line("{");
		out.indent();
		out.line("super();");
		out.undent();
		out.line("}");
		out.line("");
		out.box("Invoked at the beginning of each invocation of the Parser.");
		out.line("public override function init()");
		out.line("{");
		out.indent();
		out.line("super.init();");
		out.undent();
		out.line("}");
		out.line("");

//----------------------------------------------------------------------
// Collect Actions specified in the grammar.
//----------------------------------------------------------------------
		var actions= new Array<Action>();
		var comments = new Map<String,String>();

		for (rule in peg.rules)	{
			for (i in 0...rule.rhs.length){
				if (rule.onSucc[i] != null){
					var act = rule.onSucc[i];
					var comment = rule.name + " = " + Convert.toComment(rule.rhs[i].asString);
					var found = comments.get(act.name);
					if (found == null){
						actions.push(act);
						comments.set(act.name,comment);
					}else{
						comments.set(act.name,found + "\n" + comment);
					}
				}

				if (rule.onFail[i] != null) {
					var act = rule.onFail[i];
					var comment = "failed " + rule.name + " = " + Convert.toComment(rule.rhs[i].asString);
					var found = comments.get(act.name);
					if (found == null){
						actions.push(act);
						comments.set(act.name,comment);
					}else{
						comments.set(act.name,found + "\n" + comment);
					}
				}
			}
		}

//----------------------------------------------------------------------
// Create semantic procedures.
//----------------------------------------------------------------------
		for (i in 0...actions.length){
			var act = actions[i];
			out.box(comments.get(act.name));
			out.line("public function " + act.name + "()");
			out.line("{" + (act.and? " return true; ":"") + "}");
			out.line("");
		}

//----------------------------------------------------------------------
// Terminate the class and close output.
//----------------------------------------------------------------------
		out.undent();
		out.line("}");
		out.close();

		if (actions.length > 0)Sys.println(actions.length + " semantic procedures");
	}// genSkel()




/**********************************************************************
* This procedure returns the string to be generated as invocation
* of 'expr'. Note that 'expr' is never an Expr.Rule, as Rules are
* always referenced via Expr.Ref objects.
* The invocation string is obtained by using RefVisitor to visit
* 'expr'. The Visitor keeps track of visited objects in 'subs' and
* 'temps', and generates for them names that are stored in 'names'.
***********************************************************************/
	public function ref( expr:Expr):String
	{
		var r = "";
		if (expr != null){
			expr.accept(refVisitor);
			r = refVisitor.result;
		}
		return r;
	}

	public function inLine( expr:Expr,rej:String)
	{
		reject = rej;
		expr.accept(inliVisitor);
	}

//---------------------------------------------------------------------------
// This procedure returns kernel of a call to terminal processing.
//---------------------------------------------------------------------------
	public function termCall( expr:Expr)
	{
		termVisitor.cash = test? "_" + expr.name + "_": "";
		termVisitor.ccash = test? "," + "_" +expr.name + "_": "";
		expr.accept(termVisitor);
		return termVisitor.result;
	}




//**********************************************************************
//
// Auxiliary methods
//----------------------------------------------------------------------------
// Create parsing procedures for subexpressions.
//----------------------------------------------------------------------------
	function createSubs()
	{
		var toDo = subs.length;

		while (done < toDo) {
			for (i in done...toDo){
				var expr = subs[i];
				procName = expr.name;
				out.box(procName + " = " + Convert.toComment(expr.asString)); 
				out.line("function " + procName + "()");
				out.line("{");
				out.indent();

				if (memo || test){
					out.line("if (savedInner(_" + procName + "_)) return "
						+ (isPred(expr)? "reusePred();" : "reuseInner();"));
					if (test) cache = "_" + procName + "_";
				}else if (isPred(expr)){
					out.line("begin(\"\",\"" + Convert.toStringLit(diagPred(expr)) + "\");");
				}else{
					out.line("begin(\"\");");
				}
				expr.accept(procVisitor);
				out.undent();
				out.line("}");
				out.line("");
			}
			done = toDo;
			toDo = subs.length; // We probably added subexprs of subexprs!
		}
	}// createSubs()

//---------------------------------------------------------------------------
// isPred
//---------------------------------------------------------------------------
	function isPred( expr:Expr)
	{
		return
		Std.is(expr,Expr.And) ||
		Std.is(expr,Expr.Not) ;
	}

//---------------------------------------------------------------------------
// isTerm
//---------------------------------------------------------------------------
	public function isTerm( expr:Expr)
	{
		return
		Std.is(expr , Expr.StringLit) ||
		Std.is(expr , Expr.CharClass) ||
		Std.is(expr , Expr.Range) ||
		Std.is(expr , Expr.Any) ;
	}

//---------------------------------------------------------------------------
// Get diagnostic name of a Rule
//---------------------------------------------------------------------------
	public function diagName(rule:Expr.Rule)
	{
		if (rule.diagName == null) return rule.name;
		else return Convert.toStringLit(rule.diagName);
	}

//---------------------------------------------------------------------------
//Get diagnostic string for a Predicate
//---------------------------------------------------------------------------
	public function diagPred( expr:Expr)
	{
		if (Std.is(expr , Expr.And)){
			var arg = cast(expr,Expr.And).expr;
			if (Std.is(arg , Expr.Ref)){
				var rule = cast(arg,Expr.Ref).rule;
				return diagName(rule);
			}else{
				return arg.asString;
			}
		}else if (Std.is(expr , Expr.Not)){
			var arg = cast(expr,Expr.Not).expr;
			if (Std.is(arg , Expr.Ref)){
				var rule = cast(arg,Expr.Ref).rule;
				return "not " + diagName(rule);
			}else if (Std.is(arg , Expr.Any)){
				return "end of text";
			}else{
				return "not " + arg.asString;
			}
		}else{
			throw "SNOC";
		}
}


}// Generate

//**********************************************************************
//
// RefVisitor
//
//**********************************************************************

class RefVisitor extends Visitor{
//----------------------------------------------------------------------
// Result from Visitor
// Note that the Visitor is never called recursively.
//----------------------------------------------------------------------
	public var result:String;
	var owner:Generate;
	
	public function new(owner:Generate)
	{
		super();
		this.owner = owner;
	}

	public override function visitChoice( expr:Expr.Choice)
	{ 
		doExpr(expr); 
	}

	public override function visitSequence( expr:Expr.Sequence)
	{ 
		doExpr(expr); 
	}

	public override function visitAnd( expr:Expr.And)
	{ 
		doExpr(expr); 
	}

	public override function visitNot( expr:Expr.Not)
	{ 
		doExpr(expr); 
	}

	public override function visitPlus( expr:Expr.Plus)
	{ 
		doExpr(expr); 
	}

	public override function visitStar( expr:Expr.Star)
	{ 
		doExpr(expr);
	}

	public override function visitQuery( expr:Expr.Query)
	{ 
		doExpr(expr); 
	}

	public override function visitPlusPlus( expr:Expr.PlusPlus)
	{ 
		doExpr(expr); 
	}

	public override function visitStarPlus( expr:Expr.StarPlus)
	{ 
		doExpr(expr);
	}

	public override function visitRef( expr:Expr.Ref)
	{ 
		result = expr.name + "()"; 
	}

	public override function visitStringLit( expr:Expr.StringLit)
	{ 
		doTerm(expr); 
	}

	public override function visitCharClass( expr:Expr.CharClass)
	{ 
		doTerm(expr); 
	}

	public override function visitRange( expr:Expr.Range)
	{ 
		doTerm(expr); 
	}

	public override function visitAny( expr:Expr.Any)
	{ 
		doTerm(expr); 
	}

	function doExpr( expr:Expr)
	{
		var name:String = expr.name;

		if (name == null){
			name = owner.exprName + "_" + owner.exprNum;
			owner.exprNum++;
			expr.name = name;
			owner.subs.push(expr);
		}

		result = name + "()";
	}

	function doTerm( expr:Expr)
	{ 
		result = "next" + owner.termCall(expr); 
	}

}// RefVisitor

//**********************************************************************
//
// ProcVisitor - visitor to generate body of parsing procedure
//
//**********************************************************************

class ProcVisitor extends Visitor{
	
	var owner:Generate;

	public function new(owner:Generate)
	{
		super();
		this.owner = owner;
	}
		
	public override function visitRule( expr:Expr.Rule)
	{
		throw "SNOC" + expr.name; 
	}

	public override function visitChoice( expr:Expr.Choice)
	{
		for (e in expr.expr)
			owner.out.line("if (" + owner.ref(e) + ") return acceptInner(" + owner.cache + ");");
		owner.out.line("return rejectInner(" + owner.cache + ");");
	}

	public override function visitSequence( expr:Expr.Sequence)
	{
		for (e in expr.expr)
			owner.inLine(e,"rejectInner(" + owner.cache + ")");
		owner.out.line("return acceptInner(" + owner.cache + ");");
	}

	public override function visitAnd(expr:Expr.And )
	{
		owner.out.line("if (!" + owner.ref(expr.expr) + ") return rejectPred(" + owner.cache + ");");
		owner.out.line("return acceptPred(" + owner.cache + ");");
	}

	public override function visitNot( expr:Expr.Not)
	{
		owner.out.line("if (" + owner.ref(expr.expr) + ") return rejectPred(" + owner.cache + ");");
		owner.out.line("return acceptPred(" + owner.cache + ");");
	}

	public override function visitPlus( expr:Expr.Plus)
	{
		owner.out.line("if (!" + owner.ref(expr.expr) + ") return rejectInner(" + owner.cache + ");");
		owner.out.line("while (" + owner.ref(expr.expr) + "){ };");
		owner.out.line("return acceptInner(" + owner.cache + ");");
	}

	public override function visitStar( expr:Expr.Star)
	{
		owner.out.line("while (" + owner.ref(expr.expr) + "){ };");
		owner.out.line("return acceptInner(" + owner.cache + ");");
	}

	public override function visitQuery( expr:Expr.Query)
	{
		owner.out.line(owner.ref(expr.expr) + ";");
		owner.out.line("return acceptInner(" + owner.cache + ");");
	}

	public override function visitPlusPlus( expr:Expr.PlusPlus)
	{
		owner.out.line("if (" + owner.ref(expr.expr2) + ") return rejectInner(" + owner.cache + ");");
		owner.out.line("do{");
		owner.out.indent();
		owner.out.line("if (!" + owner.ref(expr.expr1) + ") return rejectInner(" + owner.cache + ");");
		owner.out.undent();
		owner.out.line("}while (!" + owner.ref(expr.expr2) + ");");
		owner.out.line("return acceptInner(" + owner.cache + ");");
	}

	public override function visitStarPlus( expr:Expr.StarPlus)
	{
		owner.out.line("while (!" + owner.ref(expr.expr2) + "){");
		owner.out.indent();
		owner.out.line("if (!" + owner.ref(expr.expr1) + ") return rejectInner(" + owner.cache + ");");
		owner.out.undent();
		owner.out.line("}");
		owner.out.line("return acceptInner(" + owner.cache + ");");
	}

	public override function visitRef( expr:Expr.Ref)
	{
		if (!expr.fal)
		owner.out.line(expr.name + "();");
		else
		owner.out.line("if (!" + expr.name + "()) return rejectInner(" + owner.cache + ");");
		owner.out.line("return acceptInner(" + owner.cache + ");");
	}

	public override function visitStringLit( expr:Expr.StringLit)
	{ 
		doTerm(expr); 
	}

	public override function visitCharClass( expr:Expr.CharClass)
	{ 
		doTerm(expr); 
	}

	public override function visitRange( expr:Expr.Range)
	{ 
		doTerm(expr); 
	}

	public override function visitAny( expr:Expr.Any)
	{ 
		doTerm(expr); 
	}

	function doTerm( expr:Expr)
	{trace(owner.ref(expr));
		owner.out.line("if (!" + owner.ref(expr)+ ") return rejectInner(" + owner.cache + ");");
		owner.out.line("return acceptInner(" + owner.cache + ");");
	}
}// ProcVisitor


//**********************************************************************
//
// InliVisitor - visitor to generate inLine procedure
//
// (Inline procedure falls through on success
// or returns reject() on failure.)
//
//**********************************************************************

class InliVisitor extends Visitor {

	var owner:Generate;

	public function new(owner:Generate)
	{
		super();
		this.owner = owner;
	}

	override function visitRule( expr:Expr.Rule)
	{
		throw "SNOC" + expr.name; 
	}

	override function visitChoice( expr:Expr.Choice)
	{
		var e = expr.expr[0];
		owner.out.line("if (!" + owner.ref(e));
		for (i in 1...expr.expr.length){
			e = expr.expr[i];
			owner.out.line(" && !" + owner.ref(e));
		}
		owner.out.line(" ) return " + owner.reject + ";");
	}

	override function visitSequence( expr:Expr.Sequence)
	{
		for (e in expr.expr) e.accept(owner.inliVisitor);
	}

	override function visitAnd( expr:Expr.And)
	{
		var e = expr.expr;
		if (owner.isTerm(e))
			owner.out.line("if (!ahead" + owner.termCall(e) + ") return " + owner.reject + ";");
		else
			owner.out.line("if (!" + owner.ref(expr) + ") return " + owner.reject + ";");
	}

	override function visitNot( expr:Expr.Not)
	{
		var e = expr.expr;
		if (owner.isTerm(e))
			owner.out.line("if (!aheadNot" + owner.termCall(e) + ") return " + owner.reject + ";");
		else
			owner.out.line("if (!" + owner.ref(expr) + ") return " + owner.reject + ";");
	}

	override function visitPlus( expr:Expr.Plus)
	{
		owner.out.line("if (!" + owner.ref(expr.expr) + ") return " + owner.reject + ";");
		owner.out.line("while (" + owner.ref(expr.expr) + "){ };");
	}

	override function visitStar( expr:Expr.Star)
	{ 
		owner.out.line("while (" + owner.ref(expr.expr) + "){ };"); 
	}

	override function visitQuery( expr:Expr.Query)
	{ 
		owner.out.line(owner.ref(expr.expr) + ";"); 
	}

	override function visitPlusPlus( expr:Expr.PlusPlus)
	{
		owner.out.line("if (" + owner.ref(expr.expr2) + ") return " + owner.reject + ";");
		owner.out.line("do{");
		owner.out.indent();
		owner.out.line("if (!" + owner.ref(expr.expr1) + ") return " + owner.reject + ";");
		owner.out.undent();
		owner.out.line("}while (!" + owner.ref(expr.expr2) + ");");
	}

	override function visitStarPlus( expr:Expr.StarPlus)
	{
		owner.out.line("while (!" + owner.ref(expr.expr2) + "){");
		owner.out.indent();
		owner.out.line("if (!" + owner.ref(expr.expr1) + ") return " + owner.reject + ";");
		owner.out.undent();
		owner.out.line("}");
	}

	override function visitRef( expr:Expr.Ref)
	{
		if (!expr.fal)
			owner.out.line(expr.name + "();");
		else
			owner.out.line("if (!" + expr.name + "()) return " + owner.reject + ";");
	}

	override function visitStringLit( expr:Expr.StringLit)
	{ 
		doTerm(expr); 
	}

	override function visitCharClass( expr:Expr.CharClass)
	{
		doTerm(expr); 
	}

	override function visitRange( expr:Expr.Range)
	{ 
		doTerm(expr); 
	}

	override function visitAny( expr:Expr.Any)
	{ 
		doTerm(expr); 
	}

	function doTerm(expr:Expr)
	{ 
		owner.out.line("if (!" + owner.ref(expr)+ ") return " + owner.reject + ";"); 
	}
}// InliVisitor

//**********************************************************************
//
// TermVisitor
//
//**********************************************************************

class TermVisitor extends Visitor {
//----------------------------------------------------------------------
// Result from Visitor
//----------------------------------------------------------------------
	public var result:String;

//----------------------------------------------------------------------
// Input to Visitor: references to cash
//----------------------------------------------------------------------
	public var cash:String;
	public var ccash:String;

	var owner:Generate;
	
	public function new(owner:Generate)
	{
		super();
		this.owner = owner;
	}

	override function visitStringLit(expr:Expr.StringLit)
	{
		var cLit = Convert.toCharLit(expr.s.charAt(0));
		var sLit = Convert.toStringLit(expr.s);
		if (expr.s.length == 1)
			result = "('" + cLit + "'" + ccash + ")";
		else
			result = "(\"" + sLit + "\"" + ccash + ")";
	}

	public override function visitCharClass(expr:Expr.CharClass)
	{
		var cLit = Convert.toCharLit(expr.s.charAt(0));
		var sLit = Convert.toStringLit(expr.s);
		if (expr.s.length == 1){
			if (expr.hat)
				result = "Not(\'" + cLit + "\'" + ccash + ")";
			else
				result = "(\'" + cLit + "\'" + ccash + ")";
		}else{
			if (expr.hat)
				result = "NotIn(\"" + sLit + "\"" + ccash + ")";
			else
				result = "In(\"" + sLit + "\"" + ccash + ")";
		}
	}

	public override function visitRange(expr:Expr.Range)
	{
		var aLit = Convert.toCharLit(expr.a);
		var zLit = Convert.toCharLit(expr.z);
		result = "In('"+ aLit + "','" + zLit + "'" + ccash + ")";
	}

	public override function visitAny(expr:Expr.Any)
	{ 
		result = "(" + cash + ")"; 
	}
}
