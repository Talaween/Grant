# Grant HX  
<a href="#"><img src="https://img.shields.io/travis/onury/accesscontrol.svg?branch=master&style=flat-square" alt="Build Status" /></a>

### WIP currently going through heavy testing

Role-based Access Control (RBAC) Library for Haxe, that allows you to manage all your RBAC in an easy and flexible way.

The idea of Grant is that all RBAC should be kept outside the code, it is maintained in a JSON file. RBAC can be easily changed by only modifying the JSON data. however Grant allows you to have your RBAC logic in the code as well.

Currently the library works with PHP and MYSQL, in future release it will be available for Node.JS, Python, JAVA and C#.

## Features

* all RBAC logic maintained in a single JSON file or a JSON object
* friendly json format and structure
* only few lines of code are needed to be written to manage RBAC in code
* the library will do all the required database operations to check for the permissions
* ability to use the library without database checking
* fine-grained access control to specific records of a table by applying conditions 
* fine-grained access control to specific fields of a table by applying filters
* ability to add more than one policy per role to the same table to access different records 
* support inheritance of roles
* ability to add limits to policy e.g. how many times to read a resource
* library automatically checks for JSON data validity and warns of any errors
* fast and performs well
* works with any Haxe class including record macros and anonomous structures
* supports PHP and MYSQL
* does not depend on any other Haxe library
* ability to manage sub-object access control as well e.g. resource1.resource2

### Installing

Install through haxe lib

```
haxelib install Grant
```
### how to use

get grant instance

```js
var grant = Grant.getInstance();
```
Get instance has the following signature:

```js
    public static function getInstance(?params:{user:String,?socket:Null<String>,?port:Null<Int>,pass:String,host:String,database:String}):Grant
```
It takes the required information to connect to the database as optional parameters. if your policies require verification through databas then you can let Grant access the database, more on this below.

You can build a policy stored in a json file

```js
var textualJsonData = sys.io.File.getContent('/path/to/json/policies/file.json');
grant.fromJson(textualJsonData);

```

or can build policy using an object of type Schema, more details are below

```js
grant.setSchema(schema);

```
where the function fromJson accepts an anonymous structure of type grant.Schema;

then to check if a role may access a resource use for example:

```js

public function mayAccess(role:String, action:String, resourceName:String):Permission

//an example how to use it in the code
var permission = grant.mayAccess('guest', 'read', 'article');

```

mayAccess function returns a permission object that holds the RBAC data where the initial result is stored in (permission.granted) property, the value is true if there is a chance that the user may access the resource otherwise the value is false (it is true if the user has access to some records in the table)
please note further database checks maybe needed to confirm access to the resource or the exact record.

To access the actual resource or record, you will use the permission object with the user object and the resource object. please note that the user object should have a propery called role, if user does not have a role property then an exception is thrown.

```js
public function access(user:Dynamic, permission:Permission, resource:Dynamic, connection:Connection):Dynamic

//an example of how to use it in the code
var accessibleObject = grant.access(user, permission, article, connection);

```

in case you want to know which fields the user can access for the specified action (read, create, update, delete)

```js
public function fields():Array<String>

//an example how use it in the code
var fields = permsision.fields();

```

you can also filter what user can access from the resource, in this case you will need to do the actual check for user permission by yourself for example if the user is the owner.

```js
public function filter(user:Dynamic, resource:Dynamic, connection:Connection):Dynamic

//an example of how to use it in the code
var accessibleObject = permission.filter(user, article);

```
filter function returns a new object that have only what the user can access from the resource based on the defined access policy.

### Understanding Access Control Schema

all access control data are stored in a json file or an anonymous structure in the code, if it is in a json file then it is your resposibility to prevent access or modifications to this file

The top level object of the schema is as follow, which has only one property called "accesscontrol" which is an arrya of roles.

```js

{"accesscontrol": Array<Roles>}

```
the Role object has the following properties:

* role: name of the role
* inherits: an optional field which is the name of the role to extend/inherit from
* grant: an array of Resource objects which the user role can access

```js

{"role": String, "inherits":String, "grant":Array<Resource>}

```

the Resource object has the following structure and fields:

```js

{"resource": String, "policies":Array<Policy>}

```

* resource: the name of the resource
* policies: an array of Policy objects to be applied on the resource

the Policy object has the following structure and fields:

```js

{"action": String, "fields":String, "records":String, "limit":Limit}

```

* action: one of the following create/read/update/delete
* fields: the fields the role can access from this resource, the fields should be separted by comma e.g. "title, mainText, publishedDate". you can also specify all fields "*" and exclude some fields with "!", e.g. "*, !publishedDate"
* records: the condition(s) that allow the role to access this resource, see below for explanations on conditions
* limit: is a Limit object to count how many times a role can perform the specified action on the resource

You can apply more than one policy for the same rule on the same resource, with each Policy gives the user a different access to a subset of records, for example one Policy allows user to read all the fields of his own articles, another policy to read a subset of fields for articles he does not own.
The order how you add policies on the same resource is important, If you have more than one policy on the same resource, Grant always execute the first policy that give the user access to the record.

the Limit object has the following structure and fields:

```js

{"amount": Int, "rule":String}

```

* amount: the number of times the role can perform the action on the resource, use -1 for unlimited, 0 can be used to ban
* rule: the condition need to count the limit, see below for explanations on conditions

you can specify more than one policy on the same resource for the same role, so that the role can access different records in different manner, the record property of Policy object allows you to decide which rows/records in the table the user can acess. for example an author role will allow the user to read any article and see its title, textBody and publishedDate, and another read policy that is applied to his own created articles where he will be able to see title, textBody, publishedDate and notes.

### Sub Object Permissions

you can control sub-object permission (currently to one level) by Grant.

for example if you have a resource called Comment which also has an article and user object associated with it, you can ask Grant to apply the available policies for these resources that are available for the current user by identifying the sub-object with '^' operator as follow:

```js
{
    "action" : "read",
    "records": "any",
    "fields" : "commentText, publishedDate, author^User, article^Article",
    "limit" : {
        "amount": -1,
        "rule" :""
    }
},
```

now Grant will look for what User policy is available for the current user and apply it on the author field, and the same for article, if Grant cannot find any policies or the current policy does not allow access the resource then that sub-object will not appear.

if you do not apply the "^" operator no access control policy will be applied to the sub-object and it will returned as it is if the user is allowed access the sub-object in the current policy.

### Conditions

the conditions is very important part of how Grant works, it allows you to specified how to access a specific record, it is in fact allow you to filter which records/rows of a table a user may access and how. 

conditions can be specified on two fields:

* records field of a Policy object
* rule field of a Limit object

you can specify values directly from the user obejct or the resource object, add a select statement to the condition or combine both. 

there are few simple rules how to write your conditions to ensure that Grant can get the correct answer for you:

if you are checking any values that is on User or the actual resource object then you should use the following syntax:

e.g. check if the user is the actual author of the article

```js
....
"records" : "$resource.auhthorId=$user.Id",
....
```
note that we have used the word  "user" to refer to the actual User obejct currently trying to access the resource, and the resource word to refer the current resource object.

you can also add static values:

```js
....
"records" : "$resource.price >= 20/i",
....
```

note that you have to add a tailing flag to indicate the type of the value:

* /i for integer e.g. 20/i
* /f for float e.g. 13.5/f
* /b for boolean e.g. true/b
* /d for date e.g. 2019-07-14/d

otherwise the value will be treated as a string

the comparison operator can be one of the following (>, >=, <, <=, ==, =, !=), where = or == will be the same.

if you are checking values from any other tables or objects, then you have to use a SQL select statement 

e.g. check if the user can access a picture which only allowed for users who were tagged in it:

```js
....
"records" : "Select count(*) From tags where tags.userId = $user.id And tags.pictureId = $resource.id",
....
```
if the length of result for this SQL is more than 1, it will be evaluated as true otherwise false.

you can combine both examples of conditions using either | & operators:

```js
....
"records" : "$resource.auhthorId=$user.Id | Select * From tags where tags.userId = $user.id And tags.pictureId = $resource.id",
....
```
### Limits

The Limit object provides a condition to count how many time a policy can be valid before it expires, the amount property specifies the maximum number to execute the policy, while in the "rule" property, you should use a SQL SELECT statement that counts the number of times the user role has accessed the object, for example allowing a user to only create maximum 5 articles :

```js
....
"amount" : "5",
"rule" : "SELECT count(*) From Articles where Articles.authorId=$user.id"
....
```
in this example if the SQL statement returns a result less than 5 the user will be able to access and to perform the action on the resource.


### Building the Policy in the code

if you wish you can build the policy inside the code rather than importing it from a json file.

you can use the following functions to build your schema:

* Grant.setSchma(schema:Schema)
* Grant.addRole(role:Role)
* Grant.assignToRole(roleName:String, resource:Resource)

### Policies examples

update all fields on own resource:

```js
{
    "action" : "update",
    "records": "$resource.id=$user.id",
    "fields" : "*",
    "limit" : {
        "amount": -1,
        "rule" :""
    }
}
```

read selected fields on an own resource to be read maximum 5 times:

```js
{
    "action" : "read",
    "records": "$resource.ownerId=$user.id",
    "fields" : "field1, field2, field3",
    "limit" : {
        "amount": 5,
        "rule" :"SELECT count(*) FROM ResourceTable WHERE ownerId = $user.id"
    }
}
```

create a tag on own articles, where articles are stored in a table called Article:

```js
{
    "action":"create", 
    "records":"SELECT * FROM Article WHERE Article.Id=$resource.articleId AND Article.authorId=$user.id", "fields":"*", 
    "limit": {
        "amount":-1, 
        "rule":"$resource.articleId"
    }
};
```

### Additional policies

You can let Grant verify a policy that is not part of your schema using 

```js
public function checkPolicy(user:Dynamic, policy:Policy, resource:Dynamic):Bool

```

### Built With

* [Haxe](http://www.haxe.org/) - The language used

### Contributing

Please feel free to submit pull requests to us.


### Authors

* **Mahmoud Awad** - *Initial work* - [Talaween](https://github.com/talaween)

### License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

### Acknowledgments

* Haxe Community





