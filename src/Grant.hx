
/**
 * ...
 * @author Mahmoud Awad
 * 
 * Allow more than one policy on same resource but different on records
 * Allow more than one user role
 * allow dynamic user roles creation from outide DB
 * 
 */

 import sys.db.Connection;

typedef Limit = {amount:Int, fieldToCount:String, valueToEqual:String}
typedef Policy = {action:String, records:String, fields:String, limit:Limit};   
typedef Resource = {resource:String, policies:Array<Policy>};
typedef Role = {role:String, grant:Array<Resource>};    

typedef Condition = {resource1:String, field1:String, operator:String, resource2:String, field2:String}; 
typedef Conditions = {conditions:Array<Condition>, operators:Array<String>};


class Grant 
{
    private static var _instance:Grant;

    private var schema:{accesscontrol:Array<Role>};
    private var connection:Connection;

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

        if(_policy == null)
            return new Permission(false, role, resourceName, null);
        
        if(any)
        {
            if(_policy.records != "any")
                return new Permission(false, role, resourceName, null);   
        }

        if(_policy.limit.amount == 0)
            return new Permission(false, role, resourceName, null);
        
        return new Permission(true, role, resourceName, _policy);

    }

    public function access(user:Dynamic, permission:Permission, resource:Dynamic):Dynamic
    {  
        if(permission == null || permission.policy == null || user == null)
            throw "permission, its policy or user objects is null";
        if(user.role == null)
            throw ('user object has no role property');
        
        if(user.role != permission.role){
            return null;
        }

        var allow = false;

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
        if(permission == null || permission.policy == null || permission.policy.records == "" || permission.policy.records == "none")
        {
            return false;
        }  
        else if(permission.policy.records == "any")
        {
            return true;
        }
        else 
        {
            var rule = permission.policy.records.toLowerCase();
            rule = Utils.stripSpaces(rule);

            return evaluateConditions(user, permission, resource, parseConditions(rule));
        }
    }

    public function parseConditions(cond:String):Conditions
    {
        var len = cond.length;
        var conditionPart = 0;

        var allowedOperators = ["=", "!", ">", "<", ")", "("];

        var condition:Condition = {resource1: "", field1:"", operator:"", resource2:"", field2:""};

        var allConditions:Conditions = {conditions : new Array<Condition>(), operators: new Array<String>()}

        var countOpenParanthesis = 0;
        var countCloseParanthesis = 0;

        var i = 0;
        while(i < len)
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
            else if(Utils.linearSearch(allowedOperators, char) > -1)
            {
                switch(char)
                {
                    case "=":
                        condition.operator = "=";
                        conditionPart++;
                    case "!":
                       if(i < len-1 && cond.charAt(i+1) == "=")
                        {
                            condition.operator = "!=";
                            i++;
                            conditionPart++;  
                        }
                        else
                             throw "wrong placement of ! operator";  
                    case ">" | "<":
                        if(i < len-1 && cond.charAt(i+1) == "=")
                        {
                            condition.operator = char + "=";
                            i++;
                            conditionPart++;  
                        }
                        else if(i < len-1)
                        {
                            condition.operator = char;
                            conditionPart++;
                        }
                        else
                            throw "wrong placement of > or < operators";
                    case "(":
                        countOpenParanthesis++;
                       // if(i != 0 && (cond.charAt(i-1) != "&" && cond.charAt(i-1) != "|") )
                         //   throw "Wrong placement of paranthesis (.";
                    case ")":
                        countCloseParanthesis++;
                       // if(i!= len -1 && (cond.charAt(i+1) != "&" && cond.charAt(i+1) != "|") )
                        //   throw "Wrong placement of paranthesis ).";
                }
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
            
                allConditions.conditions.push(con1);
                allConditions.operators.push(char);

                //now reset condition for next one
                condition.resource1 = "";
                condition.field1 = "";
                condition.operator = "";
                condition.resource2 = "";
                condition.field2 = "";

                conditionPart = 0;
            }
            else
                throw "unallowed character has been used in the condition expression:" + char ;

            i++;
        }

        if(countOpenParanthesis != countCloseParanthesis)
            throw "Wrong matching of open and close paranthesis";

        if(condition.resource1 != ""  && condition.operator != "" && condition.resource2 != "" )
            allConditions.conditions.push(condition);
        else{
            throw "a field is empty in the last expression";
        }
    
        return allConditions;
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
        if(permission.policy.limit.amount == -1)
        {
            //we do not care about limit
            allow = true;
        }
        else if(permission.policy.limit.amount > 0)
        {
            if(connection == null)
                throw "No connection to db provided, Grant needs to check create action limit";
            
            var vars1 = permission.policy.limit.fieldToCount.split(".");
            var vars2 = permission.policy.limit.valueToEqual.split(".");
            
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

                if(connectDB(sql) < permission.policy.limit.amount)
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
