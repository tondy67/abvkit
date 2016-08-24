
package abv.peg;


//----------------------------------------------------------------------
//
// An object-oriented counterpart of C procedure 'getopt'.
// 
// An object of class CommandArgs represents the argument list supplied
// as the 'argv' parameter to 'main'. It is constructed by parsing
// the argument list according to instructions supplied as arguments
// to the constructor. The options and arguments can be then obtained
// by invoking methods on the object thus constructed.
// The argument list is supposed to follow POSIX conventions
// (IEEE Standard 1003.1, 2004 Edition, Chapter 12).
//
//----------------------------------------------------------------------

class CommandArgs{
//----------------------------------------------------------------------
// Option letters in order of appearance.
// Note that options with argument may have multiple occurrences.
//----------------------------------------------------------------------
	var letters:String;

//----------------------------------------------------------------------
// Arguments specified with letters.
// Null for argument-less options.
//----------------------------------------------------------------------
	var _optArgs = new Array<String>();

//----------------------------------------------------------------------
// Positional arguments.
//----------------------------------------------------------------------
	public var args = new Array<String>();

//----------------------------------------------------------------------
// Error count.
//----------------------------------------------------------------------
	var errors = 0;

//----------------------------------------------------------------------
// Construct CommandArgs object from an argument list 'argv'.
//
// @paramargv Argument list, as passed to the program.
// @paramoptions String consisting of option letters for options without argument.
// @paramoptionsWithArg String consisting of option letters for options with argument.
// @paramminargs Minimum number of arguments.
// @parammaxargs Maximum number of arguments.
//
//----------------------------------------------------------------------
	public function new(argv:Array<String>, options:String, 
		optionsWithArg:String, minargs:Int, maxargs:Int)
	{
		var i = 0;
		var opts = new StringBuf();

//----------------------------------------------------------------------
// Examine elements of argv as long as they specify options.
//----------------------------------------------------------------------
		while(i < argv.length){
			var elem = argv[i];

//----------------------------------------------------------------------
// Any element that does not start with '-' terminates options
//----------------------------------------------------------------------
			if ((elem == "")|| (elem.charAt(0) != '-')) break;

//----------------------------------------------------------------------
// A single '-' is a positional argument and terminates options.
//----------------------------------------------------------------------
			if (elem == "-"){
				args.push("-");
				i++;
				break;
			}

//----------------------------------------------------------------------
// A '--' is not an argument and terminates options.
//----------------------------------------------------------------------
			if (elem == "--") {
				i++;
				break;
			}

//----------------------------------------------------------------------
// An option found - get option letter.
//----------------------------------------------------------------------
			var c = elem.substring(1,2);

			if (optionsWithArg.indexOf(c) >= 0){
//----------------------------------------------------------------------
// Option with argument
//----------------------------------------------------------------------
				opts.add(c);
				if (elem.length > 2){
// option's argument in the same element
					_optArgs.push(elem.substring(2,elem.length));
					i++;
				}else{
// option's argument in next element
					i++;
					if ((i<argv.length) && ((argv[i].length ==0) || 
						(argv[i].charAt(0) != '-'))){
						_optArgs.push(argv[i]);
						i++;
					}else{
						Sys.println("Missing argument of option -" + c + ".");
						_optArgs.push(null);
						errors++;
					}
				}
			}else {
//----------------------------------------------------------------------
// Option without argument or invalid.
// The element may specify more options.
//----------------------------------------------------------------------
				for (n in 1...elem.length){
					c = elem.substring(n,n+1);
					if (options.indexOf(c) >= 0){
						opts.add(c);
						_optArgs.push(null);
					}else{
						Sys.println("Unrecognized option -" + c + ".");
						errors++;
						break;
					}
				}
				i++;
			}
		}

		letters = opts.toString();

//----------------------------------------------------------------------
// The remaining elements of argv are positional arguments.
//----------------------------------------------------------------------
		while(i<argv.length){
			args.push(argv[i]);
			i++;
		}

		if (nArgs() < minargs){
			Sys.println("Missing argument(s).");
			errors++;
		}

		if (nArgs() > maxargs){
			Sys.println("Too many arguments.");
			errors++;
		}
	}

//----------------------------------------------------------------------
// Access to options
// Checks if a given option was specified.
//
// @paramc Option letter.
// @return true if the option is specified, false otherwise.
//----------------------------------------------------------------------
	public function opt(c:String)
	{ 
		return letters.indexOf(c) >= 0; 
	}

//----------------------------------------------------------------------
//Gets argument of a given option.
//Returns null if the option is not specified or does not have argument.
//If option was specified several times, returns the first occurrence.
//
//@paramc Option letter.
//@return value of the i-th option.
//----------------------------------------------------------------------
	public function optArg(c:String)
	{
		var i = letters.indexOf(c);
		return i < 0 ? null : _optArgs[i];
	}

//----------------------------------------------------------------------
// Gets arguments of a given option.
// Returns a vector of arguments for an option specified repeatedly-
// Returns empty vector if the option is not specified or does not have argument.
//
// @paramc Option letter.
// @return value of the i-th option.
//----------------------------------------------------------------------
	public function optArgs(c:String)
	{
	var result = new Array<String>();
	for (i in 0...letters.length)
	if (letters.charAt(i)==c)
	result.push(_optArgs[i]);
	return result;
	}

//----------------------------------------------------------------------
// Access to positional arguments
// Gets the number of arguments in the argument list.
//
// @return Number of arguments.
//----------------------------------------------------------------------
	public function nArgs()
	{ 
		return args.length; 
	}

//----------------------------------------------------------------------
// Gets the i-th argument.
//
// @parami Argument number i.
// @return the i-th argument.
//----------------------------------------------------------------------
	public function arg(i:Int)
	{ 
		return args[i]; 
	}

//----------------------------------------------------------------------
// Error count
// Gets number of errors detected when parsing the argument list.
//
// @return Number of errors.
//----------------------------------------------------------------------
	public function nErrors()
	{ 
		return errors; 
	}
}
