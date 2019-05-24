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
	
}