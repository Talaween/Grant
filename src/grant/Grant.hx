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
    
    public function fromJson(jsonData:String):Schema
    {
        var schema:Schema;
        try
        {
            schema = haxe.Json.parse(jsonData);
        }
        catch(ex:String)
        {
            throw "Invalid Json format";
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
    public function mayAccess(role:String, action:String, resourceName:String, any:Bool = false):Permission
    {

        if(schema == null || schema.accesscontrol == null)
        {
            return new Permission(false, role, resourceName, null, "schema or access control object is null");
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
            return new Permission(false, role, resourceName, null, "role was not found");

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
        
        //priority is for the extended policies before the inherited 
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
            return new Permission(false, role, resourceName, null, "no " + action + " policy found for this role:" + role);
        
        //are we checking for a policy that allow access to "any" record
        if(any)
        {            
            for(_policy in _policies)
            {
                if(_policy.records.toLowerCase() == "any")
                {
                    var p =  new Permission(true, role, resourceName, _policy);
                    return p;
                }     
            }
            //if any flag is requested but we did not find any policy that supports "any"
            return new Permission(false, role, resourceName, null, "no 'Any' policy was found to " + action + " for this role:" + role);
        }
        else
        {
            for(_policy in _policies)
            {
                if(_policy.limit.amount != 0)
                    return new Permission(true, role, resourceName, _policy);
            }
        }

        return new Permission(false, role, resourceName, null, "no policy found that has a limit amount more than 0. ");
    }

    public function access(user:Dynamic, permission:Permission, resource:Dynamic):Dynamic
    {  
        if(permission == null || permission.policy == null || user == null)
        {
             return null;
        }
        
        if(user.role == null || permission.role == null || user.role != permission.role)
        {
            return null;
        }
           
        
        var allow = false;

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
        
        var finalEval = -1;
        var sql = "";
        var counter = 0;

        if(condition.indexOf("select") == 0)
        {
            //we need to embed user and resource values inside the query
            
            var userField = extractFieldName(condition, 'user');
            var resourceField = extractFieldName(condition, 'resource');

            if(userField != '')
            {
                var userValue = Reflect.field(user, userField);

                condition = StringTools.replace(condition, 'user.' + userField, userValue);
            }

            if(resourceField != '')
            {
                var resourceValue = Reflect.field(resource, resourceField);
                condition = StringTools.replace(condition, 'resource.' + resourceField , resourceValue);
            }

            return executeQuery(condition);
        }
        else  if(condition.indexOf("resource") == 0)
        {
            condition = Utils.stripSpaces(condition);

            var reg = ~/[><]{0,1}=/;

            var operands = reg.split(condition);

            if(operands.length == 2)
            {
                var resourceParts = operands[0].split('.');

                if(resourceParts.length != 2)
                    throw "wrong expression, resource does not have a field attached to it";
                
                var userParts = operands[1].split('.');

                if(userParts.length != 2)
                    throw "wrong expression, user does not have a field attached to it";

                if(userParts[0] != 'user')
                    throw "user object was not detected in the records expression";

                var resourcePart = Reflect.field(resource, resourceParts[1]);

                if(resourcePart == null)
                {
                     return 0;
                }
                   

                var userPart = Reflect.field(user, userParts[1]);

                if(userPart == null)
                {
                    return 0;
                }
                   
                if(condition.indexOf(">=") != -1)
                {
                    return (resourcePart >= userPart ? 1:0);
                }
                else if(condition.indexOf("<=") != -1)
                {
                        return (resourcePart <= userPart ? 1:0);
                }
                else if(condition.indexOf(">") != -1)
                {
                        return (resourcePart > userPart ? 1:0);
                }
                else if(condition.indexOf("<") != -1)
                {
                        return (resourcePart < userPart ? 1:0);
                }
                else if(condition.indexOf("=") != -1)
                {
                    return (resourcePart == userPart ? 1:0);
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

    private function extractFieldName(statement:String, obj:String):String
    {
        var len1 = statement.indexOf(obj + '.') + (obj + '.').length;
        var len2 = statement.length;
        var field = '';

        for(i in len1...len2)
        {
            if(StringTools.isSpace(statement, i))
                break;
            else
                field += statement.charAt(i);
        }

        return field;
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

        sql = connection.escape(sql);

        try
        {
            records = connection.request(sql);
        }
        catch(err:String){
            return 0;
        }
        if(records == null || records.results() == null)
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
