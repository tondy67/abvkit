package abv.peg;

import abv.peg.ParserBase.SemanticsBase;

class Semantics extends SemanticsBase{
//----------------------------------------------------------------------
//Results: array of Rules and number of errors.
//----------------------------------------------------------------------
public var rules:Array<Expr.Rule> = null;
public var errcount = 0;


//----------------------------------------------------------------------
// Some shorthands
//----------------------------------------------------------------------
	function exprValue(i:Int)
	{ 
		var r:Expr = null;
		try r = cast(rhs(i).get(),Expr)catch(e:Dynamic){};
		return r; 
	}

	function ruleValue(i:Int)
	{ 
		var r:Expr.Rule = null;
		try r = cast(rhs(i).get(),Expr.Rule)catch(e:Dynamic){};
		return r; 
	}

	function actionValue(i:Int)
	{ 
		var r:Action = null; 
		try r = cast(rhs(i).get(),Action)catch(e:Dynamic){};
		return r; 
	}

	function arrayValue<T>(i:Int)
	{ 
		var r:Array<T> = null;
		try{
			r = new Array<T>();
			var a = cast(rhs(i).get(),Array<Dynamic>); 
			for (i in 0...a.length){
				if (a[i] != null)r[i] = cast a[i];
			}
		}catch(e:Dynamic){}; 
		return r;
	} 
	 
	function stringValue(i:Int)
	{ 
		return Std.string(rhs(i).get()); 
	}

	function charValue(i:Int)
	{ 
		return stringValue(i).charAt(0); 
	}

// == == == == == == == == == == == == == == == == == == == == == == === == =
//
//Semantic procedures
//
// == == == == == == == == == == == == == == == == == == == == == == === == =
//----------------------------------------------------------------------
//Grammar = Space? (&_ (Rule / Skip))* EOT
//0 1,2,..,-2-1
//----------------------------------------------------------------------
	public function Grammar()
	{
		var n = rhsSize()-2; // Number of Rules, correct or not.
	
		if (n <= 0) {
			Sys.println("input file empty");
			errcount++;
			return;
		}

		if (errcount > 0) return;

	// All Rules were correctly parsed. Construct array of Rules.
		rules = new Array<Expr.Rule>();
		for (i in 0...n) rules[i] = ruleValue(i+1);

	// Print trc if requested.
		if (trc.indexOf('G') < 0) return;
		for (r in rules) Sys.println(Convert.toPrint(r.asString));
	}

//----------------------------------------------------------------------
//Rule = Name EQUAL RuleRhs DiagName? SEMI
// 0123 4(3)
//----------------------------------------------------------------------
	public function Rule()
	{
		var ruleName = stringValue(0);

		var diagName:String = null;
		if (rhsSize() == 5) diagName = stringValue(3);

	// RuleRhs returns Expr.Rule object without name and diag name
		var temp:Expr.Rule = ruleValue(2);

	// Fill default action names
		if (temp.rhs.length == 1) {
			if ((temp.onSucc[0] != null) && (temp.onSucc[0].name == ""))
				temp.onSucc[0].name = ruleName;
			if ((temp.onFail[0] != null) && (temp.onFail[0].name== ""))
				temp.onFail[0].name = ruleName + "_fail";
		}else{
			for (i in 0...temp.rhs.length){
				if ((temp.onSucc[i] != null) && (temp.onSucc[i].name== ""))
					temp.onSucc[i].name = ruleName + "_" + i;
				if ((temp.onFail[i] != null) && (temp.onFail[i].name== ""))
					temp.onFail[i].name = ruleName + "_" + i + "_fail";
			}
		}

	// Make new object because components should be final
		lhs().put(new Expr.Rule(ruleName,diagName,temp.rhs,temp.onSucc,temp.onFail));
	}

//----------------------------------------------------------------------
//Rule not recognized
//----------------------------------------------------------------------
	public function Error()
	{
		Sys.println(lhs().errMsg());
		lhs().errClear();
		errcount++;
	}

//----------------------------------------------------------------------
//RuleRhs = Sequence Actions (SLASH Sequence Actions)*
//0 1 2,5,.. 3,6,.. 4,7,..
//----------------------------------------------------------------------
	public function RuleRhs()
	{
	// Returns a temporary Rule object with 'name' and 'diagName' null.
		var n = Std.int((rhsSize()+1)/3); // Number of 'Sequence's

		var seq:Array<Expr>= [];
		var succ:Array<Action> = [];
		var fail:Array<Action> = [];

		var actions:Array<Action>;
		for (i in 0...n){
			seq[i] = exprValue(3*i);
			actions = arrayValue(3*i+1);
			succ[i] = actions[0];
			fail[i] = actions[1]; 
		}

		lhs().put(new Expr.Rule(null,null,seq,succ,fail));
	}

//----------------------------------------------------------------------
//Choice = Sequence (SLASH Sequence)*
// 0 1,3,..2,4,..
//----------------------------------------------------------------------
	public function Choice()
	{
		var n = rhsSize();
		if (n == 1)	{
			lhs().put(rhs(0).get());
			return;
		}
		var seq = new Array<Expr>();
		var max = Std.int((n+1)/2);
		for (i in 0...max) seq[i] = exprValue(2*i);

		lhs().put(new Expr.Choice(seq));
	}

//----------------------------------------------------------------------
//Sequence = Prefixed+
// 0,1,..
//----------------------------------------------------------------------
	public function Sequence()
	{
		var n = rhsSize();

		if (n == 1)	{
			lhs().put(rhs(0).get());
			return;
		}

		var pref = new Array<Expr>();
		for (i in 0...n) pref[i] = exprValue(i);

		lhs().put(new Expr.Sequence(pref));
	}

//----------------------------------------------------------------------
//Prefixed = PREFIX? Suffixed
//0 1(0)
//----------------------------------------------------------------------
	public function Prefixed()
	{
		if (rhsSize() == 1){
			lhs().put(rhs(0).get());
			return;
		}

		var arg = exprValue(1);
		var and = rhs(0).charAt(0) == '&';

		// If nested predicate: reduce to single one
		if (Std.is(arg , Expr.And)){
			if (and) lhs().put(arg);
			else lhs().put(new Expr.Not((cast(arg,Expr.And)).expr));
		}else if (Std.is(arg , Expr.Not)){
			if (and) lhs().put(arg);
			else lhs().put(new Expr.And((cast(arg,Expr.Not)).expr));
		}else{ // Argument is not a predicate
			if (and) lhs().put(new Expr.And(arg));
			else lhs().put(new Expr.Not(arg));
		}
	}

//----------------------------------------------------------------------
//Suffixed= Primary (UNTIL Primary / SUFFIX)?
// 0 12 1
//----------------------------------------------------------------------
	public function Suffixed()
	{
		if (rhsSize() == 1){ // Primary only
			lhs().put(rhs(0).get());
		}else if (rhsSize() == 2){// Primary SUFFIX
			if (rhs(1).charAt(0) == '?') 
				lhs().put(new Expr.Query(exprValue(0)));
			else if (rhs(1).charAt(0) == '*') 
				lhs().put(new Expr.Star(exprValue(0)));
			else lhs().put(new Expr.Plus(exprValue(0)));
		}else{ // Primary UNTIL Primary
			if (rhs(1).charAt(0) == '*')
				lhs().put(new Expr.StarPlus(exprValue(0),exprValue(2)));
			else
				lhs().put(new Expr.PlusPlus(exprValue(0),exprValue(2)));
		}
	}

//----------------------------------------------------------------------
//Primary = Name
// 0
//----------------------------------------------------------------------
	public function Resolve()
	{
		var ref:Expr.Ref = new Expr.Ref(stringValue(0));
		lhs().put(ref);
	}

//----------------------------------------------------------------------
//Primary = LPAREN Choice RPAREN
// 012
//----------------------------------------------------------------------
	public function Pass2()
	{ lhs().put(rhs(1).get()); }

//----------------------------------------------------------------------
//Primary = ANY
//----------------------------------------------------------------------
	public function Any()
	{ lhs().put(new Expr.Any()); }

//----------------------------------------------------------------------
//Primary = StringLit
//Primary = Range
//Primary = CharClass
//Char = Escape
//----------------------------------------------------------------------
	public function Pass()
	{ lhs().put(rhs(0).get()); }

//----------------------------------------------------------------------
//Actions = OnSucc OnFail
// 0 1
//----------------------------------------------------------------------
	public function Actions()
	{ 
		lhs().put([actionValue(0),actionValue(1)]); // 
	}

//----------------------------------------------------------------------
//OnSucc = (LWING AND? Name? RWING)?
//01-2-1
//----------------------------------------------------------------------
	public function OnSucc()
	{
		var n = rhsSize();

		if (n == 0){
			lhs().put(null);
		}else{
			var name = rhs(n-2).isA("Name")? stringValue(n-2) : "";

			if (rhs(1).isA("AND")) lhs().put(new Action(name,true));
			else lhs().put(new Action(name,false));
		}
	}

//----------------------------------------------------------------------
//OnFail = (TILDA LWING Name? RWING)?
//0 1-2-1
//----------------------------------------------------------------------
	public function OnFail()
	{
		var n = rhsSize();

		if (n == 0){ 
			lhs().put(null);
		}else{
			var name:String = rhs(n-2).isA("Name")? stringValue(n-2) : "";
			lhs().put(new Action(name,false));
		}
	}

//----------------------------------------------------------------------
//Name = Letter (Letter / Digit)* Space
//01 ... -2 -1
//----------------------------------------------------------------------
	public function Name()
	{ lhs().put(rhsText(0,rhsSize()-1)); }

//----------------------------------------------------------------------
//DiagName = "(" (!")" Char)+ ")" Space
//01,2..,-3-2 -1
//----------------------------------------------------------------------
	public function DiagName()
	{
		var sb = new StringBuf();
		for (i in 1...rhsSize()-2)
		sb.add(charValue(i));
		lhs().put(sb.toString());
	}

//----------------------------------------------------------------------
//StringLit = ["] (!["] Char)+ ["] Space
// 01,2..,-3-2 -1
//----------------------------------------------------------------------
	public function StringLit()
	{
		var sb = new StringBuf();
		for (i in 1...rhsSize()-2)
		sb.add(charValue(i));
		lhs().put(new Expr.StringLit(sb.toString()));
	}

//----------------------------------------------------------------------
//CharClass = ("[" / "^[") (!"]" Char)+ "]" Space
//001,2..,-3-2 -1
//----------------------------------------------------------------------
	public function CharClass()
	{
		var sb = new StringBuf();
		for (i in 1...rhsSize()-2) sb.add(charValue(i));
		lhs().put(new Expr.CharClass(sb.toString(),rhs(0).charAt(0) == '^'));
	}

//----------------------------------------------------------------------
//Range = "[" Char "-" Char "]" Space
// 01 23 45
//----------------------------------------------------------------------
	public function Range()
	{
		var a = charValue(1);
		var z = charValue(3);
		lhs().put(new Expr.Range(a,z));
	}

//----------------------------------------------------------------------
//Char = ![\r\n]_
//----------------------------------------------------------------------
	public function Char()
	{ lhs().put(rhs(0).charAt(0)); }

//----------------------------------------------------------------------
//Escape = "\\u" HexDigit HexDigit HexDigit HexDigit
//0 1 234
//----------------------------------------------------------------------
	public function Unicode()
	{
		var s = rhsText(1,5);
		lhs().put(Std.parseInt(s));
	}

//----------------------------------------------------------------------
//Escape = "\n"
// 0
//----------------------------------------------------------------------
	public function Newline()
	{ lhs().put('\n'); }

//----------------------------------------------------------------------
//Escape = "\r"
// 0
//----------------------------------------------------------------------
	public function CarRet()
	{ lhs().put('\r'); }

//----------------------------------------------------------------------
//Escape = "\t"
// 0
//----------------------------------------------------------------------
	public function Tab()
	{ lhs().put('\t'); }

//----------------------------------------------------------------------
//Escape = "\" _
//01
//----------------------------------------------------------------------
	public function Escape()
	{ lhs().put(rhs(1).charAt(0)); }

//----------------------------------------------------------------------
//Space = ([ \r\n\t] / Comment)*
//----------------------------------------------------------------------
	public function Space()
	{lhs().errClear(); }

}
