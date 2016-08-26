package ;

#if flash
import flash.display.*;
import flash.events.*;
import flash.Lib;
#end

import ParserBase.Source;
import ParserBase.Cache;


@:dce
#if flash
class App extends Sprite{
#else
class App{
#end	
	public function new()
	{ 
#if flash
		super();
		addEventListener (Event.ADDED_TO_STAGE, addedToStage);
		Lib.current.addChild (this);
#else
#end		
	}
	
	public function run()
	{
		var name = "script.hxs";
		var s = haxe.Resource.getString(name);
		if (s == null) return;
		var src = new Source(s);

		var s = "\nSource : " + name + " [" + src.end() + " bytes]";

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
#if !flash		
		p.run();
#end		
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

#if flash
	function addedToStage(e:Event) 
	{
		stage.align = StageAlign.TOP_LEFT;
		stage.scaleMode = StageScaleMode.NO_SCALE;

		addEventListener(Event.ENTER_FRAME, onEnterFrame);
		stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);   
		stage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp); 

		trace("Press any key to run the Parser.");
	}// addedToStage()
	
	function onEnterFrame(e:Event) { }

	function onKeyUp(e:KeyboardEvent){ 	}

	function onKeyDown(e:KeyboardEvent)
	{	 
		run();
	}

#end	
}
