import T "./types";
import bridge "./juno.bridge";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import Error "mo:base/Error";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Buffer "mo:base/Buffer";
import Source "mo:uuid/async/SourceV4";
import UUID "mo:uuid/UUID";
import icrc "./icrc.bridge";
import val "./validate";
import enc "./encoding";
import noti "./notifications";
import escrow "canister:solutio_escrow";
import Array "mo:base/Array";
import Iter "mo:base/Iter";

actor Admin {
  //For every function, we do a maximum of 3 intercanister calls: one getManyDocs, one setManyDocs, and one for the icrc ledger, if necessary.
  let escrowCanister : Principal = Principal.fromText("2uurk-ziaaa-aaaab-qacla-cai"); // we need to update this.
  let take = func(text : Text, n : Nat) : Text {
    let chars = Text.toArray(text);
    let firstNChars = Array.subArray(chars, 0, n);
    Text.fromIter<>(Iter.fromArray(firstNChars));
  };

  func FromICPtoDecimalsInText(amountICP : Nat64) : Text {
    let E8S_PER_ICP : Nat64 = 100_000_000;
    let wholePart = Nat64.toText(Nat64.div(amountICP, E8S_PER_ICP));
    var decimalPart = Nat64.toText(Nat64.rem(amountICP, E8S_PER_ICP));

    // Add leading zeros to decimalPart until its length is 8
    while (Text.size(decimalPart) < 8) {
      decimalPart := Text.concat("0", decimalPart);
    };
    decimalPart := take(decimalPart, 2);

    let amountDecimals = Text.concat(wholePart # ".", decimalPart);
  };
  // ************** TESTING FUNCTIONS *****************
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
            // version : ?Nat64;
            // data : Blob;
            // description : ?Text;
            let usersBlob = await val.pledgesSolutionEncode(usersUpdate);
            switch (usersBlob) {
              case (#ok(response)) {
                let blob : Blob = response;
                // let doc : T.DocInput = {
                //   version = null;
                //   data = Blob.fromArray([]);
                //   description = ?("pledger: " # Principal.toText(caller) # "_amount: " # Nat64.toText(amount));
                // };
                let doc : T.DocInput = {
                  version = null;
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

  public func editPledgeTry(user : T.User, previousPledge : T.Pledge) : async [T.User] {

    let users : [T.User] = [
      { user = "juansito"; amount_pledged = 6420000000; amount_paid = 0 },
      { user = "juansito"; amount_pledged = 6420000000; amount_paid = 0 },
      { user = "juansito"; amount_pledged = 6420000000; amount_paid = 0 },
    ];
    var updatedUsers : Buffer.Buffer<T.User> = Buffer.Buffer<T.User>(0);
    var userFound : Bool = false;
    for (thisUser in users.vals()) {
      if (thisUser.user == user.user) {
        let amount : Nat = user.amount_pledged + thisUser.amount_pledged - Nat64.toNat(previousPledge.amount);
        updatedUsers.add({
          user = user.user;
          amount_pledged = amount;
          amount_paid = user.amount_paid;
        });
        userFound := true;
      } else {
        updatedUsers.add({
          user = thisUser.user;
          amount_pledged = thisUser.amount_pledged;
          amount_paid = thisUser.amount_paid;
        });
      };

    };

    if (userFound == false) {
      updatedUsers.add({
        user = user.user;
        amount_pledged = user.amount_pledged;
        amount_paid = user.amount_paid;
      });
    };
    let updatedUsersArray : [T.User] = Buffer.toArray(updatedUsers);

    return updatedUsersArray;

  };

  public shared (msg) func createPersonalNotification(sender : Text, target : Text, title : Text, description : Text, image : Text) : async Text {
    let g = Source.Source();
    let noti_id : Text = UUID.toText(await g.new());
    return noti_id;
  };

  public shared (msg) func userPrincipal() : async Text {
    return Principal.toText(msg.caller);
  };
  // ******* ***************************************** **********

  public shared (msg) func setDoc(collection : Text, key : Text, doc : T.DocInput) : async Text {
    Debug.print(Principal.toText(msg.caller));
    return await bridge.setJunoDoc(collection, key, doc);
  };

  public shared (msg) func getDoc(collection : Text, key : Text) : async T.GetDocResult {
    return await bridge.getJunoDoc(collection, key);
  };

  public shared (msg) func setManyDocs(docs : T.SetManyDocsInput) : async Text {
    if (Principal.isAnonymous(msg.caller)) {
      throw Error.reject("Not signed in: Anonymous users cannot create documents.");

    };
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

  public func deleteManyDocs(docs : [(Text, Text, { version : ?Nat64 })]) : async Text {
    return await bridge.deleteManyJunoDocs(docs);
  };

  var reputation : Nat64 = 60;

  // *******pledgeCreate********
  // Brief Description: Initiates a new Pledge for a specified feature within an idea in Solutio, ensuring the feature is eligible
  // for pledging and the pledger meets the necessary criteria.
  // Pre-Conditions:
  //  - Caller must be authenticated and not anonymous.
  //  - `idea_id` and `feature_id` must exist and be eligible for pledging.
  //  - The amount must be a positive Nat64 value.
  //  - `doc_key` must be unique to prevent duplicate pledges.
  // Post-Conditions:
  //  - Creates a new document in "pledges_active" with pledge details.
  //  - Updates "pledges_solution" and "idea_feature_pledge" collections with the new pledge information.
  //  - Adjusts total pledges count and expected amounts for the feature and idea.
  // Validators:
  //  - Validates UUID formats for `idea_id` and `feature_id`.
  //  - Checks user's balance against the pledged amount.
  //  - Ensures the feature and idea are not marked as completed or delivered.
  // External Functions Using It:
  //  - Will trigger updates in "pledges_solution", "pledges_active", and "idea_feature_pledge" collections through internal logic.
  // Official Documentation:
  //  - A detailed description and usage examples can be found at : i cant make this link public LOL 😂💀
  public shared (msg) func pledgeCreate(doc_key : Text, idea_id : Text, feature_id : Text, amount : Nat64, accounta : Blob) : async Text {
    if (amount == 0) {
      throw Error.reject("You cant pledge 0");
    };
    var userReputation = reputation;
    let caller = msg.caller;
    // Verify that the caller is not anonymous
    if (Principal.isAnonymous(caller)) {
      throw Error.reject("Anonymous users cannot create pledges.");
    };
    let docInput1 : (Text, Text) = ("idea", idea_id);
    let docInput2 : (Text, Text) = ("feature", feature_id);
    let docInput3 : (Text, Text) = ("reputation", "REP_" #Principal.toText(caller));
    let docInput4 : (Text, Text) = ("pledges_solution", "SOL_PL_" # idea_id);
    let docInput5 : (Text, Text) = ("idea_feature_pledge", "PLG_IDEA_" # idea_id);
    let docInput6 : (Text, Text) = ("idea_feature_pledge", "PLG_FEA_" # feature_id);
    var docs : [(Text, Text)] = [docInput1, docInput2, docInput3, docInput4, docInput5];
    if (Text.equal(idea_id, "") or Text.equal(idea_id, " ")) {
      throw Error.reject("idea_id is empty");
    };
    if ((Text.equal(feature_id, "")) == false) {
      docs := [docInput1, docInput2, docInput3, docInput4, docInput5, docInput6];
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
    var idea_owner : Text = idea_id;
    var feature_owner : Text = feature_id;
    switch getDocResponse {
      case (#ok(response)) {
        for ((text, maybeDoc) in response.vals()) {
          switch (maybeDoc) {
            // We check if any document requested is non-existent
            case (null) {
              if (text == "REP_" #Principal.toText(caller)) {
                throw Error.reject("User doesnt have reputation document.");
              };
              if (text == "SOL_PL_" # idea_id) {
                throw Error.reject("pledge_solution document non-existent");
              };
              if (text == feature_id and Text.notEqual(feature_id, "")) {
                throw Error.reject("Feature -" #feature_id # "- non-existent");
              };
              if (text == "PLG_FEA_" # feature_id) {
                throw Error.reject("idea_feature_pledge feature document non-existent");
              };
              if (text == "PLG_IDEA_" # idea_id) {
                throw Error.reject("idea_feature_pledge idea document non-existent");
              };
              if (text == idea_id) {
                throw Error.reject("Idea non-existent. Idea: " # idea_id);
              };
            };
            case (?doc) {
              if (text == "REP_" #Principal.toText(caller)) {
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
                updAtPl_Sol := doc.version;
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
                    idea_owner := Principal.toText(doc.owner);
                  };
                };
              };
              if (text == "PLG_FEA_" # feature_id) {
                // I have to convert the doc.data into readable data
                updAtPl_fea := doc.version;
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
              if (text == feature_id) {
                feature_owner := Principal.toText(doc.owner);
              };
              if (text == "PLG_IDEA_" # idea_id) {
                updAtPl_id := doc.version;
                descPl_id := doc.description;
                let data : T.TotalPledgingResult = await val.totalPledgesDecode(doc.data);
                switch (data) {
                  case (#ok(response)) {
                    totalPledgeIdeaInfo := ?response;
                  };
                  case (#err(error)) {
                    throw Error.reject("ERROR: PLG_IDEA_" # idea_id # ": Total pledges in idea could not be parsed." # "INFO: " # (error));
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
    //return "Balance: " # Nat64.toText(balance.e8s) # " - Amount: " # Nat64.toText(amount);
    if (balance.e8s < amount) {
      throw Error.reject("User has not enough tokens for pledging");
    };

    // Calculate expected amount based on user reputation
    // let expectedAmount : Nat64 = (amount * userReputation) / 100;
    let expectedAmount : Nat = await calculateExpectedAmount(msg.caller, amount, userReputation);
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
      version = updAtPl_Sol;
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
        throw Error.reject("Pledge idea info is unexpectedly null");
      };
      case (?info) {
        info;
      };
    };
    let newPledgeIdeaInfo : T.TotalPledging = val.totalPledgesUpdate(amount, Nat64.fromNat(expectedAmount), ideaPledge);
    // We have to reconvert that data into a blob to send to Juno
    let pledgeIdeaBlob : Blob = switch (await val.totalPledgesEncode({ pledges = Nat64.toNat(newPledgeIdeaInfo.pledges); expected = Nat64.toNat(newPledgeIdeaInfo.expected) })) {
      case (#err(error)) {
        // Handle the null case, e.g., by throwing an error or providing a default value
        throw Error.reject("Pledge idea information couldnt be converted into a Blob");
      };
      case (#ok(blob)) {
        blob;
      };
    };
    let ideaPlDocInput : T.DocInput = {
      version = updAtPl_id;
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
          throw Error.reject("Pledge feature info is unexpectedly null");
        };
        case (?info) {
          info;
        };
      };
      let newPledgeFeatureInfo : T.TotalPledging = val.totalPledgesUpdate(amount, Nat64.fromNat(expectedAmount), featurePledge);
      // We have to reconvert that data into a blob to send to Juno
      let pledgeFeatureBlob : Blob = switch (await val.totalPledgesEncode({ pledges = Nat64.toNat(newPledgeFeatureInfo.pledges); expected = Nat64.toNat(newPledgeFeatureInfo.expected) })) {
        case (#err(error)) {
          // Handle the null case, e.g., by throwing an error or providing a default value
          throw Error.reject("Pledge feature information couldnt be converted into a Blob");
        };
        case (#ok(blob)) {
          blob;
        };
      };
      let ideaPlDocInput : T.DocInput = {
        version = updAtPl_fea;
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
      expected_amount = Nat64.fromNat(expectedAmount);
      user = Principal.toText(caller);
      target = feature_owner;
    };
    let pledgeEncoding = await enc.pledgeEncode(
      pledge
    );
    let amountBlob : Blob = switch (pledgeEncoding) {
      case (#err(error)) {
        throw Error.reject(error);
      };
      case (#ok(blob)) {
        blob;
      };
    };
    let doc : T.DocInput = {
      version = null;
      data = amountBlob;
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
      throw Error.reject("Failed to create pledge: " # pledgeCreation);
    };
    let counter = await pledgesCounter(doc_key, Nat64.toNat(amount));
    if (Text.notEqual(counter, "Pledges counter modified successfully!")) {
      throw Error.reject("Failed to update pledges_counter: " # counter);
    };
    let amountDecimalsText : Text = FromICPtoDecimalsInText(amount);
    let notification : T.Notification = {
      title = "New Pledge!";
      subtitle = "User with key " # Principal.toText(caller) # " has pledged  " # amountDecimalsText # " ICP into your topic.";
      description = "";
      imageURL = "https://st2.depositphotos.com/5375910/9423/v/450/depositphotos_94239928-stock-illustration-donate-money-vector-icon.jpg";
      linkURL = "/feature/" # feature_id;
      typeOf = "pledge";
      sender = Principal.toText(caller);
    };
    let notification2 : T.Notification = {
      title = "New Pledge!";
      subtitle = "User with key " # Principal.toText(caller) # " has pledged  " # amountDecimalsText # " ICP into your idea.";
      description = "";
      imageURL = "https://st2.depositphotos.com/5375910/9423/v/450/depositphotos_94239928-stock-illustration-donate-money-vector-icon.jpg";
      linkURL = "/feature/" # feature_id;
      typeOf = "pledge";
      sender = Principal.toText(caller);
    };
    let notif = noti.createPersonalNotification(Principal.toText(caller), idea_owner, notification);
    let notif2 = noti.createPersonalNotification(Principal.toText(caller), feature_owner, notification2);
    // if (Text.notEqual(notif2, "Success!")) {
    //   throw Error.reject("THe pledge was created succesfully, but failed to notify listeners: " # notif2);
    // };
    return "Success";
  };

  func calculateExpectedAmount(user : Principal, amount : Nat64, userReputation : Nat64) : async Nat {
    // let expectedAmount : Nat64 = (amount * userReputation) / 100;

    // let userPledge : T.User = {
    //   user = Principal.toText(caller);
    //   amount_pledged = Nat64.toNat(amount);
    //   amount_paid = 0;
    // };
    let expectedGivenReputation : Nat = Nat64.toNat((amount * userReputation) / 100);
    let highestAmountPaid : Nat = await escrow.getHighestPaymentEver(Principal.toText(user));
    if (expectedGivenReputation > highestAmountPaid) {
      return highestAmountPaid;
    } else {
      return expectedGivenReputation;
    };
  };
  // *******pledgeEdit********
  // Brief Description: Updates an existing pledge for a feature within an idea in Solutio. It verifies the pledge's existence and the eligibility of the feature and idea before proceeding to update the pledge amount.
  // Pre-Conditions:
  //  - Caller must be authenticated and not anonymous.
  //  - `pledge_key`, `idea_id`, and `feature_id` must correspond to existing records.
  //  - The new amount must be a positive Nat64 value.
  //  - Checks if the idea or feature associated with the pledge is not marked as completed or delivered.
  // Post-Conditions:
  //  - Updates the document in "pledges_active" with the new pledge amount.
  //  - Adjusts "pledges_solution" and "idea_feature_pledge" documents to reflect the updated pledge information.
  //  - Modifies the total pledged and expected amounts for the feature and idea based on the new pledge amount.
  // Validators:
  //  - Validates UUID formats for `idea_id` and `feature_id`.
  //  - Confirms the pledge exists and is editable.
  //  - Checks user's balance against the new pledged amount.
  // External Functions Using It:
  //  - Triggers recalculation and updates in "pledges_solution", "pledges_active", and "idea_feature_pledge" collections.
  // Official Documentation:
  //  - For more information and usage examples, refer to https://forum.solutio.one/-165/pledgeEdit-documentation

  public shared (msg) func pledgeEdit(pledge_key : Text, idea_id : Text, feature_id : Text, amount : Nat64, accounta : Blob) : async Text {
    var userReputation = reputation;
    let caller = msg.caller;
    // Verify that the caller is not anonymous
    if (Principal.isAnonymous(caller)) {
      throw Error.reject("Anonymous users cannot create pledges.");
    };
    if (amount == 0) {
      throw Error.reject("You cant pledge 0");
    };
    let docInput1 : (Text, Text) = ("idea", idea_id);
    let docInput2 : (Text, Text) = ("feature", feature_id);
    let docInput3 : (Text, Text) = ("reputation", "REP_" #Principal.toText(caller));
    let docInput4 : (Text, Text) = ("pledges_solution", "SOL_PL_" # idea_id);
    let docInput5 : (Text, Text) = ("idea_feature_pledge", "PLG_IDEA_" # idea_id);
    let docInput6 : (Text, Text) = ("idea_feature_pledge", "PLG_FEA_" # feature_id);
    let docInput7 : (Text, Text) = ("pledges_active", pledge_key);
    var docs : [(Text, Text)] = [docInput1, docInput2, docInput3, docInput4, docInput5, docInput7];
    if (Text.equal(idea_id, "") or Text.equal(idea_id, " ")) {
      throw Error.reject("idea_id is empty");
    };
    if (Text.notEqual(feature_id, "")) {
      docs := [docInput1, docInput2, docInput3, docInput4, docInput5, docInput6, docInput7];
    };
    let getDocResponse : T.GetManyDocsResult = await bridge.getManyJunoDocs(docs);
    var pledgeInfo : ?T.Pledge = null;
    var userPledgeList : [T.User] = [];
    var totalPledgeFeatureInfo : ?T.TotalPledging = null;
    var totalPledgeIdeaInfo : ?T.TotalPledging = null;
    var docKeyPl_Sol : Text = "SOL_PL_" # idea_id;
    var docKeyPl_id : Text = "PLG_IDEA_" # idea_id;
    var docKeyPl_fea : Text = "PLG_FEA_" # feature_id;
    var updAtPl_Sol : ?Nat64 = null;
    var updAtPl_id : ?Nat64 = null;
    var updAtPl_pledge : ?Nat64 = null;
    var updAtPl_fea : ?Nat64 = null;
    var descPl_Sol : ?Text = null;
    var descPl_pledge : ?Text = null;
    var descPl_id : ?Text = null;
    var descPl_fea : ?Text = null;
    var idea_owner : Text = idea_id;
    switch getDocResponse {
      case (#ok(response)) {
        for ((text, maybeDoc) in response.vals()) {
          switch (maybeDoc) {
            // We check if any document requested is non-existent
            case (null) {
              if (text == pledge_key) {
                throw Error.reject("Cant be edited as it doesnt exist.");
              };
              if (text == "REP_" #Principal.toText(caller)) {
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
              if (text == "PLG_IDEA_" # idea_id) {
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
              if (text == pledge_key) {
                updAtPl_pledge := doc.version;
                descPl_pledge := doc.description;
                try {
                  pledgeInfo := ?(await enc.pledgeDataDecode(doc.data));

                } catch (error) {
                  throw Error.reject("Pledge data does not have information" # Error.message(error));
                };
              };
              if (text == "REP_" #Principal.toText(caller)) {
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
                updAtPl_Sol := doc.version;
                descPl_Sol := doc.description;
                try {
                  let data : T.UserPledgeListResult = await val.pledgesSolutionDecode(doc.data);
                  switch (data) {
                    case (#ok(response)) {
                      userPledgeList := response;
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
                    idea_owner := Principal.toText(doc.owner);
                  };
                };
              };
              if (text == "PLG_FEA_" # feature_id) {
                // I have to convert the doc.data into readable data
                updAtPl_fea := doc.version;
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
              if (text == "PLG_IDEA_" # idea_id) {
                updAtPl_id := doc.version;
                descPl_id := doc.description;
                let data : T.TotalPledgingResult = await val.totalPledgesDecode(doc.data);
                switch (data) {
                  case (#ok(response)) {
                    totalPledgeIdeaInfo := ?response;
                  };
                  case (#err(error)) {
                    throw Error.reject("ERROR: PLG_IDEA_" # idea_id # ": Total pledges in idea could not be parsed." # "INFO: " # (error));
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
    if (val.validateId(pledge_key) == false) {
      throw Error.reject("The doc key doesnt fullfil nanouid() requirements");
    };

    let acc : icrc.BinaryAccountBalanceArgs = { account = accounta };
    let balance = await icrc.icrc.account_balance(acc);
    //return "Balance: " # Nat64.toText(balance.e8s) # " - Amount: " # Nat64.toText(amount);
    if (balance.e8s < amount) {
      throw Error.reject("User has not enough tokens for pledging");
    };

    // Calculate expected amount based on user reputation
    let expectedAmount : Nat = await calculateExpectedAmount(msg.caller, amount, userReputation);
    //let expectedAmount = amount;

    // Now that all checks have been passed, we need to update many documents:
    // ******************************
    //  1) pledge_solution document: add the new pledge to the pledges array.
    let userPledge : T.User = {
      user = Principal.toText(caller);
      amount_pledged = Nat64.toNat(amount);
      amount_paid = 0;
    };
    //TODO: Update pledge info
    var pledgeToEncode : T.Pledge = switch (pledgeInfo) {
      case (null) {
        throw Error.reject("The pledge information could not be decoded. Its null.");
      };
      case (?pledge) {
        pledge;
      };
    };
    userPledgeList := enc.updatePledges(
      userPledgeList,
      userPledge,
      pledgeToEncode,
    );
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
      version = updAtPl_Sol;
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
        throw Error.reject("Pledge idea info is unexpectedly null");
      };
      case (?info) {
        info;
      };
    };
    let pledgeToAdd : T.Pledge = switch (pledgeInfo) {
      case (null) {
        throw Error.reject("");
      };
      case (?pledge) {
        pledge;
      };
    };
    let newPledgeIdeaInfo : T.TotalPledging = val.totalPledgesUpdate_edit(amount, Nat64.fromNat(expectedAmount), ideaPledge, pledgeToAdd);
    // We have to reconvert that data into a blob to send to Juno
    let pledgeIdeaBlob : Blob = switch (await val.totalPledgesEncode({ pledges = Nat64.toNat(newPledgeIdeaInfo.pledges); expected = Nat64.toNat(newPledgeIdeaInfo.expected) })) {
      case (#err(error)) {
        // Handle the null case, e.g., by throwing an error or providing a default value
        throw Error.reject("Pledge idea information couldnt be converted into a Blob");
      };
      case (#ok(blob)) {
        blob;
      };
    };
    let ideaPlDocInput : T.DocInput = {
      version = updAtPl_id;
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
          throw Error.reject("Pledge feature info is unexpectedly null");
        };
        case (?info) {
          info;
        };
      };
      let newPledgeFeatureInfo : T.TotalPledging = val.totalPledgesUpdate_edit(amount, Nat64.fromNat(expectedAmount), featurePledge, pledgeToAdd);
      // We have to reconvert that data into a blob to send to Juno
      let pledgeFeatureBlob : Blob = switch (await val.totalPledgesEncode({ pledges = Nat64.toNat(newPledgeFeatureInfo.pledges); expected = Nat64.toNat(newPledgeFeatureInfo.expected) })) {
        case (#err(error)) {
          // Handle the null case, e.g., by throwing an error or providing a default value
          throw Error.reject("Pledge feature information couldnt be converted into a Blob");
        };
        case (#ok(blob)) {
          blob;
        };
      };
      let ideaPlDocInput : T.DocInput = {
        version = updAtPl_fea;
        data = pledgeFeatureBlob;
        description = descPl_fea;

      };
      docInputSet3 := ?("idea_feature_pledge", docKeyPl_fea, ideaPlDocInput);
    };
    // ******************************

    // ******************************

    let pledgeBlob : Blob = switch (await enc.pledgeEncode(pledgeToEncode)) {
      case (#err(error)) {
        throw Error.reject("Updated pledge could not be encoded. Error: " # error);
      };
      case (#ok(response)) {
        response;
      };
    };
    let pledgeActiveDoc : T.DocInput = {
      version = updAtPl_pledge;
      data = pledgeBlob;
      description = ?("pledger:" # Principal.toText(caller) # " _amount:" # Nat64.toText(amount) # " _idea:" # idea_id # " _feature:" # feature_id);
    };
    let docInputSet4 : (Text, Text, T.DocInput) = ("pledges_active", pledge_key, pledgeActiveDoc);
    // *****************************

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
      throw Error.reject("Failed to edit pledge: " # pledgeCreation);
    };
    let amountDecimalsText : Text = FromICPtoDecimalsInText(amount);
    let notification : T.Notification = {
      title = "New Pledge!";
      subtitle = "User with key " # Principal.toText(caller) # " has pledged  " # amountDecimalsText # " ICP into your idea.";
      description = "";
      imageURL = "https://st2.depositphotos.com/5375910/9423/v/450/depositphotos_94239928-stock-illustration-donate-money-vector-icon.jpg";
      linkURL = "/feature/" # feature_id;
      typeOf = "pledge";
      sender = Principal.toText(caller);
    };
    let notif = await noti.createPersonalNotification(Principal.toText(caller), idea_owner, notification);
    if (Text.notEqual(notif, "Success!")) {
      throw Error.reject("THe pledge was created succesfully, but failed to notify listeners: " # notif);
    };

    return "Success";
  };

  // ******* solutionSubmit() ********
  // Brief Description: Marks a solution as completed by updating its status within Solutio, ensuring only the solution's owner can perform this action and that the solution hasn't already been marked as delivered or completed.
  // Pre-Conditions:
  // - Caller must be authenticated and not anonymous.
  // - sol_id and idea_id must correspond to existing and valid solution and idea records, respectively.
  // - The caller must be the owner of the solution.
  // - The solution must not already be marked as completed or delivered.
  // Post-Conditions:
  // - Updates the solution_status document to mark the solution as delivered.
  // - Sends notifications to relevant parties about the solution's new status.
  // Validators:
  // - Ensures the sol_id and idea_id are provided and accurately reference existing solution and idea documents.
  // - Verifies the solution's ownership and its current eligibility for completion.
  // External Functions Using It:
  // - Utilizes internal logic to update the solution's status document and to send notifications through the platform's notification system.
  // Official Documentation:
  // - Detailed guidelines and examples can be found at https://forum.solutio.one/-166/solutionsubmit-documentation

  public shared (msg) func solutionSubmit(sol_id : Text, idea_id : Text) : async Text {
    let caller = msg.caller;
    // Verify that the caller is not anonymous
    if (Principal.isAnonymous(caller)) {
      throw Error.reject("Anonymous users submit solutions.");
    };
    let docInput1 : (Text, Text) = ("solution_status", "SOL_STAT_" # sol_id);
    let docInput2 : (Text, Text) = ("idea", idea_id);
    var docs : [(Text, Text)] = [docInput1, docInput2];
    var descriptionIdea : Text = "status:delivered";
    var descriptionSol : Text = "status:delivered";
    var ideaData : ?Blob = null;
    var solData : ?Blob = null;
    var updAtPl_sol : ?Nat64 = null;
    var updAtPl_idea : ?Nat64 = null;
    if (Text.equal(idea_id, "") or Text.equal(idea_id, " ")) {
      throw Error.reject("idea_id is empty");
    };
    let getDocResponse : T.GetManyDocsResult = await bridge.getManyJunoDocs(docs);
    switch getDocResponse {
      case (#ok(response)) {
        for ((text, maybeDoc) in response.vals()) {
          switch (maybeDoc) {
            // We check if any document requested is non-existent
            case (null) {
              if (text == sol_id) {
                throw Error.reject("Solution status document doesnt exist");
              };
              if (text == idea_id) {
                throw Error.reject("Solution status document doesnt exist");
              };
            };
            case (?doc) {
              if (text == "SOL_STAT_" # sol_id) {

                switch (doc.description) {
                  case (null) {
                    throw Error.reject("Solution status document should have a description");
                  };
                  case (?description) {
                    updAtPl_sol := doc.version;
                    if (Text.contains(description, #text "delivered") or Text.contains(description, #text "completed")) {
                      throw Error.reject("Error: It was already delivered or completed.");
                    };
                    solData := ?doc.data;
                    let text = description;
                    let owner = Principal.toText(doc.owner);
                    let callerText = Principal.toText(caller);
                    if (Text.contains(owner, #text callerText) == false) {
                      throw Error.reject("Not owner of solution");
                    };
                    var text_copy = "";
                    var descriptionUpdated : Bool = false;
                    for (c : Char in text.chars()) {
                      text_copy := text_copy # Text.fromChar(c);
                      if (Text.contains(text_copy, #text "status:") and descriptionUpdated == false) {
                        descriptionSol := "";
                        descriptionUpdated := true;
                        descriptionSol := text_copy # "delivered";
                      };
                    };
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

    let blobSolData : Blob = switch (solData) {
      case (null) {
        throw Error.reject("null data");
      };
      case (?data) {
        data;
      };
    };
    let statusDoc : T.DocInput = {
      version = updAtPl_sol;
      data = blobSolData;
      description = ?descriptionSol;
    };
    let docInputSet2 : (Text, Text, T.DocInput) = ("solution_status", "SOL_STAT_" # sol_id, statusDoc);
    let approvalDoc : T.DocInput = {
      version = null;
      data = await enc.solutionApprovalDataEncode("idea: " # idea_id);
      description = ?"0";
    };
    let docInput3 = ("solution_approved", "SOL_APPR_" # sol_id, approvalDoc);
    let docsInput = [docInputSet2, docInput3];

    let updateStatusResult = await bridge.setManyJunoDocs(docsInput);
    if (Text.notEqual(updateStatusResult, "Success!")) {
      throw Error.reject("Failed to change the status: " # updateStatusResult);
    };
    let notification : T.Notification = {
      title = "Solution submited!";
      subtitle = "The owner has delivered the solution of the idea" # idea_id;
      description = "The owner " # Principal.toText(caller) # " has delivered the solution. Go check it out!";
      imageURL = "https://cdn-icons-png.flaticon.com/512/10543/10543121.png";
      linkURL = "/solution/" #sol_id;
      typeOf = "status";
      sender = Principal.toText(caller);
    };
    //let notif = await noti.createGlobalNotification(idea_id, notification);
    let notif = "Success!";
    if (Text.notEqual(notif, "Success!")) {
      throw Error.reject("Status changed successfully, but failed to notify listeners: " # notif);
    };
    return "Success";
  };
  // ******* updateSolutionStatus() ********
  // Brief Description: Changes the status of a solution, validating the ownership and current status beforehand.
  // Pre-Conditions:
  // - Caller must be authenticated and not anonymous.
  // - sol_id must correspond to an existing solution whose status is neither "completed" nor "delivered".
  // - Caller must be the owner of the solution.
  // Post-Conditions:
  // - Updates "solution_status" document for the specified solution, reflecting the new status.
  // - Notifies followers or interested parties about the status update.
  // Validators:
  // - Checks for solution existence and ownership.
  // - Verifies the solution is eligible for the status change.
  // External Functions Using It:
  // - Utilizes "setManyJunoDocs" to update the document and "createNotification" for sending notifications.
  // Official Documentation:
  // - For a detailed explanation and guidelines: https://forum.solutio.one/-176/updatesolutionstatus-documentation.
  public shared (msg) func updateSolutionStatus(sol_id : Text, status : Text) : async Text {
    let caller = msg.caller;
    if (Principal.isAnonymous(caller)) {
      throw Error.reject("Anonymous users submit solutions.");
    };
    let docInput1 : (Text, Text) = ("solution_status", "SOL_STAT_" # sol_id);
    var docs : [(Text, Text)] = [docInput1];
    var descriptionSol : Text = "status:" #status;
    var solData : ?Blob = null;
    var updAtPl_sol : ?Nat64 = null;

    let getDocResponse : T.GetManyDocsResult = await bridge.getManyJunoDocs(docs);
    switch getDocResponse {
      case (#ok(response)) {
        for ((text, maybeDoc) in response.vals()) {
          switch (maybeDoc) {
            // We check if any document requested is non-existent
            case (null) {
              if (text == sol_id) {
                throw Error.reject("Solution status document doesnt exist");
              };
            };
            case (?doc) {
              if (text == "SOL_STAT_" # sol_id) {
                switch (doc.description) {
                  case (null) {
                    throw Error.reject("Solution status document should have a description");
                  };
                  case (?description) {
                    updAtPl_sol := doc.version;
                    // if (Text.contains(description, #text "delivered") or Text.contains(description, #text "completed")) {
                    //   throw Error.reject("Error: It was already delivered or completed.");
                    // };
                    solData := ?doc.data;
                    let text = description;
                    let callerText = Principal.toText(caller);
                    descriptionSol := "status:" # status # " , owner:" # callerText;
                  };
                };
              };
              if (text == sol_id) {
                let text = Principal.toText(doc.owner);
                let callerText = Principal.toText(caller);
                if (Text.contains(text, #text callerText) == false) {
                  throw Error.reject("Not owner of solution");
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

    let blobSolData : Blob = switch (solData) {
      case (null) {
        throw Error.reject("null data");
      };
      case (?data) {
        data;
      };
    };
    let statusDoc : T.DocInput = {
      version = updAtPl_sol;
      data = blobSolData;
      description = ?descriptionSol;
    };
    let docInputSet2 : (Text, Text, T.DocInput) = ("solution_status", "SOL_STAT_" # sol_id, statusDoc);
    let docsInput = [docInputSet2];

    let updateStatusResult = await bridge.setManyJunoDocs(docsInput);
    if (Text.notEqual(updateStatusResult, "Success!")) {
      throw Error.reject("Failed to change the status: " # updateStatusResult);
    };

    if (status == "completed") {
      let updateSolutionsCompleted = await solutionsCompletedCounter();
      if (Text.notEqual(updateSolutionsCompleted, "solutions_completed_counter modified successfully!")) {
        throw Error.reject("Failed to update solutions completed number" # updateStatusResult);
      };
    };

    let notification : T.Notification = {
      title = "Solution status changed!";
      subtitle = "The owner has changed the solution status to '" # status # "' of the solution" # sol_id;
      description = "The owner " # Principal.toText(caller) # " has delivered the solution. Go check it out!";
      imageURL = "https://cdn-icons-png.flaticon.com/512/10543/10543121.png";
      linkURL = "/solution/" #sol_id;
      typeOf = "update";
      sender = Principal.toText(caller);
    };
    //let notif = await noti.createGlobalNotification(sol_id, notification);
    let notif = "Success!";
    if (Text.notEqual(notif, "Success!")) {
      throw Error.reject("Status changed successfully, but failed to notify listeners: " # notif);
    };
    return "Success";

  };

  // *******pledgeApprovedVerify********
  // Brief Description: Verifies that a pledge made to a solution has been approved in the ledger, then updates the pledge's payment status accordingly.
  // Pre-Conditions:
  //  - The solution identified by `sol_id` must have a status of "delivered" or "completed" to be eligible for pledge approval.
  //  - The pledger (caller of this function) must be authenticated and not anonymous.
  //  - The pledged amount (`amount`) must match the amount approved in the ledger for the transaction identified by `trans_number`.
  //  - Necessary documents like "solution_status", "reputation", and "pledges_solution" must exist and be accessible.
  // Post-Conditions:
  //  - Updates the "pledges_solution" document to reflect the new amount paid by the user if the ledger approval is verified.
  //  - Recalculates and updates the user's reputation based on the updated pledge amounts.
  //  - Ensures that any changes in pledge amounts are accurately reflected across related documents and metrics within the platform.
  // Validators:
  //  - Confirms the existence of required documents and their consistency with the expected states and values.
  //  - Checks that the amount passed as a parameter was the actual amount approved in the ledger.
  // External Functions Using It:
  //  - This function is a critical part of the pledge management and approval process, ensuring that user contributions are accurately recorded and rewarded.
  //  - Success in this function triggers updates in user reputation and the total approved amount for solutions, contributing to the overall transparency and trustworthiness of the Solutio platform.
  // Official Documentation:
  //  - For comprehensive details and usage scenarios of the `pledgeApprovedVerify` function, including examples and best practices, please refer to https://forum.solutio.one/-167/pledgeapprovedverify-documentation
  public shared (msg) func pledgeApprovedVerify(sol_id : Text, idea_id : Text, amount : Nat64, trans_number : Nat64) : async Text {
    // We have to check that the solution status is "delivered", otherwise we need to throw an error
    // Then we need to update the `amount_paid` field in the array of users that pledged in the collection `pledges_solution`. If there is no entry, we add it and the amount_pledged = amount and amount_paid = amount.
    // We also need to get the user reputation and update its number. We need to update the reputation, the amount_promised and amount_paid.
    // - To update the number, we need to calculat total_paid / total_promised. total_paid = amount + amount_paid, and total_promised = amount_promised + amount_pledged.
    // - amount is the one in the parameters and amount_pledged we can get it from the array. If we dont find it in the array (i.e. the user hasnt pledged), its the same as amount (i.e. the amount that the user paid).
    // - total_promised CAN'T be 0, otherwise we would be dividing by 0 and that's a mathematical error. So if both amount_pledged and amount_promised are 0, the total_promised its equal to the amount (explained in previous point).
    // - when updating reputation, amount_promised is going to be updated to the number of total_promised and amount_paid is updated to total_paid.

    // Concretely, getDoc: pledges_solution, solution_status, reputation. setDoc: pledges_solution, reputation
    // in the middle we have to update pledges_solution (update amount_paid = amount). If an entry doesnt exist, then (update amount_pledged=amount, amount_paid = amount).
    // update reputation number with (previousPaid + amount) / (previousPledged + amount_pledged) = reputation
    // update reputation fields: amount_promised = amount_promised + amount_pledged. amount_paid = amount_paid + amount.
    // check that the user has approved the canister.
    // notify the solution owner.
    let caller = msg.caller;
    if (Principal.isAnonymous(caller)) {
      throw Error.reject("Anonymous cannot approve solutions.");
    };
    let docInput1 : (Text, Text) = ("solution_status", "SOL_STAT_" # sol_id);
    let docInput2 : (Text, Text) = ("reputation", "REP_" # Principal.toText(caller));
    let docInput3 : (Text, Text) = ("pledges_solution", "SOL_PL_" # idea_id);
    let docInput4 : (Text, Text) = ("idea", idea_id);
    var docs : [(Text, Text)] = [docInput1, docInput2, docInput3, docInput4];
    var descPl_Sol : ?Text = null;
    var updAtPl_sol : ?Nat64 = null;
    var updAt_rep : ?Nat64 = null;
    var reputation : ?Nat = null;
    var reputationNumbers : ?T.ReputationNumbers = null;
    var userPledgeList : [T.User] = [];
    let getDocResponse : T.GetManyDocsResult = await bridge.getManyJunoDocs(docs);
    var idea_owner : Text = idea_id;
    switch getDocResponse {
      case (#ok(response)) {
        for ((text, maybeDoc) in response.vals()) {
          switch (maybeDoc) {
            // We check if any document requested is non-existent
            case (null) {
              if (text == "SOL_STAT_" # sol_id) {
                throw Error.reject("Solution status document doesnt exist");
              };
              if (text == "REP_" # Principal.toText(caller)) {
                throw Error.reject("Reputation document doesnt exist");
              };
              if (text == "SOL_PL_" # idea_id) {
                throw Error.reject("Pledges_solution document doesnt exist");
              };
              if (text == idea_id) {
                throw Error.reject("idea document doesnt exist");
              };
            };
            case (?doc) {
              if (text == "SOL_STAT_" # sol_id) {
                switch (doc.description) {
                  case (null) {
                    throw Error.reject("Solution status document should have a description");
                  };
                  case (?description) {
                    if ((Text.contains(description, #text "DELIVERED") or Text.contains(description, #text "COMPLETED")) == false) {
                      throw Error.reject("Error: The project was not delivered nor completed. You cant approve it yet.");
                    };
                  };
                };
              };
              if (text == "REP_" # Principal.toText(caller)) {
                switch (doc.description) {
                  case (null) {
                    throw Error.reject("Reputation document should have a description");
                  };
                  case (?description) {
                    reputation := Nat.fromText(description);
                    if (reputation == null) {
                      reputation := ?80;
                    };
                    updAt_rep := doc.version;
                    let reputationNumbersResult = await enc.reputationNumbersDecode(doc.data);
                    reputationNumbers := switch (reputationNumbersResult) {
                      case (#ok(response)) {
                        ?response;
                      };
                      case (#err(error)) {
                        throw Error.reject(error);
                      };
                    };

                  };
                };
              };
              if (text == "SOL_PL_" # idea_id) {
                updAtPl_sol := doc.version;
                descPl_Sol := doc.description;
                try {
                  let data : T.UserPledgeListResult = await val.pledgesSolutionDecode(doc.data);
                  switch (data) {
                    case (#ok(response)) {
                      userPledgeList := response;
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
                idea_owner := Principal.toText(doc.owner);
              };
            };
          };
        };
      };
      case (#err(error)) {
        return error;
      };
    };
    //Validation: Check the approval occured and that the amount is the one passed.
    //  let acc : icrc.BinaryAccountBalanceArgs = { account = accounta };
    // let balance = await icrc.icrc.account_balance(acc);
    let queryArgs : icrc.GetBlocksArgs = {
      start = trans_number;
      length = Nat64.fromNat(1);
    };
    let queryBlock : icrc.QueryBlocksResponse = await icrc.icrc.query_blocks(queryArgs);
    let hasBlocks : Bool = queryBlock.blocks.size() != 0;
    switch (hasBlocks) {
      case (true) {
        let transaction = queryBlock.blocks[0].transaction;
        switch (transaction.operation) {
          case (null) {
            throw Error.reject("Something went wong in the approval process");
          };
          case (?operation) {
            //let approvedAmount = operation.approve.allowance.e8s;
            switch (operation) {
              case (#Approve { fee; from; allowance_e8s; allowance; expected_allowance; expires_at; spender }) {
                let approvedAmount : Nat64 = allowance.e8s;
                if (approvedAmount != amount) {
                  throw Error.reject("The amount is not the approved amount: " # Nat64.toText(amount) # " | approved amount: " # Nat64.toText(approvedAmount));
                };
              };
              case (_) {
                throw Error.reject("The operation is not 'approve'");
              };

            };
          };
        };
      };
      case (false) {
        throw Error.reject("Transaction number didnt produced any blocks.");
      };
    };
    //Now we have to update pledges_solution and reputation
    // (1) pledges solution
    let user : T.User = {
      user = Principal.toText(caller);
      amount_pledged = 0;
      amount_paid = Nat64.toNat(amount);
    };
    userPledgeList := val.iterateUsersPledges(userPledgeList, user);
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

    // (2) reputation
    let reputationInfo : T.ReputationNumbers = switch (reputationNumbers) {
      case (null) {
        throw Error.reject("The reputation information is null");
      };
      case (?rep) {
        rep;
      };
    };
    let userInfo : T.User = switch (getUserPledgeInfo((Principal.toText(caller)), userPledgeList)) {
      case (#err(err)) {
        // Case it wasnt pledged and its approving out of nowhere
        {
          user = Principal.toText(caller);
          amount_pledged = Nat64.toNat(amount);
          amount_paid = Nat64.toNat(amount);
        };
      };
      case (#ok(respo)) {
        if (respo.amount_paid != 0) {
          //If the user has already approved, we dont need to sum again the amount_pledge number in the calculation.
          {
            user = Principal.toText(caller);
            amount_pledged = 0;
            amount_paid = respo.amount_paid;
          };
        } else {
          {
            user = Principal.toText(caller);
            amount_pledged = respo.amount_pledged;
            amount_paid = respo.amount_paid;
          };
        };
      };
    };
    //Before calculating the reputation, wee need to know if the user has already approved.
    // Why? because we dont want to sum up the same pledge 2 times in the calculation of the reputation.
    // How do we do this? We check if the amount_paid stored in the pledges_solution document is 0. If it isnt, it means it was previously approved.
    // If it was approved, the amount_pledged to pass over to the calculation needs to be 0. Else, it has to be the amount_pledge number.
    let resultReputation : (Nat, T.ReputationNumbersNat) = recalculateReputation({ amount_promised = Nat64.toNat(reputationInfo.amount_promised); amount_paid = Nat64.toNat(reputationInfo.amount_paid) }, userInfo);
    reputation := ?resultReputation.0;
    reputationNumbers := ?{
      amount_promised = Nat64.fromNat(resultReputation.1.amount_promised);
      amount_paid = Nat64.fromNat(resultReputation.1.amount_paid);
    };
    let numbersReputation : T.ReputationNumbers = switch (reputationNumbers) {
      case (null) {
        throw Error.reject("Reputation numbers are unexpectedly null");
      };
      case ((?numbers)) {
        numbers;
      };
    };
    let reputationNumEncoding : Blob = switch (await enc.reputationEncode(numbersReputation)) {
      case (#err(err)) {
        throw Error.reject("Reputation numbers couldnt be encoded");
      };
      case (#ok(blob)) {
        blob;
      };
    };
    //Now we have to prepare the doc input to actually update the database.
    // (1) pledges_solution
    let listDocInput : T.DocInput = {
      version = updAtPl_sol;
      data = listBlob;
      description = descPl_Sol;

    };
    let docInputSet2 : (Text, Text, T.DocInput) = ("pledges_solution", "SOL_PL_" # idea_id, listDocInput);

    // (2) reputation
    let reputationNat : Nat = switch (reputation) {
      case (null) {
        throw Error.reject("The reputation is unexpectedly null");
      };
      case (?rep) {
        rep;
      };
    };
    let reputationInput : T.DocInput = {
      version = updAt_rep;
      data = reputationNumEncoding;
      description = ?Nat.toText(reputationNat);

    };

    let docInputSet3 : (Text, Text, T.DocInput) = ("reputation", "REP_" # Principal.toText(caller), reputationInput);
    let updateReputation = escrow.updateReputation(msg.caller, Nat64.toNat(reputationInfo.amount_paid), Nat64.toNat(reputationInfo.amount_promised));
    let approveCounter : (Text, Text, T.DocInput) = await pledgeApprovedCounter(sol_id, amount, "increase");
    let docsInput = [docInputSet2, docInputSet3, approveCounter];
    let updateData = await bridge.setManyJunoDocs(docsInput);
    if (Text.notEqual(updateData, "Success!")) {
      throw Error.reject("Failed to verify approval: " # updateData);
    };

    let notification : T.Notification = {
      title = "New approval!";
      subtitle = "User has approved " # Nat64.toText(amount) # "!";
      description = "User with key " # Principal.toText(caller) # " has appproved your solution.";
      imageURL = "https://assets.materialup.com/uploads/bcf6dd06-7117-424f-9a6e-4bb795c8fb4d/preview.png";
      linkURL = "/solution/" #sol_id;
      typeOf = "approval";
      sender = Principal.toText(caller);
    };
    //let notif = await noti.createPersonalNotification(Principal.toText(caller), idea_owner, notification);
    let notif = "Success!";
    if (Text.notEqual(notif, "Success!")) {
      throw Error.reject("The approval was verified succesfully, but failed to notify listeners: " # notif);
    };
    return "Approval verified and added to database!";
  };

  func recalculateReputation(reputationNumbers : T.ReputationNumbersNat, userPayInfo : T.User) : (Nat, T.ReputationNumbersNat) {
    var totalPromised = reputationNumbers.amount_promised + userPayInfo.amount_pledged;
    if (totalPromised == 0) {
      totalPromised := userPayInfo.amount_paid + reputationNumbers.amount_paid;
    };
    var totalPaid = reputationNumbers.amount_paid +userPayInfo.amount_paid;
    if (totalPromised == 0) {
      return (
        80,
        {
          amount_promised = totalPromised;
          amount_paid = totalPaid;
        },
      );
    };
    if ((totalPaid * 100 / totalPromised) > 100) {
      return (
        100,
        {
          amount_promised = totalPromised;
          amount_paid = totalPaid;
        },
      );
    } else {
      return (
        (totalPaid * 100 / totalPromised),
        {
          amount_promised = totalPromised;
          amount_paid = totalPaid;
        },
      );
    };
  };

  func getUserPledgeInfo(user : Text, users : [T.User]) : {
    #ok : T.User;
    #err : Text;
  } {
    var updatedUsers : Buffer.Buffer<T.User> = Buffer.Buffer<T.User>(0);
    var userFound : Bool = false;
    for (thisUser in users.vals()) {
      if (thisUser.user == user) {
        // He has already pledged
        return #ok(thisUser);

      };
    };
    // return {
    //   user = user;
    //   amount_pledged = 0;
    //   amount_paid = 0;
    // };
    return #err("User hasnt pledged into the idea.");
  };

  // *******solutionReject********
  // Brief Description: Processes the rejection of a solution within the Solutio platform.
  //  It updates the pledge status and resets the 'paid' value to 0 for the pledger, ensuring no  funds
  //  are transferred for a rejected solution. Additionally, the function adjusts the total approved
  //  amount and user reputation as necessary.
  // Pre-Conditions:
  //  - The solution must exist and be associated with a specific idea.
  //  - The solution status must be checked to ensure it is in a state that allows for rejection.
  //  - Caller must be authenticated and not anonymous.
  //  - The solutionReject() assumes that the pledgeApprovedVerify() function has run successfully beforehand, without any pledge being approved due to the solution's rejection.
  // Post-Conditions:
  //  - Resets the 'paid' value in the pledges_solution collection for the user's pledge to 0.
  //  - Updates the solution status to reflect its rejection.
  //  - Adjusts user reputation based on the solution's rejection, impacting their standing within the Solutio community.
  // Validators:
  //  - Verifies that the caller has the authority to reject the solution, typically requiring specific roles or permissions.
  //  - Checks for the existence of the solution and its eligibility for rejection based on its current status.
  // External Functions Using It:
  //  - May trigger notifications to inform relevant parties (e.g., the solution provider and pledgers) about the solution's rejection.
  //  - Updates various metrics and counters related to solution approval and rejection within the platform.
  // Official Documentation:
  //  - For detailed information and further usage examples, refer to https://forum.solutio.one/-178/solutionreject-documentation
  public shared (msg) func solutionReject(sol_id : Text, idea_id : Text) : async Text {
    let caller = msg.caller;
    if (Principal.isAnonymous(caller)) {
      throw Error.reject("Anonymous cannot approve solutions.");
    };
    let amount : Nat64 = 0;
    let docInput1 : (Text, Text) = ("solution_status", "SOL_STAT_" # sol_id);
    let docInput2 : (Text, Text) = ("reputation", "REP_" # Principal.toText(caller));
    let docInput3 : (Text, Text) = ("pledges_solution", "SOL_PL_" # idea_id);
    var docs : [(Text, Text)] = [docInput1, docInput2, docInput3];
    var descPl_Sol : ?Text = null;
    var updAtPl_sol : ?Nat64 = null;
    var updAt_rep : ?Nat64 = null;
    var reputation : ?Nat = null;
    var reputationNumbers : ?T.ReputationNumbers = null;
    var userPledgeList : [T.User] = [];
    let getDocResponse : T.GetManyDocsResult = await bridge.getManyJunoDocs(docs);
    switch getDocResponse {
      case (#ok(response)) {
        for ((text, maybeDoc) in response.vals()) {
          switch (maybeDoc) {
            // We check if any document requested is non-existent
            case (null) {
              if (text == "SOL_STAT_" # sol_id) {
                throw Error.reject("Solution status document doesnt exist");
              };
              if (text == "REP_" # Principal.toText(caller)) {
                throw Error.reject("Reputation document doesnt exist");
              };
              if (text == "SOL_PL_" # idea_id) {
                throw Error.reject("Pledges_solution document doesnt exist");
              };
            };
            case (?doc) {
              if (text == "SOL_STAT_" # sol_id) {
                switch (doc.description) {
                  case (null) {
                    throw Error.reject("Solution status document should have a description");
                  };
                  case (?description) {
                    if ((Text.contains(description, #text "DELIVERED") or Text.contains(description, #text "COMPLETED")) == false) {
                      throw Error.reject("Error: The project was not delivered nor completed. You cant approve it yet.");
                    };
                  };
                };
              };
              if (text == "REP_" # Principal.toText(caller)) {
                switch (doc.description) {
                  case (null) {
                    throw Error.reject("Reputation document should have a description");
                  };
                  case (?description) {
                    reputation := Nat.fromText(description);
                    if (reputation == null) {
                      reputation := ?80;
                    };
                    updAt_rep := doc.version;
                    let reputationNumbersResult = await enc.reputationNumbersDecode(doc.data);
                    reputationNumbers := switch (reputationNumbersResult) {
                      case (#ok(response)) {
                        ?response;
                      };
                      case (#err(error)) {
                        throw Error.reject(error);
                      };
                    };

                  };
                };
              };
              if (text == "SOL_PL_" # idea_id) {
                updAtPl_sol := doc.version;
                descPl_Sol := doc.description;
                try {
                  let data : T.UserPledgeListResult = await val.pledgesSolutionDecode(doc.data);
                  switch (data) {
                    case (#ok(response)) {
                      userPledgeList := response;
                    };
                    case (#err(error)) {
                      throw Error.reject("User pledges list could not be parsed.");
                    };
                  };
                } catch (error) {
                  throw Error.reject("Data does not have information");
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
    //Now we have to update pledges_solution and reputation
    // (1) pledges solution
    let previousPaidNumber : Nat = switch (getUserPledgeInfo((Principal.toText(caller)), userPledgeList)) {
      case (#err(err)) {
        // Case it wasnt pledged and its approving out of nowhere
        0;
      };
      case (#ok(respo)) {
        respo.amount_paid;
      };
    };
    let user : T.User = {
      user = Principal.toText(caller);
      amount_pledged = 0;
      amount_paid = Nat64.toNat(amount);
    };
    userPledgeList := val.iterateUsersPledges_editPayment(userPledgeList, user);
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

    // (2) reputation
    let reputationInfo : T.ReputationNumbers = switch (reputationNumbers) {
      case (null) {
        throw Error.reject("The reputation information is null");
      };
      case (?rep) {
        rep;
      };
    };
    let userInfo : T.User = switch (getUserPledgeInfo((Principal.toText(caller)), userPledgeList)) {
      case (#err(err)) {
        // Case it wasnt pledged and its approving out of nowhere
        {
          user = Principal.toText(caller);
          amount_pledged = Nat64.toNat(amount);
          amount_paid = Nat64.toNat(amount);
        };
      };
      case (#ok(respo)) {
        if (respo.amount_paid != 0) {
          //If the user has already approved, we dont need to sum again the amount_pledge number in the calculation.
          {
            user = Principal.toText(caller);
            amount_pledged = 0;
            amount_paid = respo.amount_paid;
          };
        } else {
          {
            user = Principal.toText(caller);
            amount_pledged = respo.amount_pledged;
            amount_paid = respo.amount_paid;
          };
        };
      };
    };
    //Before calculating the reputation, wee need to know if the user has already approved.
    // Why? because we dont want to sum up the same pledge 2 times in the calculation of the reputation.
    // How do we do this? We check if the amount_paid stored in the pledges_solution document is 0. If it isnt, it means it was previously approved.
    // If it was approved, the amount_pledged to pass over to the calculation needs to be 0. Else, it has to be the amount_pledge number.
    let resultReputation : (Nat, T.ReputationNumbersNat) = recalculateReputation({ amount_promised = Nat64.toNat(reputationInfo.amount_promised); amount_paid = Nat64.toNat(reputationInfo.amount_paid) }, userInfo);
    reputation := ?resultReputation.0;
    reputationNumbers := ?{
      amount_promised = Nat64.fromNat(resultReputation.1.amount_promised);
      amount_paid = Nat64.fromNat(resultReputation.1.amount_paid);
    };
    let numbersReputation : T.ReputationNumbers = switch (reputationNumbers) {
      case (null) {
        throw Error.reject("Reputation numbers are unexpectedly null");
      };
      case ((?numbers)) {
        numbers;
      };
    };
    let reputationNumEncoding : Blob = switch (await enc.reputationEncode(numbersReputation)) {
      case (#err(err)) {
        throw Error.reject("Reputation numbers couldnt be encoded");
      };
      case (#ok(blob)) {
        blob;
      };
    };
    //Now we have to prepare the doc input to actually update the database.
    // (1) pledges_solution
    let listDocInput : T.DocInput = {
      version = updAtPl_sol;
      data = listBlob;
      description = descPl_Sol;

    };
    let docInputSet2 : (Text, Text, T.DocInput) = ("pledges_solution", "SOL_PL_" # idea_id, listDocInput);

    // (2) reputation
    let reputationNat : Nat = switch (reputation) {
      case (null) {
        throw Error.reject("The reputation is unexpectedly null");
      };
      case (?rep) {
        rep;
      };
    };
    let reputationInput : T.DocInput = {
      version = updAt_rep;
      data = reputationNumEncoding;
      description = ?Nat.toText(reputationNat);

    };

    let docInputSet3 : (Text, Text, T.DocInput) = ("reputation", "REP_" # Principal.toText(caller), reputationInput);
    let updateReputation = escrow.updateReputation(msg.caller, Nat64.toNat(0), Nat64.toNat(reputationInfo.amount_promised));
    let approveCounter : (Text, Text, T.DocInput) = await pledgeApprovedCounter(sol_id, Nat64.fromNat(previousPaidNumber), "decrease");
    let docsInput = [docInputSet2, docInputSet3, approveCounter];
    let updateData = await bridge.setManyJunoDocs(docsInput);
    if (Text.notEqual(updateData, "Success!")) {
      throw Error.reject("Failed to update pledge info: " # updateData);
    };
    return "Solution rejected successfully";
  };

  // *******solutionApproveEdit********
  // Brief Description: Allows for the modification of an existing approval for a solution within the Solutio platform. This function updates the 'paid' amount to the newly specified value, adjusting the total approved amount and user reputation accordingly.
  // Pre-Conditions:
  //  - The solution must exist and be associated with a specific idea.
  //  - Caller must be authenticated and not anonymous.
  //  - The solution must have been previously approved, with a 'paid' amount already set.
  //  - New approval amount and transaction number must be provided, reflecting the updated approval.
  // Post-Conditions:
  //  - Updates the 'paid' amount in the pledges_solution collection for the user's pledge to the new amount.
  //  - Recalculates user reputation based on the updated approval, potentially affecting their standing within the Solutio community.
  //  - Optionally, adjusts total approved amount for the solution to reflect the new approval amount.
  // Validators:
  //  - Ensures that the new approval amount and transaction number are valid and correspond to an actual transaction on the ledger.
  //  - Confirms that the solution is still in a state that allows for approval modifications.
  // External Functions Using It:
  //  - Might interact with the ledger to verify the new transaction details.
  //  - Could trigger notifications to inform relevant parties about the approval modification.
  // Official Documentation:
  //  - For more detailed guidelines on how to use this function, including examples and best practices, refer to https://forum.solutio.one/-179/solutionApproveEdit-documentation

  public shared (msg) func solutionApproveEdit(sol_id : Text, idea_id : Text, amount : Nat64, trans_number : Nat64) : async Text {
    let caller = msg.caller;
    if (Principal.isAnonymous(caller)) {
      throw Error.reject("Anonymous cannot approve solutions.");
    };
    let docInput1 : (Text, Text) = ("solution_status", "SOL_STAT_" # sol_id);
    let docInput2 : (Text, Text) = ("reputation", "REP_" # Principal.toText(caller));
    let docInput3 : (Text, Text) = ("pledges_solution", "SOL_PL_" # idea_id);
    let docInput4 : (Text, Text) = ("idea", idea_id);
    var docs : [(Text, Text)] = [docInput1, docInput2, docInput3, docInput4];
    var descPl_Sol : ?Text = null;
    var updAtPl_sol : ?Nat64 = null;
    var updAt_rep : ?Nat64 = null;
    var reputation : ?Nat = null;
    var reputationNumbers : ?T.ReputationNumbers = null;
    var userPledgeList : [T.User] = [];
    let getDocResponse : T.GetManyDocsResult = await bridge.getManyJunoDocs(docs);
    var idea_owner : Text = idea_id;
    switch getDocResponse {
      case (#ok(response)) {
        for ((text, maybeDoc) in response.vals()) {
          switch (maybeDoc) {
            // We check if any document requested is non-existent
            case (null) {
              if (text == "SOL_STAT_" # sol_id) {
                throw Error.reject("Solution status document doesnt exist");
              };
              if (text == "REP_" # Principal.toText(caller)) {
                throw Error.reject("Reputation document doesnt exist");
              };
              if (text == "SOL_PL_" # idea_id) {
                throw Error.reject("Pledges_solution document doesnt exist");
              };
            };
            case (?doc) {
              if (text == "SOL_STAT_" # sol_id) {
                switch (doc.description) {
                  case (null) {
                    throw Error.reject("Solution status document should have a description");
                  };
                  case (?description) {
                    if ((Text.contains(description, #text "delivered") or Text.contains(description, #text "completed")) == false) {
                      throw Error.reject("Error: The project was not delivered nor completed. You cant approve it yet.");
                    };
                  };
                };
              };
              if (text == "REP_" # Principal.toText(caller)) {
                switch (doc.description) {
                  case (null) {
                    throw Error.reject("Reputation document should have a description");
                  };
                  case (?description) {
                    reputation := Nat.fromText(description);
                    if (reputation == null) {
                      reputation := ?80;
                    };
                    updAt_rep := doc.version;
                    let reputationNumbersResult = await enc.reputationNumbersDecode(doc.data);
                    reputationNumbers := switch (reputationNumbersResult) {
                      case (#ok(response)) {
                        ?response;
                      };
                      case (#err(error)) {
                        throw Error.reject(error);
                      };
                    };

                  };
                };
              };
              if (text == "SOL_PL_" # idea_id) {
                updAtPl_sol := doc.version;
                descPl_Sol := doc.description;
                try {
                  let data : T.UserPledgeListResult = await val.pledgesSolutionDecode(doc.data);
                  switch (data) {
                    case (#ok(response)) {
                      userPledgeList := response;
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
                idea_owner := Principal.toText(doc.owner);
              };
            };
          };
        };
      };
      case (#err(error)) {
        return error;
      };
    };
    //Validation: Check the approval occured and that the amount is the one passed.
    //  let acc : icrc.BinaryAccountBalanceArgs = { account = accounta };
    // let balance = await icrc.icrc.account_balance(acc);
    let queryArgs : icrc.GetBlocksArgs = {
      start = trans_number;
      length = Nat64.fromNat(1);
    };
    let queryBlock : icrc.QueryBlocksResponse = await icrc.icrc.query_blocks(queryArgs);
    let hasBlocks : Bool = queryBlock.blocks.size() != 0;
    switch (hasBlocks) {
      case (true) {
        let transaction = queryBlock.blocks[0].transaction;
        switch (transaction.operation) {
          case (null) {
            throw Error.reject("Something went wong in the approval process");
          };
          case (?operation) {
            //let approvedAmount = operation.approve.allowance.e8s;
            switch (operation) {
              case (#Approve { fee; from; allowance_e8s; allowance; expected_allowance; expires_at; spender }) {
                let approvedAmount : Nat64 = allowance.e8s;
                if (approvedAmount != amount) {
                  throw Error.reject("The amount is not the approved amount: " # Nat64.toText(amount) # " | approved amount: " # Nat64.toText(approvedAmount));
                };
              };
              case (_) {
                throw Error.reject("The operation is not 'approve'");
              };

            };
          };
        };
      };
      case (false) {
        throw Error.reject("Transaction number didnt produced any blocks.");
      };
    };
    // Lets get the previous amount
    let previousPaidNumber : Nat = switch (getUserPledgeInfo((Principal.toText(caller)), userPledgeList)) {
      case (#err(err)) {
        // Case it wasnt pledged and its approving out of nowhere
        0;
      };
      case (#ok(respo)) {
        respo.amount_paid;
      };
    };
    //Now we have to update pledges_solution and reputation
    // (1) pledges solution
    let user : T.User = {
      user = Principal.toText(caller);
      amount_pledged = 0;
      amount_paid = Nat64.toNat(amount);
    };
    userPledgeList := val.iterateUsersPledges_editPayment(userPledgeList, user);
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

    // (2) reputation
    let reputationInfo : T.ReputationNumbers = switch (reputationNumbers) {
      case (null) {
        throw Error.reject("The reputation information is null");
      };
      case (?rep) {
        rep;
      };
    };
    let userInfo : T.User = switch (getUserPledgeInfo((Principal.toText(caller)), userPledgeList)) {
      case (#err(err)) {
        // Case it wasnt pledged and its approving out of nowhere
        {
          user = Principal.toText(caller);
          amount_pledged = Nat64.toNat(amount);
          amount_paid = Nat64.toNat(amount);
        };
      };
      case (#ok(respo)) {
        if (respo.amount_paid != 0) {
          //If the user has already approved, we dont need to sum again the amount_pledge number in the calculation.
          {
            user = Principal.toText(caller);
            amount_pledged = 0;
            amount_paid = respo.amount_paid;
          };
        } else {
          {
            user = Principal.toText(caller);
            amount_pledged = respo.amount_pledged;
            amount_paid = respo.amount_paid;
          };
        };
      };
    };
    //Before calculating the reputation, wee need to know if the user has already approved.
    // Why? because we dont want to sum up the same pledge 2 times in the calculation of the reputation.
    // How do we do this? We check if the amount_paid stored in the pledges_solution document is 0. If it isnt, it means it was previously approved.
    // If it was approved, the amount_pledged to pass over to the calculation needs to be 0. Else, it has to be the amount_pledge number.
    let resultReputation : (Nat, T.ReputationNumbersNat) = recalculateReputation({ amount_promised = Nat64.toNat(reputationInfo.amount_promised); amount_paid = Nat64.toNat(reputationInfo.amount_paid) }, userInfo);
    reputation := ?resultReputation.0;
    reputationNumbers := ?{
      amount_promised = Nat64.fromNat(resultReputation.1.amount_promised);
      amount_paid = Nat64.fromNat(resultReputation.1.amount_paid);
    };
    let numbersReputation : T.ReputationNumbers = switch (reputationNumbers) {
      case (null) {
        throw Error.reject("Reputation numbers are unexpectedly null");
      };
      case ((?numbers)) {
        numbers;
      };
    };
    let reputationNumEncoding : Blob = switch (await enc.reputationEncode(numbersReputation)) {
      case (#err(err)) {
        throw Error.reject("Reputation numbers couldnt be encoded");
      };
      case (#ok(blob)) {
        blob;
      };
    };
    //Now we have to prepare the doc input to actually update the database.
    // (1) pledges_solution
    let listDocInput : T.DocInput = {
      version = updAtPl_sol;
      data = listBlob;
      description = descPl_Sol;

    };
    let docInputSet2 : (Text, Text, T.DocInput) = ("pledges_solution", "SOL_PL_" # idea_id, listDocInput);

    // (2) reputation
    let reputationNat : Nat = switch (reputation) {
      case (null) {
        throw Error.reject("The reputation is unexpectedly null");
      };
      case (?rep) {
        rep;
      };
    };
    let reputationInput : T.DocInput = {
      version = updAt_rep;
      data = reputationNumEncoding;
      description = ?Nat.toText(reputationNat);

    };

    let docInputSet3 : (Text, Text, T.DocInput) = ("reputation", "REP_" # Principal.toText(caller), reputationInput);
    let updateReputation = escrow.editReputation(msg.caller, Nat64.toNat(reputationInfo.amount_paid), Nat64.toNat(reputationInfo.amount_promised), previousPaidNumber, Nat64.toNat(reputationInfo.amount_promised));

    var approveCounter : (Text, Text, T.DocInput) = await pledgeApprovedCounter(sol_id, amount, "increase");
    approveCounter := await pledgeApprovedCounter(sol_id, Nat64.fromNat(previousPaidNumber), "decrease");
    let docsInput = [docInputSet2, docInputSet3, approveCounter];
    let updateData = await bridge.setManyJunoDocs(docsInput);
    if (Text.notEqual(updateData, "Success!")) {
      throw Error.reject("Failed to updated approval in database: " # updateData);
    };
    let notification : T.Notification = {
      title = "New approval!";
      subtitle = "User has approved " # Nat64.toText(amount) # "!";
      description = "User with key " # Principal.toText(caller) # " has appproved your solution.";
      imageURL = "https://assets.materialup.com/uploads/bcf6dd06-7117-424f-9a6e-4bb795c8fb4d/preview.png";
      linkURL = "/solution/" #sol_id;
      typeOf = "approval";
      sender = Principal.toText(caller);
    };
    //let notif = await noti.createPersonalNotification(Principal.toText(caller), idea_owner, notification);
    let notif = "Success!";
    if (Text.notEqual(notif, "Success!")) {
      throw Error.reject("The approval was verified succesfully, but failed to notify listeners: " # notif);
    };
    return "Approval updated and added to database!";
  };

  // *******pledgeApprovedCounter()********
  // Brief Description: Updates the total approved amount for a solution upon a successful pledge approval, reflecting the latest state of pledges.
  // Pre-Conditions:
  //  - The solution identified by `sol_id` must exist within the "solution_approved" collection.
  //  - The amount to be added to the total approved amount (`amount`) must be a positive Nat64 value.
  //  - The approval of the pledge amount in the ledger must have been verified before calling this function.
  //  - The `pledgeApprovedVerify()` function must have been executed successfully prior to this function, with no errors or inconsistencies reported.
  // Post-Conditions:
  //  - If the "solution_approved" document exists for the specified solution, the function increments the total approved amount by the specified `amount`.
  //  - Updates the "solution_approved" document with the new total approved amount, ensuring the solution's funding state is accurately represented.
  // Validators:
  //  - Checks for the existence of the "solution_approved" document corresponding to `sol_id`.
  //  - Ensures the total approved amount is accurately calculated and updated to prevent underflow or overflow errors.
  // External Functions Using It:
  //  - This function is part of the pledge approval workflow, called after a pledge's ledger approval is verified and the `pledgeApprovedVerify()` function completes successfully.
  // Official Documentation:
  //  - For a detailed explanation and more examples of how `pledgeApprovedCounter` works within the Solutio platform's pledge approval process, visit https://forum.solutio.one/-168/pledgeapprovecounter-documentation

  func pledgeApprovedCounter(sol_id : Text, amount : Nat64, operation : Text) : async (Text, Text, T.DocInput) {
    let docInput1 : (Text, Text) = ("solution_approved", "SOL_APPR_" # sol_id);
    var docs : [(Text, Text)] = [docInput1];
    var solData : ?Blob = null;
    var updAtPl_sol : ?Nat64 = null;
    var descriptionInput : Text = Nat.toText(0);

    let getDocResponse : T.GetManyDocsResult = await bridge.getManyJunoDocs(docs);
    switch getDocResponse {
      case (#ok(response)) {
        for ((text, maybeDoc) in response.vals()) {
          switch (maybeDoc) {
            // We check if any document requested is non-existent
            case (null) {
              if (text == "SOL_APPR_" # sol_id) {
                throw Error.reject("solution_approved document doesnt exist");
              };
            };
            case (?doc) {
              if (text == "SOL_APPR_" # sol_id) {
                switch (doc.description) {
                  case (null) {
                    throw Error.reject("solution_approved document should have a description");
                  };
                  case (?description) {
                    updAtPl_sol := doc.version;
                    solData := ?doc.data;
                    var totalApproved : Nat64 = Nat64.fromNat(
                      switch (Nat.fromText(description)) {
                        case (null) {
                          throw Error.reject("solution_approved document description was not a Nat type");
                        };
                        case (?nat) {
                          nat;
                        };
                      }
                    );
                    if (operation == "increase") {
                      totalApproved := totalApproved + amount;
                    } else {
                      totalApproved := totalApproved - amount;
                    };

                    descriptionInput := Nat64.toText(totalApproved);
                  };
                };
              };
            };
          };
        };
      };
      case (#err(error)) {
        throw Error.reject(error);
      };
    };
    let dataBlob : Blob = switch (solData) {
      case (null) {
        throw Error.reject("Solution_approved data is null");
      };
      case (?blob) {
        blob;
      };
    };
    let docData : T.DocInput = {
      version = updAtPl_sol;
      data = dataBlob;
      description = ?descriptionInput;
    };
    let docInputSet3 : (Text, Text, T.DocInput) = ("solution_approved", "SOL_APPR_" # sol_id, docData);
    return docInputSet3;
  };

  // *******followerCounter********
  // Brief Description: Adjusts the follower count of a specified element (user, idea, feature, or solution) on Solutio based on the follow or unfollow action.
  // Pre-Conditions:
  //  - The caller must be authenticated and identified by `caller`.
  //  - `el_id` must correspond to an existing element (user, idea, feature, or solution) in the Solutio platform.
  //  - `instruction` determines the action: `true` for follow, `false` for unfollow.
  //  - The follow document (representing the follow action) must exist for a follow action and must be deleted for an unfollow action.
  //  - The followers document for the specified element must exist to adjust the follower count.
  // Post-Conditions:
  //  - Increments the follower count by 1 for a follow action if the pre-conditions are met.
  //  - Decrements the follower count by 1 for an unfollow action if the pre-conditions are met and the follower count is not already 0.
  //  - Updates the "followers" document for the specified element with the new follower count.
  // Validators:
  //  - Checks for the existence of the follow and followers documents related to the `el_id`.
  //  - Validates that the unfollow action does not decrement the follower count below 0.
  // External Functions Using It:
  // Official Documentation:
  //  - For further details on how `followerCounter` works and its role in managing the social interactions within Solutio, visit https://forum.solutio.one/-169/followerscounter-documentation
  public shared (msg) func followerCounter(el_id : Text, instruction : Bool, what : Text) : async Text {
    // instruction : true -> follow, else unfollow
    let caller = msg.caller;
    let callerText = Principal.toText(caller);
    let docInput1 : (Text, Text) = ("follow", callerText # "_" # el_id);
    let docInput2 : (Text, Text) = ("followers", "FOLL_" # el_id);

    var docs : [(Text, Text)] = [docInput1, docInput2];
    var updAt_foll : ?Nat64 = null;
    var descriptionFoll : Text = Nat.toText(0);
    var followersBlob : ?Blob = null;
    let getDocResponse : T.GetManyDocsResult = await bridge.getManyJunoDocs(docs);
    switch getDocResponse {
      case (#ok(response)) {
        for ((text, maybeDoc) in response.vals()) {
          switch (maybeDoc) {
            // We check if any document requested is non-existent
            case (null) {
              if ((text == callerText # "_" # el_id) and instruction == true) {
                throw Error.reject(callerText # "follow document doesnt exist!");
              };
              if ((text == "FOLL_" # el_id)) {
                throw Error.reject(callerText # "followers document of the element doesnt exist!");
              };
            };
            case (?doc) {
              if ((text == callerText # "_" # el_id) and instruction == false) {
                throw Error.reject(callerText # "follow document wasnt deleted!");
              };
              if (text == "FOLL_" # el_id) {
                switch (doc.description) {
                  case (null) {
                    throw Error.reject("followers document should have a description");
                  };
                  case (?description) {
                    updAt_foll := doc.version;
                    followersBlob := ?doc.data;
                    var totalFoll : Nat = switch (Nat.fromText(description)) {
                      case (null) {
                        throw Error.reject("Followers document description was not a Nat type");
                      };
                      case (?nat) {
                        nat;
                      };
                    };
                    totalFoll := switch (instruction) {
                      case (false) {
                        if (totalFoll == 0) {
                          totalFoll;
                        } else {
                          totalFoll - 1;
                        };

                      };
                      case (true) {
                        totalFoll + 1;
                      };
                    };
                    descriptionFoll := Nat.toText(totalFoll);
                  };
                };
              };
            };
          };
        };
      };
      case (#err(error)) {
        throw Error.reject(error);
      };
    };
    let blobInput : Blob = switch (followersBlob) {
      case (null) {
        throw Error.reject("Data is null");
      };
      case (?blob) {
        blob;
      };
    };
    let docData : T.DocInput = {
      version = updAt_foll;
      data = blobInput;
      description = ?descriptionFoll;
    };
    let docInputSet3 : (Text, Text, T.DocInput) = ("followers", "FOLL_" # el_id, docData);

    let text : Text = switch (what) {
      case ("idea") {
        "r idea!";
      };
      case ("user") {
        "!";
      };
      case ("solution") {
        "r solution!";
      };
      case ("feature") {
        "r feature!";
      };
      case _ {
        throw Error.reject("Incorrect 'what' parameter. Type: " # what # "doesnt exist!");
      };
    };

    let updateData = await bridge.setManyJunoDocs([docInputSet3]);
    if (Text.notEqual(updateData, "Success!")) {
      throw Error.reject("Failed updated followes number: " # updateData);
    };
    if (instruction) {
      let notification : T.Notification = {
        title = "New follower!";
        subtitle = "User with key " # Principal.toText(caller) # " has followed you";
        description = "";
        imageURL = "https://img.freepik.com/free-vector/user-follower-icons-social-media-notification-icon-speech-bubbles-vector-illustration_56104-847.jpg?size=626&ext=jpg&ga=GA1.1.1546980028.1703980800&semt=ais";
        linkURL = "/profile/" # Principal.toText(caller);
        typeOf = "follow";
        sender = Principal.toText(caller);
      };
      let notif = "Success!";
      //let notif = await noti.createPersonalNotification(Principal.toText(caller), el_id, notification);
      if (Text.notEqual(notif, "Success!")) {
        throw Error.reject("The approval was verified succesfully, but failed to notify listeners: " # notif);
      };
    };
    return "Followers counter modified successfully!";
  };

  // *******ideaCounter********
  // Brief Description: Manages the total count of ideas within the Solutio platform by incrementing the counter
  // every time a new idea is added.
  // Pre-Conditions:
  //  - The caller must be authenticated and identified by `caller`.
  //  - `el_id` must correspond to an existing idea in the Solutio platform.
  //  - The "ideas_counter" document in the "solutio_numbers" collection must exist to adjust the total count of ideas.
  // Post-Conditions:
  //  - Increments the total count of ideas by 1 if the pre-conditions are met.
  //  - Updates the "ideas_counter" document with the new total count of ideas.
  // Validators:
  //  - Checks for the existence of the idea document related to `el_id`.
  //  - Validates that the "ideas_counter" document exists and is properly formatted to handle the increment operation.
  // External Functions Using It:
  // Official Documentation:
  //  - For detailed information on the operation and impact of `ideaCounter` within Solutio, visit https://forum.solutio.one/-170/ideaCounter-documentation

  public shared (msg) func ideaCounter(el_id : Text) : async Text {
    let caller = msg.caller;
    let callerText = Principal.toText(caller);
    let docInput1 : (Text, Text) = ("idea", el_id);
    let docInput2 : (Text, Text) = ("solutio_numbers", "ideas_counter");
    var docs : [(Text, Text)] = [docInput1, docInput2];
    var updAt_Id : ?Nat64 = null;
    var descriptionId : Text = Nat.toText(0);
    var docBlob : ?Blob = null;
    let getDocResponse : T.GetManyDocsResult = await bridge.getManyJunoDocs(docs);
    switch getDocResponse {
      case (#ok(response)) {
        for ((text, maybeDoc) in response.vals()) {
          switch (maybeDoc) {
            // We check if any document requested is non-existent
            case (null) {
              if ((text == el_id)) {
                throw Error.reject(callerText # "Idea document of the element doesnt exist!");
              };
            };
            case (?doc) {
              if (text == "ideas_counter") {
                switch (doc.description) {
                  case (null) {
                    throw Error.reject("ideas_counter document should have a description");
                  };
                  case (?description) {
                    updAt_Id := doc.version;
                    docBlob := ?doc.data;
                    var totalId : Nat = switch (Nat.fromText(description)) {
                      case (null) {
                        throw Error.reject("Ideas_counter document description was not a Nat type");
                      };
                      case (?nat) {
                        nat;
                      };
                    };
                    totalId := totalId + 1;
                    descriptionId := Nat.toText(totalId);
                  };
                };
              };
            };
          };
        };
      };
      case (#err(error)) {
        throw Error.reject(error);
      };
    };
    let blobInput : Blob = switch (docBlob) {
      case (null) {
        throw Error.reject("Data is null");
      };
      case (?blob) {
        blob;
      };
    };
    let docData : T.DocInput = {
      version = updAt_Id;
      data = blobInput;
      description = ?descriptionId;
    };
    let docInputSet3 : (Text, Text, T.DocInput) = ("solutio_numbers", "ideas_counter", docData);
    let updateData = await bridge.setManyJunoDocs([docInputSet3]);
    if (Text.notEqual(updateData, "Success!")) {
      throw Error.reject("Failed updated ideas number: " # updateData);
    };
    return "Ideas counter modified successfully!";
  };

  // *******pledgesCounter********
  // Brief Description: Adjusts the total pledge amount across all ideas on the Solutio platform by updating the pledges counter whenever a new pledge is made or an existing one is edited.
  // Pre-Conditions:
  //  - The "pledges_active" document associated with `el_id` must exist, indicating an active pledge.
  //  - The "pledges_counter" document in the "solutio_numbers" collection must be present to adjust the total pledged amount.
  // Post-Conditions:
  //  - Updates the total pledged amount by adding the new or updated pledge amount to the current total in the "pledges_counter" document.
  // Validators:
  //  - Verifies the existence and integrity of the "pledges_active" document for the given `el_id`.
  //  - Confirms that the "pledges_counter" document exists and is properly formatted for the update operation.
  // External Functions Using It:
  //  - This function may trigger additional updates or notifications to creators, developers, and pledgers about the new total pledged amount through internal mechanisms or the `createNotification` function.
  // Official Documentation:
  //  - Detailed usage examples and the operational impact of the `pledgesCounter` function within the Solutio ecosystem are available at https://forum.solutio.one/-171/pledgescounter-documentation
  func pledgesCounter(el_id : Text, amount : Nat) : async Text {
    let docInput1 : (Text, Text) = ("pledges_active", el_id);
    let docInput2 : (Text, Text) = ("solutio_numbers", "pledges_counter");
    var docs : [(Text, Text)] = [docInput1, docInput2];
    var updAt_Id : ?Nat64 = null;
    var descriptionId : Text = Nat.toText(0);
    var docBlob : ?Blob = null;
    let getDocResponse : T.GetManyDocsResult = await bridge.getManyJunoDocs(docs);
    switch getDocResponse {
      case (#ok(response)) {
        for ((text, maybeDoc) in response.vals()) {
          switch (maybeDoc) {
            // We check if any document requested is non-existent
            case (null) {
              if ((text == el_id)) {
                throw Error.reject("pledge document of the element doesnt exist!");
              };
              if ((text == "pledges_counter")) {
                throw Error.reject("pledge_counter document doesnt exist!");
              };
            };
            case (?doc) {
              if (text == "pledges_counter") {
                switch (doc.description) {
                  case (null) {
                    throw Error.reject("pledges_counter document should have a description");
                  };

                  case (?description) {
                    updAt_Id := doc.version;
                    docBlob := ?doc.data;
                    var totalId : Nat = switch (Nat.fromText(description)) {
                      case (null) {
                        throw Error.reject("pledges_counter document description was not a Nat type");
                      };
                      case (?nat) {
                        nat;
                      };
                    };
                    totalId := totalId + amount;
                    descriptionId := Nat.toText(totalId);
                  };
                };
              };
              if (text == el_id) {
                switch (doc.description) {
                  case (null) {
                    throw Error.reject("pledges_active document should have a description");
                  };
                  case (?description) {};
                };
              };
            };
          };
        };
      };
      case (#err(error)) {
        throw Error.reject(error);
      };
    };
    let blobInput : Blob = switch (docBlob) {
      case (null) {
        throw Error.reject("Data is null");
      };
      case (?blob) {
        blob;
      };
    };
    let docData : T.DocInput = {
      version = updAt_Id;
      data = blobInput;
      description = ?descriptionId;
    };
    let docInputSet3 : (Text, Text, T.DocInput) = ("solutio_numbers", "pledges_counter", docData);
    let updateData = await bridge.setManyJunoDocs([docInputSet3]);
    if (Text.notEqual(updateData, "Success!")) {
      throw Error.reject("Failed to update pledges_counter number: " # updateData);
    };
    return "Pledges counter modified successfully!";
  };

  // *******transfersBuildersCounter********
  // Brief Description: Updates the total builder revenue by adjusting the "transfers_builders_counter" whenever a reward is paid out. It ensures the accurate tracking of earnings distributed to idea contributors and developers.
  // Pre-Conditions:
  //  - Only the `escrowCanister` is authorized to call this function to ensure that only validated payouts trigger adjustments.
  //  - The "transfers_builders_counter" document must exist within the "solutio_numbers" collection to update the total builder revenue.
  // Post-Conditions:
  //  - Increments the total builder revenue stored in the "transfers_builders_counter" document by the amount specified in the function call.
  // Validators:
  //  - Verifies caller's identity to ensure only the escrow canister can execute the function.
  //  - Checks for the existence and proper formatting of the "transfers_builders_counter" document to ensure reliable updates.
  // External Functions Using It:
  //  - May be called after successful payment distributions to update the platform's records of total earnings by builders.
  // Official Documentation:
  //  - For more insights and details on how the `transfersBuildersCounter` function supports the financial transparency and accountability of the Solutio platform, visit https://forum.solutio.one/-172/transfersbuilderscounter-documentation
  public shared (msg) func transfersBuildersCounter(amount : Nat) : async Text {
    if (msg.caller != escrowCanister) {
      throw Error.reject "Caller not allowed to use this function";
    };
    let docInput2 : (Text, Text) = ("solutio_numbers", "transfers_builders_counter");
    var docs : [(Text, Text)] = [docInput2];
    var updAt_Id : ?Nat64 = null;
    var descriptionId : Text = Nat.toText(0);
    var docBlob : ?Blob = null;
    let getDocResponse : T.GetManyDocsResult = await bridge.getManyJunoDocs(docs);
    switch getDocResponse {
      case (#ok(response)) {
        for ((text, maybeDoc) in response.vals()) {
          switch (maybeDoc) {
            // We check if any document requested is non-existent
            case (null) {

              if ((text == "transfers_builders_counter")) {
                throw Error.reject("transfers_builders_counter document doesnt exist!");
              };
            };
            case (?doc) {
              if (text == "transfers_builders_counter") {
                switch (doc.description) {
                  case (null) {
                    throw Error.reject("transfers_builders_counter document should have a description");
                  };

                  case (?description) {
                    updAt_Id := doc.version;
                    docBlob := ?doc.data;
                    var totalId : Nat = switch (Nat.fromText(description)) {
                      case (null) {
                        throw Error.reject("transfers_builders_counter document description was not a Nat type");
                      };
                      case (?nat) {
                        nat;
                      };
                    };
                    totalId := totalId + amount;
                    descriptionId := Nat.toText(totalId);
                  };
                };
              };

            };
          };
        };
      };
      case (#err(error)) {
        throw Error.reject(error);
      };
    };
    let blobInput : Blob = switch (docBlob) {
      case (null) {
        throw Error.reject("Data is null");
      };
      case (?blob) {
        blob;
      };
    };
    let docData : T.DocInput = {
      version = updAt_Id;
      data = blobInput;
      description = ?descriptionId;
    };
    let docInputSet3 : (Text, Text, T.DocInput) = ("solutio_numbers", "transfers_builders_counter", docData);
    let updateData = await bridge.setManyJunoDocs([docInputSet3]);
    if (Text.notEqual(updateData, "Success!")) {
      throw Error.reject("Failed to update transfers_builders_counter number: " # updateData);
    };
    return "transfers_builders_counter modified successfully!";
  };

  // *******solutionsCompletedCounter********
  // Brief Description: Incrementally updates the count of completed solutions within the Solutio platform by adjusting the "solutions_completed_counter" each time a solution is marked as completed.
  // Pre-Conditions:
  //  - Although commented out, typically, only certain canisters (e.g., `escrowCanister`) or users with specific permissions would be allowed to call this function to ensure accurate tracking of completed solutions.
  //  - The "solutions_completed_counter" document must exist within the "solutio_numbers" collection for updates.
  // Post-Conditions:
  //  - The count of completed solutions stored in the "solutions_completed_counter" document is incremented by one to reflect the completion of another solution.
  // Validators:
  //  - (If applicable) Verifies the caller's identity to ensure that only authorized entities can execute the function.
  //  - Ensures the existence and proper formatting of the "solutions_completed_counter" document for reliable count updates.
  // External Functions Using It:
  //  - This function can be triggered after a solution is officially marked as completed, to keep an updated record of the platform's progress in addressing and solving user-generated ideas.
  // Official Documentation:
  //  - For a detailed explanation of how the `solutionsCompletedCounter` contributes to the transparency and achievement tracking on the Solutio platform, visit https://forum.solutio.one/-173/solutionscompletedcounter-documentation
  public shared /*(msg)*/ func solutionsCompletedCounter() : async Text {
    // if (msg.caller != escrowCanister) {
    //   throw Error.reject "Caller not allowed to use this function";
    // };
    let amount = 1;
    let docInput2 : (Text, Text) = ("solutio_numbers", "solutions_completed_counter");
    var docs : [(Text, Text)] = [docInput2];
    var updAt_Id : ?Nat64 = null;
    var descriptionId : Text = Nat.toText(0);
    var docBlob : ?Blob = null;
    let getDocResponse : T.GetManyDocsResult = await bridge.getManyJunoDocs(docs);
    switch getDocResponse {
      case (#ok(response)) {
        for ((text, maybeDoc) in response.vals()) {
          switch (maybeDoc) {
            // We check if any document requested is non-existent
            case (null) {

              if ((text == "solutions_completed_counter")) {
                throw Error.reject("solutions_completed_counter document doesnt exist!");
              };
            };
            case (?doc) {
              if (text == "solutions_completed_counter") {
                switch (doc.description) {
                  case (null) {
                    throw Error.reject("solutions_completed_counter document should have a description");
                  };

                  case (?description) {
                    updAt_Id := doc.version;
                    docBlob := ?doc.data;
                    var totalId : Nat = switch (Nat.fromText(description)) {
                      case (null) {
                        throw Error.reject("solutions_completed_counter document description was not a Nat type");
                      };
                      case (?nat) {
                        nat;
                      };
                    };
                    totalId := totalId + amount;
                    descriptionId := Nat.toText(totalId);
                  };
                };
              };

            };
          };
        };
      };
      case (#err(error)) {
        throw Error.reject(error);
      };
    };
    let blobInput : Blob = switch (docBlob) {
      case (null) {
        throw Error.reject("Data is null");
      };
      case (?blob) {
        blob;
      };
    };
    let docData : T.DocInput = {
      version = updAt_Id;
      data = blobInput;
      description = ?descriptionId;
    };
    let docInputSet3 : (Text, Text, T.DocInput) = ("solutio_numbers", "solutions_completed_counter", docData);
    let updateData = await bridge.setManyJunoDocs([docInputSet3]);
    if (Text.notEqual(updateData, "Success!")) {
      throw Error.reject("Failed to update solutions_completed_counter number: " # updateData);
    };
    return "solutions_completed_counter modified successfully!";
  };

  // *******userRevenueCounter********
  // Brief Description: Updates an individual user's revenue counter within the Solutio platform, reflecting new earnings.
  // Pre-Conditions:
  //  - The function can be designed to be called by specific canisters (e.g., `escrowCanister`) or users with permissions to ensure accurate revenue tracking. (Commented out permission check)
  //  - "users_revenue_counter" document for the user identified by `el_id` must exist for the update.
  // Post-Conditions:
  //  - Adjusts the total revenue recorded in the user's "users_revenue_counter" document by adding the specified `amount` to the existing total.
  // Validators:
  //  - Ensures the `el_id` corresponds to an existing user with a revenue counter.
  //  - Validates that the document contains both a description (for human-readable revenue info) and data (for computational purposes).
  // External Functions Using It:
  //  - This function could be called following the resolution of a solution or the distribution of rewards, allowing for the dynamic update of users' earnings on the platform.
  // Official Documentation:
  //  - Detailed guidelines and examples on how `userRevenueCounter` aids in financial transparency and user motivation on the Solutio platform can be found at https://forum.solutio.one/-173/userRevenueCounter-documentation
  public func /*(msg)*/ userRevenueCounter(el_id : Text, amount : Nat) : async Text {
    // if (msg.caller != escrowCanister) {
    //   throw Error.reject "Caller not allowed to use this function";
    // };
    let docInput1 : (Text, Text) = ("users_revenue_counter", "REV_" #el_id);
    var docs : [(Text, Text)] = [docInput1];
    var updAt_Id : ?Nat64 = null;
    var descriptionId : Text = "";
    var docBlob : ?Blob = null;
    let getDocResponse : T.GetManyDocsResult = await bridge.getManyJunoDocs(docs);
    switch getDocResponse {
      case (#ok(response)) {
        for ((text, maybeDoc) in response.vals()) {
          switch (maybeDoc) {
            // We check if any document requested is non-existent
            case (null) {
              if ((text == el_id)) {
                throw Error.reject("users_revenue_counter document of the element doesnt exist!");
              };
            };
            case (?doc) {
              if (text == "REV_" # el_id) {
                switch (doc.description) {
                  case (null) {
                    throw Error.reject("users_revenue_counter document should have a description");
                  };

                  case (?description) {
                    updAt_Id := doc.version;
                    docBlob := ?doc.data;
                    descriptionId := description;
                    var docBlobNotNull : Blob = switch (docBlob) {
                      case (null) {
                        throw Error.reject("users_revenue_counter document should have data");
                      };
                      case (?blob) {
                        blob;
                      };
                    };
                    var totalRev : T.TotalRevenue = await enc.totalRevenueDecode(docBlobNotNull);
                    totalRev := {
                      total_revenue = totalRev.total_revenue + amount;
                    };
                    docBlob := ?(await enc.totalRevenueEncode(totalRev));

                  };
                };
              };
            };
          };
        };
      };
      case (#err(error)) {
        throw Error.reject(error);
      };
    };
    let blobInput : Blob = switch (docBlob) {
      case (null) {
        throw Error.reject("Data is null");
      };
      case (?blob) {
        blob;
      };
    };
    let docData : T.DocInput = {
      version = updAt_Id;
      data = blobInput;
      description = ?descriptionId;
    };
    let docInputSet3 : (Text, Text, T.DocInput) = ("users_revenue_counter", "REV_" # el_id, docData);
    let updatedData = await bridge.setManyJunoDocs([docInputSet3]);
    if (Text.notEqual(updatedData, "Success!")) {
      throw Error.reject("Failed to update user " # el_id # " revenue number: " # updatedData);
    };
    return "User total revenue modified successfully!";
  };

  // *******ideaRevenueCounter********
  // Brief Description: Updates the revenue counter for a specific idea on the Solutio platform, reflecting new earnings from the idea.
  // Pre-Conditions:
  //  - Ideally designed to be called by authorized canisters or users (such as `escrowCanister`) to update revenue after certain transactions or approvals. (Commented out permission check)
  //  - Requires the existence of an "idea_revenue_counter" document for the idea identified by `el_id`.
  // Post-Conditions:
  //  - Updates the total revenue for the specified idea by adding the new `amount` to the current total in the "idea_revenue_counter" document.
  // Validators:
  //  - Ensures the existence of the `el_id` for the idea whose revenue is being updated.
  //  - Validates the presence of a description for readability and data for updating revenue calculations.
  // External Functions Using It:
  //  - This function might be invoked after an idea achieves certain milestones or receives payments, thus dynamically reflecting its financial success on the platform.
  // Official Documentation:
  //  - For a comprehensive explanation and examples of how `ideaRevenueCounter` supports financial tracking and showcases idea success, visit https://forum.solutio.one/-175/idearevenuecounter-documentation
  public func /*(msg)*/ ideaRevenueCounter(el_id : Text, amount : Nat) : async Text {
    // if (msg.caller != escrowCanister) {
    //   throw Error.reject "Caller not allowed to use this function";
    // };
    let docInput1 : (Text, Text) = ("idea_revenue_counter", "REV_" # el_id);
    var docs : [(Text, Text)] = [docInput1];
    var updAt_Id : ?Nat64 = null;
    var descriptionId : Text = "";
    var docBlob : ?Blob = null;
    let getDocResponse : T.GetManyDocsResult = await bridge.getManyJunoDocs(docs);
    switch getDocResponse {
      case (#ok(response)) {
        for ((text, maybeDoc) in response.vals()) {
          switch (maybeDoc) {
            // We check if any document requested is non-existent
            case (null) {
              if ((text == el_id)) {
                throw Error.reject("idea_revenue_counter document of the element doesnt exist!");
              };
            };
            case (?doc) {
              if (text == "REV_" # el_id) {
                switch (doc.description) {
                  case (null) {
                    throw Error.reject("idea_revenue_counter document should have a description");
                  };

                  case (?description) {
                    updAt_Id := doc.version;
                    docBlob := ?doc.data;
                    descriptionId := description;
                    var docBlobNotNull : Blob = switch (docBlob) {
                      case (null) {
                        throw Error.reject("idea_revenue_counter document should have data");
                      };
                      case (?blob) {
                        blob;
                      };
                    };
                    var totalRev : T.TotalRevenue = await enc.totalRevenueDecode(docBlobNotNull);
                    totalRev := {
                      total_revenue = totalRev.total_revenue + amount;
                    };
                    docBlob := ?(await enc.totalRevenueEncode(totalRev));

                  };
                };
              };
            };
          };
        };
      };
      case (#err(error)) {
        throw Error.reject(error);
      };
    };
    let blobInput : Blob = switch (docBlob) {
      case (null) {
        throw Error.reject("Data is null");
      };
      case (?blob) {
        blob;
      };
    };
    let docData : T.DocInput = {
      version = updAt_Id;
      data = blobInput;
      description = ?descriptionId;
    };
    let docInputSet3 : (Text, Text, T.DocInput) = ("idea_revenue_counter", "REV_" # el_id, docData);
    let updatedData = await bridge.setManyJunoDocs([docInputSet3]);
    if (Text.notEqual(updatedData, "Success!")) {
      throw Error.reject("Failed to update idea " # el_id # " revenue number: " # updatedData);
    };
    return "Idea total revenue modified successfully!";
  };

  // *******deleteElement********
  // Brief Description: Facilitates the comprehensive removal of an element (idea, user, solution, or feature) and all its related documents on the Solutio platform, ensuring data integrity and cleanliness.
  // Pre-Conditions:
  //  - Caller must be authenticated and verified as the owner or have the necessary permissions to delete the element.
  //  - The element and its associated documents must exist in the platform's database.
  // Post-Conditions:
  //  - Deletes the target element along with all related documents, including revenue counters, pledges, search indexes, and follower counts, ensuring no residual data is left.
  // Validators:
  //  - Ensures the element exists and the caller has the right to delete it.
  //  - Validates the 'what' parameter to ensure the correct type of element is being targeted for deletion.
  // External Functions Using It:
  //  - This function can be utilized in various administrative, user settings, or system cleanup operations within the Solutio platform.
  // Official Documentation:
  //  - Comprehensive guidelines and best practices for utilizing this function can be found at https://forum.solutio.one/-182/deleteelement-documentation
  public shared (msg) func deleteElement(el_id : Text, what : Text) : async Text {
    let caller = msg.caller;
    let callerText = Principal.toText(caller);
    // del_many_docs input : [(Text, Text, { version : ?Nat64 })]
    switch (what) {
      case ("idea") {
        // Documents to delete: idea_revenue_counter, idea_feature_pledge, pledges_solution, idea, index_search, followers
        let docInput1 : (Text, Text) = ("idea", el_id);
        let docInput2 : (Text, Text) = ("pledges_solution", "SOL_PL_" # el_id);
        let docInput3 : (Text, Text) = ("idea_feature_pledge", "PLG_IDEA_" # el_id);
        let docInput4 : (Text, Text) = ("idea_revenue_counter", "REV_IDEA_" # el_id);
        let docInput5 : (Text, Text) = ("index_search", "INDEX_" # el_id);
        let docInput6 : (Text, Text) = ("followers", "FOLL_" # el_id);
        var docs : [(Text, Text)] = [docInput1, docInput2, docInput3, docInput4, docInput5, docInput6];
        var deleteDocsInput : Buffer.Buffer<(Text, Text, { version : ?Nat64 })> = Buffer.Buffer<(Text, Text, { version : ?Nat64 })>(0);
        let getDocResponse : T.GetManyDocsResult = await bridge.getManyJunoDocs(docs);
        switch getDocResponse {
          case (#ok(response)) {
            for ((text, maybeDoc) in response.vals()) {
              switch (maybeDoc) {
                // We check if any document requested is non-existent
                case (null) {
                  if (text == el_id) {
                    throw Error.reject("Element doesnt exist!");
                  };
                };
                case (?doc) {
                  if (text == el_id) {
                    if (msg.caller != doc.owner) {
                      throw Error.reject("Caller is not the owner of the element.");
                    };
                    let docInput : (Text, Text, { version : ?Nat64 }) = ("idea", el_id, { version = doc.version });
                    deleteDocsInput.add(docInput);
                  };
                  if (text == "SOL_PL_" # el_id) {
                    let docInput : (Text, Text, { version : ?Nat64 }) = ("pledges_solution", "SOL_PL_" # el_id, { version = doc.version });
                    deleteDocsInput.add(docInput);
                  };
                  if (text == "REV_IDEA_" # el_id) {
                    let docInput : (Text, Text, { version : ?Nat64 }) = ("idea_revenue_counter", "REV_IDEA_" # el_id, { version = doc.version });
                    deleteDocsInput.add(docInput);
                  };
                  if (text == "INDEX_" # el_id) {
                    let docInput : (Text, Text, { version : ?Nat64 }) = ("index_search", "INDEX_" # el_id, { version = doc.version });
                    deleteDocsInput.add(docInput);
                  };
                  if (text == "FOLL_" # el_id) {
                    let docInput : (Text, Text, { version : ?Nat64 }) = ("followers", "FOLL_" # el_id, { version = doc.version });
                    deleteDocsInput.add(docInput);
                  };
                };
              };
            };
          };
          case (#err(error)) {
            return error;
          };
        };
        let result = await bridge.deleteManyJunoDocs(Buffer.toArray(deleteDocsInput));
        if (result != "Success!") {
          throw Error.reject("Idea couldnt be deleted: " # result);
        };
        return "Idea deleted successfully";
      };
      case ("user") {
        // Documents to delete: users_revenue_counter, user, user_index, followers, reputation
        let docInput1 : (Text, Text) = ("user", el_id);
        let docInput3 : (Text, Text) = ("reputation", "REP_" # el_id);
        let docInput4 : (Text, Text) = ("users_revenue_counter", "REV_" # el_id);
        let docInput5 : (Text, Text) = ("user_index", "INDEX_" # el_id);
        let docInput6 : (Text, Text) = ("followers", "FOLL_" # el_id);
        var docs : [(Text, Text)] = [docInput1, docInput3, docInput4, docInput5, docInput6];
        var deleteDocsInput : Buffer.Buffer<(Text, Text, { version : ?Nat64 })> = Buffer.Buffer<(Text, Text, { version : ?Nat64 })>(0);
        let getDocResponse : T.GetManyDocsResult = await bridge.getManyJunoDocs(docs);
        switch getDocResponse {
          case (#ok(response)) {
            for ((text, maybeDoc) in response.vals()) {
              switch (maybeDoc) {
                // We check if any document requested is non-existent
                case (null) {
                  if (text == el_id) {
                    throw Error.reject("User doesnt exist!");
                  };
                };
                case (?doc) {
                  if (text == el_id) {
                    if (msg.caller != doc.owner) {
                      throw Error.reject("Caller is not the owner of the element.");
                    };
                    let docInput : (Text, Text, { version : ?Nat64 }) = ("user", el_id, { version = doc.version });
                    deleteDocsInput.add(docInput);
                  };
                  if (text == "REP_" # el_id) {
                    let docInput : (Text, Text, { version : ?Nat64 }) = ("reputation", "REP_" # el_id, { version = doc.version });
                    deleteDocsInput.add(docInput);
                  };
                  if (text == "REV_" # el_id) {
                    let docInput : (Text, Text, { version : ?Nat64 }) = ("users_revenue_counter", "REV_" # el_id, { version = doc.version });
                    deleteDocsInput.add(docInput);
                  };
                  if (text == "INDEX_" # el_id) {
                    let docInput : (Text, Text, { version : ?Nat64 }) = ("user_index", "INDEX_" # el_id, { version = doc.version });
                    deleteDocsInput.add(docInput);
                  };
                  if (text == "FOLL_" # el_id) {
                    let docInput : (Text, Text, { version : ?Nat64 }) = ("followers", "FOLL_" # el_id, { version = doc.version });
                    deleteDocsInput.add(docInput);
                  };
                };
              };
            };
          };
          case (#err(error)) {
            return error;
          };
        };
        let result = await bridge.deleteManyJunoDocs(Buffer.toArray(deleteDocsInput));
        if (result != "Success!") {
          throw Error.reject("User couldnt be deleted: " # result);
        };
        "User deleted successfully";
      };
      case ("solution") {
        // Documents to delete: solution_status, solution_approved, solution, index_search, followers
        let docInput1 : (Text, Text) = ("solution", el_id);
        let docInput2 : (Text, Text) = ("solution_status", "SOL_STAT_" # el_id);
        let docInput4 : (Text, Text) = ("solution_approved", "SOL_APPR_" # el_id);
        let docInput5 : (Text, Text) = ("index_search", "INDEX_" # el_id);
        let docInput6 : (Text, Text) = ("followers", "FOLL_" # el_id);
        var docs : [(Text, Text)] = [docInput1, docInput2, docInput4, docInput5, docInput6];
        var deleteDocsInput : Buffer.Buffer<(Text, Text, { version : ?Nat64 })> = Buffer.Buffer<(Text, Text, { version : ?Nat64 })>(0);
        let getDocResponse : T.GetManyDocsResult = await bridge.getManyJunoDocs(docs);
        switch getDocResponse {
          case (#ok(response)) {
            for ((text, maybeDoc) in response.vals()) {
              switch (maybeDoc) {
                // We check if any document requested is non-existent
                case (null) {
                  if (text == el_id) {
                    throw Error.reject("Solution doesnt exist!");
                  };
                };
                case (?doc) {
                  if (text == el_id) {
                    if (msg.caller != doc.owner) {
                      throw Error.reject("Caller is not the owner of the element.");
                    };
                    let docInput : (Text, Text, { version : ?Nat64 }) = ("solution", el_id, { version = doc.version });
                    deleteDocsInput.add(docInput);
                  };
                  if (text == "SOL_STAT_" # el_id) {
                    let docInput : (Text, Text, { version : ?Nat64 }) = ("solution_status", "SOL_PL_" # el_id, { version = doc.version });
                    deleteDocsInput.add(docInput);
                  };
                  if (text == "SOL_APPR_" # el_id) {
                    let docInput : (Text, Text, { version : ?Nat64 }) = ("solution_approved", "SOL_APPR_" # el_id, { version = doc.version });
                    deleteDocsInput.add(docInput);
                  };
                  if (text == "INDEX_" # el_id) {
                    let docInput : (Text, Text, { version : ?Nat64 }) = ("index_search", "INDEX_" # el_id, { version = doc.version });
                    deleteDocsInput.add(docInput);
                  };
                  if (text == "FOLL_" # el_id) {
                    let docInput : (Text, Text, { version : ?Nat64 }) = ("followers", "FOLL_" # el_id, { version = doc.version });
                    deleteDocsInput.add(docInput);
                  };
                };
              };
            };
          };
          case (#err(error)) {
            return error;
          };
        };
        let result = await bridge.deleteManyJunoDocs(Buffer.toArray(deleteDocsInput));
        if (result != "Success!") {
          throw Error.reject("Idea couldnt be deleted: " # result);
        };
        "Solution deleted successfully";
      };
      case ("feature") {
        // Documents to delete: idea_revenue_counter, idea_feature_pledge, feature, index_search, followers
        let docInput1 : (Text, Text) = ("feature", el_id);
        let docInput3 : (Text, Text) = ("idea_feature_pledge", "PLG_FEA_" # el_id);
        let docInput4 : (Text, Text) = ("idea_revenue_counter", "REV_FEA_" # el_id);
        let docInput5 : (Text, Text) = ("index_search", "INDEX_" # el_id);
        let docInput6 : (Text, Text) = ("followers", "FOLL_" # el_id);
        var docs : [(Text, Text)] = [docInput1, docInput3, docInput4, docInput5, docInput6];
        var deleteDocsInput : Buffer.Buffer<(Text, Text, { version : ?Nat64 })> = Buffer.Buffer<(Text, Text, { version : ?Nat64 })>(0);
        let getDocResponse : T.GetManyDocsResult = await bridge.getManyJunoDocs(docs);
        switch getDocResponse {
          case (#ok(response)) {
            for ((text, maybeDoc) in response.vals()) {
              switch (maybeDoc) {
                // We check if any document requested is non-existent
                case (null) {
                  if (text == el_id) {
                    throw Error.reject("Element doesnt exist!");
                  };
                };
                case (?doc) {
                  if (text == el_id) {
                    if (msg.caller != doc.owner) {
                      throw Error.reject("Caller is not the owner of the element.");
                    };
                    let docInput : (Text, Text, { version : ?Nat64 }) = ("feature", el_id, { version = doc.version });
                    deleteDocsInput.add(docInput);
                  };
                  if (text == "REV_FEA_" # el_id) {
                    let docInput : (Text, Text, { version : ?Nat64 }) = ("idea_revenue_counter", "REV_FEA_" # el_id, { version = doc.version });
                    deleteDocsInput.add(docInput);
                  };
                  if (text == "PL_FEA_" # el_id) {
                    let docInput : (Text, Text, { version : ?Nat64 }) = ("idea_feature_pledge", "PL_FEA_" # el_id, { version = doc.version });
                    deleteDocsInput.add(docInput);
                  };
                  if (text == "INDEX_" # el_id) {
                    let docInput : (Text, Text, { version : ?Nat64 }) = ("index_search", "INDEX_" # el_id, { version = doc.version });
                    deleteDocsInput.add(docInput);
                  };
                  if (text == "FOLL_" # el_id) {
                    let docInput : (Text, Text, { version : ?Nat64 }) = ("followers", "FOLL_" # el_id, { version = doc.version });
                    deleteDocsInput.add(docInput);
                  };
                };
              };
            };
          };
          case (#err(error)) {
            return error;
          };
        };
        let result = await bridge.deleteManyJunoDocs(Buffer.toArray(deleteDocsInput));
        if (result != "Success!") {
          throw Error.reject("Idea couldnt be deleted: " # result);
        };
        "Feature deleted successfully";
      };
      case _ {
        throw Error.reject("Incorrect 'what' parameter. Type: " # what # "doesnt exist!");
      };
    };
  };

  public shared (msg) func createNotification(notiType : Text) : async Text {
    let notification : T.Notification = {
      title = "Example of notification title";
      subtitle = "Example of notification subtitle";
      imageURL = "https://png.pngtree.com/png-vector/20190419/ourmid/pngtree-vector-notification-icon-png-image_958619.jpg";
      linkURL = "https://xh6qb-uyaaa-aaaal-acuaq-cai.icp0.io/idea?id=2lRq1Zc3xdId1cWCfYW9Y";
      sender = Principal.toText(msg.caller);
      typeOf = notiType;
      description = "Example of a description";
    };
    return await noti.createPersonalNotification(Principal.toText(msg.caller), Principal.toText(msg.caller), notification);
  };
};
