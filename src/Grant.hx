
/**
 * ...
 * @author Mahmoud Awad
 * 
 * Allow more than one user role
 * allow dynamic user roles creation from outide DB
 * 
 */

import sys.db.Connection;

typedef Condition = {resource1:String, field1:String, operator:String, resource2:String, field2:String}; 
typedef Conditions = {list:Array<Condition>, operators:Array<String>};
typedef Limit = {amount:Int, rule:String, ?conditions:Conditions};
typedef Policy = {action:String, records:String, fields:String, limit:Limit, ?conditions:Conditions};   
typedef Resource = {resource:String, policies:Array<Policy>};
typedef Role = {role:String, ?inherits:String, grant:Array<Resource>};  
typedef Schema = {accesscontrol:Array<Role>};

class Grant 
{
    private static var _instance:Grant;
    private var connection:Connection;
    private var schema:Schema;

    public static function getInstance():Grant
    {
        if (_instance == null)
            _instance = new Grant();

        return _instance;
    }
    
    private function new()
    {

    }
    
    public function buildPolicy(schema:String)
    {
        this.schema = PolicyBuilder.build(schema);
    }
    
    public function mayAccess(role:String, action:String, resourceName:String, any:Bool = false):Permission
    {

        if(schema == null || schema.accesscontrol == null){
            return new Permission(false, role, resourceName, null);
        }
        
        //find the role in the schema
        var _thisRole:Role = null;
        var _inherited:Role = null;

        for(_r in schema.accesscontrol)
        {
            if(_r.role == role)
            {
                _thisRole = _r;
                break;
            }
        }

        //if the role inherits from another role find it
        if(_thisRole.inherits != null && _thisRole.inherits != "")
        {
            for(_rInh in schema.accesscontrol)
            {
                if(_rInh.role == _thisRole.inherits)
                {
                    _inherited = _rInh;
                    break;
                }
            }
        }
        
        //if we finish loop but could not find the role
        if(_thisRole == null){
            return  new Permission(false, role, resourceName, null);
        }
            
        //find all policies on this resource for this role and its inheritied  
        var _policies = new Array<Policy>();
        
        //priority to add new policies before the ones which are inherited as they extend the inherited role
        for(_res in _thisRole.grant)
        {
            if(_res.resource == resourceName)
            {
                for (_pol in _res.policies)
                {
                    if(_pol.action == action)
                    { 
                        _policies.push(_pol);
                    }
                }
            }    
        }
        if(_inherited != null)
        {
            for(_resInh in _inherited.grant)
            {
                if(_resInh.resource == resourceName)
                {
                    for (_polInh in _resInh.policies)
                    {
                        if(_polInh.action == action)
                        { 
                            _policies.push(_polInh);
                        }
                    }
                }    
            }
        }
        
        if(_policies.length == 0)
            return new Permission(false, role, resourceName, null);
        
        if(any)
        {            
            for(_policy in _policies)
            {
                if(_policy.records.toLowerCase() == "any")
                {
                    var p =  new Permission(true, role, resourceName, _policies);
                    p.activePolicy = _policy;
                    return p;
                }     
            }
            //if any flag is requested but we did not any policy supports any
            return new Permission(false, role, resourceName, null);
        }

        for(_policy in _policies)
        {
            if(_policy.limit.amount != 0)
                return new Permission(true, role, resourceName, _policies);
        }
        
        return new Permission(false, role, resourceName, null);
    }

    public function access(user:Dynamic, permission:Permission, resource:Dynamic):Dynamic
    {  
        if(permission == null || permission.allPolicies == null || user == null)
        {
            trace(permission.granted);
             return null;
        }
        
        if(user.role == null)
            throw ('user object has no role property');
        
        if(user.role != permission.role)
            return null;

        var allow = false;

        if(permission.activePolicy == null)
        {
            //try all policies until we find a policy allow access to the record
            for(policy in permission.allPolicies)
            {
                permission.activePolicy = policy;
                allow = checkRecord(user, permission, resource);
                if(allow)
                {
                    //we found a policy that allow access to the record
                    break;
                }
            }
        }
        else
            allow = checkRecord(user, permission, resource);
        
        if(allow)
        {
             allow = checkLimit (user, permission, resource);
             if(allow)
             {
                 return permission.filter(user, resource);
             }
        }
           
        return null;
    }

    private function checkRecord(user:Dynamic, permission:Permission, resource:Dynamic):Bool
    {
        if(permission == null || permission.activePolicy.records.toLowerCase() == "none")
        {
            return false;
        }  
        else if(permission.activePolicy.records.toLowerCase() == "any")
        {
            return true;
        }
        else 
        {            
            return (runConditions(user, permission, resource) > 0 ? true : false);
        }
    }

    private function runConditions(user:Dynamic, permission:Permission, resource:Dynamic, ?checkLimit:Bool):Int
    {
        //TODO currently we are ignoring grouping conditions with ( )
        var finalEval = -1;
        var sql = "";
        var counter = 0;

        for(cond in permission.activePolicy.conditions.list)
        {
            if( cond.resource1.toLowerCase() == 'user'  && cond.resource2 == permission.resource )
            {
                if(checkLimit)
                {
                    var resourcePart = Reflect.field(resource, cond.field2);
                    
                    if(resourcePart == null)
                        throw "record expression is wrong, " + cond.resource2 + " is not part of " + permission.resource + " class";

                    var sql = "SELECT count(*) FROM " + cond.resource1 + " WHERE " + cond.field1 + " = " + resourcePart;

                }
                else if(cond.field1 != '' && cond.field2 != '')
                {
                    var part1 = Reflect.field(user, cond.field1);
                    var part2 = Reflect.field(resource, cond.field2);
                    
                    if(part1 == null)
                        throw "record expression is wrong, " + cond.field1 + " is not part of user class";

                    if(part2 == null)
                        throw "record expression is wrong, " + cond.field2 + " is not part of " + permission.resource + " class";
                    
                    finalEval = (part1 == part2 ? 1:0);
                }
            }
            else if( cond.resource2.toLowerCase() == 'user'  && cond.resource1 == permission.resource )
            {
                if(checkLimit)
                {
                    var userPart = Reflect.field(user, cond.field2);
                    
                    if(userPart == null)
                        throw "record expression is wrong, " + cond.field2 + " is not part of user class";

                    var sql = "SELECT count(*) FROM " + cond.resource1 + " WHERE " + cond.field1 + " = " + userPart;

                }
                else if(cond.field1 != '' && cond.field2 != '')
                {
                    var part1 = Reflect.field(user, cond.field2);
                    var part2 = Reflect.field(resource, cond.field1);
                    
                    if(part1 == null)
                        throw "record expression is wrong, " + cond.field2 + " is not part of user class";

                    if(part2 == null)
                        throw "record expression is wrong, " + cond.field1 + " is not part of " + permission.resource + " class";
                    
                    finalEval = (part1 == part2 ? 1:0);
                }
            }
            else if(cond.resource2.toLowerCase() == 'user' && cond.resource1 != permission.resource)
            {
                var part2 = Reflect.field(user, cond.field2);

                 if(part2 == null)
                    throw "record expression is wrong, " + cond.field2 + " is not part of user class";

                if(sql == "")
                    sql = "SELECT count(*) FROM " + cond.resource1 + " WHERE " + cond.field1 + " = " + part2;
                else
                {
                    switch (cond.operator)
                    {
                        case "&": sql += " AND " + cond.resource1 + " WHERE " + cond.field1 + " = " + part2;
                        case "":  sql += " OR " + cond.resource1 + " WHERE " + cond.field1 + " = " + part2;
                    }
                }

            }
            else if(cond.resource2 == permission.resource  && cond.resource1.toLowerCase() != 'user')
            {
                var part2 = Reflect.field(resource, cond.field2);

                 if(part2 == null)
                    throw "record expression is wrong, " + cond.field2 + " is not part of " + permission.resource;

                if(sql == "")
                    sql = "SELECT count(*) FROM " + cond.resource1 + " WHERE " + cond.field1 + " = " + part2;
                else
                {
                    switch (cond.operator)
                    {
                        case "&": sql += " AND " + cond.resource1 + " WHERE " + cond.field1 + " = " + part2;
                        case "":  sql += " OR " + cond.resource1 + " WHERE " + cond.field1 + " = " + part2;
                    }
                }
            }
            else
            {
                throw "wrong expression in the condition";
            }

            counter++;
           
        }//end for

        if(finalEval != -1 && sql != "")
        {
            //some condition used resourceUser values and another needs a connection to DB 
            //TODO: how to evaluate this case
           

        }
        else if(finalEval == -1 && sql != "" )
        {
            //only connect sql is required
            finalEval = connectDB(sql);
        }
        else if(finalEval == -1 && sql == "")
        {
            //nothing has been used
            finalEval = 0;
        }

        return finalEval;
       
    }
     
    private function checkLimit(user:Dynamic, permission:Permission, resource:Dynamic):Bool
    {
        var allow = false;
        if(permission.activePolicy.limit.amount == -1)
        {
            //we do not care about limit
            allow = true;
        }
        else if(permission.activePolicy.limit.amount > 0)
        {
            if(connection == null)
                throw "No connection to db provided, Grant needs to check create action limit";
            
            var result = runConditions(user, permission, resource);

            return (result > 0 ? true:false);

        } 
        else if(permission.activePolicy.limit.amount == 0)
        {
            allow = false;
        }   

        return allow;
    }
    private function connectDB(sql:String):Int
    {
        if(connection == null)
            throw "no connection to db is provided.";
        
        sql = connection.escape(sql);

        var results = connection.request(sql);

        if(results == null || results.results() == null)
            return 0;

        return results.results().length;
    }

    public function setConnection(connection:Connection)
    {
        this.connection = connection;
    }
    public function removeConnection()
    {
        this.connection = null;
    }
    
}
