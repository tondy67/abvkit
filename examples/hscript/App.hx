package ;

import ParserBase.Source;
import ParserBase.Cache;


@:dce
class App{
	
	public function new(){ }
	
	public function run()
	{
		var name = "script.hxs";
		var s = haxe.Resource.getString(name);
		if (s == null) return;
		var src = new Source(s);

		var s = "Source : " + name + " [" + src.end() + " bytes]";

		var t0 = haxe.Timer.stamp();
//		Cache.size = 3;
		var parser = new HscriptParser();
		var parsed = parser.parse(src);
		var time = haxe.Timer.stamp() - t0;
		
		s += "\nGrammar: " + parser.grammar;
		s += "\nParser : " + parser.kind;
		if (parser.kind != "norm") s += " [" + Cache.size + "]";
		s += "\nTime   : " + Std.string(time).substr(0,5);
		s += "\nResult : ";
		s += parsed ? "Ok!" : "failed.";
		println(s);
	};

	public static function main()
	{
		var p = new App();
		p.run();
	}	

	function println(s:String)
	{
#if flash
		trace(s);
#elseif js
		if (js.Browser.supported)js.Browser.alert(s);else trace(s); 
#else 
		Sys.println(s); 
#end		
	}
	
}
