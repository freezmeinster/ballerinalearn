import ballerina/http;
import ballerina/io;

public function main() returns @tainted error? {
	http:Client helloClient = new("http://localhost:7070/hello");
	http:Response helloResp = check helloClient->get("/sayHello");
	io:println(check helloResp.getTextPayload());
}
