
/**
 * ...
 * @author Mahmoud Awad
 */

 import sys.db.Connection;

typedef CreatePolicy = {limit:Int, withField:String};
typedef UpdatePolicy = {records:String, fields:String, limit:Int, withField:String}; 
typedef ReadPolicy = {records:String, fields:String, limit:Int, withField:String}; 
typedef DeletePolicy = {records:String};   
typedef Resource = {name:String, create:CreatePolicy, update:UpdatePolicy, read:ReadPolicy, delete:DeletePolicy};
typedef Role = {name:String, grant:Array<Resource>};    
    
class Grant 
{
    private static var _instance:Grant;

    private var _schema:{accesscontrol:Array<Role>};

    private var _dbConnection:Connection;

    public static function getInstance(?connection:Connection):Grant
    {
        if (_instance == null)
            _instance = new Grant(connection);

        return _instance;
    }
    
    private function new(connection)
    {

        _dbConnection = connection;
    }
    
    public function buildPolicy(schema:String)
    {
        try
        {
             _schema = haxe.Json.parse(schema);
        }
        catch(ex:String)
        {
            throw "Invalid Json format";
        }
    }
    
    public function access(user:Dynamic, action:String, resource:Dynamic):Permission
    {
        
        var role= "";

        if(user.role == null)
        {
            throw ('user object has no role property');
            return new Permission(false, action, "");
        }
        else
            role = user.role;
        
        var resourceName = Type.getClassName(resource);

        //find the role object in the schema
        var _thisRole:Role = null;
        for(_r in _schema.accesscontrol)
        {
            if(_r.name == role)
                _thisRole = _r;
        }
        
        if(_thisRole == null)
            return  new Permission(false, action, "");

        //find the resource policies in the schema
        var _policies:Resource = null;
        
        for(_p in _thisRole.grant)
        {
            if(_p.name == resource)
                _policies = _p;
        }
              
        if(_policies == null)
        {
            return  new Permission(false, action, "");
        }
            
        //check the action

        action = action.toUpperCase();

        switch(action)
        {
            case "CREATE":
                //check which fields the role can create
                //check limits
                if(_policies.create.limit == -1)
                {
                    //we do not care about limit
                    return new Permission(true, "Create", "*");
                }
                else if(_policies.create.limit > 0)
                {
                    if(_dbConnection == null)
                    {
                        throw "No connection to db provided, grant needs to check create action limit";
                        return  new Permission(false, action, "");
                    }  
                }    
                else
                {
                    //user not allowed to create, limit is 0
                    return new Permission(false, action, "");
                }
            case "READ":
                //check if this record accessible by user for reading
                try
                {
                    var allow = checkRecord(_policies.read.records, user, resource, resourceName);
                    if(allow)
                    {
                        //now we need to know which fields
                        return new Permission(true, "Read", checkFields(_policies.read.fields));
                    }
                    else
                        return  new Permission(false, "Read", "");
                }
                catch(err:String)
                {
                    throw err;
                    return  new Permission(false, "Read", "");
                }
            case "UPDATE":
            case "DELETE":
        }//end switch
        
        return  new Permission(false, action, "");     
    }

    private function checkRecord(user:Dynamic, rule:String, resource:Dynamic, resourceName:String):Bool{
        
        rule = rule.toLowerCase();
        rule = StringTools.trim(rule);
        resourceName = resourceName.toLowerCase();

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
            var conditions = rule.split('&');
            var conLen = conditions.length;

            if(conLen == 1)
            {
                
                //we have only one condition
                //resources involved in the cndition are the user and the resource
                //example: resource.ownerId = user.id

                //we need to know the name of the field associated with user
                var userField = "";
                //the name of the field associated with resource
                var resourceField = "";
                //split the operands of the condition 
                var operands = conditions[0].split("=");
                if(operands.length != 2)
                {
                    throw "records expression is wrong, less or more than two operands: " + rule;
                    return false;
                }
                else
                {
                    //make sure one operand is the resource name and the other is the user
                    operands[0] =  StringTools.trim(operands[0]);
                    var operand1Parts = operands[0].split(".");
                    if(operand1Parts.length != 2)
                    {
                        throw "records expression is wrong, dot notation is wrong at operand 1: " + rule;
                        return false;
                    }
                    if(operand1Parts[0] != 'user')
                    {
                        if(operand1Parts[0] != resourceName)
                        {
                            throw "record expression is wrong, unknown resource on operand 1: " + rule;
                            return false;
                        }
                        else
                        {
                            resourceField =  StringTools.trim(operand1Parts[1]); 
                        }   
                    }
                    else
                    {
                        userField =  StringTools.trim(operand1Parts[1]);
                    }
                    operands[1] =  StringTools.trim(operands[1]);
                    var operand2Parts = operands[1].split(".");
                    if(operand2Parts.length != 2)
                    {
                        throw "records expression is wrong, dot notation is wrong at operand 2: " + rule;
                        return false;
                    }
                    
                    if(operand2Parts[0] != 'User')
                    {
                        if(operand2Parts[0] != resourceName)
                        {
                            throw "record expression is wrong, unknown resource on operand 2: " + rule;
                            return false;
                        }
                        else
                        {
                            resourceField =  StringTools.trim(operand2Parts[1]); 
                        }
                    }
                    else
                    {
                         userField =  StringTools.trim(operand2Parts[1]);
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
            } //end if conditions == 1
            else if(conLen == 2)
            {
                //case we have three resources
                //example pupilTasks.pupilId = pupil.id & pupilTask.taskId = task.id
                return false;
            }
            else
            {
                throw "wrong expression, more than two conditions are not yet supported.";
                return false;
            }
                
        }
    } //end checkRecords

    private function checkFields(fields:String):String
    {

        var fieldsArray = fields.split(",");
        var includedFields = new Array<String>();
        var excludedFields = new Array<String>();
        var allFieldsUsed = false;

        for(field in fieldsArray)
        {
            field = StringTools.trim(field);
            if(field == "*")
            {
                allFieldsUsed = true;
            }
            else if(field.charAt(0) != '!')
            {
                if(Utils.linearSearch(includedFields, field) == -1)
                {
                    includedFields.push(field);
                }
            }
            else 
            {
                if(Utils.linearSearch(excludedFields, field) == -1)
                {
                    includedFields.push(field);
                }
            }
        }
        
        var finalFields = "";

        if(allFieldsUsed)
            finalFields = "*" + "," + Std.string(excludedFields);
        else
            finalFields = Std.string(includedFields);

       return finalFields; 
    }  
}
