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
/**
 * abvkit tools
 **/
import sys.io.File;
import sys.FileSystem;
import haxe.io.Path;

using StringTools;

@:dce 
class AP{

	public static inline function clear<T>(a:Array<T>)
	{
#if flash 
		untyped a.length = 0; 
#else 	
		a.splice(0,a.length); 
#end
    }// clear<T>()
	
	public static inline function add<T>(a:Array<T>,v:T)
	{   
		var r = false; 
		if ((v != null) && !exists(a,v)){
			a.push(v);
			r = true;
		} 
		return r;
	}// add<T>()

	public static inline function exists<T>(a:Array<T>,v:T)
	{
		return a.indexOf(v) == -1 ? false:true;
	}
	   
	public static inline function rpad(d:Dynamic, len:Int, c=" ")
	{
		var s = Std.string(d).substr(0,len);
		return s.rpad(c,len);
	}

	public static inline function lpad(d:Dynamic, len:Int, c=" ")
	{
		var s = Std.string(d).substr(0,len);
		return s.lpad(c,len);
	}

	public static inline function now()
	{
		return haxe.Timer.stamp();
	}

	public static inline function timezone()
	{
		var ms = 3600000;
		var now = Date.now();
		var y = now.getFullYear();
		var m = now.getMonth();
		var d = now.getDate();
		var n = new Date(y, m, d, 0, 0, 0 );
		var t =  n.getTime(); 
		return Std.int(24 * Math.ceil(t / 24 / ms ) - t/  ms);  
	}// timezone();

	public static inline function utc()
	{
		var time = Date.now().getTime();
		var n = Date.fromTime(time - timezone() * 3600000); 
		return new Date(n.getFullYear(),n.getMonth(),n.getDate(),
			n.getHours(),n.getMinutes(),n.getSeconds());
	}// utc()

	public static inline function utc2ver()
	{
		var r = 0.1;
		var t = Std.string(utc()).replace("-","").replace(":","").replace(" ",".");
		try r = Std.parseFloat(t) catch(e:Dynamic){}
		return r;
	}// utc2ver()

	public static inline function open(path:String)
	{
		var r:String = null;
		try r = File.getContent(path) catch(e:Dynamic){trace(e);}
		return r;
	}// open()

	public static inline function save(path:String, content:String)
	{
		var r = true;
		var dir = dirname(path);
		if ((dir != "") && !FileSystem.exists(dir)) FileSystem.createDirectory(dir);
		try File.saveContent(path, content)
		catch(e:Dynamic){ 
			trace(e); 
			r = false;
		}
		return r;
	}// save()

	public static inline function isFile(path:String)
	{
		var r = false;
		if ((path != null) && FileSystem.exists(path) &&
			!FileSystem.isDirectory(path)) r = true;
		return r;
	}// isFile()

	public static inline function fullPath(path:String)
	{
		return FileSystem.fullPath(path);
	}// fullPath()

	public static inline function addSlash(path:String)
	{
		return Path.addTrailingSlash(path);
	}// addSlash()

	public static inline function basename(path:String)
	{
		return Path.withoutDirectory(path);
	}// basename()

	public static inline function dirname(path:String)
	{
		return Path.directory(path);
	}// dirname()

	public static inline function print(s:String)
	{
		Sys.print(s);
	}
	
	public static inline function println(s:String)
	{
		print(s + "\n");
	}

	public static inline function errNoFile(path:String)
	{
		println("Error: No such file [" + path + "]");
	}
	
}// AP

