import T "./types";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import List "mo:base/List";
module {
    let juno = actor ("svftd-daaaa-aaaal-adr3a-cai") : actor {
        set_doc : (Text, Text, T.DocInput) -> async ();
        get_doc : (Text, Text) -> async ?T.GetDocResponse;
        set_many_docs : (T.SetManyDocsInput) -> async ();
        get_many_docs : (T.GetManyDocsInput) -> async T.GetManyDocsResponse;
        list_docs : (Text, T.ListDocsFilter) -> async T.ListDocsResponse;
        del_doc : (Text, Text, { updated_at : ?Nat64 }) -> async ();
        del_many_docs : [(Text, Text, { updated_at : ?Nat64 })] -> async ();
    };

    // *******setJunoDoc********
    // Brief description: Interfaces with Juno to add or update a document in a collection, serving as a bridge for data storage.
    // Pre-Conditions: Caller must have permissions; `collection`, `key`, and `doc` parameters must be provided as per `DocInput`.
    // Post-conditions: Returns "Success!" upon successful operation, or an error message if the operation fails.
    // Validators: Error handling through try-catch; Juno's validation is assumed for document structure and permissions.
    // External functions using it: src/solutio_admin_backend/juno.bridge.mo.updateJunoDocument() .
    // Official Documentation:(https://forum.solutio.one/-152/setjunodoc-documentation)
    public func setJunoDoc(collection : Text, key : Text, doc : T.DocInput) : async Text {
        // if(msg.caller != Principal.fromText(Self)){}
        try {
            await juno.set_doc(collection, key, doc);
        } catch (errore) {
            let error = await handleErrors(errore);
            return error;
        };
        return "Success!";

    };

    // *******getJunoDoc********
    // Brief description: Retrieves a document from a specified collection in Juno, acting as a bridge for data retrieval.
    // Pre-Conditions: Caller must specify `collection` and `key` parameters correctly as per the expected document location.
    // Post-conditions: Returns #ok(response) with the document if found, or #err("Document Not Found") if not available or an error occurs.
    // Validators: Error handling through try-catch; relies on Juno for validating collection names and document keys.
    // External functions using it: None currently.
    // Official Documentation: [getJunoDoc Documentation](https://forum.solutio.one/-154/getjunodoc-documentation)
    public func getJunoDoc(collection : Text, key : Text) : async T.GetDocResult {
        try {
            let response = await juno.get_doc(collection, key);
            switch (response) {
                case (?response) {
                    // Handle the successful case
                    return #ok(response);
                };
                case null {
                    // Handle the case where the result is null
                    return #err("Document Not Found");
                };
            };
        } catch (errore) {
            let error = await handleErrors(errore);
            return #err(Error.message(errore));

        };
    };
    func handleErrors(errore : Error) : async Text {
        let error = Error.message(errore);
        return error;
    };

    // *******setManyJunoDocs********
    // Brief description: Facilitates batch creation or updating of documents in Juno, ensuring atomicity. Reverts all changes if any operation fails.
    // Pre-Conditions: Caller must have necessary permissions;`docs` must be structured as per `SetManyDocsInput`.
    // Post-conditions: Returns "Success!" if operations succeed, otherwise reverts changes and returns an error message.
    // Validators: Implicit validation through try-catch; relies on Juno canister for input validation.
    // External functions using it: None currently.
    // Official Documentation: https://forum.solutio.one/-153/setmanyjunodocs-documentation
    public func setManyJunoDocs(docs : T.SetManyDocsInput) : async Text {
        try {
            await juno.set_many_docs(docs);
        } catch (errore) {
            let error = await handleErrors(errore);
            return error;
        };
        return "Success!";
    };

    // *******getManyJunoDocs********
    // Brief description: Retrieves multiple documents from various collections in Juno, offering a bulk-fetching mechanism for efficiency.
    // Pre-Conditions: `docsInput` must be correctly structured as per `GetManyDocsInput` to specify the documents and collections to fetch.
    // Post-conditions: Returns #ok(response) with the documents if found; returns #err with an error message if an error occurs.
    // Validators: Utilizes try-catch for error handling; relies on Juno for input validation and ensuring atomicity in retrieval.
    // External functions using it: None currently.
    // Official Documentation: (https://forum.solutio.one/-155/getmanyjunodocs-documentation)
    public func getManyJunoDocs(docsInput : T.GetManyDocsInput) : async T.GetManyDocsResult {
        try {
            let response = await juno.get_many_docs(docsInput);
            return #ok(response);
        } catch (errore) {
            let error = await handleErrors(errore);
            return #err(Error.message(errore));

        };
    };

    // *******listJunoDocs********
    // Brief description: Retrieves a list of documents from a collection in Juno, supporting filtering, pagination, and sorting.
    // Pre-Conditions: `collection` parameter must specify the target collection; `filter` must be structured as per `ListDocs` for filtering and sorting.
    // Post-conditions: Returns #ok(response) with the list of documents matching the criteria; returns #err with an error message if an error occurs.
    // Validators: Employs try-catch for error management; depends on Juno to validate filtering, pagination, and sorting parameters.
    // External functions using it: None currently.
    // Official Documentation: [listJunoDocs Documentation](https://forum.solutio.one/-156/listjunodocs-documentation)
    public func listJunoDocs(collection : Text, filter : T.ListDocsFilter) : async T.ListDocsResult {
        try {
            let response = await juno.list_docs(collection, filter);
            return #ok(response);
        } catch (errore) {
            let error = await handleErrors(errore);
            return #err(Error.message(errore));

        };
    };

    // *******updateJunoDocument********
    // Brief description: Updates an existing document in Juno by ensuring it's the latest version using the updated_at timestamp.
    // Pre-Conditions: Requires `collection` and `key` to identify the document; `docsInput` must include the new data and description.
    // Post-conditions: Returns "Success" if update is successful; "Document not Found" if the document doesn't exist.
    // Validators: Checks for document existence and matches the updated_at timestamp for consistency.
    // External functions using it: None currently.
    // Official Documentation: [updateJunoDoc Documentation](https://forum.solutio.one/-160/updatejunodoc-documentation)
    public func updateJunoDocument(collection : Text, key : Text, docsInput : T.DocInput) : async Text {
        //This function first gets the updated_at number and then updates the doc with it.
        let doc : ?T.GetDocResponse = await juno.get_doc(collection, key);
        switch (doc) {
            case (null) {
                return "Document not Found";
            };
            case (?doc) {
                let updated_number = ?doc.updated_at;
                let newDocInput : T.DocInput = {
                    updated_at = updated_number;
                    data = docsInput.data;
                    description = docsInput.description;
                };
                let result : Text = await setJunoDoc(collection, key, newDocInput);
                return result;
            };
        };
        return "Success";
    };

    // *******updateManyJunoDocs********
    // Brief description: Atomically updates multiple documents across collections in Juno, ensuring data integrity with bulk updates.
    // Pre-Conditions: `docs` parameter must be provided as per `SetManyDocsInput`, specifying the documents to update.
    // Post-conditions: Returns "Success" if all documents are updated successfully; returns an error message if any part of the operation fails.
    // Validators: Implements atomicity checks to ensure all documents are updated to their most recent versions.
    // External functions using it: None currently.
    // Official Documentation: [updateManyJunoDocs Documentation](https://forum.solutio.one/-161/updatemanyjunodocs-documentation)
    //TODO: NOT SECURE. This function needs to be tested on deployment.
    public func updateManyJunoDocs(docs : [T.CollectionKeyPair]) : async Text {
        let docsKeyData = List.nil<(Text, Text)>();
        let docsWholeData = List.nil<(Text, Text, T.DocInput)>();
        let docIter = Array.vals<T.CollectionKeyPair>(docs);
        var updatedList = docsKeyData;
        var updatedDocs = docsWholeData;
        for (doc in docIter) {
            updatedList := List.push((doc.collection, doc.key), docsKeyData);

        };
        switch (updatedList) {
            case (list) {
                let myArray = List.toArray<(Text, Text)>(list);
                //1) Get all the documents for those docs passed as parameters
                let response = await getManyJunoDocs(myArray);
                // Now we have all those docs. The ones that didnt exist, are passed along as a null element
                Debug.print(debug_show ("Response: ", response));
                switch (response) {
                    case (#ok(response)) {
                        let responseIter = Array.vals<(Text, ?T.DocResponse)>(response);
                        for (resp in responseIter) {
                            let textPart = resp.0;
                            let docResponsePart : ?T.DocResponse = resp.1;
                            switch (docResponsePart) {
                                case (null) {
                                    // do nothing
                                };
                                case (?docResponse) {
                                    let updatedAt : Nat64 = docResponse.updated_at;
                                    let updatedDocs = Array.map<T.CollectionKeyPair, T.CollectionKeyPair>(
                                        docs,
                                        func(doc) {
                                            var updatedDocInput : T.DocInput = doc.docInput;
                                            if (doc.key == textPart) {
                                                updatedDocInput := {
                                                    updated_at = ?updatedAt;
                                                    data = docResponse.data;
                                                    description = docResponse.description;
                                                };
                                            };
                                            {
                                                collection = doc.collection;
                                                key = doc.key;
                                                docInput = updatedDocInput;
                                            };
                                        },
                                    );

                                };
                            };
                        };
                        let transformed : [(Text, Text, T.DocInput)] = Array.map<T.CollectionKeyPair, (Text, Text, T.DocInput)>(
                            docs,
                            func(pair) {
                                return (pair.collection, pair.key, pair.docInput);
                            },
                        );
                        try {
                            let result = await setManyJunoDocs(transformed);
                            return result;
                        } catch (errore) {
                            let error = await handleErrors(errore);
                            return error;
                        };
                    };
                    case (#err(text)) {
                        return text;
                    };
                };

            };
        };

        // try {
        //     let result = await setManyJunoDocs(docs);
        //     return result;
        // } catch (errore) {
        //     let error = await handleErrors(errore);
        //     return error;
        // };
    };

    // *******deleteJunoDoc********
    // Brief description: Securely removes a document from a specified collection in Juno, with optional timestamp validation for version control.
    // Pre-Conditions: Requires `collection` and `key` to identify the document; optional `updated_at` for version check.
    // Post-conditions: Returns "Success" if the document is successfully deleted; "Document not Found" if it doesn't exist or has been updated.
    // Validators: Optional timestamp validation to ensure the document being deleted is the most recent version.
    // External functions using it: None currently.
    // Official Documentation: [deleteJunoDoc Documentation](https://forum.solutio.one/-158/deletejunodoc-documentation)
    public func deleteJunoDoc(collection : Text, key : Text) : async Text {
        let doc : ?T.GetDocResponse = await juno.get_doc(collection, key);
        switch (doc) {
            case (null) {
                return "Document not Found";
            };
            case (?doc) {
                let updated_number : ?Nat64 = ?doc.updated_at;
                try {
                    let result = await juno.del_doc(collection, key, { updated_at = updated_number });

                } catch (errore) {
                    let error = await handleErrors(errore);
                    return error;
                };
                return "Success";
            };
        };
    };

    // *******deleteManyJunoDocs********
    // Brief description: Atomically deletes multiple documents from Juno, ensuring all or none are deleted to maintain data integrity.
    // Pre-Conditions: `docs` parameter must include collection, key, and optional `updated_at` for each document to validate its version.
    // Post-conditions: Returns "Success" if all specified documents are deleted successfully; returns an error message if the operation fails.
    // Validators: Ensures atomic deletion by checking `updated_at` timestamps, when provided, for version control.
    // External functions using it: None currently.
    // Official Documentation: (https://forum.solutio.one/-159/deletemanyjunodocs-documentation)
    //TODO: Probably works. But still, this function needs to be tested on deployment.
    public func deleteManyJunoDocs(docs : [(Text, Text, { updated_at : ?Nat64 })]) : async Text {
        try {
            let result = await juno.del_many_docs(docs);

        } catch (errore) {
            let error = await handleErrors(errore);
            return error;
        };
        return "Success!";
    };
};
