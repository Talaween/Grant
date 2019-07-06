package grant;
/**
 * ...
 * @author Mahmoud Awad
 * 
 * Allow more than one user role
 * allow dynamic user roles creation from outide DB
 * 
 */

import sys.db.Connection;
import sys.db.ResultSet;
import grant.*;

typedef Limit = {amount:Int, rule:String};
typedef Policy = {action:String, records:String, fields:String, limit:Limit};   
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
    
    public function setSchema(schema:Schema)
    {
        this.schema = schema;
    }
    public function fromJson(jsonData:String):Schema
    {
        var schema:Schema;
        try
        {
            schema = haxe.Json.parse(jsonData);
        }
        catch(ex:String)
        {
            throw "Invalid Json format:" + ex;
        }
       
        this.schema = schema;

        return schema;
    }

    public function addRole(obj:Role)
    {
        schema.accesscontrol.push(obj);
    }
    public function assignToRole(roleName:String, resource:Resource):Bool
    {
        var len = schema.accesscontrol.length;

        for(i in 0...len)
        {
            if(schema.accesscontrol[i].role == roleName)
            {
                schema.accesscontrol[i].grant.push(resource);
                return true;
            }  
        }

        return false;
    }
    public function mayAccess(role:String, action:String, resourceName:String):Permission
    {

        if(schema == null || schema.accesscontrol == null)
        {
            return new Permission(role, resourceName, null, "schema or access control object is null");
        }
        
        //find the role in the schema
        var _thisRole:Role = null;
        var _inherited:Role = null;
        
        //find the desired role in the schema
        for(_r in schema.accesscontrol)
        {
            if(_r.role == role)
            {
                _thisRole = _r;
                break;
            }
        }

        //if we could not find the role 
        if(_thisRole == null)
            return new Permission(role, resourceName, null, "role was not found");

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
            
        //find all policies on this resource for this role and its inherited ones  
        var _policies = new Array<Policy>();
         var zerolimited = true;

        //priority is for the extended policies before the inherited 
        for(_res in _thisRole.grant)
        {
            if(_res.resource == resourceName)
            {
                for (_pol in _res.policies)
                {
                    if(_pol.action == action)
                    { 
                        if(_pol.limit.amount != 0)
                            zerolimited = false;

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
                            if(_polInh.limit.amount != 0)
                                zerolimited = false; 

                            _policies.push(_polInh);
                        }
                    }
                }    
            }
        }
        
        var accessMessage = "";

        if(_policies.length == 0)
            accessMessage =  "no " + action + " policy found for this role:" + role + " on this resource:" + resourceName;
        
        if(zerolimited == true)
        {
            accessMessage =  "all existing policies found are limited to zero for this role:" + role + " on this resource:" + resourceName;
            //because all limited to 0 discard them
            _policies = null;
        }

        return new Permission(role, resourceName, _policies, accessMessage);
    }

    public function access(user:Dynamic, permission:Permission, resource:Dynamic):Dynamic
    {  
        var allow = false;

        if(permission != null && permission.policy != null && user != null)
        {
            if(user.role != null && permission.role != null && user.role == permission.role)
            {
                allow = checkRecord(user, permission.policy, resource);
                
                if(allow)
                {
                    allow = checkLimit (user, permission.policy.limit, resource);
                    if(allow)
                    {
                        permission.policy.fields = checkFields(permission.policy.fields);
                        return permission.filter(user, resource);
                    }
                }
            }
        }
        
        if(permission.nextPolicy() == true)
            return access(user, permission, resource);
        else
            return null;
    }

    private function checkRecord(user:Dynamic, policy:Policy, resource:Dynamic):Bool
    {
        if(policy.records == null || policy.records == "" || policy.records.toLowerCase() == "none")
        {
            return false;
        }  
        else if(policy.records.toLowerCase() == "any")
        {
            return true;
        }
        else 
        {    
            return (runCondition(user, policy.records, resource) > 0 ? true : false);
        }
    }

    //this function needs revisions, having count (*) of resource.field = user.field doesn't 
    //mean we can access the current record. we need to explicitly include the current record
    private function runCondition(user:Dynamic, condition:String, resource:Dynamic):Int
    {
        var operators = new Array<String>();
        var conditions = new Array<String>();

        var conditionPart = "";
        var len = condition.length;
        
        //evaluate each sub part of condition by splitting through & and | operators
        for(i in 0...len)
        {
            switch(condition.charAt(i))
            {
                case "&":   operators.push("&");
                            conditions.push(conditionPart);
                            conditionPart = "";

                case "|":   operators.push("|");
                            conditions.push(conditionPart);
                            conditionPart = "";

                default: conditionPart += condition.charAt(i);
            }

        }
        

        //push the last condition part
        conditions.push(conditionPart);

        var finalValue = false;
        var counter = 0;

        for(conditionPart in conditions)
        {
            var retVal = evaluateExpression(user, conditionPart, resource);
            
            trace(retVal + "=>" + conditionPart);

            if(counter == 0)
            {
                finalValue = (retVal == 1 ? true:false);
            }
            else
            {
                switch (operators[counter-1])
                {
                    case "&": finalValue = finalValue && (retVal == 1 ? true:false);
                    case "|": finalValue = finalValue || (retVal == 1 ? true:false);
                }
            }
        }
        return (finalValue == true ? 1 : 0);
        //case when we use a select statement in the condition
        
    }

    private function extractFieldName(statement:String, obj:String):String
    {
        var len1 = statement.indexOf(obj + '.') + (obj + '.').length;
        var len2 = statement.length;
        var field = '';

        for(i in len1...len2)
        {
            if(StringTools.isSpace(statement, i))
                break;
            else if(statement.charAt(i) == "\"")
                continue;
            else
                field += statement.charAt(i);
        }

        return field;
    }
    
    private function evaluateExpression(user:Dynamic, condition:String, resource:Dynamic):Int
    {
        if(condition.indexOf("select") == 0 || condition.indexOf("Select") == 0 || condition.indexOf("SELECT") == 0)
        {
            //we need to embed user and resource values inside the query
            
            var userField = extractFieldName(condition, 'user');
            var resourceField = extractFieldName(condition, 'resource');

            if(userField != '')
            {
                var userValue = Reflect.field(user, userField);
                trace(condition+ "<>user." + userField + "<>" + userValue);
                condition = StringTools.replace(condition, 'user.' + userField, userValue);
            }

            if(resourceField != '')
            {
                var resourceValue = Reflect.field(resource, resourceField);
                condition = StringTools.replace(condition, 'resource.' + resourceField , resourceValue);
            }

            return executeQuery(condition);
        }
        //case we use (resource.fieldName = user.fieldName) or (resource.fieldName = someValue)
        else  if(condition.indexOf("resource") == 0 || condition.indexOf("user") == 0)
        {
            condition = Utils.stripSpaces(condition);

            var reg = ~/[><!=]{0,1}=/;

            var operands = reg.split(condition);
            
            var secondPartValue:Dynamic;
            var firstPartValue:Dynamic;
            
            if(operands.length == 2)
            {
                var firstParts = operands[0].split('.');
                
                if(firstParts.length != 2)
                    throw "wrong expression, left side of expression does not have a field attached to it";
                
                if(firstParts[0] == "resource")
                    firstPartValue = Reflect.field(resource, firstParts[1]);
                else
                    firstPartValue = Reflect.field(user, firstParts[1]);

                if(firstPartValue == null)
                {
                    return 0;
                }

                //case right operand is user.fieldName or resource.fieldName
                if(operands[1].indexOf("user") == 0 || operands[1].indexOf("resource") == 0  )
                {
                    var secondParts = operands[1].split('.');

                    if(secondParts.length != 2)
                        throw "wrong expression, left side user or resource does not have a field attached to it";

                    if(secondParts[0] == "resource")
                        secondPartValue = Reflect.field(resource, secondParts[1]);
                    else
                        secondPartValue = Reflect.field(user, secondParts[1]);

                    if(secondPartValue == null)
                    {
                        return 0;
                    }

                }
                //case right operand is someValue
                else
                {
                    var rightOperand = operands[1].split('/');
                    //we need to know resource fieldName type so we can correctly cast the someValue
                    //we will add a flag to the value like this: 45/i 3.58/f textTitle 2018-04-13/d true/b
                    if(rightOperand.length == 2)
                    {
                        switch(rightOperand[1])
                        {
                            case 'i': secondPartValue = Std.parseInt(rightOperand[0]);
                            case 'f': secondPartValue = Std.parseFloat(rightOperand[0]);
                            case 'b': secondPartValue = (rightOperand[0].toLowerCase() == "true" ? true:false);
                            case 'd': secondPartValue = Date.fromString(rightOperand[0]);
                            default:  secondPartValue = rightOperand[0];
                        }
                    }
                    else
                    {
                        //it is a string value
                        secondPartValue = operands[1];
                    }
                }

                if(condition.indexOf(">=") != -1)
                {
                    return (firstPartValue >= secondPartValue ? 1:0);
                }
                else if(condition.indexOf("<=") != -1)
                {
                    return (firstPartValue <= secondPartValue ? 1:0);
                }
                else if(condition.indexOf(">") != -1)
                {
                    return (firstPartValue > secondPartValue ? 1:0);
                }
                else if(condition.indexOf("<") != -1)
                {
                    return (firstPartValue < secondPartValue ? 1:0);
                }
                else if(condition.indexOf("!=") != -1)
                {
                    return (firstPartValue != secondPartValue ? 1:0);
                }
                else if(condition.indexOf("==") != -1)
                {
                    return (firstPartValue == secondPartValue ? 1:0);
                }
                else if(condition.indexOf("=") != -1)
                {
                    return (firstPartValue == secondPartValue ? 1:0);
                }
                else
                    throw "error in records expression, wrong operator used in expression";
            }
            else
            {
                throw "error in records expression, no 2 operands were detected";
            } 
        }

        return 0;
        
    }
    private function checkLimit(user:Dynamic, limit:Limit, resource:Dynamic):Bool
    {
        var allow = false;
        if(limit == null || limit.amount == null || limit.amount == -1)
        {
            //we do not care about limit
            allow = true;
        }
        else if(limit.amount > 0)
        {
            if(connection == null)
                throw "No connection to db provided, Grant needs to check action limit";
            
            return (runCondition(user, limit.rule, resource) > 0 ? true: false);

        } 
        else if(limit.amount == 0)
        {
            allow = false;
        }   

        return allow;
    }

    private function executeQuery(sql:String):Int
    {
        if(connection == null)
            throw "no connection to db is provided.";
        
        var records:ResultSet;

        try
        {
            records = connection.request(sql);
        }
        catch(err:String){
            return 0;
        }
        if(records == null || records.results().length == null)
            return 0;

        return records.results().length;
    }

    /* check the order of the fields that are allowed or prohibited to be accessed
    *  make sure the * ioperator is put at first and no duplication is in there
    *  and the excluded fields put after the allowed ones 
    * */
    private static function checkFields(fields:String):String
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
                if(grant.Utils.linearSearch(includedFields, field) == -1)
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

    public function setConnection(connection:Connection)
    {
        this.connection = connection;
    }
    public function removeConnection()
    {
        this.connection = null;
    }
    
}
