import T "./types";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Char "mo:base/Char";
import Nat "mo:base/Nat";
import List "mo:base/List";
import Array "mo:base/Array";
import Error "mo:base/Error";
import Text "mo:base/Text";
import { JSON; Candid; CBOR } "mo:serde";
import serdeJson "mo:serde/JSON";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";

module {
    // Function for ID validation
    //TODO: Create this
    public func validateId(id : Text) : Bool {
        // Implement ID validation logic
        return true;
    };

    public func textToNat64(txt : Text) : Nat64 {
        assert (txt.size() > 0);
        let chars = txt.chars();

        var num : Nat32 = 0;
        for (v in chars) {
            let charToNum = (Char.toNat32(v) -48);
            assert (charToNum >= 0 and charToNum <= 9);
            num := num * 10 + charToNum;
        };

        Nat32.toNat64(num);
    };

    public func pledgesSolutionDecode(data : Blob) : async T.UserPledgeListResult {
        // Conversion:
        //     a. Parse JSON text into a candid blob using JSON.fromText.
        //     b. Convert the blob to a Motoko data type with from_candid.
        //let jsonText = "[{\"name\": \"John\", \"id\": 123}, {\"name\": \"Jane\", \"id\": 456, \"email\": \"jane@gmail.com\"}]";
        //let #ok(blob) = JSON.fromText(jsonText, null); // you probably want to handle the error case here :)
        try {
            let UserKeys = ["user", "amount_pledged", "amount_paid"];
            let info = Text.decodeUtf8(data);
            // let ht : Blob = to_candid (#Blob data);
            // let json_result : { #ok : Text; #err : Text } = JSON.toText(ht, UserKeys, null);
            switch (info) {
                case (?info) {
                    let blob = serdeJson.fromText(info, null);
                    switch (blob) {
                        case (#ok(blob)) {
                            let users : ?[T.User] = from_candid (blob);
                            switch (users) {
                                case (?users) {
                                    return #ok(users);
                                };
                                case null {
                                    return #err("Unexpected error: Incorrectly parsed");
                                };
                            };
                        };
                        case (#err(err)) {
                            return #err(err);
                        };
                    };
                    //return #ok(info);
                };
                case (null) {
                    return #err("Data was incorrectly decoded");
                };
            };

        } catch (e) {
            return #err(Error.message(e));
        };

    };
    public func pledgesSolutionEncode(data : [T.User]) : async {
        #ok : Blob;
        #err : Text;
    } {
        try {
            let UserKeys = ["user", "amount_pledged", "amount_paid"];
            let blob : Blob = to_candid (data);
            let json_result = JSON.toText(blob, UserKeys, null);
            switch (json_result) {
                case (#ok(json)) {
                    let info : Blob = Text.encodeUtf8(json);
                    switch (?info) {
                        case (?info) {
                            return #ok(info);
                        };
                        case (null) {
                            return #err("Data was incorrectly decoded");
                        };
                    };
                };
                case (#err(error)) {
                    return #err(error);
                };
            };

            // let info = Text.decodeUtf8(data);
            // let blob = serdeJson.fromText(info, null);
            // let users : ?[T.User] = from_candid (blob);

        } catch (e) {
            return #err(Error.message(e));
        };

    };
    // it receives a list and an element to add. If the element its already in the list,
    // it updates the list. If it isnt on it, it adds it.
    public func iterateUsersPledges(users : [T.User], user : T.User) : [T.User] {
        var updatedUsers : Buffer.Buffer<T.User> = Buffer.Buffer<T.User>(0);
        var userFound : Bool = false;
        for (thisUser in users.vals()) {
            if (thisUser.user == user.user) {
                // He has already pledged
                var amountPledged = user.amount_pledged + thisUser.amount_pledged;
                if (amountPledged == 0) {
                    amountPledged := user.amount_paid;
                };
                updatedUsers.add({
                    user = user.user;
                    amount_pledged = amountPledged;
                    amount_paid = user.amount_paid + thisUser.amount_paid;
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
            var amountPledged = user.amount_pledged;
            if (amountPledged == 0) {
                amountPledged := user.amount_paid;
            };
            updatedUsers.add({
                user = user.user;
                amount_pledged = amountPledged;
                amount_paid = user.amount_paid;
            });
        };
        let updatedUsersArray : [T.User] = Buffer.toArray(updatedUsers);

        return updatedUsersArray;

    };
    // edits the amount paid of a given user.
    public func iterateUsersPledges_editPayment(users : [T.User], user : T.User) : [T.User] {
        var updatedUsers : Buffer.Buffer<T.User> = Buffer.Buffer<T.User>(0);
        var userFound : Bool = false;
        for (thisUser in users.vals()) {
            if (thisUser.user == user.user) {
                // He has already pledged
                var amountPledged = user.amount_pledged + thisUser.amount_pledged;
                if (amountPledged == 0) {
                    amountPledged := user.amount_paid;
                };
                updatedUsers.add({
                    user = user.user;
                    amount_pledged = amountPledged;
                    amount_paid = user.amount_paid; //new amount
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
            var amountPledged = user.amount_pledged;
            if (amountPledged == 0) {
                amountPledged := user.amount_paid;
            };
            updatedUsers.add({
                user = user.user;
                amount_pledged = amountPledged;
                amount_paid = user.amount_paid;
            });
        };
        let updatedUsersArray : [T.User] = Buffer.toArray(updatedUsers);

        return updatedUsersArray;

    };
    public func totalPledgesDecode(data : Blob) : async T.TotalPledgingResult {
        try {
            let info = Text.decodeUtf8(data);
            switch (info) {
                case (?info) {
                    //return #err("Data stringyfied: " #info);
                    let blob = serdeJson.fromText(info, null);
                    switch (blob) {
                        case (#ok(blob)) {
                            let money : ?T.TotalPledgingNat = from_candid (blob);
                            switch (money) {
                                case (?money) {
                                    let moneyNat64 : T.TotalPledging = {
                                        pledges = Nat64.fromNat(money.pledges);
                                        expected = Nat64.fromNat(money.expected);
                                    };
                                    return #ok(moneyNat64);
                                };
                                case null {
                                    return #err("Incorrectly parsed");
                                };
                            };
                        };
                        case (#err(err)) {
                            return #err(err);
                        };
                    };
                    //return #ok(info);
                };
                case (null) {
                    return #err("Data was incorrectly decoded");
                };
            };
        } catch (e) {
            return #err(Error.message(e));
        };
    };

    public func totalPledgesUpdate(amount : Nat64, expected : Nat64, pledgesInfo : T.TotalPledging) : T.TotalPledging {
        let updatedPledgeInfo : T.TotalPledging = {
            pledges = amount + pledgesInfo.pledges;
            expected = expected + pledgesInfo.expected;
        };
    };
    public func totalPledgesUpdate_edit(amount : Nat64, expected : Nat64, pledgesInfo : T.TotalPledging, previousPledge : T.PledgeActive) : T.TotalPledging {
        let updatedPledgeInfo : T.TotalPledging = {
            pledges = amount + pledgesInfo.pledges - previousPledge.pledge;
            expected = expected + pledgesInfo.expected - previousPledge.expected;
        };
    };
    public func totalPledgesEncode(data : T.TotalPledgingNat) : async {
        #ok : Blob;
        #err : Text;
    } {
        try {
            let UserKeys = ["pledges", "expected"];
            let blob : Blob = to_candid (data);
            let json_result = JSON.toText(blob, UserKeys, null);
            switch (json_result) {
                case (#ok(json)) {
                    let info : Blob = Text.encodeUtf8(json);
                    switch (?info) {
                        case (?info) {
                            return #ok(info);
                        };
                        case (null) {
                            return #err("Data was incorrectly decoded");
                        };
                    };
                };
                case (#err(error)) {
                    return #err(error);
                };
            };
        } catch (e) {
            return #err(Error.message(e));
        };
    };
};
