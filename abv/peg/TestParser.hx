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
// TestParser
//
//-----------------------------------------------------------------------
//
// Run the instrumented parser (generated with option -T),
// and print information about its operation.
//
// The <arguments> are specified as options according to POSIX syntax:
//
// -f <file>
// Apply the parser to file <file>. Optional.
// The <file> should include any extension.
// Need not be a complete path, just enough to identify the file
// in the current environment.
//
// -F <list>
// Apply the parser separately to each file in a list of files. Optional.
// The <list> identifies a text file containing one fully qualified
// file name per line.
// The <list> itself need not be a complete path, just enough
// to identify the file in the current environment.
//
// -m <n>
// Amount of memoization. Optional.
// <n> is a digit from 1 through 9 specifying the number of results
// to be cached. Default is no memoization.
//
// -T <string>
// Tracing switches. Optional.
// The <string> is assigned to the 'trc' field in your semantics
// object, where it can be used it to activate any trc
// programmed there.
// In addition, presence of certain letters in <string>
// activates trcs in the parser:
// r - trace execution of parsing procedures for rules.
// i - trace execution of parsing procedures for inner expressions.
// e - trace error information.
//
// -d Show detailed statistics for backtracking - rescan - reuse. Optional.
//
// -D Show detailed statistics for all invoked procedures. Optional.
//
// -C <file>
// Write all statistics as comma separated values (CSV) to file <file>,
// rather than to System.out. Optional; can only be specified with -F.
// The <file> should include any extension.
// Need not be a complete path, just enough to identify the file
// in the current environment.
//
// -t Show timing for -f and -F.
//
// If you do not specify -f or -F,the parser is executed interactively,
// prompting for input by printing '>'.
// It is invoked separately for each input line after you press 'Enter'.
// You terminate the session by pressing 'Enter' directly at the prompt.
//
//**********************************************************************
import sys.io.File;

import ParserBase.Source;
import ParserBase.Cache;
import ParserTest.TCache;

//using abv.peg.AP;
using StringTools;

@:dce
class TestParser{
	
	var parser:AbvkitParser;
//----------------------------------------------------------------------
// Command arguments.
//----------------------------------------------------------------------
	var cmd:CommandArgs;

	var cacheList:Array<TCache> = [];

//----------------------------------------------------------------------
// Statistics switches.
//----------------------------------------------------------------------
	var details:Bool;// -d or -D specified
	var allDetails:Bool; // -D specified
	var csv:Bool;// -C specified
	var timing:Bool; // -t specified

//----------------------------------------------------------------------
// CSV file.
//----------------------------------------------------------------------
	var csvFile:String;

//-------------------------------------------------------------
// Computed totals.
//-------------------------------------------------------------
	var calls:Int;
	var succ:Int;
	var fail:Int;
	var back:Int;
	var reuse:Int;
	var rescan:Int;
	var totback:Int;
	var maxback:Int;

//-------------------------------------------------------------
// Execution time.
//-------------------------------------------------------------
	var time:Float;

	var failed = 0;
	var parsed:Bool;
	var _csv:String;
		
	public function new(){};

	public function run()
	{
//----------------------------------------------------------------------
// Get and check command arguments.
//----------------------------------------------------------------------
		cmd = new CommandArgs
			 (Sys.args(),// arguments to parse
			"Ddt", // options
			"FfmTC",// options with argument
			 0,0); // no positional arguments
		if (cmd.nErrors() > 0) return;

//---------------------------------------------------------------
// The -m option.
//---------------------------------------------------------------
		var m = 0;
		if (cmd.opt('m')){
			var memo = cmd.optArg('m');
			if (memo.length != 1) m = -1;
			else m = 1 + "123456789".indexOf(memo.charAt(0));
			if (m < 1){
				Sys.println("-m is outside the range 1-9.");
				return;
			}
			Cache.size = m;
		}
		
		parser = new AbvkitParser();
//---------------------------------------------------------------
// The -T option.
//---------------------------------------------------------------
		var trc = cmd.optArg('T');
		if (trc == null) trc = "";

//---------------------------------------------------------------
// Set statistics switches.
//---------------------------------------------------------------
		if (cmd.opt('F') && cmd.opt('f')){
			Sys.println("-f and -F are mutually exclusive.");
			return;
		}

		if (cmd.opt('C') && !cmd.opt('F')){
			Sys.println("-C can only be specified together with -F.");
			return;
		}

		if (cmd.opt('D') && cmd.opt('d')){
			Sys.println("-d and -D are mutually exclusive.");
			return;
		}

		csv = cmd.opt('C');
		details = cmd.opt('d') || cmd.opt('D');
		allDetails = cmd.opt('D');
		timing = cmd.opt('t');

		cacheList = [];
		if (parser.kind == "test"){
			for (it in parser.caches){
				cacheList.push(cast(it,TCache));
			}
		}

		var s =  "\nGrammar: " + parser.grammar + "\n";
		s += "Parser : " + parser.kind;
		if (parser.kind != "norm") s += " [" + Cache.size + "]";
		Sys.println(s);

//----------------------------------------------------------------------
// If no input files given, run parser interactively.
//----------------------------------------------------------------------
		if (!cmd.opt('f') && !cmd.opt('F')){
			interact();
			return;
		}

//----------------------------------------------------------------------
// If -f specified, process the file.
//----------------------------------------------------------------------
		if (cmd.opt('f')){
			test(cmd.optArg('f'));
			return;
		}

//----------------------------------------------------------------------
// If -F specified, process files from the list.
//----------------------------------------------------------------------
		var listName = cmd.optArg("F");
		if (listName == null) return;
		
		s = AP.open(listName);

		if (s == null){
			AP.errNoFile(listName);
			return;
		}

		var files = new Array<String>();
		var a = s.split("\n");

		for (it in a) if (it != "")files.push(it);
		
		if (files.length == 0){
			Sys.println("No files to test.");
			return;
		}

//---------------------------------------------------------------
// If -C specified, open the CSV file and write header.
//---------------------------------------------------------------
		if (parser.kind != "test") csv = false;
		
		if (csv){
			_csv = "name,size,";
			csvFile = cmd.optArg('C');
			if (timing)	_csv += "time,";
			_csv += "calls,ok,fail,back,resc,reuse,totbk,maxbk\n";

		}

//---------------------------------------------------------------
// Process the files.
//---------------------------------------------------------------
		failed = 0;
		var t0 = AP.now();

		for (name in files)	if (!test(name)) failed++;

		time = AP.now() - t0;

//---------------------------------------------------------------
// Write number of processed / failed files.
//---------------------------------------------------------------
		Sys.println("\nTried " + files.length + " files.");
		if (failed == 0) Sys.println("All successfully parsed.");
		else Sys.println(failed + " failed.");

//---------------------------------------------------------------
// Write total time if requested.
//---------------------------------------------------------------
		if (timing) Sys.println("Total time " + time + " s.");

//---------------------------------------------------------------
// Close the CSV file.
//---------------------------------------------------------------
		if (csv) AP.save(csvFile, _csv);
	}


//----------------------------------------------------------------------
// Run parser on file 'name'
//----------------------------------------------------------------------

	function test(name:String)
	{
		var s = AP.open(name); 
		if (s == null){
			AP.errNoFile(name);
			return false;
		}
		var src = new Source(s);
		var size = src.end();

		Sys.println("Source : " + name + " [" + size + " bytes]");

		var t0 = AP.now();

		parsed = parser.parse(src);

		time = AP.now() - t0;

		s = "Result : ";
		if (parsed){
			if (timing)Sys.println("Time   : " + AP.rpad(time,6) + " s.");
			Sys.println(s + "Ok!\n");
			if (parser.kind == "test"){
				compTotals();

				if (csv) csvTotals(name,size); else writeTotals();

				if (details){
					if (csv) csvDetails(allDetails);
					else writeDetails(src,allDetails);
				}
			}
		}else{
			Sys.println(s + "failed.");
			return false;
		}

		return true;
	 }// test()


//----------------------------------------------------------------------
// Run test interactively
//----------------------------------------------------------------------

	function interact()
	{
		var input = "";
		var s:String;
		
		while (true){
			Sys.print("> ");
			try  input = Sys.stdin().readLine()
			catch (e:Dynamic){
				trace(e);
				return;
			}
			if (input.length == 0) return;

			var src = new Source(input);

			parsed = parser.parse(src);

			s = "Result: ";
			if (parsed){
				Sys.println(s + "Ok!");
				if (parser.kind == "test"){
					compTotals();
					Sys.println("");
					writeTotals();
				}
			}else{
				Sys.println(s + "failed.");
			}

			Sys.println("");
			}
		return;
	}


//----------------------------------------------------------------------
// Compute totals
//----------------------------------------------------------------------

	function compTotals()
	{
		calls = 0;
		succ= 0;
		fail= 0;
		back= 0;
		reuse = 0;
		rescan= 0;
		totback = 0;
		maxback = 0;

		for (s in cacheList){
			calls += s.calls;
			succ+= s.succ;
			fail+= s.fail;
			back+= s.back;
			reuse += s.reuse;
			rescan+= s.rescan;
			totback += s.totback;
			if (s.maxback > maxback) maxback = s.maxback;
		}
	}


//----------------------------------------------------------------------
// Write totals to System.out
//----------------------------------------------------------------------

	function writeTotals()
	{
		Sys.println('$calls calls: $succ ok, $fail failed, $back backtracked.');
		Sys.print('$rescan rescanned');
		
		if (reuse == 0) Sys.println(".\n");
		else Sys.println(', $reuse reused.');
		
		var average = totback/back;
		if (back > 0) Sys.println('backtrack length: max $maxback, average ' + AP.rpad(average,4));
	}


//----------------------------------------------------------------------
// Write totals to CSV file
//----------------------------------------------------------------------

	function csvTotals(name:String, size:Int)
	{
		_csv += '"$name",$size,';
		if (timing) _csv += '${AP.lpad(time+"",6)},';
		_csv += '$calls,$succ,$fail,$back,$rescan,$reuse,$totback,$maxback\n';

	}


//----------------------------------------------------------------------
// Write details to System.out
//----------------------------------------------------------------------

	function writeDetails( src:Source,  all:Bool)
	{
		var desc = "";
		if (!all) Sys.println("\nBacktracking, rescan, reuse:");
		Sys.println("procedure     ok    fail  back  resc  reuse totbk maxbk at");
		Sys.println("------------- ----- ----- ----- ----- ----- ----- ----- --");
		for (s in cacheList){
			if (all || (s.back != 0) || (s.reuse != 0) || (s.rescan != 0)){
				desc = Convert.toPrint(s.name);
				if (desc.length>13) desc = desc.substring(0,11) + "..";
				else desc = AP.rpad(desc,13);
				Sys.print(desc + " " + AP.lpad(s.succ,5) + " " +
					AP.lpad(s.fail,5)+ " " +AP.lpad(s.back,5)+ " " +AP.lpad(s.rescan,5) +
					" " + AP.lpad(s.reuse,5) + " ");
				if (s.back==0) Sys.println("    0     0");
				else Sys.println(AP.lpad(s.totback,5)+" "+ AP.lpad(s.maxback,5) + 
					" " + src.where(s.maxbpos));
			}
		}
	}


//----------------------------------------------------------------------
// Write details to CSV file
//----------------------------------------------------------------------
	function csvDetails(all:Bool)
	{
		for (s in cacheList){
			if (all || (s.back != 0) || (s.reuse != 0) || (s.rescan != 0)){
				_csv += '"' + Convert.toPrint(s.name).replace('"','""') + '",';
				if (timing) _csv += '"",';
				_csv += '${s.calls},${s.succ},${s.fail},${s.back},${s.rescan},${s.reuse},${s.totback},${s.maxback}\n';
			}
		} 
	}

	public static function main()
	{
		var p = new TestParser();
		p.run();
	}	
}
