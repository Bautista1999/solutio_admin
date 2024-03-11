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
    public func createNotification() : async Text {
        return "Success";
    };
};
