import Grant.Policy;
import Grant.Schema;
import Grant.Conditions;
import Grant.Condition;


class PolicyBuilder
{

    public function new()
    {
        
    }

    public static function build(jsonData:String):Schema
    {
        var schema:Schema;
        try
        {
             schema = haxe.Json.parse(jsonData);
             
             for(role in schema.accesscontrol)
             {
                 for (resource in role.grant)
                 {
                     for (policy in resource.policies)
                     {
                         policy.fields = checkFields(policy.fields);
                         policy.conditions = parseConditions(Utils.stripSpaces(policy.records));
                         policy.limit.conditions = parseConditions(policy.limit.rule);

                         if(policy.limit.conditions.list.length > 1)
                             throw "no more than one condition is allowed in limit rule.";
                     }
                     //do not use auto priority now
                    // resource.policies = priorotizePolicies(resource.policies);
                 }
             }
        }
        catch(ex:String)
        {
            throw "Invalid Json format";
        }
        return schema;
    }

    private static function priorotizePolicies(policies:Array<Policy>):Array<Policy>
    {
        var priorotized = new Array<Policy>();
        var leastPriority = new Array<Policy>();
        var priorityValue = new Array<Int>();

        var maxPriority = 1000;

        for(policy in policies)
        {
            if(policy.records.toLowerCase() == 'any')
                priorotized.push(policy);
            else if(policy.records.toLowerCase() == 'none')
                leastPriority.push(policy);
            else
            {
                var pFields = policy.fields.split(',');
                if(pFields[0] == '*')
                    priorityValue.push(maxPriority-pFields.length);
                else
                    priorityValue.push(pFields.length);
            }
           
        }

        while(priorityValue.length > 0)
        {
            var indexBiggest = Utils.maxIndex(priorityValue);
            priorotized.push(policies[indexBiggest]);
            priorityValue.splice(indexBiggest, 1);
        }

        for(lp in leastPriority)
        {
            priorotized.push(lp);
        }
        return priorotized;
        
    }
    private static function parseConditions(cond:String):Conditions
    {
        var len = cond.length;
        var conditionPart = 0;

        var allowedOperators = ["=", "!", ">", "<", ")", "("];

        var condition:Condition = {resource1: "", field1:"", operator:"", resource2:"", field2:""};
        var allConditions:Conditions = {list : new Array<Condition>(), operators: new Array<String>()}

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
            
                allConditions.list.push(con1);
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
            allConditions.list.push(condition);
        else{
            throw "a field is empty in the last expression";
        }
    
        return allConditions;
    }

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
                if(Utils.linearSearch(includedFields, field) == -1)
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

}