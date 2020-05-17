import ballerina/config;
import ballerina/http;
import ballerinax/java.jdbc;
import ballerina/lang.'int as ints;
import ballerina/log;

listener http:Listener httpListener = new(7071);

type Product record {
    string name;
    int price;
    int productId;
};

// Create SQL client for Postgresql database
jdbc:Client productDB = new ({
    url: config:getAsString("DATABASE_URL", "jdbc:postgresql://localhost:5432/cloud_erp"),
    username: config:getAsString("DATABASE_USERNAME", "bram"),
    password: config:getAsString("DATABASE_PASSWORD", "bram"),
    poolOptions: { maximumPoolSize: 5 },
    dbOptions: { useSSL: false }
});

// Service for the employee data service
@http:ServiceConfig {
    basePath: "/records"
}
service ProductData on httpListener {

    @http:ResourceConfig {
        methods: ["POST"],
        path: "/product/"
    }
    resource function addProductResource(http:Caller httpCaller, http:Request request) {
        // Initialize an empty http response message
        http:Response response = new;

        // Extract the data from the request payload
        var payloadJson = request.getJsonPayload();

        if (payloadJson is json) {
            Product|error productData = Product.constructFrom(payloadJson);

            if (productData is Product) {
                // Validate JSON payload
                if (productData.name == "" || productData.price ==0 || productData.productId == 0) {
                        response.statusCode = 400;
                        response.setPayload("Error: JSON payload should contain " + "{name:<string>, age:<int>, ssn:<123456>, productId:<int>");
                } else {
                    // Invoke insertData function to save data in the MySQL database
                    json ret = insertData(productData.name, productData.price, productData.productId);
                    // Send the response back to the client with the employee data
                    response.setPayload(ret);
                }
            } else {
                // Send an error response in case of a conversion failure
                response.statusCode = 400;
                response.setPayload("Error: Please send the JSON payload in the correct format");
            }
        } else {
            // Send an error response in case of an error in retriving the request payload
            response.statusCode = 500;
            response.setPayload("Error: An internal error occurred");
        }
        var respondRet = httpCaller->respond(response);
        if (respondRet is error) {
            // Log the error for the service maintainers.
            log:printError("Error responding to the client", err = respondRet);
        }
    }

    @http:ResourceConfig {
        methods: ["GET"],
        path: "/product/{productId}"
    }
    resource function retrieveProductResource(http:Caller httpCaller, http:Request request, string
        productId) {
        // Initialize an empty http response message
        http:Response response = new;
        // Convert the productId string to integer
        var empID = ints:fromString(productId);
        if (empID is int) {
            // Invoke retrieveById function to retrieve data from MYSQL database
            var productData = retrieveById(empID);
            // Send the response back to the client with the employee data
            response.setPayload(productData);
        } else {
            response.statusCode = 400;
            response.setPayload("Error: productId parameter should be a valid integer");
        }
        var respondRet = httpCaller->respond(response);
        if (respondRet is error) {
            // Log the error for the service maintainers.
            log:printError("Error responding to the client", err = respondRet);
        }
    }

    @http:ResourceConfig {
        methods: ["PUT"],
        path: "/product/"
    }
    resource function updateProductResource(http:Caller httpCaller, http:Request request) {
        // Initialize an empty http response message
        http:Response response = new;

        // Extract the data from the request payload
        var payloadJson = request.getJsonPayload();
        if (payloadJson is json) {
            Product|error productData = Product.constructFrom(payloadJson);

            if (productData is Product) {
                if (productData.name == "" || productData.price == 0 || productData.productId == 0) {
                    response.setPayload("Error : json payload should contain {name:<string>, price:<int>, productId:<int>}");
                    response.statusCode = 400;
                } else {
                    // Invoke updateData function to update data in mysql database
                    json ret = updateData(productData.name, productData.price, productData.productId);
                    // Send the response back to the client with the employee data
                    response.setPayload(ret);
                }
            } else {
                // Send an error response in case of a conversion failure
                response.statusCode = 400;
                response.setPayload("Error: Please send the JSON payload in the correct format");
            }
        } else {
            // Send an error response in case of an error in retriving the request payload
            response.statusCode = 500;
            response.setPayload("Error: An internal error occurred");
        }
        var respondRet = httpCaller->respond(response);
        if (respondRet is error) {
            // Log the error for the service maintainers.
            log:printError("Error responding to the client", err = respondRet);
        }
    }

    @http:ResourceConfig {
        methods: ["DELETE"],
        path: "/product/{productId}"
    }
    resource function deleteProductResource(http:Caller httpCaller, http:Request request, string
        productId) {
        // Initialize an empty http response message
        http:Response response = new;
        // Convert the productId string to integer
        var prdID = ints:fromString(productId);
        if (prdID is int) {
            var deleteStatus = deleteData(prdID);
            // Send the response back to the client with the employee data
            response.setPayload(deleteStatus);
        } else {
            response.statusCode = 400;
            response.setPayload("Error: productId parameter should be a valid integer");
        }
        var respondRet = httpCaller->respond(response);
        if (respondRet is error) {
            // Log the error for the service maintainers.
            log:printError("Error responding to the client", err = respondRet);
        }
    }
}

public function insertData(string name, int price, int productId) returns (json) {
    json updateStatus;
    string sqlString =
    "INSERT INTO PRODUCTS (Name, Price, ProductID) VALUES (?,?,?)";
    // Insert data to SQL database by invoking update action
    var ret = productDB->update(sqlString, name, price, productId);
    // Check type to verify the validity of the result from database
    if (ret is jdbc:UpdateResult) {
        updateStatus = { "Status": "Data Inserted Successfully" };
    } else {
        updateStatus = { "Status": "Data Not Inserted", "Error": "Error occurred in data update" };
        // Log the error for the service maintainers.
        log:printError("Error occurred in data update", err = ret);
    }
    return updateStatus;
}

public function retrieveById(int productID) returns (json) {
    json jsonReturnValue = {};
    string sqlString = "SELECT * FROM PRODUCTS WHERE ProductID = ?";
    // Retrieve employee data by invoking select remote function defined in ballerina sql client
    var ret = productDB->select(sqlString, (), productID);
    if (ret is table<record {}>) {
        // Convert the sql data table into JSON using type conversion
        var jsonConvertRet = json.constructFrom(ret);
        if (jsonConvertRet is json) {
            jsonReturnValue = jsonConvertRet;
        } else {
            jsonReturnValue = { "Status": "Data Not Found", "Error": "Error occurred in data conversion" };
            log:printError("Error occurred in data conversion", err = jsonConvertRet);
        }
    } else {
        jsonReturnValue = { "Status": "Data Not Found", "Error": "Error occurred in data retrieval" };
        log:printError("Error occurred in data retrieval", err = ret);
    }
    return jsonReturnValue;
}

public function updateData(string name, int price, int productId) returns (json) {
    json updateStatus;
    string sqlString =
    "UPDATE PRODUCTS SET Name = ?, Price = ?, WHERE ProductID  = ?";
    // Update existing data by invoking update remote function defined in ballerina sql client
    var ret = productDB->update(sqlString, name, price, productId);
    if (ret is jdbc:UpdateResult) {
        if (ret["updatedRowCount"] > 0) {
            updateStatus = { "Status": "Data Updated Successfully" };
        } else {
            updateStatus = { "Status": "Data Not Updated" };
        }
    } else {
        updateStatus = { "Status": "Data Not Updated",  "Error": "Error occurred during update operation" };
        // Log the error for the service maintainers.
        log:printError("Error occurred during update operation", err = ret);
    }
    return updateStatus;
}

public function deleteData(int productID) returns (json) {
    json updateStatus;

    string sqlString = "DELETE FROM PRODUCTS WHERE ProductID = ?";
    // Delete existing data by invoking update remote function defined in ballerina sql client
    var ret = productDB->update(sqlString, productID);
    if (ret is jdbc:UpdateResult) {
        updateStatus = { "Status": "Data Deleted Successfully" };
    } else {
        updateStatus = { "Status": "Data Not Deleted",  "Error": "Error occurred during delete operation" };
        // Log the error for the service maintainers.
        log:printError("Error occurred during delete operation", err = ret);
    }
    return updateStatus;
}

