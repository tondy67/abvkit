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
// Container for conversion utilities.
// They support the following policy for character representation.
// 1. Input file for the generator (the PEG) uses default encoding.
// 2. Input for the generated parser wrapped in SourceFile uses
// default encoding. The user may modify SourceFile or provide
// own wrapper to use another encoding.
// 3. The source of the generated parser uses ASCII (codes 32-126)
// with LF control character for line termination.
// The non-ASCII characters may appear in PEG within terminal
// definitions and DiagNames. They are converted to Java escapes
// when generated as Java literals.
// 4. Within the generated parser, all characters of terminal
// definitions and DiagNames are represented by themselves.
//
//**********************************************************************
using StringTools;

@:dce
class Convert{
//----------------------------------------------------------------------
// toCharLit
//----------------------------------------------------------------------
/**
*Converts character to (unquoted) Java character literal
*representing that character in ASCII encoding.
*A character outside ASCII is converted to a Java escape.
*In addition, a character literal must not be " or \.
*These characters are also escaped.
*
*@paramc the character.
*@return literal representaton of c.
*/
	public static function toCharLit(c:String)
	{
		c = c.charAt(0);
		switch(c){
			case "\\": return("\\\\");
			case "'": return("\\'");
			default: return(toRange(c,32,126));
		}
	}

//----------------------------------------------------------------------
// toStringLit
//----------------------------------------------------------------------
/**
*Converts character string to (unquoted) Java string literal
*representing that string in ASCII encoding.
*Characters outside ASCII are converted to Java escapes.
*In addition, a string literal must not contain " or \.
*These characters are also escaped.
*
*@params the string.
*@return literal representaton of s.
*/
	public static function toStringLit( s:String)
	{
		var sb = new StringBuf();
		for (i in 0...s.length){
			var c = s.charAt(i);
			switch(c){
				case '"' : sb.add("\\\""); 
				case "\\": sb.add("\\\\"); 
				default: sb.add(toRange(c,32,126)); 
			}
		}
		return sb.toString();
	}

//----------------------------------------------------------------------
// toPrint
//----------------------------------------------------------------------
	/**
	*Converts string to a printable / readable form.
	*Characters outside the range 32-255 are replaced by Java escapes.
	*
	*@params the string.
	*@return printable representaton of s.
	*/
	public static function toPrint( s:String)
	{
		var sb = new StringBuf();

		for (i in 0...s.length) sb.add(toRange(s.charAt(i),32,255));

		return sb.toString();
	}

//----------------------------------------------------------------------
// toComment
//----------------------------------------------------------------------
	/**
	*Converts string to a form that can be generated as comment.
	*Java processes unicodes before recognizing comments.
	*A 'backslash u' in comment not followed by hex digits
	*is signaled as error. It is replaced by '\ u'
	*and then the result converted to printable.
	*
	*@params the string.
	*@return comment representaton of s.
	*/
	public static function toComment(s:String)
	{
		return toPrint(s);
	}

//----------------------------------------------------------------------
// toRange
//----------------------------------------------------------------------
	/**
	*If 'c' is outside the range 'low' through 'high' (inclusive),
	*return its representation as Java escape.
	*Otherwise return 'c' as a one-character string.
	*
	*@paramc the character.
	*@return Representaton of c within the range.
	*/
	static function toRange(c:String,low:Int,high:Int):String
	{
		switch(c){
			// case "\b": return "\\b" ;
			 //case "\f": return "\\f" ;
			case "\n": return "\\n" ;
			case "\r": return "\\r" ;
			case "\t": return "\\t" ;
			default: return c;
			/*default:
			if (c<low || c>high)
			{
			String u = "000" + Integer.toHexString(c);
			return("\\u" + u.substring(u.length()-4,u.length()));
			}
			else return Character.toString(c); */
		}
	}

}
