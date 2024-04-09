import T "./types";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Char "mo:base/Char";

import Error "mo:base/Error";
import Text "mo:base/Text";
import { JSON } "mo:serde";
import serdeJson "mo:serde/JSON";
import Buffer "mo:base/Buffer";
module {

    public func pledgesSolutionDecode(data : Blob) : async [T.UserReputationInfo] {
        // Conversion:
        //     a. Parse JSON text into a candid blob using JSON.fromText.
        //     b. Convert the blob to a Motoko data type with from_candid.
        //let jsonText = "[{\"name\": \"John\", \"id\": 123}, {\"name\": \"Jane\", \"id\": 456, \"email\": \"jane@gmail.com\"}]";
        //let #ok(blob) = JSON.fromText(jsonText, null); // you probably want to handle the error case here :)
        try {
            let info = Text.decodeUtf8(data);
            // let ht : Blob = to_candid (#Blob data);
            // let json_result : { #ok : Text; #err : Text } = JSON.toText(ht, UserKeys, null);
            switch (info) {
                case (?info) {
                    let blob = serdeJson.fromText(info, null);
                    switch (blob) {
                        case (#ok(blob)) {
                            let users : ?[T.UserReputationInfo] = from_candid (blob);
                            switch (users) {
                                case (?users) {
                                    return users;
                                };
                                case null {
                                    throw Error.reject("List could not be parsed: returned null");
                                };
                            };
                        };
                        case (#err(err)) {
                            throw Error.reject("List could not be parsed");
                        };
                    };
                    //return #ok(info);
                };
                case (null) {
                    throw Error.reject("List could not be parsed.");
                };
            };

        } catch (e) {
            throw Error.reject("List could not be parsed.");
        };

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
};
