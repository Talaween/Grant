
/**
 * ...
 * @author Mahmoud Awad
 */

 import sys.db.Connection;

typedef Limit = {amount:Int, on:String, equal:String}
typedef Policy = {action:String, records:String, fields:String, limit:Limit};   
typedef Resource = {resource:String, policies:Array<Policy>};
typedef Role = {role:String, grant:Array<Resource>};    
    
class Grant 
{
    private static var _instance:Grant;

    private var schema:{accesscontrol:Array<Role>};

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
        try
        {
             this.schema = haxe.Json.parse(schema);
        }
        catch(ex:String)
        {
            throw "Invalid Json format";
        }
    }
    
    public function canAccess(role:String, action:String, resourceName:String, any:Bool = false):Permission
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
        var _policy:Policy = null;
        
        for(_res in _thisRole.grant)
        {
            if(_res.resource == resourceName)
            {
                for (_pol in _res.policies)
                {
                    if(_pol.action == action)
                    { 
                        _policy = _pol;
                        break;
                    }
                       
                }
            }    
        }

        if(_policy == null){
            return new Permission(false, role, resourceName, null);
        }
            
        if(any)
        {
            if(_policy.records != "any")
            {
                return new Permission(false, role, resourceName, null);
            }
        }
        if(_policy.limit.amount == 0)
        {
            return new Permission(false, role, resourceName, null);
        }
        
        return new Permission(true, role, resourceName, _policy);

    }

    public function access(user:Dynamic, permission:Permission, resource:Dynamic, ?connection:Connection):Dynamic
    {  
        if(permission == null || permission.policy == null || user == null){
            throw "permission, its policy or user objects is null";
            return null;
        }
        if(user.role == null)
        {
            throw ('user object has no role property');
            return null;
        }

        if(user.role != permission.role){
            return null;
        }

        var allow = false;

        allow = checkRecord(user, permission.resource, resource, permission.policy.records, connection);
        
        if(allow)
        {
             allow = checkLimit (permission.policy.limit, connection);

             if(allow)
             {
                 return permission.filter(resource);
             }
        }
           
        return null;
 
    }

    private function checkLimit(limit:Limit, connection:Connection):Bool
    {

        var allow = false;
        if(limit.amount == -1)
        {
            //we do not care about limit
            allow = true;
        }
        else if(limit.amount > 0)
        {
            if(connection == null)
            {
                throw "No connection to db provided, Grant needs to check create action limit";
            }
            //TODO find limit in DB
        }    

        return allow;
    }

    private function checkRecord(user:Dynamic, resourceName:String, resource:Dynamic, rule:String, connection:Connection):Bool
    {
        
        if(rule == null || rule == "" || rule == "none")
        {
            return false;
        }  
        else if(rule == "any")
        {
            return true;
        }
        else 
        {
            rule = rule.toLowerCase();
            rule = Utils.stripSpaces(rule);

            var conditions = rule.split('&');
            var numConditions = conditions.length;

            if(numConditions == 1)
            {
                return evalOneCondition(user, conditions[0], resourceName, resource, connection);
            } 
            else if(numConditions == 2)
            {
                
                return evalTwoConditions(user, conditions, resourceName, resource, connection);
            }
            else
            {
                throw "wrong expression, more than two conditions is not yet supported.";
                return false;
            }
        }
    }

    private function evalOneCondition(user:Dynamic, condition:String, resourceName:String, resource:Dynamic, connection:Connection):Bool
    {
        //we have only one condition
        //resources involved in the cndition are the user and the resource
        //example: resource.ownerId = user.id

        //we need to know the name of the field associated with user
        var userField = "";
        //the name of the field associated with resource
        var resourceField = "";
        //split the operands of the condition 
        var operands = condition.split("=");

        if(operands.length != 2)
        {
            throw "records expression is wrong, less or more than two operands";
            return false;
        }
        else
        {
            //make sure one operand is the resource name and the other is the user
            var operand1Parts = operands[0].split(".");
            if(operand1Parts.length != 2)
            {
                throw "records expression is wrong, dot notation is wrong at operand 1.";
                return false;
            }
            if(operand1Parts[0] != 'user')
            {
                if(operand1Parts[0] != resourceName)
                {
                    throw "record expression is wrong, unknown resource on operand 1.";
                    return false;
                }
                else
                {
                    resourceField =  operand1Parts[1]; 
                }   
            }
            else
            {
                userField =  operand1Parts[1];
            }
            var operand2Parts = operands[1].split(".");
            if(operand2Parts.length != 2)
            {
                throw "records expression is wrong, dot notation is wrong at operand 2.";
                return false;
            }
            
            if(operand2Parts[0] != 'user')
            {
                if(operand2Parts[0] != resourceName)
                {
                    throw "record expression is wrong, unknown resource on operand 2.";
                    return false;
                }
                else
                {
                    if(resourceField == "")
                    {
                        resourceField =  operand2Parts[1]; 
                    }
                    else
                    {
                        throw "resource name is used on both side of the consition";
                        return false;
                    }
                }
            }
            else
            {
                if(userField == "")
                {
                    userField =  operand2Parts[1];
                }
                else
                {
                    throw "user is used on both side of the condition";
                    return false;
                }    
            }

            var part1 = Reflect.field(user, userField);
            var part2 = Reflect.field(resource, resourceField);
            
            if(part1 == null)
            {
                throw "record expression is wrong, " + userField + " is not part of user class";
                return false;
            }

            if(part2 == null)
            {
                throw "record expression is wrong, " + resourceField + " is not part of " + resourceName + " class";
                return false;
            }

            if(part1 == part2)
                return true;
            else
                return false;
        }  
    }
    private function evalTwoConditions(user:Dynamic, conditions:Array<String>, resourceName:String, resource:Dynamic, connection:Connection):Bool
    {

        //case we have three resources 
        //example pupilTasks.pupilId = pupil.id & pupilTask.taskId = task.id

        //we need to know the name of the field associated with user
        var userField = "";
        //the name of the field associated with resource
        var resourceField = "";

        var operandsCon1 = conditions[0].split("=");
        var operandsCon2 = conditions[1].split("=");

        var operandsCon1Parts1 = operandsCon1[0].split(".");
        var operandsCon1Parts2 = operandsCon1[1].split(".");

        var operandsCon2Parts1 = operandsCon2[0].split(".");
        var operandsCon2Parts2 = operandsCon2[1].split(".");

        if(operandsCon1Parts1[0] != operandsCon2Parts1[0] )
        {
            throw "wrong expression in condition, not same resource used in left part of each condition.";
            return false;
        }
        if(operandsCon1Parts2[0] != 'user')
        {
            if(operandsCon1Parts2[0] != resourceName)
            {
                throw "record expression is wrong, unknown resource on operand 2 at first condition.";
                return false;
            }
            else
            {
                resourceField =  operandsCon1Parts2[0]; 
            }
        }
        else
        {
                userField =  operandsCon1Parts2[0];
        }
        if(operandsCon2Parts2[0] != 'user')
        {
            if(operandsCon2Parts2[0] != resourceName)
            {
                throw "record expression is wrong, unknown resource on operand 2 at first condition.";
                return false;
            }
            else
            {
                if(resourceField == "")
                {
                    resourceField =  operandsCon2Parts2[0];
                }
                else
                {
                    throw "resource name is used on both side of the consition";
                    return false;
                }
            }
        }
        else
        {
            if(userField == "")
            {
                userField =  operandsCon2Parts2[0];
            }
            else
            {
                throw "user is used on both side of the consition";
                return false;
            }  
        }

        var part1 = Reflect.field(user, userField);
        var part2 = Reflect.field(resource, resourceField);

        if(part1 == null)
        {
            throw "record expression is wrong, " + userField + " is not part of user class";
            return false;
        }
        if(part2 == null)
        {
            throw "record expression is wrong, " + resourceField + " is not part of " + resourceName + " class";
            return false;
        }

        //now we need to run an sql query
        var sql = "SELECT * FROM " + operandsCon1Parts1[0] + " WHERE " + operandsCon1Parts1[1] + " = " + part1 + " AND " + operandsCon2Parts1[1] + " = " + part2;
        try
        {
             if(connectDB(sql, connection) > 0)
                return true;
            else
                return false;
        }
        catch(err:String)
        {
            throw err;
        }
       
        return false;
    }

    private function connectDB(sql, connection:Connection):Int
    {
        if(connection == null)
        {
            throw "no connection to db is provided.";
            return 0;
        }
        
        var results = connection.request(sql);

        return results.results().length;
    }
    
}
