import ballerina/http;
import ballerina/io;

service hello on new http:Listener(7070) {

	resource function sayHello(http:Caller caller, http:Request req){
		
		error? result = caller->respond("Hallo NGuk");
		
		if (result is error){
			io:println("Error in response: ", result);
		}
	}
}
