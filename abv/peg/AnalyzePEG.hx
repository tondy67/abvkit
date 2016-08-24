package abv.peg;

//**********************************************************************
//
// AnalyzePEG
//
//----------------------------------------------------------------------
//
// Analyze the grammar.
//
// The <arguments> are specified as options according to POSIX syntax:
//
// -G <filename>
// Identifies the file containing the grammar. Mandatory.
// The <filename> need not be a complete path,
// just enough to identify the file in current environment.
// Should include file extension, if any.
//
//
//**********************************************************************
import abv.peg.BitMatrix.BitSet;
import abv.peg.ParserBase.Source;

using StringTools;

@:dce
class AnalyzePEG{
//----------------------------------------------------------------------
// PEG being analyzed, representaed by a structure of Expr objects.
//----------------------------------------------------------------------
	var peg:PEG;

//----------------------------------------------------------------------
// Index of all Expr objects.
// Each object has its position in the vector as the 'index' component.
// Rules and Terminals come first in the index.
// Refs are not included in the index, but they obtain index
// of the node they refer to.
//----------------------------------------------------------------------
	public var index:Array<Expr>;
	public var N:Int;// Total length of index.
	public var T:Int;// Index of first Terminal.
	public var S:Int;// Index of first Subexpression.

//----------------------------------------------------------------------
// Dictionary for retrieving Rules by name.
//----------------------------------------------------------------------
	var rules:Map<String, Expr.Rule>;

//----------------------------------------------------------------------
// Relation first.
// last[i,j] = true means that expression with index j
// may appear as first in expression with index i.
//----------------------------------------------------------------------
	public var first:BitMatrix;

//----------------------------------------------------------------------
// Relation last.
// last[i,j] = true means that expression with index i
// may appear as last in expression with index j.
//----------------------------------------------------------------------
	public var last:BitMatrix;

//----------------------------------------------------------------------
// Relation next.
// last[i,j] = true means that expression with index j
// may appear after expression with index i.
//----------------------------------------------------------------------
	public var next:BitMatrix;

//----------------------------------------------------------------------
// Relation disjoint.
// disjoint[i,j] = true means that Terminals with indexes i,j
// are disjoint.
//----------------------------------------------------------------------
	public var disjoint:BitMatrix;

//----------------------------------------------------------------------
// Relation First.
// First[i,j] = true means that expression with index j belongs
// to First of expression with index i.
//----------------------------------------------------------------------
	var First:BitMatrix;

//----------------------------------------------------------------------
// Relation Follow.
// Follow[i,j] = true means that expression with index j belongs
// to Follow of expression with index i.
//----------------------------------------------------------------------
	var _Follow:BitMatrix;


	var terms:BitSet;


//----------------------------------------------------------------------
// Output indentation.
//----------------------------------------------------------------------
	var _indent:Int;


	public function new(){ }
	
	public static function main()
	{
		var analyzer = new AnalyzePEG();
		analyzer.run();
	}

//=====================================================================
//
// Do the job
//
//=====================================================================

	function run()
	{
//---------------------------------------------------------------
// Parse arguments.
//---------------------------------------------------------------
		var cmd = new CommandArgs
			 (Sys.args(),// arguments to parse
			"",// options without argument
			"G", // options with argument
			 0,0); // no positional arguments
			if (cmd.nErrors()>0) return;

		var gramName = cmd.optArg('G');
		if (gramName == null){
			Sys.println("Specify -G grammar file.");
			return;
		}

		var s = "";
		try s = sys.io.File.getContent(gramName)catch(e:Dynamic){trace(e);}
		if (s == "") return;
		var src = new Source(s);

//---------------------------------------------------------------
// Create PEG object.
//---------------------------------------------------------------
		var peg = new PEG(src);
		if (peg.errors > 0) return;

		if (peg.notWF != 0){
			Sys.println("The grammar is not well-formed.");
			return;
		}

//---------------------------------------------------------------
// Get numbers of Expr objects.
//---------------------------------------------------------------
		T = peg.rules.length;
		S = T + peg.terms.length;
		N = S + peg.subs.length;

//---------------------------------------------------------------
// Build the index and dictionary of Rules.
//---------------------------------------------------------------
		index = new Array<Expr>();//[N];
		rules = new Map<String, Expr.Rule>();

		var i = 0;

		for (e in peg.rules) {
			e.index = i;
			index[i] = e;
			rules.set(e.name,e);
			i++;
		}

		for (e in peg.terms) {
			e.index = i;
			index[i] = e;
			i++;
		}

		for (e in peg.subs) {
			e.index = i;
			index[i] = e;
			i++;
		}

		for (e in peg.refs) e.index = e.rule.index;

//---------------------------------------------------------------
// Compute first, last and next using MatrixVisitor.
//---------------------------------------------------------------
		first = BitMatrix.empty(N);
		last= BitMatrix.empty(N);
		next= BitMatrix.empty(N);

		var matrixVisitor = new MatrixVisitor(this);

		for (e in index) e.accept(matrixVisitor);

//---------------------------------------------------------------
// Compute First and Follow.
//---------------------------------------------------------------
		First = first.star();
		_Follow = last.star().times(next);

//---------------------------------------------------------------
// Compute disjoint.
//---------------------------------------------------------------
		disjoint = BitMatrix.empty(N);

		var disjointVisitor = new DisjointVisitor(this);

		for (i in T...S) index[i].accept(disjointVisitor);

//---------------------------------------------------------------
// Create reader for user's input.
//---------------------------------------------------------------


		terms = new BitSet(N);
		for (i in T...S) terms.set(i);

//---------------------------------------------------------------
// Keep processing user's requests.
//---------------------------------------------------------------
		var request = "";

		while(true)	{
			Sys.print("rule: ");
			try request = Sys.stdin().readLine()
			catch (e:Dynamic){
				trace(e);
				return;
			}
		if (request.length == 0) return;

		var eRule:Expr.Rule; 
		if (request == "LL1") {
			for (i in 0...T){
				eRule = cast(index[i], Expr.Rule);
				if (!LL1(eRule,eRule.rhs))
				Sys.println(diagName(eRule));
			}

			var eChoice:Expr.Choice;
			for (i in S...N){
				if (!Std.is(index[i] , Expr.Choice)) continue;
				eChoice = cast(index[i],Expr.Choice);
				if (!LL1(eChoice,eChoice.expr))
				Sys.println(diagName(eChoice));
			}
			continue;
		}

		var r = rules.get(request);
		if (r == null) continue;

		//if (r.rhs.length<2) continue;
		//showFirst(r,r.rhs);

		showFollow(r);

		}
	}


//=====================================================================
//
// Show Follow of an Expression.
//
//=====================================================================
	function showFollow(e:Expr)
	{
		var v = Follow(e);
		for (f in v) Sys.println(diagName(f));
	}

//=====================================================================
//
// Show first terminals of alternatives in Rule or Choice.
//
//=====================================================================
	function showFirst(e:Expr, alt:Array<Expr>)
	{
		if (alt.length < 2) return;
		for (a in 0...alt.length){
			_indent = 0;
			write(diagName(alt[a]));
			_indent = 2;
			var firstTerms = First.row(alt[a].index);
			firstTerms.and(terms);
			for (k in 0...N){
				if (firstTerms.get(k)) write(diagName(index[k]));
			}
		}
	}


//=====================================================================
//
// Check LL1 for Rule or Choice.
//
//=====================================================================
	function LL1(e:Expr, alt:Array<Expr>)
	{
		if (alt.length<2) return true;
		for (a in 0...alt.length-1)	{
			var firstTerms1 = First.row(alt[a].index);
			firstTerms1.and(terms);
			var firstTerms2 = First.row(alt[a+1].index);
			for (i in a+2...alt.length)	firstTerms2.or(First.row(alt[i].index));
			firstTerms2.and(terms);
			var pairs = BitMatrix.product(firstTerms1,firstTerms2,N);
			var conflicts = pairs.and(disjoint.not());
			if (conflicts.weight()>0) {
			 // Sys.println("---conflicts---");
			 // showMatrix(conflicts);
				return false;
			}
		}
		return true;
	}


//=====================================================================
//
// Get Follow as Vector.
//
//=====================================================================
	function Follow(e:Expr)
	{
		var result = new Array<Expr>();
		var i = e.index;
		for (j in 0...N){
			if (_Follow.at(i,j)) result.push(index[j]);
		}
		return result;
	}


//=====================================================================
//
// Show matrix.
//
//=====================================================================
	function showMatrix(M:BitMatrix)
	{
		for (i in 0...N){
			var row = M.row(i);
			if (!row.isEmpty()) {
				_indent = 0;
				write(diagName(index[i]));
				_indent = 2;
				for (j in 0...N){
					if (row.get(j)) write(diagName(index[j]));
				}
			}
		}
	}




//=====================================================================
//
// Diagnostic name for expression.
//
//=====================================================================
	function diagName( e:Expr)
	{
	if (e.name != null) return e.name;
	return Convert.toPrint(e.asString);
	}


//=====================================================================
//
// Write line consisting of string 's',
// indented by 'indent' positions.
//
//=====================================================================
	function write( s:String)
	{
	// if (indent>2) return;
		for (i in 0..._indent) Sys.print(" ");
		Sys.println(s);
	}

//=====================================================================
//
// Increment / decrement indentation.
//
//=====================================================================
	function indent()
	{ 
		_indent++; 
	}

	function undent()
	{ 
		_indent--; 
	}

}// AnalyzePEG

//**********************************************************************
//
// MatrixVisitor - builds matrices first, last and next.
//
//**********************************************************************

class MatrixVisitor extends Visitor{

	var owner:AnalyzePEG;
	
	public function new(owner:AnalyzePEG)
	{
		super();
		this.owner = owner;
	}

//-----------------------------------------------------------------
// Rule.
//-----------------------------------------------------------------
	override function visitRule(e:Expr.Rule)
	{
		for (expr in e.rhs){
			owner.first.set(e.index,expr.index);
			owner.last.set(expr.index,e.index);
		}
	}

//-----------------------------------------------------------------
// Choice.
//-----------------------------------------------------------------
	override function visitChoice(e:Expr.Choice)
	{
		for (expr in e.expr){
			owner.first.set(e.index,expr.index);
			owner.last.set(expr.index,e.index);
		}
	}

//-----------------------------------------------------------------
// Sequence.
//-----------------------------------------------------------------
	override function visitSequence(e:Expr.Sequence)
	{
		for (i in 0...e.expr.length) {
			owner.first.set(e.index,e.expr[i].index);
			if (!e.expr[i].nul) break;
		}

		var a = [for(i in 0...e.expr.length-1)i]; 
		a.reverse(); 
		for (i in a) {
			owner.last.set(e.expr[i].index,e.index);
			if (!e.expr[i].nul) break;
		}

		for (i in 0...e.expr.length-1){
			for (j in i+1...e.expr.length){
				owner.next.set(e.expr[i].index,e.expr[j].index);
				if (!e.expr[j].nul) break ;
			}
		}
	}

//-----------------------------------------------------------------
// Plus.
//-----------------------------------------------------------------
	override function visitPlus(e:Expr.Plus)
	{
		owner.first.set(e.index,e.expr.index);
		owner.last.set(e.expr.index,e.index);
		owner.next.set(e.expr.index,e.expr.index);
	}

//-----------------------------------------------------------------
// Star.
//-----------------------------------------------------------------
	override function visitStar(e:Expr.Star)
	{
		owner.first.set(e.index,e.expr.index);
		owner.last.set(e.expr.index,e.index);
		owner.next.set(e.expr.index,e.expr.index);
	}

//-----------------------------------------------------------------
// Query.
//-----------------------------------------------------------------
	override function visitQuery(e:Expr.Query)
	{
		owner.first.set(e.index,e.expr.index);
		owner.last.set(e.expr.index,e.index);
	}

//-----------------------------------------------------------------
// StarPlus.
//-----------------------------------------------------------------
	override function visitStarPlus(e:Expr.StarPlus)
	{
		owner.first.set(e.index,e.expr1.index);
		owner.last.set(e.expr2.index,e.index);
		owner.next.set(e.expr1.index,e.expr1.index);
		owner.next.set(e.expr1.index,e.expr2.index);
	}

//-----------------------------------------------------------------
// PlusPlus.
//-----------------------------------------------------------------
	override function visitPlusPlus(e:Expr.PlusPlus)
	{
		owner.first.set(e.index,e.expr1.index);
		owner.last.set(e.expr2.index,e.index);
		owner.next.set(e.expr1.index,e.expr1.index);
		owner.next.set(e.expr1.index,e.expr2.index);
	}
}

//**********************************************************************
//
// DisjointVisitor - builds matrix 'disjoint'.
//
//**********************************************************************

class DisjointVisitor extends Visitor {

	var owner:AnalyzePEG;
	
	public function new(owner:AnalyzePEG)
	{
		super();
		this.owner = owner;
	}

//-----------------------------------------------------------------
// StringLit.
//-----------------------------------------------------------------
	override function visitStringLit( x:Expr.StringLit)
	{
		var i = x.index;
		for (j in i+1...owner.S){
			if (Std.is(owner.index[j], Expr.StringLit)) disjoint(x,owner.index[j]);

			if (Std.is(owner.index[j], Expr.CharClass)) disjoint(x,owner.index[j]);

			if (Std.is(owner.index[j], Expr.Range)) disjoint(x,owner.index[j]);
		}
	}

//-----------------------------------------------------------------
// CharClass.
//-----------------------------------------------------------------
	override function visitCharClass( x:Expr.CharClass)
	{
		var i = x.index;
		for (j in i+1...owner.S){
			if (Std.is(owner.index[j], Expr.StringLit))disjoint(owner.index[j],x);

			if (Std.is(owner.index[j], Expr.CharClass)) disjoint(x,owner.index[j]);

			if (Std.is(owner.index[j], Expr.Range)) disjoint(x,owner.index[j]);
		}
	}

//-----------------------------------------------------------------
// Range.
//-----------------------------------------------------------------
	override function visitRange(x:Expr.Range)
	{
		var i = x.index;
		for (j in i+1...owner.S){
			if (Std.is(owner.index[j], Expr.StringLit)) disjoint(owner.index[j],x);

			if (Std.is(owner.index[j], Expr.CharClass)) disjoint(owner.index[j],x);

			if (Std.is(owner.index[j], Expr.Range)) disjoint(x,owner.index[j]);
		}
	}

//=================================================================
// Checks for disjointness
//=================================================================
//-----------------------------------------------------------------
//-----------------------------------------------------------------
	function disjoint( x:Expr, y:Expr)
	{
		if (Std.is(x,Expr.StringLit) && Std.is(y,Expr.StringLit)){
// String - String
			var xx = cast(x,Expr.StringLit);	
			var yy = cast(y,Expr.StringLit);	
			if (!xx.s.startsWith(yy.s) && !yy.s.startsWith(xx.s))	setBits(xx,yy);
		}else if (Std.is(x,Expr.StringLit) && Std.is(y,Expr.CharClass)){
// String - Class
			var xx = cast(x,Expr.StringLit);	
			var yy = cast(y,Expr.CharClass);	
			if (yy.s.indexOf(xx.s.charAt(0)) < 0) setBits(xx,yy);
		}else if (Std.is(x,Expr.StringLit) && Std.is(y,Expr.Range)){
// String - Range
			var xx = cast(x,Expr.StringLit);	
			var yy = cast(y,Expr.Range);	
			var c = xx.s.charAt(0);
			if ((c < yy.a) || (c > yy.z)) setBits(xx,yy);
		}else if (Std.is(x,Expr.CharClass) && Std.is(y,Expr.CharClass)){
// Class - Class
			var xx = cast(x,Expr.CharClass);	
			var yy = cast(y,Expr.CharClass);	
			var collision = false;
			for (k in 0...yy.s.length){
				if (xx.s.indexOf(yy.s.charAt(k)) >= 0){
					collision = true;
					break;
				}
			}
			if (!collision) setBits(xx,yy);
		}else if (Std.is(x,Expr.CharClass) && Std.is(y,Expr.Range)){
// Class - Range
			var xx = cast(x,Expr.CharClass);	
			var yy = cast(y,Expr.Range);	
			var collision = false;
			var start = yy.a.charCodeAt(0);
			var end = yy.z.charCodeAt(0);
			for (c in start...end){
				if (xx.s.indexOf(String.fromCharCode(c)) != -1){
					collision = true;
					break;
				}
			}
			if (!collision) setBits(xx,yy);
		}else if (Std.is(x,Expr.Range) && Std.is(y,Expr.Range)){
// Range - Range
			var xx = cast(x,Expr.Range);	
			var yy = cast(y,Expr.Range);	
			if ((xx.z < yy.a) || (yy.z < xx.a)) setBits(xx,yy);
		}
	}// disjoint()

//-----------------------------------------------------------------
// Set bits
//-----------------------------------------------------------------
	function setBits( x:Expr,y:Expr)
	{
		owner.disjoint.set(x.index,y.index);
		owner.disjoint.set(y.index,x.index);
	}

}
