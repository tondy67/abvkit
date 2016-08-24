package abv.peg;


class Expr {

	public var name:String;

//----------------------------------------------------------------------
// Index in vectors and matrices.
//----------------------------------------------------------------------
	public var index:Int;

//----------------------------------------------------------------------
// Reconstructed source text in 'true' form:
// with all literals converted to charaters they represent.
//----------------------------------------------------------------------
	public var asString:String;

//----------------------------------------------------------------------
// Ford's attributes.
//----------------------------------------------------------------------
	public var nul = false; // May consume null string
	public var adv = false; // May consume non-null string
	public var fal = false; // May fail
	public var WF= false; // Is well-formed

	public function new(){ };

//----------------------------------------------------------------------
// Accept visitor.
//----------------------------------------------------------------------
	public function accept( v:Visitor){};

//----------------------------------------------------------------------
// Binding strength.
//----------------------------------------------------------------------
	public function bind() 
	{ 
		return 5; 
	}

	public function toString() 
	{ 
		return 'Expr{$name: $asString}'; 
	}

}

//**********************************************************************
//
// Class Rule
//
// Represents rule of the form name = expression.
//
//**********************************************************************

class Rule extends Expr {
//-----------------------------------------------------------------
// Data.
// An absent action is represented by null (NOT empty String).
//-----------------------------------------------------------------
	public var diagName:String; // Diagnostic name (null if none).
	public var rhs:Array<Expr>;// Expressions on the right-hand side.
	public var onSucc:Array<Action>; // Actions for components of Expr.
	public var onFail:Array<Action>;


//-----------------------------------------------------------------
// Create the object with specified components.
//-----------------------------------------------------------------
	public function new(name:String,diagName:String,
		rhs:Array<Expr>, onSucc:Array<Action>, onFail:Array<Action>)
	{
		super();
		this.name = name;
		this.diagName = diagName;
		this.rhs= rhs;
		this.onSucc = onSucc;
		this.onFail = onFail;
	}

//-----------------------------------------------------------------
// Accept visitor.
//-----------------------------------------------------------------
	public override function accept( v:Visitor)
	{ 
		v.visitRule(this); 
	}
}

//**********************************************************************
//
// Class Expr.Choice
//
// Represents expression 'expr-1 / expr-2 / ... / expr-n' where n>1.
//
//**********************************************************************

class Choice extends Expr {
//-----------------------------------------------------------------
// Data
//-----------------------------------------------------------------
	public var expr:Array<Expr>;// The expr's

//-----------------------------------------------------------------
// Create object with specified expr's.
//-----------------------------------------------------------------
	public function new(expr:Array<Expr>)
	{ 
		super();
		this.expr = expr; 
	}

//-----------------------------------------------------------------
// Accept visitor.
//-----------------------------------------------------------------
	public override function accept( v:Visitor)
	{ 
		v.visitChoice(this); 
	}

//----------------------------------------------------------------------
// Binding strength.
//----------------------------------------------------------------------
	public override function bind() 
	{ 
		return 0; 
	}
}

//**********************************************************************
//
// Class Expr.Sequence
//
// Represents expression "expr-1 expr-2... expr-n" where n>1.
//
//**********************************************************************

class Sequence extends Expr{
//-----------------------------------------------------------------
// Data
//-----------------------------------------------------------------
	public var expr:Array<Expr>;// The 'expr's

//-----------------------------------------------------------------
// Create object with specified 'expr's.
//-----------------------------------------------------------------
	public function new (expr:Array<Expr>)
	{ 
		super();
		this.expr = expr; 
	}

//-----------------------------------------------------------------
// Accept visitor.
//-----------------------------------------------------------------
	public override function accept( v:Visitor)
	{ 
		v.visitSequence(this); 
	}

//----------------------------------------------------------------------
// Binding strength.
//----------------------------------------------------------------------
	public override function bind() 
	{ 
		return 1; 
	}
}

class And extends Expr {
//-----------------------------------------------------------------
// Data
//-----------------------------------------------------------------
	public var expr:Expr;

//-----------------------------------------------------------------
// Create object with specified 'expr'.
//-----------------------------------------------------------------
	public function new( expr:Expr)
	{ 
		super();
		this.expr = expr; 
	}

//-----------------------------------------------------------------
// Accept visitor.
//-----------------------------------------------------------------
	public override function accept( v:Visitor)
	{ 
		v.visitAnd(this); 
	}

//----------------------------------------------------------------------
// Binding strength.
//----------------------------------------------------------------------
	public override function bind() 
	{ 
		return 3; 
	}
}



//**********************************************************************
//
// Class Expr.Not
//
// Represents expression '!expr'.
//
//**********************************************************************

class Not extends Expr {
//-----------------------------------------------------------------
// Data
//-----------------------------------------------------------------
	public var expr:Expr;

//-----------------------------------------------------------------
// Create object with specified 'expr'.
//-----------------------------------------------------------------
	public function new( expr:Expr)
	{ 
		super();
		this.expr = expr; 
	}

//-----------------------------------------------------------------
// Accept visitor.
//-----------------------------------------------------------------
	public override function accept( v:Visitor)
	{ 
		v.visitNot(this); 
	}

//----------------------------------------------------------------------
// Binding strength.
//----------------------------------------------------------------------
	public override function bind() { return 3; }
}



//**********************************************************************
//
// Class Expr.Plus
//
// Represents expression 'expr+'.
//
//**********************************************************************

class Plus extends Expr {
//-----------------------------------------------------------------
// Data
//-----------------------------------------------------------------
	public var expr:Expr;

//-----------------------------------------------------------------
// Create object with specified 'expr'.
//-----------------------------------------------------------------
	public function new ( expr:Expr)
	{ 
		super();
		this.expr = expr; 
	}

//-----------------------------------------------------------------
// Accept visitor.
//-----------------------------------------------------------------
	public override function accept( v:Visitor)
	{ 
		v.visitPlus(this); 
	}

//----------------------------------------------------------------------
// Binding strength.
//----------------------------------------------------------------------
	public override function bind() { return 4; }
}



//**********************************************************************
//
// Class Expr.Star
//
// Represents expression 'expr*'.
//
//**********************************************************************

class Star extends Expr {
//-----------------------------------------------------------------
// Data
//-----------------------------------------------------------------
	public var expr:Expr;

//-----------------------------------------------------------------
// Create object with specified 'expr'.
//-----------------------------------------------------------------
	public function new( expr:Expr)
	{ 
		super();
		this.expr = expr; 
	}

//-----------------------------------------------------------------
// Accept visitor.
//-----------------------------------------------------------------
	public override function accept( v:Visitor)
	{ 
		v.visitStar(this); 
	}

//----------------------------------------------------------------------
// Binding strength.
//----------------------------------------------------------------------
	public override function bind() { return 4; }
}



//**********************************************************************
//
// Class Expr.Query
//
// Represents expression 'expr?'.
//
//**********************************************************************

class Query extends Expr{
//-----------------------------------------------------------------
// Data
//-----------------------------------------------------------------
	public var expr:Expr;

//-----------------------------------------------------------------
// Create object with specified 'expr'.
//-----------------------------------------------------------------
	public function new(expr:Expr)
	{ 
		super();
		this.expr = expr; 
	}

//-----------------------------------------------------------------
// Accept visitor.
//-----------------------------------------------------------------
	public override function accept( v:Visitor)
	{ 
		v.visitQuery(this); 
	}

//----------------------------------------------------------------------
// Binding strength.
//----------------------------------------------------------------------
	public override function bind() { return 4; }
}



//**********************************************************************
//
// Class Expr.PlusPlus
//
// Represents expression 'expr1++expr2'.
//
//**********************************************************************

class PlusPlus extends Expr{
//-----------------------------------------------------------------
// Data
//-----------------------------------------------------------------
	public var expr1:Expr;
	public var expr2:Expr;

//-----------------------------------------------------------------
// Create object with specified 'expr1' and 'expr2'.
//-----------------------------------------------------------------
	public function new( expr1:Expr,expr2:Expr)
	{
		super();
		this.expr1 = expr1;
		this.expr2 = expr2;
	}

//-----------------------------------------------------------------
// Accept visitor.
//-----------------------------------------------------------------
	public override function accept( v:Visitor)
	{ 
		v.visitPlusPlus(this); 
	}

//----------------------------------------------------------------------
// Binding strength.
//----------------------------------------------------------------------
	public override function bind() { return 4; }
}



//**********************************************************************
//
// Class Expr.StarPlus
//
// Represents expression 'expr1*+expr2'.
//
//**********************************************************************

class StarPlus extends Expr{
//-----------------------------------------------------------------
// Data
//-----------------------------------------------------------------
	public var expr1:Expr;
	public var expr2:Expr;

//-----------------------------------------------------------------
// Create object with specified 'expr1' and 'expr2'.
//-----------------------------------------------------------------
	public function new( expr1:Expr,expr2:Expr)
	{
		super();
		this.expr1 = expr1;
		this.expr2 = expr2;
	}

//-----------------------------------------------------------------
// Accept visitor.
//-----------------------------------------------------------------
	public override function accept( v:Visitor)
	{ 
		v.visitStarPlus(this); 
	}

//----------------------------------------------------------------------
// Binding strength.
//----------------------------------------------------------------------
	public override function bind() { return 4; }
}



//**********************************************************************
//
// Class Expr.Ref
//
// Represents reference to the Rule identified by 'name'.
//
//**********************************************************************

class Ref extends Expr{
	public var rule:Rule;

//-----------------------------------------------------------------
// Create the object with specified name.
//-----------------------------------------------------------------
	public function new( name:String)
	{
		super();
		this.name = name;
		asString = name;
	}

//-----------------------------------------------------------------
// Accept visitor.
//-----------------------------------------------------------------
	public override function accept( v:Visitor)
	{ 
		v.visitRef(this); 
	}
}



//**********************************************************************
//
// Class Expr.StringLit
//
// Represents string literal.
//
//**********************************************************************

class StringLit extends Expr{
//-----------------------------------------------------------------
// Data
//-----------------------------------------------------------------
	public var s:String; // The string in true form.

//-----------------------------------------------------------------
// Create the object with specified string.
//-----------------------------------------------------------------
	public function new( s:String)
	{
		super();
		this.s = s;
		adv = true;
		fal = true;
		WF= true;
		asString = "\"" + s + "\"";
	}

//-----------------------------------------------------------------
// Accept visitor.
//-----------------------------------------------------------------
	public override function accept( v:Visitor)
	{ 
		v.visitStringLit(this); 
	}
}



//**********************************************************************
//
// Class Expr.Range
//
// Represents range [a-z].
//
//**********************************************************************

class Range extends Expr{
//-----------------------------------------------------------------
// Data
//-----------------------------------------------------------------
	public var a:String;// Range limits in true form.
	public var z:String;

//-----------------------------------------------------------------
// Create the object with limits a-z.
//-----------------------------------------------------------------
	public function new(a:String, z:String)
	{
		super();
		this.a = a;
		this.z = z;
		adv = true;
		fal = true;
		WF= true;
		asString = "[" + a + "-" + z + "]";
	}

//-----------------------------------------------------------------
// Accept visitor.
//-----------------------------------------------------------------
	public override function accept( v:Visitor)
	{ 
		v.visitRange(this); 
	}
}



//**********************************************************************
//
// Class Expr.CharClass
//
// Represents character class [s] or ^[s].
//
//**********************************************************************

class CharClass extends Expr{
//-----------------------------------------------------------------
// Data
//-----------------------------------------------------------------
	public var s:String; // The string in true form.
	public var hat:Bool;// '^' present?

//-----------------------------------------------------------------
// Create object with specified string and 'not'.
//-----------------------------------------------------------------
	public function new( s:String, hat:Bool)
	{
		super();
		this.s = s;
		this.hat = hat;
		adv = true;
		fal = true;
		WF= true;
		asString = (hat?"^[":"[") + s + "]";
	}

//-----------------------------------------------------------------
// Accept visitor.
//-----------------------------------------------------------------
	public override function accept( v:Visitor)
	{ 
		v.visitCharClass(this); 
	}
}



//**********************************************************************
//
// Class Expr.Any
//
// Represents 'any character'.
//
//**********************************************************************

class Any extends Expr{
//-----------------------------------------------------------------
// Create.
//-----------------------------------------------------------------
	public function new()
	{
		super();
		adv = true;
		fal = true;
		WF= true;
		asString = "_";
	}

//-----------------------------------------------------------------
// Accept visitor.
//-----------------------------------------------------------------
	public override function accept( v:Visitor)
	{ 
		v.visitAny(this); 
	}
}
