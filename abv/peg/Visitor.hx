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
// Visitor
//
//----------------------------------------------------------------------
//
// Base class for visitors processing the grammar built by PEG parser.
// The reason for using base class rather than interface is that
// many visitor methods are empty. These methods thus need not be defined
// in concrete visitors.
//
//**********************************************************************

@:dce
class Visitor {
	
	public function new(){ }
	public function visitRule(expr:Expr.Rule) {}
	public function visitChoice(expr:Expr.Choice) {}
	public function visitSequence(expr:Expr.Sequence) {}
	public function visitAnd(expr:Expr.And) {}
	public function visitNot(expr:Expr.Not) {}
	public function visitPlus(expr:Expr.Plus) {}
	public function visitStar(expr:Expr.Star) {}
	public function visitQuery(expr:Expr.Query) {}
	public function visitPlusPlus(expr:Expr.PlusPlus) {}
	public function visitStarPlus(expr:Expr.StarPlus) {}
	public function visitRef(expr:Expr.Ref) {}
	public function visitStringLit(expr:Expr.StringLit) {}
	public function visitCharClass(expr:Expr.CharClass) {}
	public function visitRange(expr:Expr.Range) {}
	public function visitAny(expr:Expr.Any) {}
}

