
package abv.peg;

class Action {
	public var name:String;
	public var and:Bool;
	public var asString(get,never):String;
	function get_asString()
	{
		return "{" + (and? "&" : "") + name + "}"; 
	}

	public function new(name:String, and:Bool,?p:haxe.PosInfos)
	{
		this.name = name; //trace(name,p.fileName,p.lineNumber);
		this.and = and;
	}

}

