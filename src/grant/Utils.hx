package grant;

class Utils 
{
	
	public static function linearSearch(searchArray:Array<Dynamic>, key:Dynamic):Int
	{
		
		if (searchArray != null) 
		{
			var len = searchArray.length;
			
			for (i in 0...len)
			{
				if (searchArray[i] == key)
					return i;
			}
		}
		
		return -1;
	}

	public static function maxIndex(array:Array<Int>):Int
	{
		var max:Int;
		var index:Int;
		var counter:Int;

		max = array[0];
		index = 0;
		counter = 0;

		for (num in array)
		{
			if(num > max)
			{
				max = num;
				index = counter;
			}
			counter++;
		}

		return index;
	}

	public static function stripSpaces(str:String):String
	{

		var tempStr = "";

		var len = str.length;

		for (i in 0...len)
		{
			if(StringTools.isSpace(str, i) == false)
				tempStr += str.charAt(i);
		}

		return tempStr;
	}

	public static function isLetter(char:String):Bool
	{
		if(char.length > 1)
			return false;
		
		var code = char.toLowerCase().charCodeAt(0);
		
		if( code > 96 && code < 123)
			return true;

		return false;
	}
	public static function isDigit(char:String):Bool
	{
		if(char.length > 1)
			return false;
		
		var code = char.toLowerCase().charCodeAt(0);
		
		if( code > 47 && code < 58)
			return true;

		return false;
	}
	public static function isLetterOrDigit(char:String):Bool
	{
		return (isLetter(char) || isDigit(char));
	}
	
}