
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
typedef Conditions = {conditions:Array<Condition>, operators:Array<String>};
typedef Limit = {amount:Int, rule:String, ?conditions:Conditions};
typedef Policy = {action:String, records:String, fields:String, limit:Limit, ?conditions:Conditions};   
typedef Resource = {resource:String, policies:Array<Policy>};
typedef Role = {role:String, grant:Array<Resource>};  
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
        
    }
    
    public function mayAccess(role:String, action:String, resourceName:String, any:Bool = false):Permission
    {

        if(schema == null || schema.accesscontrol == null){
            return new Permission(false, role, resourceName, null);
        }
        
        //find the role in the schema
        var _thisRole:Role = null;

        for(_r in schema.accesscontrol)
        {
            if(_r.role == role)
            {
                _thisRole = _r;
                break;
            }
        }
        
        //if we could not find the role
        if(_thisRole == null){
            return  new Permission(false, role, resourceName, null);
        }
            
        //find the policy on resource for this role 
        var _policies = new Array<Policy>();
        
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

        if(_policies.length == 0)
            return new Permission(false, role, resourceName, null);
        
        if(any)
        {            
            for(_policy in _policies)
            {
                if(_policy.records == "any")
                {
                    var p =  new Permission(true, role, resourceName, _policies);
                    p.activePolicy = _policy;
                    return p;
                }     
            }
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
            throw "permission, its policy or user objects is null";
        if(user.role == null)
            throw ('user object has no role property');
        
        if(user.role != permission.role){
            return null;
        }

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
        if(permission == null || permission.activePolicy.records == "none")
        {
            return false;
        }  
        else if(permission.activePolicy.records == "any")
        {
            return true;
        }
        else 
        {
            var rule = permission.activePolicy.records.toLowerCase();
            rule = Utils.stripSpaces(rule);

            return evaluateConditions(user, permission, resource, parseConditions(rule));
        }
    }

    private function evaluateConditions(user:Dynamic, permission:Permission, resource:Dynamic, conditions:Conditions):Bool
    {
        var finalEvals = new Array<Bool>();

        for(cond in conditions.conditions)
        {
            if( cond.resource1 == 'user'  && cond.resource2 == permission.resource )
            {
                if(cond.field1 != '' && cond.field2 != '')
                {
                    var part1 = Reflect.field(user, cond.field1);
                    var part2 = Reflect.field(resource, cond.field2);
                    
                    if(part1 == null)
                        throw "record expression is wrong, " + cond.field1 + " is not part of user class";

                    if(part2 == null)
                        throw "record expression is wrong, " + cond.field2 + " is not part of " + permission.resource + " class";
                    
                    if(part1 == part2)
                        finalEvals.push(true);
                    else
                       finalEvals.push(false);
                }
            }
            if( cond.resource2 == 'user'  && cond.resource1 == permission.resource )
            {
                if(cond.field1 != '' && cond.field2 != '')
                {
                    var part1 = Reflect.field(user, cond.field2);
                    var part2 = Reflect.field(resource, cond.field1);
                    
                    if(part1 == null)
                        throw "record expression is wrong, " + cond.field2 + " is not part of user class";

                    if(part2 == null)
                        throw "record expression is wrong, " + cond.field1 + " is not part of " + permission.resource + " class";
                    
                    if(part1 == part2)
                        finalEvals.push(true);
                    else
                        finalEvals.push(false);
                }
            }
            else if(cond.resource2 == 'user' && cond.resource1 != permission.resource)
            {
                var part2 = Reflect.field(user, cond.field2);

                 if(part2 == null)
                    throw "record expression is wrong, " + cond.field2 + " is not part of user class";

                var sql = "SELECT count(*) FROM " + cond.resource1 + " WHERE " + cond.field1 + " = " + part2;

                if(connectDB(sql) > 0)
                {
                    finalEvals.push(true);
                }
                else
                {
                    finalEvals.push(false);
                }
            }
            else if(cond.resource2 == permission.resource  && cond.resource1 != 'user')
            {
                var part2 = Reflect.field(resource, cond.field2);

                 if(part2 == null)
                    throw "record expression is wrong, " + cond.field2 + " is not part of " + permission.resource;

                var sql = "SELECT count(*) FROM " + cond.resource1 + " WHERE " + cond.field1 + " = " + part2;

                if(connectDB(sql) > 0)
                {
                    finalEvals.push(true);
                }
                else
                {
                    finalEvals.push(false);
                }
            }
            else
            {
                throw "wrong expression in the condition";
            }
           
        }

        var i = 0;
        var finalResult = false;
        //finally if we have many conditions evaluate them all.
        for(val in finalEvals)
        {
            if(i == 0) 
                finalResult = val;
            else
            {
                switch(conditions.operators[i])
                {
                    case "&": finalResult = finalResult && val;
                    case "|": finalResult = finalResult || val;
                }
            }
        }

        return finalResult;
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
            
            var vars1 = permission.activePolicy.limit.fieldToCount.split(".");
            var vars2 = permission.activePolicy.limit.valueToEqual.split(".");
            
            if(vars1.length != 2 && vars2.length > 2)
                throw "error in limit criteria.";
            
            var value:Dynamic;
            var sql = "";

            if(vars2[0] == 'user')
                value = Reflect.field(user, vars2[1]);
            else if(vars2[0] == permission.resource)
                value = Reflect.field(resource, vars2[1]);
            else if(vars2.length == 1)
                value = vars2[0];
            else
                throw "error in limit criteria toEqual.";

            if(value != null)
            {
                sql = "SELECT count(*) FROM " + vars1[0] + " WHERE " + vars1[1] + " = " + value;

                if(connectDB(sql) < permission.activePolicy.limit.amount)
                    allow = true;
            }
   
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
