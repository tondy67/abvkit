abvkit
======

This is a [haxe](http://haxe.org) port of Roman R. Redziejowski [PEG parser generator](http://www.romanredz.se/Mouse/index.htm)

**under development!**

Installation
============
Install the latest version of [Haxe](http://www.haxe.org/download).

	$ haxe build.hxml 
	$ cd build
	$ neko gen -G ../grammars/hscript.peg -P Hscript -M
	$ cd ..
	$ haxe test.hxml
	$ cd build
	$ neko test -t -f script.hxs
	 
