import Grant.Policy;

/**
 * ...
 * @author Mahmoud Awad
 */

 class Permission {

     //read only properties 
    public var granted(default, null):Bool;
    public var policy(default, null):Policy;
    public var role(default, null):String;

    @:isVar private var message(get, set):String;

    private var fields:String;
   
    public function new(granted:Bool,role:String, policy:Policy){
        this.granted = granted;
        this.role = role;
        this.policy = policy;
        this.fields = checkFields(fields);
    }
    
    function get_message(){
        return message;
    }
    function set_message(message:String){
        return this.message = message;
    }

    private function checkFields(fields:String):String
    {

        var fieldsArray = fields.split(",");
        var includedFields = new Array<String>();
        var excludedFields = new Array<String>();
        var allFieldsUsed = false;

        for(field in fieldsArray)
        {
            field = StringTools.trim(field);
            if(field == "*")
            {
                allFieldsUsed = true;
            }
            else if(field.charAt(0) != '!')
            {
                if(Utils.linearSearch(includedFields, field) == -1)
                {
                    includedFields.push(field);
                }
            }
            else 
            {
                if(Utils.linearSearch(excludedFields, field) == -1)
                {
                    includedFields.push(field);
                }
            }
        }
        
        var finalFields = "";

        if(allFieldsUsed)
            finalFields = "*" + "," + Std.string(excludedFields);
        else
            finalFields = Std.string(includedFields);

       return finalFields; 
    }  

    public function filter(resource:Dynamic):Dynamic{

        //create a new object 
        var tempResource:Dynamic = {};

        tempResource.x = 0;

        return tempResource;
    }
     
 }