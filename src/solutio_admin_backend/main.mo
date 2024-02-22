import T "./types";
import bridge "./juno.bridge";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import Error "mo:base/Error";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import icrc "./icrc.bridge";
import val "./validate";

actor Admin {
  public func fromCandidDescription(docKey : Text) : async {
    #ok : [T.User];
    #err : Text;
  } {
    let id = "TEST_solutionPledges";
    let document : T.GetDocResult = await getDoc("idea", id);
    switch (document) {
      case (#ok(response)) {
        let data : Blob = response.data;
        let decoding : { #ok : [T.User]; #err : Text } = await val.pledgesSolutionDecode(data);
        switch (decoding) {
          case (#ok(response)) {
            let user : T.User = {
              user = "Juansito";
              amount_pledged = 120;
              amount_paid = 100;
            };
            let user2 : T.User = {
              user = "Algun chupapija";
              amount_pledged = 2222;
              amount_paid = 222;
            };
            var usersUpdate : [T.User] = val.iterateUsersPledges(response, user);
            usersUpdate := val.iterateUsersPledges(response, user2);
            // updated_at : ?Nat64;
            // data : Blob;
            // description : ?Text;
            let usersBlob = await val.pledgesSolutionEncode(usersUpdate);
            switch (usersBlob) {
              case (#ok(response)) {
                let blob : Blob = response;
                // let doc : T.DocInput = {
                //   updated_at = null;
                //   data = Blob.fromArray([]);
                //   description = ?("pledger: " # Principal.toText(caller) # "_amount: " # Nat64.toText(amount));
                // };
                let doc : T.DocInput = {
                  updated_at = null;
                  data = blob;
                  description = null;
                };
                let pledgeCreation = await bridge.setJunoDoc("pledges_solution", "SOL_PL" # docKey, doc);
                if (Text.notEqual(pledgeCreation, "Success!")) {
                  throw Error.reject(pledgeCreation);
                };
                return #ok(usersUpdate);
              };
              case (#err(error)) {
                return #err(error);
              };
            };

            return #ok(usersUpdate);
          };
          case (#err(error)) {
            return #err(error);
          };

        };

      };
      case (#err(error)) {
        return #err(error);
      };
    };
  };

  public shared (msg) func setDoc(collection : Text, key : Text, doc : T.DocInput) : async Text {
    Debug.print(Principal.toText(msg.caller));
    return await bridge.setJunoDoc(collection, key, doc);
  };
  public shared (msg) func getDoc(collection : Text, key : Text) : async T.GetDocResult {
    return await bridge.getJunoDoc(collection, key);
  };
  public func setManyDocs(docs : T.SetManyDocsInput) : async Text {
    return await bridge.setManyJunoDocs(docs);
  };
  public func getManyDocs(docsInput : T.GetManyDocsInput) : async T.GetManyDocsResult {
    return await bridge.getManyJunoDocs(docsInput);
  };
  public func listDocs(collection : Text, filter : T.ListDocsFilter) : async T.ListDocsResult {
    return await bridge.listJunoDocs(collection, filter);
  };
  public func updateDocument(collection : Text, key : Text, docsInput : T.DocInput) : async Text {
    return await bridge.updateJunoDocument(collection, key, docsInput);
  };
  public func updateManyDocs(docs : [T.CollectionKeyPair]) : async Text {
    return await bridge.updateManyJunoDocs(docs);
  };
  public func deleteDoc(collection : Text, key : Text) : async Text {
    return await bridge.deleteJunoDoc(collection, key);
  };
  public func deleteManyDocs(docs : [(Text, Text, { updated_at : ?Nat64 })]) : async Text {
    return await bridge.deleteManyJunoDocs(docs);
  };

  var reputation : Nat64 = 60;

  //For every function, we do a maximum of 3 intercanister calls: one getManyDocs, one setManyDocs, and one for the icrc ledger, if necessary.
  public shared (msg) func pledgeCreate(doc_key : Text, idea_id : Text, feature_id : Text, amount : Nat64, accounta : Blob) : async Text {
    var userReputation = reputation;
    let caller = msg.caller;
    // Verify that the caller is not anonymous
    if (Principal.isAnonymous(caller)) {
      throw Error.reject("Anonymous users cannot create pledges.");
    };
    let docInput1 : (Text, Text) = ("idea", idea_id);
    let docInput2 : (Text, Text) = ("feature", feature_id);
    let docInput3 : (Text, Text) = ("reputation", Principal.toText(caller));
    let docInput4 : (Text, Text) = ("pledge_solution", "SOL_PL_" # idea_id);
    let docInput5 : (Text, Text) = ("idea_feature_pledging", "PLG_IDEA_" # idea_id);
    let docInput6 : (Text, Text) = ("idea_feature_pledging", "PLG_FEA_" # feature_id);
    var docs : [(Text, Text)] = [docInput1, docInput2, docInput3, docInput4, docInput5];
    if (Text.notEqual(feature_id, "")) {
      var docs = [docInput1, docInput2, docInput3, docInput4, docInput5, docInput6];
    };
    let getDocResponse : T.GetManyDocsResult = await bridge.getManyJunoDocs(docs);
    var userPledgeList : [T.User] = [];
    var totalPledgeFeatureInfo : ?T.TotalPledging = null;
    var totalPledgeIdeaInfo : ?T.TotalPledging = null;
    var docKeyPl_Sol : Text = "SOL_PL_" # idea_id;
    var docKeyPl_id : Text = "PLG_IDEA_" # idea_id;
    var docKeyPl_fea : Text = "PLG_FEA_" # feature_id;
    var updAtPl_Sol : ?Nat64 = null;
    var updAtPl_id : ?Nat64 = null;
    var updAtPl_fea : ?Nat64 = null;
    var descPl_Sol : ?Text = null;
    var descPl_id : ?Text = null;
    var descPl_fea : ?Text = null;
    switch getDocResponse {
      case (#ok(response)) {
        for ((text, maybeDoc) in response.vals()) {
          switch (maybeDoc) {
            // We check if any document requested is non-existent
            case (null) {
              if (text == Principal.toText(caller)) {
                throw Error.reject("User doesnt have reputation document.");
              };
              if (text == "SOL_PL_" # idea_id) {
                throw Error.reject("pledge_solution document non-existent");
              };
              if (text == feature_id and Text.notEqual(feature_id, "")) {
                throw Error.reject("Feature non-existent");
              };
              if (text == "PLG_FEA_" # feature_id) {
                throw Error.reject("idea_feature_pledge feature document non-existent");
              };
              if (text == "PLG_IDEA_" # feature_id) {
                throw Error.reject("idea_feature_pledge idea document non-existent");
              };
              if (text == idea_id) {
                throw Error.reject("Idea non-existent");
              };
              if (text == feature_id) {
                throw Error.reject("Feature non-existent");
              };
            };
            case (?doc) {
              if (text == Principal.toText(caller)) {
                switch (doc.description) {
                  case (null) {
                    throw Error.reject("Reputation should have a description. Try signing in again.");
                  };
                  case (?description) {
                    // We get the user reputation
                    try {
                      userReputation := val.textToNat64(description);
                    } catch (error) {
                      throw Error.reject("Reputation is wrongly formated. It should have only numbers.");
                    };
                  };
                };
              };
              if (text == "SOL_PL_" # idea_id) {
                updAtPl_Sol := ?doc.updated_at;
                descPl_Sol := doc.description;
                try {
                  let data : T.UserPledgeListResult = await val.pledgesSolutionDecode(doc.data);
                  switch (data) {
                    case (#ok(response)) {
                      userPledgeList := response;
                      //We have to check if that user has already pledged, if it has, we have to update that pledge.
                      //If it hasnt pledged, we have to add it
                    };
                    case (#err(error)) {
                      throw Error.reject("User pledges list could not be parsed.");
                    };
                  };
                } catch (error) {
                  throw Error.reject("Data does not have information");
                };
              };
              if (text == idea_id) {
                switch (doc.description) {
                  case (null) {
                    throw Error.reject("Idea should have a description");
                  };
                  case (?description) {
                    if (Text.contains(description, #text "delivered") or Text.contains(description, #text "completed")) {
                      throw Error.reject("This idea is not available for pledging. It was already delivered or completed.");
                    };
                  };
                };
              };
              if (text == "PLG_FEA_" # feature_id) {
                // I have to convert the doc.data into readable data
                updAtPl_fea := ?doc.updated_at;
                descPl_fea := doc.description;
                let data : T.TotalPledgingResult = await val.totalPledgesDecode(doc.data);
                switch (data) {
                  case (#ok(response)) {
                    totalPledgeFeatureInfo := ?response;
                  };
                  case (#err(error)) {
                    throw Error.reject("Total pledges in feature could not be parsed.");
                  };
                };

              };
              if (text == "PLG_IDEA_" # feature_id) {
                updAtPl_id := ?doc.updated_at;
                descPl_id := doc.description;
                let data : T.TotalPledgingResult = await val.totalPledgesDecode(doc.data);
                switch (data) {
                  case (#ok(response)) {
                    totalPledgeIdeaInfo := ?response;
                  };
                  case (#err(error)) {
                    throw Error.reject("Total pledges in feature could not be parsed.");
                  };
                };
              };

            };
          };
        };
      };
      case (#err(error)) {
        return error;
      };
    };
    // Validate input formats using the validateId function
    //TODO: validateId() function
    if (val.validateId(doc_key) == false) {
      throw Error.reject("The doc key doesnt fullfil nanouid() requirements");
    };

    let acc : icrc.BinaryAccountBalanceArgs = { account = accounta };
    let balance = await icrc.icrc.account_balance(acc);
    if (balance.e8s < amount) {
      throw Error.reject("User has not enough tokens for pledging");
    };

    // Calculate expected amount based on user reputation
    let expectedAmount : Nat64 = (amount * userReputation) / 100;
    //let expectedAmount = amount;

    // Now that all checks have been passed, we need to update many documents:
    // ******************************
    //  1) pledge_solution document: add the new pledge to the pledges array.
    let userPledge : T.User = {
      user = Principal.toText(caller);
      amount_pledged = Nat64.toNat(amount);
      amount_paid = 0;
    };
    userPledgeList := val.iterateUsersPledges(userPledgeList, userPledge);
    let userList = await val.pledgesSolutionEncode(userPledgeList);
    var blobList : ?Blob = null;
    switch (userList) {
      case (#ok(blob)) {
        blobList := ?blob;
      };
      case (#err(error)) {
        throw Error.reject(error);
      };
    };
    let listBlob : Blob = switch (blobList) {
      case (null) {
        // Handle the null case, e.g., by throwing an error or providing a default value
        throw Error.reject("Blob is unexpectedly null");
      };
      case (?blob) {
        blob;
      };
    };
    let listDocInput : T.DocInput = {
      updated_at = updAtPl_Sol;
      data = listBlob;
      description = descPl_Sol;

    };

    let docInputSet1 : (Text, Text, T.DocInput) = ("pledges_solution", docKeyPl_Sol, listDocInput);
    // ******************************

    // ******************************
    //  2) idea_feature_pledges idea document: edit the total amount of pledges for this idea.
    // We have to update the pledges and expected numbers
    let ideaPledge : T.TotalPledging = switch (totalPledgeIdeaInfo) {
      case (null) {
        // Handle the null case, e.g., by throwing an error or providing a default value
        throw Error.reject("Pledge idea info is unexpectedly null");
      };
      case (?info) {
        info;
      };
    };
    let newPledgeIdeaInfo : T.TotalPledging = val.totalPledgesUpdate(amount, expectedAmount, ideaPledge);
    // We have to reconvert that data into a blob to send to Juno
    let pledgeIdeaBlob : Blob = switch (await val.totalPledgesEncode(newPledgeIdeaInfo)) {
      case (#err(error)) {
        // Handle the null case, e.g., by throwing an error or providing a default value
        throw Error.reject("Pledge idea information couldnt be converted into a Blob");
      };
      case (#ok(blob)) {
        blob;
      };
    };
    let ideaPlDocInput : T.DocInput = {
      updated_at = updAtPl_id;
      data = pledgeIdeaBlob;
      description = descPl_id;

    };
    let docInputSet2 : (Text, Text, T.DocInput) = ("idea_feature_pledge", docKeyPl_id, ideaPlDocInput);

    // ******************************

    // ******************************
    //  3) idea_feature_pledges feature document: edit the total amount of pledges for this feature.
    //    (if its pledging to a feature, in other words if(feature_id!=""). )
    // We have to update the pledges and expected numbers
    // We have to reconvert that data into a blob to send to Juno
    var docInputSet3 : ?(Text, Text, T.DocInput) = null;
    if (Text.notEqual(feature_id, "")) {

      let featurePledge : T.TotalPledging = switch (totalPledgeFeatureInfo) {
        case (null) {
          // Handle the null case, e.g., by throwing an error or providing a default value
          throw Error.reject("Pledge feature info is unexpectedly null");
        };
        case (?info) {
          info;
        };
      };
      let newPledgeFeatureInfo : T.TotalPledging = val.totalPledgesUpdate(amount, expectedAmount, featurePledge);
      // We have to reconvert that data into a blob to send to Juno
      let pledgeFeatureBlob : Blob = switch (await val.totalPledgesEncode(newPledgeFeatureInfo)) {
        case (#err(error)) {
          // Handle the null case, e.g., by throwing an error or providing a default value
          throw Error.reject("Pledge feature information couldnt be converted into a Blob");
        };
        case (#ok(blob)) {
          blob;
        };
      };
      let ideaPlDocInput : T.DocInput = {
        updated_at = updAtPl_fea;
        data = pledgeFeatureBlob;
        description = descPl_fea;

      };
      docInputSet3 := ?("idea_feature_pledge", docKeyPl_fea, ideaPlDocInput);
    };
    // ******************************

    // ******************************
    //  4) We need to create a document for the `pledges_active` collection with the doc_key.
    let pledge : T.Pledge = {
      doc_key = doc_key;
      idea_id = idea_id;
      feature_id = feature_id;
      amount = amount;
      expected_amount = expectedAmount;
      user = caller;
    };
    let doc : T.DocInput = {
      updated_at = null;
      data = Blob.fromArray([]);
      description = ?("pledger:" # Principal.toText(caller) # " _amount:" # Nat64.toText(amount) # " _idea:" # idea_id # " _feature:" # feature_id);
    };
    let docInputSet4 : (Text, Text, T.DocInput) = ("pledges_active", doc_key, doc);
    // *****************************

    // Update all the documents with setManyJunoDocs();
    //var docsInput : [(Text,Text,T.DocInput)]= [docInputSet1,docInputSet2,docInputSet4] ;
    let docsInput : [(Text, Text, T.DocInput)] = switch (docInputSet3) {
      case (null) {
        [docInputSet1, docInputSet2, docInputSet4];
      };
      case (?doc) {
        [docInputSet1, docInputSet2, doc, docInputSet4];
      };
    };
    let pledgeCreation = await bridge.setManyJunoDocs(docsInput);
    if (Text.notEqual(pledgeCreation, "Success!")) {
      throw Error.reject("Failed to create pledge.");
    };

    return "Success";
  };
};
