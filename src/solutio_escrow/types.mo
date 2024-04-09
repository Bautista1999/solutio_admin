import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";
import Hash "mo:base/Hash";
import Trie "mo:base/Trie";

module {
    public type Transaction = {
        sender : Principal;
        target : Principal;
        amount : Nat;
        transaction_number : ?Nat;
        status : Text;
        message : Text;
        project_id : Text;
        created_at : Nat64;
    };
    public type Reputation = {
        number : Nat;
        amount_promised : Nat;
        amount_paid : Nat;
    };
    public type DocInput = {
        updated_at : ?Nat64;
        data : Blob;
        description : ?Text;
    };
    public type TotalRevenue = {
        total_revenue : Nat;
    };
    public type Key = { key : Text; hash : Hash.Hash };
    public type TransactionKey = {
        sender : Principal;
        target : Principal;
        transaction_id : Text;
    };

    // public type Approval = (Principal, Principal, Nat64);
    public type Approval = {
        sender : Principal;
        target : Principal;
        amount : Nat;
        approval_transaction_number : Nat;
    };
    public type Project_Trie = Trie.Trie<Text, [Approval]>;
    public type GetManyDocsInput = [(Text, Text)];
    public type SetManyDocsInput = [(Text, Text, DocInput)];
    public type GetDocManyResponse = {
        key : ?Text;
        document : ?{
            updated_at : ?Nat64;
            owner : Principal;
            data : Blob;
            description : ?Text;
            created_at : Nat64;
        };
    };
    public type GetManyDocsResult = { #ok : GetManyDocsResponse; #err : Text };
    public type GetManyDocsResponse = [(Text, ?DocResponse)];
    public type DocResponse = {
        updated_at : Nat64;
        owner : Principal;
        data : Blob;
        description : ?Text;
        created_at : Nat64;
    };
    public type Order = ?{ field : OrderField; desc : Bool };
    public type Matcher = ?{ key : ?Text; description : ?Text };
    public type Paginate = ?{ start_after : ?Text; limit : ?Nat64 };
    public type ListDocsResponse = {
        matches_pages : ?Nat64;
        matches_length : Nat64;
        items_page : ?Nat64;
        items : [(Text, Doc)];
        items_length : Nat64;
    };
    public type GetDocResult = { #ok : GetDocResponse; #err : Text };
    public type ListDocsResult = { #ok : ListDocsResponse; #err : Text };

    public type DelDocInput = (Text, Text, { updated_at : Nat64 });
    public type CollectionKeyPair = {
        collection : Text;
        key : Text;
        docInput : DocInput;
    };
    public type Doc = {
        updated_at : ?Nat64;
        owner : Principal;
        data : Blob;
        description : ?Text;
        created_at : Nat64;
    };
    public type OrderField = { #UpdatedAt; #Keys; #CreatedAt };
    public type ListDocsFilter = ({
        order : Order;
        owner : ?Principal;
        matcher : Matcher;
        paginate : Paginate;
    });
    public type GetDocResponse = (DocResponse);
    public type ReputationNumbersNat = {
        amount_promised : Nat;
        amount_paid : Nat;
    };
    public type UserReputationInfo = {
        user : Text;
        amount_pledged : Nat;
        amount_paid : Nat;
    };
};
