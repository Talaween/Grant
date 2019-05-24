
/**
 * ...
 * @author Mahmoud Awad
 */

 class Permission {

     //read only property granted
    private var _granted:Bool;
    private var _action:String;
    private var _fields:String;
    private var _message:String;

    public function new(granted:Bool, action:String, fields:String, ?message:String){
        _granted = granted;
        _action = action;
        _fields = fields;
        _message = message;
    }
    
    public function filter(resource:Dynamic){

         //create a new object 

     }
     
 }