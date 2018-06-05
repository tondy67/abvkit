[https://gitlab.com/tondy67](https://gitlab.com/tondy67)

abvkit
======

This is a [haxe](http://haxe.org) port of Roman R. Redziejowski [PEG parser generator](http://www.romanredz.se/Mouse/index.htm)

**Under development!**

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
	$ cd ../examples/hscript
	$ haxe app.hxml
	

Information
===========
[Parsing_expression_grammar](https://en.wikipedia.org/wiki/Parsing_expression_grammar)

[packrat](http://bford.info/packrat/)

[Excellent manual](http://mousepeg.sourceforge.net/Manual.pdf)

```
//**********************
// Comments by 
//-----------------
// Roman R. Redziejowski
//**********************

/*
 * Comments by me (tondy)
 */
```	 
License
=======
Apache License, Version 2.0
