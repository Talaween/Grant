# Grant HX  ![build passing](https://raw.githubusercontent.com/dwyl/repo-badges/master/highresPNGs/build-passing.png)

Role-based Access Control (RBAC) Library for Haxe, Inspired from [accesscontrol](https://www.npmjs.com/package/accesscontrol) Library on npm, however Grant HX brings more flexibity and features to manage RBAC.

The idea of Grant is that all RBAC should be kept outside the code, it is maintained in a JSON file. RBAC can be easily changed by only modifying the JSON data.

Currently the library works with PHP and MYSQL target, in future release it will be available for Node.JS, Python, JAVA and C# targets

## Features

* all RBAC logic maintained in a single JSON file
* friendly json format and structure
* only two lines of code are needed to be written to manage RBAC in code
* the library will do all the required database inquiries to check for the permissions
* ability to use the library without database checking
* fine-grained access control to specific records of a table by applying conditions 
* fine-grained access control to specific fields of a table by applying filters
* support inheritance of roles
* ability to assign more than one role to the users
* ability to assign more than one policy on the same resource for the same role
* ability to add limits to policy e.g. how many times to read a resource
* library automatically checks for JSON data validity and warns of any errors
* library automatically prioritize policies based on their access level
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

```
//get grant instance
var grant = Grant.getInstance();

//if you want Grant to manage RBAC by accessing database 
//you need to provide connection to the databse
grant.setConnection(connection);

//first function to use is mayAccess
//this function return a permission object that hold the RBAC data
//the initial result is stored in permission.granted 
//the value is true if there is a chance the user may access the resource
//otherwise it is false
//please note further database check is needed to confirm access to the resource
var permission = grant.mayAccess('guest', 'read', 'article');

```

## Running the tests

TODO add unit testing

## Built With

* [Haxe](http://www.haxe.org/) - The language used

## Contributing

Please feel free to submit pull requests to us.


## Authors

* **Mahmoud Awad** - *Initial work* - [Talaween](https://github.com/talaween)

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

* Haxe Community
* [accesscontrol](https://www.npmjs.com/package/accesscontrol) Lib on NPM





