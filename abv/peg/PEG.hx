package abv.peg;

//**********************************************************************
//
//Class PEG
//
//------------------------------------------------------------------------
//
//A PEG object represents parsed grammar.
//The parsed grammar is a structure of Expr objects in the form of
//trees rooted in Expr.Rule objects. The Expr.Rule objects are listed
//in the array 'rules'. For easier handling, additional arrays contain
//lists of other objects appearing in the structure: 'subs' for
//subexpressions, 'terms' for terminals, and 'refs' for Expr.Ref objects.
//
//The constructor builds this structure from a file containing PEG,
//computes Ford's attributes, and checks various aspects of the grammar.
//
//Method 'compact' eliminates duplicate subexpressions from the
//parsed grammar. After this operation, the parsed grammar is no longer
//a set of trees, but an acyclic graph, as different Expr nodes may
//point to the same subexpressions. The 'rules' array is not changed
//(duplicate rules are not eliminated), but the other arrays are updated.
//
//The 'show' methods print out on System.out the grammar reconstructed
//from its parsed form, together with the computed attributes.
//
//**********************************************************************
import abv.peg.ParserBase.Source;

using abv.peg.AP;

class PEG{
//----------------------------------------------------------------------
//Rules, subexpressions, terminals, references.
//----------------------------------------------------------------------
	public var rules:Array<Expr.Rule>;
	public var subs:Array<Expr>;
	public var terms:Array<Expr>;
	public var refs:Array<Expr.Ref>;

//----------------------------------------------------------------------
//Counters.
//----------------------------------------------------------------------
	public var errors:Int; // Errors
	public var iterAt:Int; // Iterations for attributes
	public var iterWF:Int; // Iterations for WF
	public var notWF:Int;// Not well-formed expressions


// == == == == == == == == ==
//
//Constructor
//
// == == == == == == == == ==

	public function new(src:Source)
	{
	//---------------------------------------------------------------
	//Parse the grammar
	//---------------------------------------------------------------
		var parser = new Parser(); 
		parser.parse(src); 

		var sem = parser.sem;
		rules = sem.rules;
		errors = sem.errcount; 

	//---------------------------------------------------------------
	//Quit if parsing failed.
	//---------------------------------------------------------------
		if (errors>0) return;

	//---------------------------------------------------------------
	//Build expression lists.
	//---------------------------------------------------------------
		makeLists();

	//---------------------------------------------------------------
	//Resolve name references and quit if error found.
	//---------------------------------------------------------------
		resolve();
		if (errors>0) return;

	//---------------------------------------------------------------
	//Compute 'asString' for all nodes.
	//---------------------------------------------------------------
		reconstruct();

	//---------------------------------------------------------------
	//Compute attributes and well-formedness.
	//---------------------------------------------------------------
		attributes();
		computeWF();

	//---------------------------------------------------------------
	//Diagnose.
	//---------------------------------------------------------------
		var diag = new Diagnose();
		diag.applyTo(this);
	}


// == == == == == == == == ==
//
//Compact
//
// == == == == == == == == ==

	public function compact()
	{
	//---------------------------------------------------------------
	//Use CompactVisitor to eliminate duplicate expressions
	//from parse tree. (The result is no longer a tree.)
	//---------------------------------------------------------------
		var compactVisitor = new CompactVisitor();
		for (r in rules)
		r.accept(compactVisitor);

	//---------------------------------------------------------------
	//Build new expression lists.
	//---------------------------------------------------------------
		makeLists();
	}


// == == == == == == == == ==
//
//Show
//
// == == == == == == == == ==
//----------------------------------------------------------------------
//showRules.
//----------------------------------------------------------------------
	public function showRules()
	{
		Sys.println("\n" + rules.length + " rules");
		for (r in rules)
		Sys.println("" + Convert.toPrint(r.asString) + " // " + attrs(r));
	}

//----------------------------------------------------------------------
//showAll.
//----------------------------------------------------------------------
	public function showAll()
	{
		showRules();

		Sys.println("\n" + subs.length + " subexpressions");
		for (e in subs)
		Sys.println("" + Convert.toPrint(e.asString) + " // " + attrs(e));

		Sys.println("\n" + terms.length + " terminals");
		for (e in terms)
		Sys.println("" + Convert.toPrint(e.asString) + " // " + attrs(e));
	}

//----------------------------------------------------------------------
//Format attributes
//----------------------------------------------------------------------
	function attrs( e:Expr)
	{ 
		return " " + (e.nul?"0":"") + (e.adv?"1":"")
	 + (e.fal?"f":"") + (e.WF?"":" !WF"); 
	}


// == == == == == == == == ==
//
//Make Lists
//
//----------------------------------------------------------------------
//
//Make linear lists of expressions contained in the parse tree:
//inner expressions ('subs'), terminals (terms), references ('refs').
//
// == == == == == == == == ==

	function makeLists()
	{
	//---------------------------------------------------------------
	//Use ListVisitor to build the lists in its local hash sets.
	//---------------------------------------------------------------
		var listVisitor = new ListVisitor();
		for (r in rules) r.accept(listVisitor);

	//---------------------------------------------------------------
	//Convert the hash sets to arrays.
	//---------------------------------------------------------------
		subs= listVisitor.subs.copy(); 
		terms = listVisitor.terms.copy();
		refs= listVisitor.refs.copy();
	}


// == == == == == == == == ==
//
//Resolve references.
//
// == == == == == == == == ==

	function resolve()
	{
	//---------------------------------------------------------------
	//Mapping from names to Rules.
	//---------------------------------------------------------------
		var names = new Map<String,Expr.Rule>();

	//---------------------------------------------------------------
	//Referenced names.
	//Top rule is assumed referenced.
	//---------------------------------------------------------------
		var referenced = new Array<String>();
		referenced.add(rules[0].name); 

	//---------------------------------------------------------------
	//Dummy rule - replaces undefined to stop multiple messages.
	//---------------------------------------------------------------
		var dummy = new Expr.Rule(null,null,null,null,null);

	//---------------------------------------------------------------
	//Build table of Rule names, checking for duplicates.
	//---------------------------------------------------------------
		for (r in rules){
			if (names.exists(r.name)) {
				Sys.println("Error: duplicate name '" + r.name + "'.");
				errors++;
			}else{
				names.set(r.name,r);
			}
		}

	//---------------------------------------------------------------
	//Resolve references.
	//---------------------------------------------------------------
		for (ref in refs){
			ref.rule = names.get(ref.name);
			if (ref.rule == null) {
				Sys.println("Error: undefined name '" + ref.name + "'.");
				errors++;
				names.set(ref.name,dummy);
			}else{
				referenced.add(ref.name); 
			}
		}

	//---------------------------------------------------------------
	//Detect unused rules.
	//---------------------------------------------------------------
		for (r in rules) {
			if (!referenced.exists(r.name))
				Sys.println("Warning: rule '" + r.name + "' is not used.");
		}
	}


// == == == == == == == == ==
//
//Reconstruct Source
//
//----------------------------------------------------------------------
//
//Reconstructs, in a standard form, the source string of each
//expressions and assigns it to 'asString' field of the Expr object.
//
// == == == == == == == == ==

	function reconstruct()
	{
	//---------------------------------------------------------------
	//Use SourceVisitor to reconstruct source.
	//---------------------------------------------------------------
		var sourceVisitor = new SourceVisitor();
		for (e in rules) e.accept(sourceVisitor);
	}


// == == == == == == == == ==
//
//Compute Ford's attributes: nul, adv, fal for all expressions.
//
//----------------------------------------------------------------------
//
//Computes nul, adv, and fal attributes for all expressions.
//For terminals the attributes are preset by the constructor.
//For other expressions they are computed by iteration to a fixpoint.
//The AttrVisitor is used for the iteration step.
//
// == == == == == == == == ==

	function attributes()
	{
		var trueAttrs:Int; // Number of true attributes after last step
		var a = 0; // Number of true attributes before last step
		iterAt = 0;// Number of steps

		var attrVisitor = new AttrVisitor();

		while(true){
	//-------------------------------------------------------------
	//Iteration step
	//-------------------------------------------------------------
			for (e in refs)	e.accept(attrVisitor);
			for (e in subs)	e.accept(attrVisitor);
			for (e in rules)e.accept(attrVisitor);

	//-------------------------------------------------------------
	//Count true attributes (non-terminals only)
	//-------------------------------------------------------------
			trueAttrs = 0;
			for (e in rules) trueAttrs += (e.nul? 1:0) + (e.adv? 1:0) + (e.fal? 1:0);
			for (e in subs) trueAttrs += (e.nul? 1:0) + (e.adv? 1:0) + (e.fal? 1:0);

	//-------------------------------------------------------------
	//Break if fixpoint reached
	//-------------------------------------------------------------
			if (trueAttrs == a) break;

	//-------------------------------------------------------------
	//To next step
	//-------------------------------------------------------------
			a = trueAttrs;
			iterAt++;
		}
	}

// == == == == == == == == ==
//
//Compute well-formedness.
//
//----------------------------------------------------------------------
//
//Computes the WF attribute for all expressions.
//For terminals the attribute is preset by the constructor.
//For other expressions it is computed by iteration to a fixpoint.
//The FormVisitor is used for the iteration step.
//
// == == == == == == == == ==

	function computeWF()
	{
		var s = -1;// Number of not well-formed after last step
		iterWF = 0;// Number of iterations

		var formVisitor = new FormVisitor();

		while(true){
	//-------------------------------------------------------------
	//Iteration step
	//-------------------------------------------------------------
			for (e in refs)	e.accept(formVisitor);
			for (e in subs)	e.accept(formVisitor);
			for (e in rules)e.accept(formVisitor);

	//-------------------------------------------------------------
	//Count not well-formed (non-terminals only)
	//-------------------------------------------------------------
			notWF = 0;
			for (e in rules)
			if (!e.WF) notWF++;
			for (e in subs)
			if (!e.WF) notWF++;

	//-------------------------------------------------------------
	//Break if fixpoint reached
	//-------------------------------------------------------------
			if (notWF == s) break;

	//-------------------------------------------------------------
	//To next step
	//-------------------------------------------------------------
			s = notWF;
			iterWF++;
		}
	}



}

//**********************************************************************
//
//ListVisitor - makes lists of expressions
//
//**********************************************************************
//----------------------------------------------------------------------
//Each visit adds the visited expression to its proper list, and
//then proceeeds to visit all subexpressions, if any.
//Note that the visitor must also work after 'compact' operation
//that changed the tree into an acyclic graph. As a result, the
//visitor may arrive to a node that was already visited.
//Therefore we collect data in hash sets, and do not visit
//subexpressions if the node is already listed.
//----------------------------------------------------------------------

class ListVisitor extends Visitor{
//-----------------------------------------------------------------
//Local lists
//-----------------------------------------------------------------
	public var subs = new Array<Expr>();
	public var terms = new Array<Expr>();
	public var refs = new Array<Expr.Ref>();

	public override function visitRule( expr:Expr.Rule)
	{
		for (e in expr.rhs)	e.accept(this);
	}

	public override function visitChoice( expr:Expr.Choice)
	{ 
		doCompound(expr, expr.expr); 
	}

	public override function visitSequence( expr:Expr.Sequence)
	{ 
		doCompound(expr, expr.expr); 
	}

	public override function visitAnd( expr:Expr.And)
	{ 
		doUnary(expr, expr.expr); 
	}

	public override function visitNot( expr:Expr.Not)
	{ 
		doUnary(expr, expr.expr); 
	}

	public override function visitPlus( expr:Expr.Plus)
	{ 
		doUnary(expr, expr.expr); 
	}

	public override function visitStar( expr:Expr.Star)
	{ 
		doUnary(expr, expr.expr); 
	}

	public override function visitQuery( expr:Expr.Query)
	{ 
		doUnary(expr, expr.expr); 
	}

	public override function visitRef( expr:Expr.Ref)
	{ 
		refs.add(expr); 
	}

	public override function visitPlusPlus( expr:Expr.PlusPlus)
	{ 
		doBinary(expr, expr.expr1,expr.expr2); 
	}

	public override function visitStarPlus( expr:Expr.StarPlus)
	{ 
		doBinary(expr, expr.expr1,expr.expr2); 
	}

	public override function visitStringLit( expr:Expr.StringLit)
	{ //trace(expr);
		terms.add(expr); 
	}

	public override function visitRange( expr:Expr.Range)
	{ //trace(expr);
		terms.add(expr); 
	}

	public override function visitCharClass( expr:Expr.CharClass)
	{ //trace(expr);
			terms.add(expr); }

	public override function visitAny( expr:Expr.Any)
	{ //trace(expr);
		terms.add(expr); 
	}

	function doCompound( expr:Expr, list:Array<Expr>)
	{
		if (subs.add(expr)){ // If not visited yet
			for (e in list) e.accept(this);
		}
	}

	function doBinary( expr:Expr,arg1:Expr,arg2:Expr)
	{
		if (subs.add(expr)) // If not visited yet
			arg1.accept(this);
		arg2.accept(this);
	}

	function doUnary( expr:Expr,arg:Expr)
	{
		if (subs.add(expr)) // If not visited yet
			arg.accept(this);
	}
}



//**********************************************************************
//
//SourceVisitor - recostructs source strings of expressions
//
//**********************************************************************
//----------------------------------------------------------------------
//Each visit starts with visiting the subexpressions to construct
//their source strings. These strings are then used as building
//blocks to produce the final result. Procedure 'enclose'
//encloses the subexpression in parentheses if needed, depending
//on the binding strength of subexpression and containing expression.
//----------------------------------------------------------------------

class SourceVisitor extends Visitor{
	public override function visitRule( r:Expr.Rule)
	{
		var sb = new StringBuf();
		sb.add(r.name + " ");

		sb.add("= ");

		var sep = "";
		for (i in 0...r.rhs.length)	{
			sb.add(sep);
			r.rhs[i].accept(this);
			sb.add(enclose(r.rhs[i],0));
			if (r.onSucc[i] != null)sb.add(" " + r.onSucc[i].asString);
			if (r.onFail[i] != null)sb.add(" ~" + r.onFail[i].asString);
			sep = " / ";
		}

		if (r.diagName != null)	sb.add(" <" + r.diagName + ">");

		sb.add(" ;");
		r.asString = sb.toString();
	}

	public override function visitChoice( expr:Expr.Choice)
	{
		var sb = new StringBuf();
		var sep = "";
		for (e in expr.expr){
			sb.add(sep);
			e.accept(this);
			sb.add(enclose(e,0));
			sep = " / ";
		}
		expr.asString = sb.toString();
	}

	public override function visitSequence( expr:Expr.Sequence)
	{
		var sb = new StringBuf();
		var sep = "";
		for (e in expr.expr){
			sb.add(sep);
			e.accept(this);
			sb.add(enclose(e,1));
			sep = " ";
		}
		expr.asString = sb.toString();
	}

	public override function visitAnd( expr:Expr.And)
	{
		expr.expr.accept(this);
		expr.asString = "&" + enclose(expr.expr,3);
	}

	public override function visitNot( expr:Expr.Not)
	{
		expr.expr.accept(this);
		expr.asString = "!" + enclose(expr.expr,3);
	}

	public override function visitPlus( expr:Expr.Plus)
	{
		expr.expr.accept(this);
		expr.asString = enclose(expr.expr,4) + "+";
	}

	public override function visitStar( expr:Expr.Star)
	{
		expr.expr.accept(this);
		expr.asString = enclose(expr.expr,4) + "*";
	}

	public override function visitQuery( expr:Expr.Query)
	{
		expr.expr.accept(this);
		expr.asString = enclose(expr.expr,4) + "?";
	}

	public override function visitPlusPlus( expr:Expr.PlusPlus)
	{
		expr.expr1.accept(this);
		expr.expr2.accept(this);
		expr.asString = enclose(expr.expr1,4) + "++ " + enclose(expr.expr2,4);
	}

	public override function visitStarPlus( expr:Expr.StarPlus)
	{
		expr.expr1.accept(this);
		expr.expr2.accept(this);
		expr.asString = enclose(expr.expr1,4) + "*+ " + enclose(expr.expr2,4);
	}



	//-----------------------------------------------------------------
	//Parenthesizing
	//-----------------------------------------------------------------
	function enclose( e:Expr, mybind:Int)
	{
		var nest = e.bind() <= mybind;
		return (nest?"(":"") + e.asString + (nest?")":"");
	}
}



//**********************************************************************
//
//CompactVisitor - eliminates duplicate expresions
//
//**********************************************************************
//----------------------------------------------------------------------
//Each visit examines subexpressions of a visited expression.
//If it finds the subexpression identical to a previously
//encountered, replaces the subexpression by the latter.
//Otherwise, it proceeds to visit the subexpression.
//Expressions are considered identical if they have the same
//reconstructed source.
//----------------------------------------------------------------------
class CompactVisitor extends Visitor{
//-----------------------------------------------------------------
//Hash table to detect identical expressions.
//The table maps sources to expressions.
//-----------------------------------------------------------------
	var sources = new Map<String,Expr>();

	public override function visitRule(r:Expr.Rule)
	{ 
		doCompound(r, r.rhs); 
	}

	public override function visitChoice(expr:Expr.Choice)
	{ 
		doCompound(expr, expr.expr); 
	}

	public override function visitSequence(expr:Expr.Sequence)
	{ 
		doCompound(expr, expr.expr); 
	}

	public override function visitAnd(expr:Expr.And)
	{
		var alias = alias(expr.expr);
		if (alias != null) expr.expr = alias;
	}

	public override function visitNot(expr:Expr.Not)
	{
		var alias = alias(expr.expr);
		if (alias != null) expr.expr = alias;
	}

	public override function visitPlus(expr:Expr.Plus)
	{
		var alias = alias(expr.expr);
		if (alias != null) expr.expr = alias;
	}

	public override function visitStar(expr:Expr.Star)
	{
		var alias = alias(expr.expr);
		if (alias != null) expr.expr = alias;
	}

	public override function visitQuery(expr:Expr.Query)
	{
		var alias = alias(expr.expr);
		if (alias != null) expr.expr = alias;
	}

	public override function visitPlusPlus(expr:Expr.PlusPlus)
	{ 
		doBinary(expr, expr.expr1, expr.expr2); 
	}

	public override function visitStarPlus(expr:Expr.StarPlus)
	{ 
		doBinary(expr, expr.expr1, expr.expr2); 
	}


	function doBinary( expr:Expr,arg1:Expr,arg2:Expr)
	{
		var a = alias(arg1);
		if (a != null) arg1 = a;
		a = alias(arg2);
		if (a != null) arg2 = a;
	}

	function doCompound( expr:Expr, args:Array<Expr>)
	{
		for (i in 0...args.length)	{
			var alias = alias(args[i]);
			if (alias != null) args[i] = alias;
		}
	}

	//-----------------------------------------------------------------
	//If the 'sources' table already contains an expression with
	//the same source as 'expr', return that expression.
	//Otherwise add 'expr' to the table, visit 'expr', and return null.
	//-----------------------------------------------------------------
	function alias( expr:Expr)
	{
		var source = expr.asString;
		var found = sources.get(source);
		if (found != null) return found;
		sources.set(source,expr);
		expr.accept(this);
		return null;
	}
}



//**********************************************************************
//
//AttrVisitor - computes Ford's attributes
//
//**********************************************************************
//----------------------------------------------------------------------
//Each visit computes attributes from those of subexpressions.
//Attributes for terminals are preset by their constructors.
//The visitor does not climb down the parse tree.
//----------------------------------------------------------------------

class AttrVisitor extends Visitor{
	public override function visitRule( expr:Expr.Rule)
	{ 
		doChoice(expr,expr.rhs); 
	}

	public override function visitChoice( expr:Expr.Choice)
	{ 
		doChoice(expr,expr.expr); 
	}

	public override function visitSequence( expr:Expr.Sequence)
	{
		var allNull = true;
		var exAdv = false;
		var allSucc = true;
		var exFail= false;

		for (e in expr.expr){
			if (!e.nul) allNull = false;
			if (allSucc && e.fal) exFail = true;
			if (e.adv)exAdv = true;
			if (!e.nul && !e.adv) allSucc = false;
		}

		if (allNull) expr.nul = true;
		if (allSucc && exAdv) expr.adv = true;
		if (exFail) expr.fal = true;
	}

	public override function visitAnd( expr:Expr.And)
	{
		var e = expr.expr;
		if (e.nul || e.adv) expr.nul = true;
		if (e.fal) expr.fal = true;
	}

	public override function visitNot( expr:Expr.Not)
	{
		var e = expr.expr;
		if (e.nul || e.adv) expr.fal = true;
		if (e.fal) expr.nul = true;
	}

	public override function visitPlus( expr:Expr.Plus)
	{
		var e = expr.expr;
		if (e.adv) expr.adv = true;
		if (e.fal) expr.fal = true;
	}

	public override function visitStar( expr:Expr.Star)
	{
		var e = expr.expr;
		if (e.adv) expr.adv = true;
		if (e.fal) expr.nul = true;
	}

	public override function visitQuery( expr:Expr.Query)
	{
		var e = expr.expr;
		if (e.adv) expr.adv = true;
		if (e.nul || e.fal) expr.nul = true;
	}

	public override function visitPlusPlus( expr:Expr.PlusPlus)
	{
		var e1 = expr.expr1;
		var e2 = expr.expr2;

	// Computed as for (!e2 e1)(!e2 e1)* e2
	// Attributes of !e2 e1
		var nul1 = e2.fal && e1.nul;
		var adv1 = e2.fal && e1.adv;
		var fal1 = e2.nul || e2.adv;

	// Attributes of (!e2 e1)*
		var nul2 = fal1;
		var adv2 = adv1;
		var fal2 = false;

	// Attributes of (!e2 e1)* e2
		var nul3 = nul2 && e2.nul;
		var adv3 = (nul2 && e2.adv) || (adv2 && e2.adv) || (adv2 && e2.nul);
		var fal3 = fal2 || ((nul2 || adv2) && e2.fal);

	// Attributes of (!e2 e1)(!e2 e1)* e2
		expr.nul = nul1 && nul3;
		expr.adv = (nul1 && adv3) || (adv1 && adv3) || (adv1 && nul3);
		expr.fal = fal1 || ((nul1 || adv1) && fal3);
	}

	public override function visitStarPlus( expr:Expr.StarPlus)
	{
		var e1 = expr.expr1;
		var e2 = expr.expr2;

	// Computed as for (!e2 e1)* e2
	// Attributes of !e2 e1
		var adv1 = e2.fal && e1.adv;
		var fal1 = e2.nul || e2.adv;

	// Attributes of (!e2 e1)*
		var nul2 = fal1;
		var adv2 = adv1;
		var fal2 = false;

	// Attributes of (!e2 e1)* e2
		expr.nul = nul2 && e2.nul;
		expr.adv = (nul2 && e2.adv) || (adv2 && e2.adv) || (adv2 && e2.nul);
		expr.fal = fal2 || ((nul2 || adv2) && e2.fal);
	}

	public override function visitRef( expr:Expr.Ref)
	{
		var e = expr.rule;
		expr.nul = e.nul;
		expr.adv = e.adv;
		expr.fal = e.fal;
	}


	function doChoice( expr:Expr, list:Array<Expr>)
	{
		var n = false;
		var a = false;
		var f = true;

		for (e in list){
			n = n || e.nul;
			a = a || e.adv;
			f = f && e.fal;
			if (!f) break;
		}

		if (n) expr.nul = true;
		if (a) expr.adv = true;
		if (f) expr.fal = true;
	}
}



//**********************************************************************
//
//FormVisitor - computes WellFormed attribute
//
//**********************************************************************
//----------------------------------------------------------------------
//Each visit computes the attribute from those of subexpressions.
//Attributes for terminals are preset by their constructors.
//The visitor does not climb down the parse tree.
//----------------------------------------------------------------------

class FormVisitor extends Visitor{

	public override function visitRule( expr:Expr.Rule)
	{
		for (e in expr.rhs)
		if (!e.WF) return;
		expr.WF = true;
	}

	public override function visitChoice( expr:Expr.Choice)
	{
		for (e in expr.expr)
		if (!e.WF) return;
		expr.WF = true;
	}

	public override function visitSequence( expr:Expr.Sequence)
	{
		for (e in expr.expr){
			if (!e.WF) return;
			if (!e.nul) break;
		}
		expr.WF = true;
	}

	public override function visitAnd( expr:Expr.And)
	{
		if (expr.expr.WF) expr.WF = true;
	}

	public override function visitNot( expr:Expr.Not)
	{
		if (expr.expr.WF) expr.WF = true;
	}

	public override function visitPlus( expr:Expr.Plus)
	{
		if (expr.expr.WF && !expr.expr.nul)	expr.WF = true;
	}

	public override function visitStar( expr:Expr.Star)
	{
		if (expr.expr.WF && !expr.expr.nul)	expr.WF = true;
	}

	public override function visitQuery( expr:Expr.Query)
	{
		if (expr.expr.WF) expr.WF = true;
	}

	public override function visitPlusPlus( expr:Expr.PlusPlus)
	{
		if (expr.expr1.WF && expr.expr2.WF && !expr.expr1.nul)	expr.WF = true;
	}

	public override function visitStarPlus( expr:Expr.StarPlus)
	{
		if (expr.expr1.WF && expr.expr2.WF && !expr.expr1.nul) expr.WF = true;
	}

	public override function visitRef( expr:Expr.Ref)
	{ 
		expr.WF = expr.rule.WF; 
	}
}
