import Grant.Policy;

/**
 * ...
 * @author Mahmoud Awad
 */

 class Permission 
 {

     //read only properties 
    public var granted(default, null):Bool;
    
    public var policy:Policy;
    public var role:String;
    public var resource:String;

    @:isVar private var message(get, set):String;
   
    public function new(granted:Bool, role:String, resource:String, policy:Policy){
        
        this.granted = granted;
        this.role = role;

        if(resource != null)
            this.resource = resource.toLowerCase();

        if(policy != null)
        {
            this.policy = policy;
            this.policy.fields = checkFields(this.policy.fields);
        }
        
    }
    
    function get_message(){
        return message;
    }
    function set_message(message:String){
        return this.message = message;
    }

    private function checkFields(fields:String):String
    {

        fields = Utils.stripSpaces(fields);

        var fieldsArray = fields.split(",");
        var includedFields = new Array<String>();
        var excludedFields = new Array<String>();
        var finalFields = "";

        for(field in fieldsArray)
        {
            if(field == "*")
            {
                finalFields = "*, " + finalFields;
            }
            else if(field.charAt(0) != '!')
            {
                if(Utils.linearSearch(includedFields, field) == -1)
                {
                    includedFields.push(field);
                    finalFields += field + ",";
                }
            }
            else 
            {
                if(Utils.linearSearch(excludedFields, field) == -1)
                {
                    excludedFields.push(field);
                    finalFields += field + ",";
                }
            }
        }
        
        return finalFields; 
    }  

    public function filter(resource:Dynamic):Dynamic
    {
        var fields = policy.fields.split(",");
        var field:String;

        var  len = fields.length;

        if(fields[0] == "*")
        {
            if(len == 1)
                return resource;
            else
            {
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
                if(fields[i].length > 0){

                    if(fields[i].charAt(0) != "!")
                        Reflect.setField(resourceCopy, fields[i], Reflect.field(resource, fields[i]));
                    else
                    {
                        field = fields[i].substr(1);
                        Reflect.deleteField(resourceCopy, field);
                    }
                }   
            }

            return resourceCopy;
        }
    }

    public function getFields():Array<String>
    {
        return policy.fields.split(",");
    }
     
 }