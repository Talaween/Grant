# Grant HX  
<a href="#"><img src="https://img.shields.io/travis/onury/accesscontrol.svg?branch=master&style=flat-square" alt="Build Status" /></a>

### WIP not yet ready for production

Role-based Access Control (RBAC) Library for Haxe, Inspired from [accesscontrol](https://www.npmjs.com/package/accesscontrol) Library on npm, however Grant HX brings more flexibity and features to manage RBAC.

The idea of Grant is that all RBAC should be kept outside the code, it is maintained in a JSON file. RBAC can be easily changed by only modifying the JSON data.

Currently the library works with PHP and MYSQL target, in future release it will be available for Node.JS, Python, JAVA and C# targets

## Features

* all RBAC logic maintained in a single JSON file
* friendly json format and structure
* only few lines of code are needed to be written to manage RBAC in code
* the library will do all the required database inquiries to check for the permissions
* ability to use the library without database checking
* fine-grained access control to specific records of a table by applying conditions 
* fine-grained access control to specific fields of a table by applying filters
* support inheritance of roles
* ability to assign more than one policy on the same resource for the same role
* ability to add limits to policy e.g. how many times to read a resource
* library automatically checks for JSON data validity and warns of any errors
* fast and performs well
* works with any Haxe class including record macros and anonomous structures
* supports PHP and MYSQL targets
* does not depend on any other Haxe library
* ability to manage sub-object access control as well e.g. resource1.resource2

### Installing

Install through haxe lib

```
haxelib install Grant
```
### how to use

```js
//get grant instance

var grant = Grant.getInstance();

//set connection if you want Grant to manage RBAC by accessing database 

grant.setConnection(connection);

//build the policy stored in json file

var textualJsonData = sys.io.File.getContent('/path/to/json/policies/file.json');
grant.buildPolicy(textualJsonData);

//check if a role may access a resource
//this function return a permission object that holds the RBAC data
//the initial result is stored in permission.granted property
//the value is true if there is a chance the user may access the resource
//otherwise the value is false
//please note further database checks is needed to confirm access to the resource

var permission = grant.mayAccess('guest', 'read', 'article');

//then you can use the permission object to actually access the resource
//you need to supply the user object and it should has a role propery that matches the same role used to create 
//the permission object, if user has no role property an exception is thrown
//you also need to supply the resource the user would like to access
//the return value is a new object based on what the user can access from the resource

var accessibleObject = grant.access(user, permission, article);

//in case you want to know which fields the user can access for the specified action

var fields = permsision.getFields();

//you can also filter what user can access from resource without having Grant to access DB
// in this case you will need to do the actual check for user permission by yourself
//e.g. is the user actual owner?

var accessibleObject = permission.filter(user, article);

```

### Roles for Json file structure

all access control data are stored in a json file, it is your resposibility to prevent access or modifications to this file

Grant checks the policy for validity the first time you build it with buildPolicy function. it will throw errors if it finds any error in the policy structure. the strucure is easy, the json file has the following object:

```js

{"accesscontrol": Array<Roles>}

```
the main propery called accesscontrol is an array of Role objects, the Role object is as follow:

```js

{"role": String, "inherits":String, "grant":Array<Resource>}

```

the Role object has the following properties:

* role: name of the role
* inherits: an optional field which is the name of the role to extend/inherit from
* grant: an array of Resource objects

the Resource object has the following structure and fields:

```js

{"resource": String, "policies":Array<Policy>}

```

* resource: the name of the resource
* policies: an array of Policy objects

the Policy object has the following structure and fields:

```js

{"action": String, "fields":String, "records":String, "limit":Limit}

```

* action: one of the following create/read/update/delete
* fields: the fields the role can access from the resource, writting in this format e.g. "title, mainText, publishedDate". you can also specify all fields "*" and exclude some fields with "!", e.g. "*, !note"
* records: the condition(s) that allow the role to access this resource, see below for explanations on conditions
* limit: is a Limit object

the Limit object has the following structure and fields:

```js

{"amount": Int, "rule":String}

```

* amount: the number of times the role can perform the action on the resource, use -1 for unlimited, 0 can be used to ban
* rule: the condition need to cound the limit, see below for explanations on conditions

you can specify more than one role on the same resource for the same role, using the record property allow you to decide which rows/records int he table the user can acess. for example an author role will allow the user to read any article and see its title, textBody and publishedDate, and another read policy that is applied to his own created articles where he will be able to see title, textBody, publishedDate and some notes.

### Conditions

the conditions can be specified on two fields:

* record field of a Policy object
* rule field of a limit object

the condition allows Grant to decide whether the user has access to a specific row/recod in the table or has reached the limit. in other words, conditions is the part that you may use after WHERE clause in a SQL statement

there are few simple rules how to write your conditions to ensure that Grant can get the correct answer for you:

if you are checking any values that is on User or the actual resource object then you should use the following syntax:

e.g. check if the user is the actual author of the article

```js
....
"records" : "article.auhthorId=user.Id",
....
```
note that we have used the word  "user" to refer to the User obejct and the actual resource name as it appears in the json file (case-sensitive) bacuause we are accessing the values directly from the objects so no need to connect to database.

if you are checking values from any other tables, then you have to use the table name as it is appears in the database, remeber user and resource values can be used with table names in conditons but they always need to be on the left side of the condition 

e.g. check if the user can access a picture which only allowed for users who were tagged in it:

```js
....
"records" : "tags.imageId=picture.id&tags.userId=user.Id",
....
```

assuming the user with Id 7 trying to access the picture with Id 145, the following select statement will be generated and executed in the database:

```sql
"SELECT count(*) FROM tags WHERE imageId = 145 AND userId=7"
```

in this example there should be a table called tags in the database which has fields imageId and userId.

you can chain consitions using "&" and "|" operators. currently using paranthesis "(" ")" to group conditions does not work.

When building the policy; Grant throws exception if there is an syntax error in any condition. 

the same apply to the conditions set for the Limit object, however here you set the condition to count the limit, which will always require connecting to the database:

e.g. if user not allowed to create more than 10 articles, the conditon should be:

```js
....
"records" : "article.authorId=user.Id",
....
```
even though we refer to the resource and user objects, this will make Grant to generate the following SQL statement:

```sql
"SELECT count(*) FROM article WHERE authorId = 7"
```

note that placing article.authorId on the right side of the condition is important to generate the correct sql statement

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
* [accesscontrol](https://www.npmjs.com/package/accesscontrol) Lib on NPM





