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



using StringTools;
using abv.peg.AP;

@:dce
class LineWriter {
	var fileName:String;
	var out = "";
	var _indent = 0;

	static var dashes =
	"//----------------------------------------------------------------------";

	static var Dashes =
	"//**********************************************************************";


//----------------------------------------------------------------------
// Create LineWriter for output file 'fileName'.
//----------------------------------------------------------------------
	public function new(fileName:String)
	{
		this.fileName = fileName;
	}

//----------------------------------------------------------------------
// Write line consisting of string 's',
// indented by 'indent' positions.
//----------------------------------------------------------------------
	public function line( s:String)
	{
		for (i in 0..._indent) out += " ";
		out += s + "\n";
	}

//----------------------------------------------------------------------
// Write box containing string "s"
//----------------------------------------------------------------------
	public function box(s:String)
	{
		line(dashes.substring(0,71 - _indent));
		format(s,67 - _indent);
		line(dashes.substring(0,71 - _indent));
	}

//----------------------------------------------------------------------
// Write medium box containing string "s"
//----------------------------------------------------------------------
	public function Box(s:String)
	{
		line(Dashes.substring(0,73 - _indent));
		format(s,69 - _indent);
		line(Dashes.substring(0,73 - _indent));
	}

//----------------------------------------------------------------------
// Write large box containing string "s"
//----------------------------------------------------------------------
	public function BOX(s:String)
	{
		line(Dashes.substring(0,75 - _indent));
		line("//");
		format(s,71 - _indent);
		line("//");
		line(Dashes.substring(0,75 - _indent));
	}

//----------------------------------------------------------------------
// Write string "s" as comment, splitting it at blanks
// into lines not exceeding "n" positions.
//----------------------------------------------------------------------
	public function format( s:String, n:Int)
	{
		var text = s;
		var rest:String;
		var i:Int;
		while (text.length > 0){
			rest = text;
			i = text.indexOf("\n");
			if (i >= 0){
				rest = text.substring(0,i).trim();
				text = text.substring(i+1,text.length);
			}else{
				text = "";
			}

			var pfx = "// ";
			var k = n;
			while (rest.length >= k){
				i = rest.lastIndexOf(" ",k);
				if (i >= 0){
					line(pfx + rest.substring(0,i));
					rest = rest.substring(i+1,rest.length);
				}else{
					line(pfx + rest.substring(0,k));
					rest = rest.substring(k,rest.length);
				}

				pfx = "// ";
				k = n - 2;
			}
			line(pfx + rest);
		}
	}

//----------------------------------------------------------------------
// Increment / decrement indentation.
//----------------------------------------------------------------------
	public function indent()
	{ 
		_indent += 2; 
	}

	public function undent()
	{ 
		_indent -= 2; 
	}

//----------------------------------------------------------------------
// Close output.
//----------------------------------------------------------------------
	public function close()
	{
		AP.save(fileName, out);
	}
}
