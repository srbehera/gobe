/*

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The Software shall be used for Good, not Evil.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*
* Updated for haxe by ritchie turner
* Copyright (c) 2007 ritchie@blackdog-haxe.com
*
* There are control character things I didn't bother with.
*/


class Json {

	public static function encode(v:Dynamic):String {
		var e = new Encode(v);
		return e.getString();
	}

	public static function decode(v:String):Dynamic	{
		var d = new Decode(v);
		return d.getObject();
	}
}

private class Encode {

	var jsonString:String;

	public function new(value:Dynamic ) {
		jsonString = convertToString( value );
	}

	public function getString():String {
		return jsonString;
	}

	function convertToString(value:Dynamic):String {

		if (Std.is(value,String)) {
			return escapeString(Std.string(value));

		} else if (Std.is(value,Float)) {
			return Math.isFinite(value) ? Std.string(value) : "null";

		} else if (Std.is(value,Bool)) {
			return value ? "true" : "false";

		} else if (Std.is(value,Array)) {
			return arrayToString(value);
			
		} else if (value != null && Reflect.isObject(value)) {
			return objectToString( value );
		}
		
		return "null";
	}

	function escapeString( str:String ):String {
		var s = new StringBuf();
		var ch:String;
		var i = 0;
		while ((ch = str.charAt( i )) != ""){
			switch ( ch ) {
				case '"':	// quotation mark
					s.add('\\"');
				case '/':	// solidus
					s.add("\\/");
				case '\\':	// reverse solidus
					s.add("\\\\");
				case '\\b':	// backspace
					s.add("\\b");
				case '\\f':	// form feed
					s.add("\\f");
				case '\\n':	// newline
					s.add("\\n");
				case '\\r':	// carriage return
					s.add("\\r");
				case '\\t':	// horizontal tab
					s.add("\\t");
				default: // skipped encoding control chars here
					s.add(ch);
			}	
			i++;
		}	// end for loop

		return "\"" + s.toString() + "\"";
	}

	function arrayToString( a:Array<Dynamic> ):String {
		var s:String = "";
		var i:Int= 0;

		while(i < a.length) {
			if ( s.length > 0 ) {
				s += ",";
			}
			s += convertToString( a[i] );
			i++;
		}

		return "[" + s + "]";
	}

	function objectToString( o:Dynamic):String {
		var s:String = "";
		if ( Reflect.isObject(o)) {
			var value:Dynamic;
			for (key in Reflect.fields(o)) {
				value = Reflect.field(o,key);

				if (Reflect.isFunction(value))
					continue;

				if ( s.length > 0 ) {
					s += ",";
				}

				s += escapeString( key ) + ":" + convertToString( value );
			}
		}
		else {
			for(v in Reflect.fields(o)) {
				if ( s.length > 0 ) {
					s += ",";
				}
				s += escapeString(v) + ":" + convertToString( Reflect.field(o,v) );
			}
		}
		return "{" + s + "}";
	}
}

private class Decode {

	var at:Int;
    var ch:String;
	var text:String ;

	var parsedObj:Dynamic;

	public function new(t:String) {
		parsedObj = parse(t);
	}

	public function getObject() {
		return parsedObj;
	}

    public function parse(text:String):Dynamic {
		try {
			at = 0 ;
			ch = '';
			this.text = text ;
			return value();
		} catch (exc:Dynamic) {
		}
		return '{"err":"parse error"}';
	}

	function error(m):Void {
		throw {
			name: 'JSONError',
			message: m,
			at: at - 1,
			text: text
		};
	}

	function next() {
		ch = text.charAt(at);
		at += 1;
		if (ch == '') return ch = '0';
		return ch;
	}

	function white() {
		while (ch != '0') {
			if (ch <= ' ') {
				next();
			} else if (ch == '/') {
				switch (next()) {
					case '/':
						while (ch != '0' && ch != '\n' && ch != '\r') {}
						break;
					case '*':
						next();
						while (true) {
							if (ch != '0') {
								if (ch == '*') {
									if (next() == '/') {
										next();
										break;
									}
								} else {
									next();
								}
							} else {
								error("Unterminated comment");
							}
						}
						break;
					default:
						error("Syntax error");
				}
			} else {
				break;
			}
		}
	}

	function str():String {
		var i, s = '', t, u;
		var outer:Bool = false;

		if (ch == '"') {
			while (next() != '') {
				if (ch == '"') {
					next();
					return s;
				} else if (ch == '\\') {
					switch (next()) {


				/*	case 'b':
						s += "\\b";
						break;
						
					case 'f':
						s += '\f';
						break;
*/
					case 'n':
						s += '\n';
						break;
					case 'r':
						s += '\r';
						break;
					case 't':
						s += '\t';
						break;

					case 'u':			// unicode
						u = 0;
						for (i in 0...4) {
							t = Std.parseInt(next());
							if (!Math.isFinite(t)) {
								outer = true;
								break;
							}
							u = u * 16 + t;
						}
						if(outer) {
							outer = false;
							break;
						}
						s += String.fromCharCode(u);
						break;
					default:
						s += ch;
					}
				} else {
					s += ch;
				}
			}
		} else {
			error("ok this should be a quote");
		}
		error("Bad string");
		return s;
	}

     function arr() {
		var a = [];

		if (ch == '[') {
			next();
			white();
			if (ch == ']') {
				next();
				return a;
			}
			while (ch != '0') {
			    a.push(value());
				white();
				if (ch == ']') {
					next();
					return a;
				} else if (ch != ',') {
					break;
				}
				next();
				white();
			}
		}
		error("Bad array");
		return []; // never get here
	}

    function obj() {
		var k, o = {};

		if (ch == '{') {
			next();
			white();
			if (ch == '}') {
				next();
				return o;
			}
			while (ch != '0') {
				k = str();
				white();
				if (ch != ':') {
					break;
				}
				next();
				Reflect.setField(o,k,value());
				white();
				if (ch == '}') {
					next();
					return o;
				} else if (ch != ',') {
					break;
				}
				next();
				white();
			}
		}
		error("Bad object");
		return o;
	}

     function num() {
		var n = '', v;

		if (ch == '-') {
			n = '-';
			next();
		}
		while (ch >= '0' && ch <= '9') {
			n += ch;
			next();
		}
		if (ch == '.') {
			n += '.';
			next();
			while (ch >= '0' && ch <= '9') {
				n += ch;
				next();
			}
		}
		if (ch == 'e' || ch == 'E') {
			n += ch;
			next();
			if (ch == '-' || ch == '+') {
				n += ch;
				next();
			}
			while (ch >= '0' && ch <= '9') {
				n += ch;
				next();
			}
		}
		v = Std.parseFloat(n);
		if (!Math.isFinite(v)) {
			error("Bad number");
		}
		return v;
	}

     function word():Null<Bool> {
		switch (ch) {
			case 't':
				if (next() == 'r' && next() == 'u' &&
						next() == 'e') {
					next();
					return true;
				}
			case 'f':
				if (next() == 'a' && next() == 'l' &&
						next() == 's' && next() == 'e') {
					next();
					return false;
				}
			case 'n':
				if (next() == 'u' && next() == 'l' &&
						next() == 'l') {
					next();
					return null;
				}
		}
		error("Syntax error");
		return false; // never get here
	}

    function value():Dynamic {
		white();
		switch (ch) {
			case '{':
				return obj();
			case '[':
				return arr();
			case '"':
				return str();
			case '-':
				return num();
			default:
				if (ch >= '0' && ch <= '9'){
						return num();
				}else {
					return word();
				}
		}
	}
}

