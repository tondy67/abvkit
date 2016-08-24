package abv.peg;

//**********************************************************************
//
// Visitor
//
//------------------------------------------------------------------------
//
// Base class for visitors processing the grammar built by PEG parser.
// The reason for using base class rather than interface is that
// many visitor methods are empty. These methods thus need not be defined
// in concrete visitors.
//
//**********************************************************************

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

