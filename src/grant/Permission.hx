package grant;

import sys.db.Connection;
import grant.Grant.Policy;
import grant.Grant;

/**
 * ...
 * @author Mahmoud Awad
 */

@:final
@:allow(grant.Grant)
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

    private function new(role:String, resource:String, policies:Array<Policy>, ?message:String)
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
            this.granted = false;
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
    public function filter(user:Dynamic, resource:Dynamic, connection:Connection):Dynamic
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
                    fields[i] = StringTools.trim(fields[i]);
                    field = fields[i].substr(1);
                    Reflect.deleteField(resource, field);
                }
                return resource;
            }
        }
        else
        {
            var resourceCopy:Dynamic = {};

            for(i in 0...len)
            {
                fields[i] = StringTools.trim(fields[i]);

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

                                if(subPermission.granted == true)
                                {
                                    var subObjCopy = grant.access(user, subPermission, subObj, connection);
                                    Reflect.setField(resourceCopy, subs[0], subObjCopy );
                                }
                            } 
                        }
                    }
                    //else if(fields[i].charAt(0) != "!")
                      //  Reflect.setField(resourceCopy, fields[i], Reflect.field(resource, fields[i]));
                    else
                    {
                        //field = fields[i].substr(1);
                        Reflect.setField(resourceCopy, fields[i], Reflect.field(resource, fields[i]));
                        
                    }
                }   
            }

            return resourceCopy;
        }
    }

    public function fields():Array<String>
    {
        if(this.policy == null)
            return null;

        var tmp_fields = this.policy.fields.split(",");

        var len = tmp_fields.length;

        for(i in 0...len)
        {
            if(tmp_fields[i].indexOf("^") > -1)
                tmp_fields[i] = tmp_fields[i].split("^")[0];
        }

        return tmp_fields;
    }
     
 }