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
// ParserTest
//
//**********************************************************************
import BitMatrix.BitSet;
import ParserBase.Cache;

@:dce
class ParserTest extends ParserBase{
//----------------------------------------------------------------------
// Trace switches.
//----------------------------------------------------------------------
	public var traceRules:Bool;// Trace Rules
	public var traceInner:Bool;// Trace subexpressions
	public var traceError:Bool;// Trace error info

	public function new() 
	{
		super();
	}

	public override function setTrace(s:String)
	{
		super.setTrace(s);
		traceRules = s.indexOf('r') != -1;
		traceInner = s.indexOf('i') != -1;
		traceError = s.indexOf('e') != -1;
	}

//----------------------------------------------------------------------
// Methods called from parsing procedures
//
// If saved result found, use it, otherwise begin new procedure.
// Version for Rule.
//----------------------------------------------------------------------
	override function saved(c:Cache)
	{
		var	c = cast(c,TCache);
		c.calls++;
		if (traceRules) trc = source.where(pos) + ": INIT " + c.name;
		_reuse = c.find(pos);
		if (_reuse != null)	{
			c.reuse++;
			if (traceRules) trc = "REUSE " + (_reuse.success? "succ " : "fail ");
			return true;
		}

		begin(c.name,c.diag);
		c.save(current);
		if (c.prevpos.get(pos)) c.rescan++; else c.prevpos.set(pos);
		return false;
	}

//----------------------------------------------------------------------
// If saved result found, use it, otherwise begin new procedure.
// Version for Inner.
//----------------------------------------------------------------------
	override function savedInner(c:Cache)
	{
		var c = cast(c,TCache);
		c.calls++;
		if (traceInner) trc = source.where(pos) + ": INIT " + c.name;
		_reuse = c.find(pos);
		if (_reuse != null){
			c.reuse++;
			if (traceInner) trc = "REUSE " + (_reuse.success? "succ " : "fail ");
			return true;
		}

		begin("",c.diag);
		c.save(current);
		if (c.prevpos.get(pos)) c.rescan++; else c.prevpos.set(pos);
		return false;
	}


//----------------------------------------------------------------------
// Accept Rule
//----------------------------------------------------------------------
	override function accept(c:Cache=null)
	{
		super.accept();
		traceAccept(c,traceRules);
		return true;
	}

//----------------------------------------------------------------------
// Accept Inner
//----------------------------------------------------------------------
	override function acceptInner(c:Cache=null)
	{
		super.acceptInner();
		traceAccept(c,traceInner);
		return true;
	}

//----------------------------------------------------------------------
// Accept Predicate
//----------------------------------------------------------------------
	override function acceptPred(c:Cache=null)
	{
		super.acceptPred();
		traceAccept(c,traceInner);
		return true;
	}

//----------------------------------------------------------------------
// Trace accept
//----------------------------------------------------------------------
	function traceAccept(c:Cache, cond:Bool)
	{
		var c = cast(c,TCache);
		if (cond){
			trc = source.where(pos) + ": ACCEPT " + c.name;
			if (traceError) trc = current.diag + "--" + current.errMsg();
		}
		c.succ++;
	}


//----------------------------------------------------------------------
// Reject Rule
//----------------------------------------------------------------------
	override function reject(c:Cache=null)
	{
		var endpos = pos;
		super.reject();
		traceReject(c,traceRules,endpos);
		return false;
	}

//----------------------------------------------------------------------
// Reject Inner
//----------------------------------------------------------------------
	override function rejectInner(c:Cache=null)
	{
		var endpos = pos;
		super.rejectInner();
		traceReject(c,traceInner,endpos);
		return false;
	}

//----------------------------------------------------------------------
// Reject Predicate
//----------------------------------------------------------------------
	override function rejectPred(c:Cache=null)
	{
		var endpos = pos;
		super.rejectPred();
		traceReject(c,traceInner,endpos);
		return false;
	}

//----------------------------------------------------------------------
// Trace reject
//----------------------------------------------------------------------
	function traceReject(c:Cache, cond:Bool, endpos:Int)
	{
		var c = cast(c,TCache);
		if (cond){
			trc = source.where(endpos) + ": REJECT " + c.name;
			if (traceError) trc = current.diag + "--" + current.errMsg();
		}
		if (pos==endpos){
			c.fail++; // No backtrack
		}else{ // Backtrack
		
			var b = endpos-pos;
			c.back++;
			c.totback += b;
			if (b>c.maxback){
				c.maxback = b;
				c.maxbpos = pos;
			}
		}
	}



//----------------------------------------------------------------------
// Execute expression ^'c'
//----------------------------------------------------------------------
	override function nextNot(ch:String,c:Cache=null)
	{
		var endpos = pos;
		var succ = super.nextNot(ch);
		return traceTerm(endpos,succ,c);
	}

	override function aheadNotNot(ch:String,c:Cache=null)
	{ 
		return ahead(ch,c); 
	}


	override function next(s="",c:Cache=null)
	{
		var succ:Bool;
		var endpos = pos;
		if (s == ""){
// Execute expression _
			succ = super.next();
		}else{
// Execute expression 'c', "s"
			succ = super.next(s);
		}
		return traceTerm(endpos,succ,c);
	}

	override function ahead(s="",c:Cache=null)
	{
		var succ:Bool;
		var endpos = pos;

		if (s == ""){
// Execute expression &_
			succ = super.ahead();
		}else{
// Execute expression &'c', !^'c', &"s"
			succ = super.ahead(s);
		}
		return traceTerm(endpos,succ,c);
	}

	override function aheadNot(s="",c:Cache=null)
	{
		var succ:Bool;
		var endpos = pos;
		if (s == ""){
// Execute expression !_
			succ = super.aheadNot();
		}else{
// Execute expression !"s", !'c', &^'c'
			succ = super.aheadNot(s);
		}
		return traceTerm(endpos,succ,c);
	}

//----------------------------------------------------------------------
// Execute expression ^[s]
//----------------------------------------------------------------------
	override function nextNotIn(s:String,c:Cache=null)
	{
		var endpos = pos;
		var succ = super.nextNotIn(s);
		return traceTerm(endpos,succ,c);
	}

	override function aheadIn(a:String, z="", c:Cache=null)
	{
		var succ:Bool;
		var endpos = pos;
		if (z == ""){
// Execute expression &[s], !^[s]
			succ = super.aheadIn(a);
		}else{
// Execute expression &[a-z]
			succ = super.aheadIn(a,z);
		}
		return traceTerm(endpos,succ,c);
	}

	override function aheadNotNotIn(s:String,c:Cache=null)
	{ 
		return aheadIn(s,"",c); 
	}

	override function nextIn(a:String, z="", c:Cache=null)
	{
		var succ:Bool;
		var endpos = pos;

		if (z == ""){
// Execute expression [s]
			succ = super.nextIn(a);
		}else{
// Execute expression [a-z]
			succ = super.nextIn(a,z);
		}
		return traceTerm(endpos,succ,c);
	}

	override function aheadNotIn(a:String, z="", c:Cache=null)
	{
		var succ:Bool;
		var endpos = pos;
		
		if (z == ""){
// Execute expression ![s], &^[s]
			succ = super.aheadNotIn(a);
		}else{
// Execute expression ![a-z]
			succ = super.aheadNotIn(a,z);
		}
		return traceTerm(endpos,succ,c);
	}



//----------------------------------------------------------------------
// Trace term
//----------------------------------------------------------------------
	function traceTerm(endpos:Int, succ:Bool, c:Cache)
	{
		var c = cast(c,TCache);
		c.calls++;
		if (c.prevpos.get(endpos)) c.rescan++;else c.prevpos.set(endpos);
		if (succ){ 
			c.succ++; 
			return true; 
		}else{ 
			c.fail++; 
			return false; 
		}
	}




}

//**********************************************************************
//
// Cache object
//
//**********************************************************************
class TCache extends Cache {
	public var calls:Int; // Total number of calls
	public var rescan:Int ; // How many were rescans without reuse
	public var reuse:Int; // How many were rescans with reuse
	public var succ:Int ; // How many resulted in success
	public var fail:Int ; // How many resulted in failure, no backtrack
	public var back:Int ; // How many resulted in backtrack
	public var totback:Int; // Accumulated amount of backtrack
	public var maxback:Int; // Maximum length of backtrack
	public var maxbpos:Int; // Position of naximal backtrack
	public var prevpos:BitSet; // Scan history


	public function new(name:String,diag="")
	{ 
		super(name,diag); 
	}

	public override function reset()
	{
		super.reset();
		calls = 0;
		rescan= 0;
		reuse = 0;
		succ= 0;
		fail= 0;
		back= 0;
		totback = 0;
		maxback = 0;
		maxbpos = 0;
		prevpos = new BitSet(60000);
	}
}


