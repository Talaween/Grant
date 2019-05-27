import Grant.Policy;

/**
 * ...
 * @author Mahmoud Awad
 */

 class Permission 
 {

     //read only properties 
    public var granted(default, null):Bool;
    public var policy(default, null):Policy;
    public var role(default, null):String;
    public var resource(default, null):String;

    @:isVar private var message(get, set):String;
   
    public function new(granted:Bool, role:String, resource:String, policy:Policy){
        
        this.granted = granted;
        this.role = role;
        this.policy = policy;
        this.resource = resource.toLowerCase();
        this.policy.fields = checkFields(this.policy.fields);

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

    public function filter(resource:Dynamic):Dynamic
    {
        var fields = policy.fields.split(",");

        var  len = fields.length;

        if(fields[0] == "*")
        {
            if(len == 1)
                return resource;
            else
            {
                var field:String;
                for(i in 1...len)
                {
                    field = fields[i].substr(1);
                    Reflect.deleteField(resource, field);
                }
                return resource;
            }
        }
        else
        {
            var resourceCopy = {};

            for(i in 0...len)
            {
                Reflect.setField(resourceCopy, fields[i], Reflect.field(resource, fields[i]));
            }

            return resourceCopy;
        }
    }

    public function getFields():Array<String>
    {
        return policy.fields.split(",");
    }
     
 }