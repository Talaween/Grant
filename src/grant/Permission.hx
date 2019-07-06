package grant;

import grant.Grant.Policy;
/**
 * ...
 * @author Mahmoud Awad
 */

 class Permission 
 {

     //read only properties 
    public var granted(default, null):Bool;
    public var policy(default, null):Policy;
    
    public var message:String;
    public var role:String;
    public var resource:String;

    private var policies:Array<Policy>;
    private var currentIndex:Int;

    public function new(role:String, resource:String, policies:Array<Policy>, ?message:String)
    {
        this.role = role;
        this.policies = policies;
        this.resource = resource;
        this.message = message;

        currentIndex =  0;

        if(policies != null && policies.length > 0)
        {
            this.policy = policies[currentIndex];
            this.granted = true;
        } 
        else
        {
            this.granted = false;
        }
    }
    
    function get_granted(){

        return this.granted;
    }

    function get_policy(){

        return this.policy;
    }
    
    public function nextPolicy():Bool
    {
        currentIndex++;
        if(currentIndex < policies.length)
        {
            this.policy = policies[currentIndex];
            return true;
        }

        return false;
    }
    public function filter(user:Dynamic, resource:Dynamic):Dynamic
    {
        if(this.policy == null)
            return null;
        
        var fields = this.policy.fields.split(",");
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
                if(fields[i].length > 0)
                {
                    if(fields[i].indexOf("^") > 0)
                    {
                        var subs = fields[i].split("^");
                        if(subs.length == 2)
                        {
                            var subObj = Reflect.field(resource, subs[0]);
                            var grant = Grant.getInstance();

                            //currently it does not work if resource has another same resource type
                            //as subobject in order to prevent infinite recursions
                            if(subs[1] != this.resource)
                            {
                                var subPermission = grant.mayAccess(this.role, this.policy.action, subs[1]);

                                trace("subobject permission is:" + subPermission.granted);
                                if(subPermission.granted == true)
                                {
                                    var subObjCopy = grant.access(user, subPermission, subObj);
                                    Reflect.setField(resourceCopy, subs[0], subObjCopy );
                                }
                            } 
                        }
                    }
                    else if(fields[i].charAt(0) != "!")
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
        if(this.policy == null)
            return null;

        var fields = this.policy.fields.split(",");

        var len = fields.length;

        for(i in 0...len)
        {
            if(fields[i].indexOf("^") > -1)
            {
                fields[i] = fields[i].split("^")[0];
            }
        }

        return fields;
    }
     
 }