package abv.peg;

//**********************************************************************
//
// ParserBase
//
//**********************************************************************
using StringTools;

class ParserBase implements CurrentRule{
//----------------------------------------------------------------------
// Input
//----------------------------------------------------------------------
	var source:Source;// Source of text to parse
	var endpos:Int; // Position after the end of text
	var pos:Int;// Current position in the text

//----------------------------------------------------------------------
// trace string.
//----------------------------------------------------------------------
	var trc = "";

//----------------------------------------------------------------------
// Current phrase (top of parse stack).
//----------------------------------------------------------------------
	var current:Phrase = null;

//-------------------------------------------------------------------
//Phrase to reuse.
//-------------------------------------------------------------------
	var _reuse:Phrase;

//-------------------------------------------------------------------
//List of Cache objects for initialization.
//-------------------------------------------------------------------
	public var caches = new Array<Cache>();

	public function new() { }

	public function init(src:Source)
	{
		source = src;
		pos = 0;
		endpos = source.end();
		current = new Phrase("","",0,source); // Dummy bottom of parse stack
		for (c in caches) c.reset();
	}

//----------------------------------------------------------------------
//Implementation of Parser interface CurrentRule
//----------------------------------------------------------------------
	public function lhs()
	{ 
		return current; 
	}

	public function rhs(i:Int)
	{ 
		return current.rhs[i]; 
	}

	public function rhsSize()
	{ 
		return current.rhs.length; 
	}

	public function rhsText(i:Int, j:Int)
	{
		if (j<=i) return "";
		return source.at(rhs(i).start,rhs(j-1).end);
	}

	public function setTrace(s:String)
	{
		this.trc = s;
	}

//----------------------------------------------------------------------
// Close parser: print messages (if not caught otherwise).
//----------------------------------------------------------------------
	function closeParser(ok:Bool)
	{
		current.actExec();
		if (!ok && (current.hwm >= 0)){
			var err = current.errMsg();
			if (err != "") println(err);
		}
	}

// == == == == == == == == ==
//
// Methods called from parsing procedures
//
// == == == == == == == == ==
//----------------------------------------------------------------------
// Initialize processing of a nonterminal:
// create new Phrase and push it on compile stack.
//----------------------------------------------------------------------
	function begin( name:String, diag="")
	{
		var p:Phrase;
		if (diag == "") p = new Phrase(name,name,pos,source);
		else p = new Phrase(name,diag,pos,source);
		p.parent = current;
		current = p;
	}

//----------------------------------------------------------------------
// Accept Rule
//----------------------------------------------------------------------
	function accept(c:Cache=null)
	{
		var p:Phrase = pop();// Pop the finishing Phrase
 // Finalize p:
		p.success = true;// Indicate p successful
		p.rhs = null;// Discard rhs of p
 // Update parent Phrase:
		current.end = pos; // End of text
		current.rhs.push(p);// Add p to the rhs
		current.hwmUpdFrom(p); // Update failure history
		current.defAct = current.defAct.concat(p.defAct); // Proagate deferred actions
		return true;
	}

//----------------------------------------------------------------------
// Accept Inner
//----------------------------------------------------------------------
	function acceptInner(c:Cache=null)
	{
		var p:Phrase = pop();// Pop the finishing Phrase
		 // Finalize p:
		p.success = true;// Indicate p successful
		 // Update parent Phrase:
		current.end = pos; // End of text
		current.rhs = current.rhs.concat(p.rhs); // Append p's rhs to the rhs
		current.hwmUpdFrom(p); // Update failure history
		current.defAct = current.defAct.concat(p.defAct); // Proagate deferred actions
		return true;
	}

//----------------------------------------------------------------------
// Accept predicate
//----------------------------------------------------------------------
	function acceptPred(c:Cache=null)
	{
		var p:Phrase = pop();// Pop the finishing Phrase
		pos = p.start; // Do not consume input
		 // Finalize p:
		p.end = pos; // Reset end of text
		p.success = true;// Indicate p successful
		p.rhs = null;// Discard rhs of p
		p.hwmClear();// Remove failure history
		 // Update parent Phrase:
		current.end = pos; // End of text
		return true;
	}

//----------------------------------------------------------------------
//Reject Rule
//----------------------------------------------------------------------
	function reject(c:Cache=null)
	{
		var p:Phrase = pop();// Pop the finishing Phrase
		pos = p.start; // Do not consume input
		 // Finalize p:
		p.end = pos; // Reset end of text
		p.success = false; // Indicate p failed
		p.rhs = null;// Discard rhs of p
		if (p.hwm<=pos)// If hwm reached or passed..
		p.hwmSet(p.diag,p.start);// ..register failure of p
		 // Update parent Phrase:
		current.end = pos; // End of text
		current.hwmUpdFrom(p); // Update failure history
		return false;
	}

//----------------------------------------------------------------------
//Reject Inner
//----------------------------------------------------------------------
	function rejectInner(c:Cache=null)
	{
		var p:Phrase = pop();// Pop the finishing Phrase
		pos = p.start; // Do not consume input
		 // Finalize p:
		p.end = pos; // Reset end of text
		p.success = false; // Indicate p failed
		p.rhs = null;// Discard rhs of p
		 // Update parent Phrase:
		current.end = pos; // End of text
		current.hwmUpdFrom(p); // Update failure history
		return false;
	}

//----------------------------------------------------------------------
//Reject predicate
//----------------------------------------------------------------------
	function rejectPred(c:Cache=null)
	{
		var p:Phrase = pop();// Pop the finishing Phrase
		pos = p.start; // Do not consume input
		 // Finalize p:
		p.end = pos; // Reset end of text
		p.success = false; // Indicate p failed
		p.rhs = null;// Discard rhs of p
		p.hwmSet(p.diag,pos);// Register 'xxx (not) expected'
		 // Update parent Phrase:
		current.end = pos; // End of text
		current.hwmUpdFrom(p); // Update failure history
		return false;
	}


	function next(s="",c:Cache=null)
	{
		if(s == ""){
//Execute expression _
			if (pos < endpos) return consume(1);
			else return fail("any character");
		}else if(s.length == 1){
//Execute expression 'c'
			if ((pos < endpos) && (source.at(pos) == s)) return consume(1);
			else return fail("'" + s + "'");
		}else{
//Execute expression "s"
			var lg = s.length;
			if ((pos+lg <= endpos) && (source.at(pos,pos+lg) == s)) return consume(lg);
			else return fail("'" + s + "'");
		}
	}

//----------------------------------------------------------------------
// Execute expression ^'c'
//----------------------------------------------------------------------
	function nextNot(ch:String,c:Cache=null)
	{
		if ((pos < endpos) && (source.at(pos) != ch)) return consume(1);
		else return fail("not '" + ch + "'");
	}

	function ahead(s="",c:Cache=null)
	{
		if (s == ""){
// Execute expression &_
			if (pos < endpos) return true;
			else return fail("any character");
		}else if(s.length == 1){
// Execute expression &'c', !^'c'
			if ((pos < endpos) && (source.at(pos) == s)) return true;
			else return fail("'" + s + "'");
		}else{
// Execute expression &"s"
			var lg = s.length;
			if ((pos+lg <= endpos) && (source.at(pos,pos+lg) == s)) return true;
			else return fail("'" + s + "'");
		}
	}

	function aheadNotNot(ch:String,c:Cache=null)// temporary
	{ 
		return ahead(ch); 
	}

	function aheadNot(s="",c:Cache=null)
	{
		if (s == ""){
// Execute expression !_
			if (pos<endpos) return fail("end of text");
			else return true;
		}else if(s.length == 1){
// Execute expression !'c', &^'c'
			if ((pos < endpos) && (source.at(pos) == s)) return fail("not '" + s + "'");
			else return true;
				
		}else{
// Execute expression !"s"
			var lg = s.length;
			if ((pos+lg <= endpos) && (source.at(pos,pos+lg)== s)) return fail("not '" + s + "'");
			else return true;
		}
	}


//----------------------------------------------------------------------
// Execute expression ^[s]
//----------------------------------------------------------------------
	function nextNotIn(s:String,c:Cache=null)
	{
		if ((pos < endpos) && (s.indexOf(source.at(pos)) < 0)) return consume(1);
		else return fail("not [" + s + "]");
	}

	function aheadNotNotIn(s:String,c:Cache=null) // temporary
	{ 
		return aheadIn(s); 
	}

	function nextIn(a:String, z="",c:Cache=null)
	{
		if (z == ""){
// Execute expression [s]
			if ((pos<endpos) && (a.indexOf(source.at(pos)) >= 0)) return consume(1);
			else return fail("[" + a + "]");
		}else{
// Execute expression [a-z]
			if ((pos<endpos) && (source.at(pos) >= a) && (source.at(pos)<=z))
				return consume(1);
			else return fail("[" + a + "-" + z + "]");
		}
	}

	function aheadIn(a:String, z="",c:Cache=null)
	{
			if (z == ""){
// Execute expression &[s], !^[s]
			if (pos<endpos && a.indexOf(source.at(pos)) >= 0) return true;
			else return fail("[" + a + "]");
			}else{
// Execute expression &[a-z]
			if (pos<endpos && source.at(pos) >= a && source.at(pos)<=z)
				return true;
			else return fail("[" + a + "-" + z + "]");
			}
	}

	function aheadNotIn(a:String, z="",c:Cache=null)
	{
		if (z == ""){
// Execute expression ![s], &^[s]
			if ((pos < endpos) && (a.indexOf(source.at(pos)) >= 0)) return fail("not [" + a + "]");
			else return true;
		}else{
// Execute expression ![a-z]
			if ((pos < endpos) && (source.at(pos) >= a) && (source.at(pos) <= z))
				return fail("not [" + a + "-" + z + "]");
			else return true;
		}
	}



//----------------------------------------------------------------------
// Pop Phrase from compile stack
//----------------------------------------------------------------------
	function pop()
	{
		var p:Phrase = current;
		current = p.parent;
		p.parent = null;
		return p;
	}

//----------------------------------------------------------------------
// Consume terminal
//----------------------------------------------------------------------
	function consume(n:Int)
	{
		var p = new Phrase("","",pos,source);
		pos += n;
		p.end = pos;
		current.rhs.push(p);
		current.end = pos;
		return true;
	}

//----------------------------------------------------------------------
// Fail
//----------------------------------------------------------------------
	function fail( msg:String)
	{
		current.hwmUpd(msg,pos);
		return false;
	}

//=====================================================================
//
//Methods called from parsing procedures
//
//=====================================================================
//-------------------------------------------------------------------
//If saved result found, use it, otherwise begin new procedure.
//Version for Rule.
//-------------------------------------------------------------------
	function saved(c:Cache)
	{
		_reuse = c.find(pos);
		if (_reuse != null) // If found Phrase to reuse..
		return true; // .. return

		begin(c.name,c.diag);// Otherwise push new Phrase
		c.save(current); // .. and cache it
		return false;
	}

//-------------------------------------------------------------------
//If saved result found, use it, otherwise begin new procedure.
//Version for Inner.
//-------------------------------------------------------------------
	function savedInner(c:Cache)
	{
		_reuse = c.find(pos);
		if (_reuse != null) // If found Phrase to reuse..
		return true; // .. return

		begin("",c.diag);// Otherwise push new Phrase
		c.save(current); // .. and cache it
		return false;
	}

//-------------------------------------------------------------------
//Reuse Rule
//-------------------------------------------------------------------
	function reuse()
	{
		pos = _reuse.end; // Update position
		current.end = pos; // Update end of current
		current.hwmUpdFrom(_reuse); // Propagate error info
		if (!_reuse.success) return false;
		current.rhs.push(_reuse);// Attach to rhs of current
		return true;
	}

//-------------------------------------------------------------------
//Reuse Inner
//-------------------------------------------------------------------
	function reuseInner()
	{
		pos = _reuse.end; // Update position
		current.end = pos; // Update end of current
		current.hwmUpdFrom(_reuse); // Propagate error info
		if (!_reuse.success)
		 return false;
		current.rhs.concat(_reuse.rhs); // Add rhs to rhs of current
		return true;
	}

//-------------------------------------------------------------------
//Reuse predicate
//-------------------------------------------------------------------
	function reusePred()
	{
		pos = _reuse.end; // Update position
		current.end = pos; // Update end of current
		current.hwmUpdFrom(_reuse); // Propagate error info
		return (_reuse.success);
	}

	function print(s:String)
	{
#if (flash || js) trace(s); #else Sys.print(s); #end
	}

	function println(s:String)
	{
		print(s + "\n");
	}

}// ParserBase

//**********************************************************************
//
//Current Rule seen by a semantic action
//
//**********************************************************************

interface CurrentRule{
//----------------------------------------------------------------------
//Left-hand side.
//----------------------------------------------------------------------
	public function lhs():Phrase;

//----------------------------------------------------------------------
//Number of right-hand side items.
//----------------------------------------------------------------------
	public function rhsSize():Int;

//----------------------------------------------------------------------
//i-th item on the right-hand side.
//----------------------------------------------------------------------
	public function rhs(i:Int):Phrase;

//----------------------------------------------------------------------
//String represented by right-hand side items i through j-1.
//----------------------------------------------------------------------
	public function rhsText(i:Int,j:Int):String;
}// CurrentRule

//**********************************************************************
//
//SemanticsBase
//
//**********************************************************************

class SemanticsBase{
//**********************************************************************
//
// Fields set by the Parser.
//
//**********************************************************************
// Reference to current rule in the Parser.
// Set when Parser instantiates Semantics.
//----------------------------------------------------------------------
	public var rule:CurrentRule;

//----------------------------------------------------------------------
// String that you can use to trigger trc.
// Set by applying method 'setTrace' to the Parser.
//----------------------------------------------------------------------
	public var trc = "";

	public function new() {}
//----------------------------------------------------------------------
// Invoked at the beginning of each invocation of the Parser.
// You can override it to perform your own initialization.
//----------------------------------------------------------------------
	public function init() {}


// == == == == == == == == ==
//
// Methods to be invoked from semantic actions.
// They call back the parser to obtain details of the environment
// in which the action was invoked.
//
// == == == == == == == == ==
//----------------------------------------------------------------------
// Returns the left-hand side Phrase object.
//----------------------------------------------------------------------
	function lhs()
	{ 
		return rule.lhs(); 
	}

//----------------------------------------------------------------------
// Returns the number of Phrase objects on the right-hand side.
//----------------------------------------------------------------------
	function rhsSize()
	{ 
		return rule.rhsSize(); 
	}

//----------------------------------------------------------------------
// Returns the i-th right-hand side object, 0<=i<rhs<=rhsSize().
// (The right-hand side objects are numbered starting with 0.)
//----------------------------------------------------------------------
	function rhs(i:Int)
	{ 
		return rule.rhs(i); 
	}

//----------------------------------------------------------------------
// Returns as one String the text represented
// by the right-hand side objects numbered i through j-1,
// where 0<=i<j<=rhsSize().
// (The right-hand side objects are numbered starting with 0.)
//----------------------------------------------------------------------
	function rhsText(i:Int, j:Int)
	{ 
		return rule.rhsText(i,j); 
	}

}// SemanticsBase

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH
//
// Cache
//
//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

class Cache{
//----------------------------------------------------------------------
// Cache size = Memo level
//----------------------------------------------------------------------
	public static var size = 3;

	public var name:String;
	public var diag:String;

	var last:Int;
	var cache:Array<Phrase>;

	public function new( name:String,  diag="")
	{
		this.name = name;
		this.diag = diag;
	}

	public function reset()
	{
		cache = [];
		last = 0;
	}

	public function save( p:Phrase)
	{
		if (size < 1) return;
		last = (last+1) % size;
		cache[last] = p;
	}

	public function find(pos:Int):Phrase
	{
		if (size < 1) return null;
		for (p in cache)
			if ((p != null) && (p.start==pos)) return p;
		return null;
	}
}// Cache

class Source {

	var text:String;

	public function new (s:String)
	{ 
		text = s; 
	}


//----------------------------------------------------------------------
//Returns end position.
//----------------------------------------------------------------------
	public function end()
	{ 
		return text.length; 
	}

//----------------------------------------------------------------------
//Returns character at position p.
//----------------------------------------------------------------------
	public function at(p:Int, q=0)
	{ 
		var r = q == 0 ? text.charAt(p) : text.substring(p,q);
		return r; 
	}

//----------------------------------------------------------------------
//Describes position p in terms of preceding text.
//----------------------------------------------------------------------
	public function whereIs(p:Int)
	{
		if (p > 15)return "After '... " + text.substring(p-15,p) + "'";
		else if (p > 0)return "After '" + text.substring(0,p) + "'";
		else return "At start";
	}

//----------------------------------------------------------------------
// Describes position p in terms of line and column number.
// Lines and columns are numbered starting with 1.
//----------------------------------------------------------------------
	public function where(p:Int)
	{
		var ln = 1; // Line number
		var ls = -1;// Line start (position of preceding newline)
		var nextnl:Int; // Position of next newline or end

		while (true){
			nextnl = text.indexOf('\n',ls+1);
			if (nextnl < 0) nextnl = text.length;
			if ((ls < p) && (p <= nextnl))return ("line " + ln + " col. " + (p-ls));
			ls = nextnl;
			ln++;
		}
	}

}// Source

//**********************************************************************
//
// Phrase
//
//**********************************************************************
class Phrase{

	public var name:String;
	public var diag:String;
	public var start:Int;
	public var end:Int;
	public var success:Bool;
	public var rhs:Array<Phrase> = [];
	public var value:Dynamic = null;
	public var parent:Phrase = null;
	var source:Source;

//-----------------------------------------------------------------
// Information about the failure farthest down in the text
// encountered while processing this Phrase.
// It can only be failure of a rule, predicate, or terminal.
// - 'hwm' (high water mark) is the position of the failure,
// or -1 if there was none.
// - 'hwmExp' identifies the expression(s) that failed at 'hwm'.
// There may be several such expressions if 'hwm' was reached
// on several attempts. The expressions are identified
// by their diagnostic names.
//-----------------------------------------------------------------
	public var hwm = -1;
	public var hwmExp = new Array<String>();

//-----------------------------------------------------------------
//Deferred actions
//-----------------------------------------------------------------
	public var defAct = new Array<Deferred>();

	public function new( name:String, diag:String,start:Int, source:Source)
	{
		this.name = name;
		this.diag = diag;
		this.start = start;
		this.end = start;
		this.source = source;
	}

// == == == == == == == == == == == == == == == == == == == == == == ==
//
// Methods called from semantic procedures
//
// == == == == == == == == == == == == == == == == == == == == == == ==
//-----------------------------------------------------------------
// Set value
//-----------------------------------------------------------------
	public function put(o:Dynamic)
	{ 
		value = o; 
	}

//-----------------------------------------------------------------
// Get value
//-----------------------------------------------------------------
	public function get()
	{ 
		return value; 
	}

//-----------------------------------------------------------------
// Get text
//-----------------------------------------------------------------
	public function text()
	{ 
		return source.at(start,end); 
	}

//----------------------------------------------------------------------
// Get i-th character of text
//----------------------------------------------------------------------
	public function charAt(i:Int)
	{ 
		return source.at(start+i); 
	}

//-----------------------------------------------------------------
// Is text empty?
//-----------------------------------------------------------------
	public function isEmpty()
	{ 
		return start == end; 
	}

//----------------------------------------------------------------------
// Get name of rule that created this Phrase.
//----------------------------------------------------------------------
	public function rule()
	{ 
		return name; 
	}

//----------------------------------------------------------------------
// Was this Phrase created by rule 'rule'?
//----------------------------------------------------------------------
	public function isA( rule:String)
	{ 
		return name == rule ; 
	}

//----------------------------------------------------------------------
// Was this Phrase created by a terminal?
//----------------------------------------------------------------------
	public function isTerm()
	{ 
		return name == "" ; 
	}

//-----------------------------------------------------------------
// Describe position of i-th character of the Phrase in source text.
//-----------------------------------------------------------------
	public function where(i:Int)
	{ 
		return source.where(start+i); 
	}

//-----------------------------------------------------------------
// Get error message
//-----------------------------------------------------------------
	public function errMsg()
	{
		if (hwm < 0) return "";
		return source.whereIs(hwm) + ":" + listErr();
	}

//-----------------------------------------------------------------
// Clear error information
//-----------------------------------------------------------------
	public function errClear()
	{ 
		hwmClear(); 
	}

//-----------------------------------------------------------------
// Add information about 'expr' failing at the i-th character
// of this Phrase.
//-----------------------------------------------------------------
	public function errAdd( expr:String, i:Int)
	{ 
		hwmSet(expr,start+i); 
	}

//-----------------------------------------------------------------
// Clear deferred actions
//-----------------------------------------------------------------
	public function actClear()
	{ 
		clear(defAct); 
	}

//-----------------------------------------------------------------
// Add deferred action
//-----------------------------------------------------------------
	public function actAdd( a:Deferred)
	{ 
		defAct.push(a); 
	}

//-----------------------------------------------------------------
// Execute deferred actions
//-----------------------------------------------------------------
	public function actExec()
	{
		for (a in defAct) a.exec();
		clear(defAct);
	}


// == == == == == == == == == == == == == == == == == == == == == == ==
//
// Metods called from Parser
//
// == == == == == == == == == == == == == == == == == == == == == == ==
//-----------------------------------------------------------------
// Clear high-water mark
//-----------------------------------------------------------------
	public function hwmClear()
	{
		clear(hwmExp);
		hwm = -1;
	}

//-----------------------------------------------------------------
// Set fresh mark ('what' failed 'where'), discarding any previous.
//-----------------------------------------------------------------
	public function hwmSet( what:String, where:Int)
	{
		clear(hwmExp);
		hwmExp.push(what);
		hwm = where;
	}

//-----------------------------------------------------------------
// Add info about 'what' failing at position 'where'.
//-----------------------------------------------------------------
	public function hwmUpd( what:String, where:Int)
	{
		if (hwm>where) return; // If 'where' older: forget
		if (hwm<where){ // If 'where' newer: replace
			clear(hwmExp);
			hwm = where;
		}
		// If same position: add
		hwmExp.push(what);
	}

//-----------------------------------------------------------------
// Update error high-water mark with that from Phrase 'p'.
//-----------------------------------------------------------------
	public function hwmUpdFrom( p:Phrase)
	{
		if (hwm > p.hwm) return;// If p's info older: forget
		if (hwm < p.hwm){// If p's infonewer: replace
			clear(hwmExp);
			hwm = p.hwm;
		}
		hwmExp = hwmExp.concat(p.hwmExp);// If same position: add
	}


//-----------------------------------------------------------------
// Translate high-water mark into error message.
//-----------------------------------------------------------------
	function listErr()
	{
		var one = new StringBuf();
		var two = new StringBuf();
		var done = new Array<String>();
		for ( s in hwmExp) { 
			if (done.indexOf(s) != -1) continue;
			done.push(s);
			if (s.startsWith("not ")) toPrint(" or " + s.substring(4),two);
			else toPrint(" or " + s,one);
		}

		if (one.length > 0){		
			if (two.length== 0) return " expected " + one.toString().substring(4);
			else return " expected " + one.toString().substring(4) +
			 "; not expected " + two.toString().substring(4);
		}else{
			return " not expected " + two.toString().substring(4);
		}
	}

//-----------------------------------------------------------------
//Convert string to printable and append to StringBuf.
//-----------------------------------------------------------------
	function toPrint( s:String,sb:StringBuf)
	{
		for (i in 0...s.length)	{
			var c = s.charAt(i);
			switch(c) {
//				case '\\b': sb.add("\\b"); 
//				case '\\f': sb.add("\\f"); 
				case '\\n': sb.add("\\n"); 
				case '\\r': sb.add("\\r"); 
				case '\\t': sb.add("\\t"); 
				default:sb.add(c);
			/*if ((c<32) || (c>256))
			{
			var u = "000" + Std.toHex(c);
			sb.add("\\u" + u.substring(u.length()-4,u.length()));
			}
			else sb.add(c); */

			}
		}
	}
	
	public static inline function clear<T>(a:Array<T>)
	{
#if flash 
		untyped a.length = 0; 
#else 	
		a.splice(0,a.length); 
#end
    }// clear<T>()
	
}// Phrase

//**********************************************************************
//
// Functional interface for deferred actions
//
//**********************************************************************

interface Deferred{
	
	public function exec():Void;
  
}

