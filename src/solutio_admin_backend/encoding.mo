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
    public func pledgeEncode(data : T.PledgeActive) : async {
        #ok : Blob;
        #err : Text;
    } {
        try {
            let UserKeys = ["pledge", "expected"];
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
    public func pledgeDataDecode(data : Blob) : async T.PledgeActiveResult {
        try {
            let info = Text.decodeUtf8(data);
            switch (info) {
                case (?info) {
                    let blob = serdeJson.fromText(info, null);
                    switch (blob) {
                        case (#ok(blob)) {
                            let pledge : ?T.PledgeActiveNat = from_candid (blob);
                            switch (pledge) {
                                case (?money) {

                                    let moneyNat64 : T.PledgeActive = {
                                        pledge = Nat64.fromNat(money.pledge);
                                        expected = Nat64.fromNat(money.expected);
                                    };
                                    return #ok(moneyNat64);
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

    public func updatePledges(users : [T.User], user : T.User, previousPledge : T.PledgeActive) : [T.User] {
        var updatedUsers : Buffer.Buffer<T.User> = Buffer.Buffer<T.User>(0);
        var userFound : Bool = false;
        for (thisUser in users.vals()) {
            if (thisUser.user == user.user) {
                let amount : Nat = user.amount_pledged + thisUser.amount_pledged - Nat64.toNat(previousPledge.pledge);
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

    public func reputationNumbersDecode(data : Blob) : async T.ReputationNumbersResult {
        try {
            let info = Text.decodeUtf8(data);
            switch (info) {
                case (?info) {
                    let blob = serdeJson.fromText(info, null);
                    switch (blob) {
                        case (#ok(blob)) {
                            let pledge : ?T.ReputationNumbersNat = from_candid (blob);
                            switch (pledge) {
                                case (?money) {

                                    let moneyNat64 : T.ReputationNumbers = {
                                        amount_promised = Nat64.fromNat(money.amount_promised);
                                        amount_paid = Nat64.fromNat(money.amount_paid);
                                    };
                                    return #ok(moneyNat64);
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
    public func reputationEncode(data : T.ReputationNumbers) : async {
        #ok : Blob;
        #err : Text;
    } {
        try {
            let UserKeys = ["amount_promised", "amount_paid"];
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
    public func solutionApprovalDataEncode(data : Text) : async Blob {
        let info : Blob = Text.encodeUtf8(data);
        return info;
    };

    public func totalRevenueDecode(data : Blob) : async T.TotalRevenue {
        try {
            let info = Text.decodeUtf8(data);
            switch (info) {
                case (?info) {
                    let blob = serdeJson.fromText(info, null);
                    switch (blob) {
                        case (#ok(blob)) {
                            let pledge : ?T.TotalRevenue = from_candid (blob);
                            switch (pledge) {
                                case (?money) {
                                    return money;
                                };
                                case null {
                                    throw Error.reject("Total revenue could not be parsed");
                                };
                            };
                        };
                        case (#err(err)) {
                            throw Error.reject(err);
                        };
                    };
                };
                case (null) {
                    throw Error.reject("Data was incorrectly decoded");
                };
            };

        } catch (e) {
            throw Error.reject(Error.message(e));

        };

    };

    public func totalRevenueEncode(data : T.TotalRevenue) : async Blob {
        try {
            let UserKeys = ["total_revenue"];
            let blob : Blob = to_candid (data);
            let json_result = JSON.toText(blob, UserKeys, null);
            switch (json_result) {
                case (#ok(json)) {
                    let info : Blob = Text.encodeUtf8(json);
                    switch (?info) {
                        case (?info) {
                            return info;
                        };
                        case (null) {
                            throw Error.reject("Data was incorrectly decoded");
                        };
                    };
                };
                case (#err(error)) {
                    throw Error.reject(error);
                };
            };
        } catch (e) {
            throw Error.reject(Error.message(e));
        };
    };

    public func notificationEncode(data : T.Notification) : async Blob {
        try {
            // title : Text;
            // subtitle : Text;
            // imageURL : Text;
            // linkURL : Text;
            // sender : Text;
            let UserKeys = ["title", "subtitle", "imageURL", "linkURL", "sender"];
            let blob : Blob = to_candid (data);
            let json_result = JSON.toText(blob, UserKeys, null);
            switch (json_result) {
                case (#ok(json)) {
                    let info : Blob = Text.encodeUtf8(json);
                    switch (?info) {
                        case (?info) {
                            return info;
                        };
                        case (null) {
                            throw Error.reject("Data was incorrectly decoded");
                        };
                    };
                };
                case (#err(error)) {
                    throw Error.reject(error);
                };
            };
        } catch (e) {
            throw Error.reject(Error.message(e));
        };
    };
};
