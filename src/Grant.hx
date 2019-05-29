
/**
 * ...
 * @author Mahmoud Awad
 * 
 * Allow more than one policy on same resource but different on records
 * Allow using != > >= < or <= operators
 * allow using & and | on two conditions
 * Allow more than one user roles
 * allow dynamic user roles creation from outide DB
 * filter sub-object based on role view on the sub-object by using ^ operator
 * 
 * 
 */

 import sys.db.Connection;

typedef Limit = {amount:Int, on:String, equal:String}
typedef Policy = {action:String, records:String, fields:String, limit:Limit};   
typedef Resource = {resource:String, policies:Array<Policy>};
typedef Role = {role:String, grant:Array<Resource>};    

typedef Condition = {resource1:String, field1:String, operator:String, resource2:String, field2:String}; 

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
        if(permission == null || permission.policy == null || user == null)
            throw "permission, its policy or user objects is null";
        if(user.role == null)
            throw ('user object has no role property');
        

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
                throw "No connection to db provided, Grant needs to check create action limit";
            
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
                throw "wrong expression, more than two conditions is not yet supported.";
            
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
            throw "records expression is wrong, less or more than two operands";
        else
        {
            //make sure one operand is the resource name and the other is the user
            var operand1Parts = operands[0].split(".");
            if(operand1Parts.length != 2)
                throw "records expression is wrong, dot notation is wrong at operand 1.";
            
            if(operand1Parts[0] != 'user')
            {
                if(operand1Parts[0] != resourceName)
                    throw "record expression is wrong, unknown resource on operand 1.";
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
                throw "records expression is wrong, dot notation is wrong at operand 2.";
            
            
            if(operand2Parts[0] != 'user')
            {
                if(operand2Parts[0] != resourceName)
                    throw "record expression is wrong, unknown resource on operand 2.";
                else
                {
                    if(resourceField == "")
                    {
                        resourceField =  operand2Parts[1]; 
                    }
                    else
                        throw "resource name is used on both side of the consition";
                    
                }
            }
            else
            {
                if(userField == "")
                {
                    userField =  operand2Parts[1];
                }
                else
                    throw "user is used on both side of the condition";
            }

            var part1 = Reflect.field(user, userField);
            var part2 = Reflect.field(resource, resourceField);
            
            if(part1 == null)
                throw "record expression is wrong, " + userField + " is not part of user class";
            

            if(part2 == null)
                throw "record expression is wrong, " + resourceField + " is not part of " + resourceName + " class";
            

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
            throw "wrong expression in condition, not same resource used in left part of each condition.";
        if(operandsCon1Parts2[0] != 'user')
        {
            if(operandsCon1Parts2[0] != resourceName)
                throw "record expression is wrong, unknown resource on operand 2 at first condition.";
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
                throw "record expression is wrong, unknown resource on operand 2 at first condition.";
            else
            {
                if(resourceField == "")
                {
                    resourceField =  operandsCon2Parts2[0];
                }
                else
                    throw "resource name is used on both side of the consition";
            }
        }
        else
        {
            if(userField == "")
            {
                userField =  operandsCon2Parts2[0];
            }
            else
                throw "user is used on both side of the consition";
        }

        var part1 = Reflect.field(user, userField);
        var part2 = Reflect.field(resource, resourceField);

        if(part1 == null)
            throw "record expression is wrong, " + userField + " is not part of user class";
        if(part2 == null)
            throw "record expression is wrong, " + resourceField + " is not part of " + resourceName + " class";
        

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

    public function parseConditions(cond:String):Array<Condition>
    {
        var len = cond.length;
        var conditionPart = 0;

        var condition:Condition = {resource1: "", field1:"", operator:"", resource2:"", field2:""};

        var conditions = new Array<Condition>();

        for(i in 0...len)
        {
            var char = cond.charAt(i);

            if(Utils.isLetterOrDigit(char) )
            {
               switch (conditionPart)
               {
                   case 0:
                        //do not accept digit to start variable names
                        if(condition.resource1.length == 0 && Utils.isDigit(char))
                            throw "resource1 name should not start with a digit";
                        condition.resource1 += char;
                   case 1:
                        if(condition.field1.length == 0 && Utils.isDigit(char))
                             throw "field1 name should not start with a digit";
                        condition.field1 += char;
                   case 2:
                        if(condition.resource2.length == 0 && Utils.isDigit(char))
                            throw "resource2 name should not start with a digit";
                        condition.resource2 += char;
                   case 3:
                        if(condition.field2.length == 0 && Utils.isDigit(char))
                            throw "field2 name should not start with a digit";
                        condition.field2 += char;
                    case 4:
                        throw "too many dots have been detected";
               }
            }
            else if(char == "=")
            {
                if(conditionPart == 1 && i != 0 && cond.charAt(i-1) != "!")
                {
                    condition.operator = "=";
                    conditionPart++;  
                }
                else if(conditionPart == 1 && i != 0 && cond.charAt(i-1) == "!")
                {
                    condition.operator = "!=";
                    conditionPart++;
                }
                else
                    throw "wrong placement of = operator";
            }
            else if(char == ".")
            {
                conditionPart++;
            }
            else if( (char == "&" || char == "|"))
            {
                
                if(conditionPart != 3)
                    throw "wrong placement of & or | characters in the condition expression";

                var con1:Condition = {resource1: "", field1:"", operator:"", resource2:"", field2:""};

                //copy the condition before resetting it
                if(condition.resource1 != "")
                    con1.resource1 = condition.resource1;
                else 
                    throw "resource1 is empty";
                
                if(condition.field1 != "")
                    con1.field1 = condition.field1;
                else 
                     throw "field1 is empty";
                
                if(condition.operator != "")
                    con1.operator = condition.operator;
                else 
                     throw "operator is empty";

                if(condition.resource2 != "")
                    con1.resource2 = condition.resource2;
                else 
                     throw "resource2 is empty";
                
                if(condition.field2 != "")
                    con1.field2 = condition.field2;
                else 
                     throw "field2 is empty";

                conditions.push(con1);

                //now reset condition for next one
                condition.resource1 = "";
                condition.field1 = "";
                condition.operator = "";
                condition.resource2 = "";
                condition.field2 = "";

                conditionPart = 0;
            }
            else
            {
                if(char != "!")
                    throw "unallowed character has been used in the condition expression:" + char ;
                //be mindful where the ! character is located in the condition
                else if(condition.operator != "" || ( i+1 < len && cond.charAt(i+1) != "=") || i== len-1)
                    throw "wrong placement of ! character in the condition";
            }
        }

        if(condition.resource1 != "" && condition.field1 != "" && condition.operator != "" && condition.resource2 != "" && condition.field2 != "")
            conditions.push(condition);
        else{

            throw "a field is empty";
        }
            

        return conditions;
    }

    private function connectDB(sql, connection:Connection):Int
    {
        if(connection == null)
            throw "no connection to db is provided.";
        
        
        var results = connection.request(sql);

        if(results == null || results.results() == null)
            return 0;

        return results.results().length;
    }
    
}
