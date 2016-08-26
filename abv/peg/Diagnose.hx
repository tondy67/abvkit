/***********************************************************************
*
*  Part of abvkit (haxe port of http://www.romanredz.se/Mouse/)
*
*  Copyright (c) 2016 by Todor Angelov (www.tondy.com).
*
*  Licensed under the Apache License, Version 2.0 (the "License");
*  you may not use this file except in compliance with the License.
*  You may obtain a copy of the License at
*
*       http://www.apache.org/licenses/LICENSE-2.0
*
*  Unless required by applicable law or agreed to in writing, software
*  distributed under the License is distributed on an "AS IS" BASIS,
*  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
*  See the License for the specific language governing permissions and
*  limitations under the License.
*
***********************************************************************/

package abv.peg;

//**********************************************************************
//
// Class Diagnose
//
//----------------------------------------------------------------------
//
// Contains methods to detect and write messages about:
// - not well-formed expressions;
// - no-fail alternatives in Choice;
// - no-success alternatives in Sequence;
// - superfluous '?' operators.
//
//**********************************************************************

using abv.peg.AP;

@:dce
class Diagnose{
//----------------------------------------------------------------------
//
// Nonterminal expressions.
//
//----------------------------------------------------------------------
	var N:Int;// Number of nonterminals
	var R:Int;// Number of rules
	var exprs:Array<Expr> = []; // Array of nonterminals

//----------------------------------------------------------------------
//
// Matrices for diagnosing left recursion.
// first.at(i,j) means exprs[i] directly calls exprs[j] as first.
// First.at(i,j) means exprs[i] (in)directly calls exprs[j] as first.
// For easier construction, the matrices have dimension N+1 x N+1,
// with row and column N used for all terminals (not listed in exprs).
// This row and column are not used in diagnostics.
//
//----------------------------------------------------------------------
	public var first:BitMatrix;
	var First:BitMatrix;

//----------------------------------------------------------------------
//
// Lists of expression names to appear in diagnostics.
// The grammar often contains duplicate sub-expressions.
// To avoid duplication of messages, information is collected
// in hash sets.
//
//----------------------------------------------------------------------
//----------------------------------------------------------------------
// Left-recursive expressions.
//----------------------------------------------------------------------
	public var recur = new Array<String>();

//----------------------------------------------------------------------
// Expressions under superfluous query.
//----------------------------------------------------------------------
	public var query = new Array<String>();

//----------------------------------------------------------------------
// Choice alternatives that cannot fail.
//----------------------------------------------------------------------
	public var choice = new Array<String>();

//----------------------------------------------------------------------
// Expressions that always fail.
//----------------------------------------------------------------------
	public var fail = new Array<String>();

//----------------------------------------------------------------------
// Nullable iterations.
//----------------------------------------------------------------------
	public var iter = new Array<String>();

	public function new(){}
	
//----------------------------------------------------------------------
//
// Detect problems and write messages.
//
//----------------------------------------------------------------------

	public function applyTo(peg:PEG)
	{
//----------------------------------------------------------------------
// Build array 'exprs' of nonterminal expressions.
// For each Expr object, set 'index' to its position in 'exprs'.
//----------------------------------------------------------------------
		N = peg.rules.length + peg.subs.length;
		R = peg.rules.length;
		exprs = [new Expr()];

		var i = 0;

		for (e in peg.rules){
			e.index = i;
			exprs[i] = e;
			i++;
		}

		for (e in peg.subs)	{
			e.index = i;
			exprs[i] = e;
			i++;
		}

//----------------------------------------------------------------------
// The Expr.Ref nodes are not included in 'exprs',
// but they obtain index of the node they refer to.
//----------------------------------------------------------------------
		for (e in peg.refs) e.index = e.rule.index;

//----------------------------------------------------------------------
// The terminal nodes are not included in 'exprs',
// but they obtain index N.
//----------------------------------------------------------------------
		for (e in peg.terms) e.index = N;

//----------------------------------------------------------------------
// Initialize 'first'.
//----------------------------------------------------------------------
		first = BitMatrix.empty(N+1);

//----------------------------------------------------------------------
// Scan nonterminals using DiagVisitor.
//----------------------------------------------------------------------
		var diagVisitor = new DiagVisitor(this);
		for (e in exprs) e.accept(diagVisitor);

//----------------------------------------------------------------------
// Find expressions that always fail.
//----------------------------------------------------------------------
		for (e in exprs){
			if ((!e.nul) && (!e.adv)) fail.add(diagName(e));
		}
//----------------------------------------------------------------------
// Find left recursion.
//----------------------------------------------------------------------
		First = first.closure();
		for (i in 0...R){
			if (First.at(i,i)) leftRecursion(i);
		}
//----------------------------------------------------------------------
// Write out findings.
//----------------------------------------------------------------------
		if (peg.notWF > 0) {
			Sys.println("Warning: the grammar not well-formed.");

			for (s in iter)
			Sys.println("- " + s + " may consume empty string.");

			for (s in recur)
			Sys.println(s + ".");

			return;
		}

//----------------------------------------------------------------------
// We arrive here only if the grammar is well-formed.
// Otherwise the fail / succeed attributes are incomplete.
//----------------------------------------------------------------------
		for (s in fail) Sys.println("Warning: " + s + " always fails.");

		for (s in choice)
			Sys.println("Warning: " + s + " never fails and hides other alternative(s).");

		for (s in query)
			Sys.println("Info: as " + s + " never fails, the '?' in " + s + "? can be dropped.");
}


//----------------------------------------------------------------------
//
// Provide left-recursion details of exprs[i].
//
//----------------------------------------------------------------------
	function leftRecursion(i:Int)
	{
		var sb = new StringBuf();
		sb.add("- " + diagName(exprs[i]) + " is left-recursive");
		var sep = " via ";
		for (j in 0...N) {
			if (first.at(i,j) && First.at(j,i))	{
				sb.add(sep + diagName(exprs[j]));
				sep = " and ";
			}
		}
		recur.add(sb.toString());
	}


//----------------------------------------------------------------------
//
// Diagnostic name for expression.
//
//----------------------------------------------------------------------
	public function diagName(e:Expr)
	{
		if (e.name != null) return e.name;
		return Convert.toPrint(e.asString);
	}



//**********************************************************************
//
// DiagVisitor - collects diagnostic information.
//
//**********************************************************************

}// Diagnose

class DiagVisitor extends Visitor{
	
	var owner:Diagnose;
	
	public function new(owner:Diagnose)
	{
		super();
		this.owner = owner;
	}// new()
//----------------------------------------------------------------------
// Rule.
//----------------------------------------------------------------------
	public override function visitRule( expr:Expr.Rule)
	{ 
		doChoice(expr,expr.rhs);
	}

//----------------------------------------------------------------------
// Choice.
//----------------------------------------------------------------------
	public override function visitChoice( expr:Expr.Choice)
	{ 
		doChoice(expr,expr.expr);
	}

//----------------------------------------------------------------------
// Sequence.
//----------------------------------------------------------------------
	public override function visitSequence( expr:Expr.Sequence)
	{
		for (i in 0...expr.expr.length){
			owner.first.set(expr.index,expr.expr[i].index);
			if (!expr.expr[i].nul) break;
		} 
	}

//----------------------------------------------------------------------
// And predicate.
//----------------------------------------------------------------------
	public override function visitAnd( expr:Expr.And)
	{ 
		owner.first.set(expr.index,expr.expr.index);
	}

//----------------------------------------------------------------------
// Not predicate.
//----------------------------------------------------------------------
	public override function visitNot( expr:Expr.Not)
	{ 
		owner.first.set(expr.index,expr.expr.index); 
	}

//----------------------------------------------------------------------
// Plus.
//----------------------------------------------------------------------
	public override function visitPlus( expr:Expr.Plus)
	{
		if (expr.expr.nul) owner.iter.add(owner.diagName(expr.expr) + " in " + owner.diagName(expr));
		owner.first.set(expr.index,expr.expr.index); 
	}

//----------------------------------------------------------------------
// Star.
//----------------------------------------------------------------------
	public override function visitStar( expr:Expr.Star)
	{
		if (expr.expr.nul) owner.iter.add(owner.diagName(expr.expr) + " in " + owner.diagName(expr));
		owner.first.set(expr.index,expr.expr.index);
	}

//----------------------------------------------------------------------
// Query.
//----------------------------------------------------------------------
	public override function visitQuery( expr:Expr.Query)
	{
		if (expr.expr.nul) owner.query.add(owner.diagName(expr.expr));
		owner.first.set(expr.index,expr.expr.index); 
	}

//----------------------------------------------------------------------
// StarPlus.
//----------------------------------------------------------------------
	public override function visitStarPlus( expr:Expr.StarPlus)
	{
		if (expr.expr1.nul) owner.iter.add(owner.diagName(expr.expr1) + " in " + owner.diagName(expr));
		owner.first.set(expr.index,expr.expr1.index);
		owner.first.set(expr.index,expr.expr2.index); 
	}

//----------------------------------------------------------------------
// PlusPlus.
//----------------------------------------------------------------------
	public override function visitPlusPlus( expr:Expr.PlusPlus)
	{
		if (expr.expr1.nul) owner.iter.add(owner.diagName(expr.expr1) + " in " + owner.diagName(expr));
		owner.first.set(expr.index,expr.expr1.index);
		owner.first.set(expr.index,expr.expr2.index);
	}

//----------------------------------------------------------------------
// Common for Rule and Choice.
//----------------------------------------------------------------------
	function doChoice( expr:Expr, list:Array<Expr>)
	{
		for (i in 0...list.length-1){
			if (!list[i].fal) owner.choice.add(owner.diagName(list[i]) + " in " + owner.diagName(expr));
		}
		for (e in list) owner.first.set(expr.index,e.index);
	} 
}
