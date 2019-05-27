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

	public static function stripSpaces(str:String):String
	{

		var tempStr = "";

		var len = str.length;

		for (i in 0...len)
		{
			if(StringTools.isSpace(str, i) == false)
			{
				tempStr += str.charAt(i);
			}
		}

		return tempStr;
	}
	
}