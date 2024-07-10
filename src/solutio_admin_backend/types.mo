import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
module {
    public type Doc = {
        updated_at : Nat64;
        owner : Principal;
        data : Blob;
        description : ?Text;
        created_at : Nat64;
        version : ?Nat64;
    };
    public type ListMatcher = { key : ?Text; description : ?Text };
    public type ListOrder = { field : ListOrderField; desc : Bool };
    public type ListOrderField = { #UpdatedAt; #Keys; #CreatedAt };
    public type ListPaginate = { start_after : ?Text; limit : ?Nat64 };
    public type ListParams = {
        order : ?ListOrder;
        owner : ?Principal;
        matcher : ?ListMatcher;
        paginate : ?ListPaginate;
    };
    public type ListResults_1 = {
        matches_pages : ?Nat64;
        matches_length : Nat64;
        items_page : ?Nat64;
        items : [(Text, Doc)];
        items_length : Nat64;
    };

    public type SolutionStatus = {
        status : Text;
    };
    public type Pledge = {
        doc_key : Text;
        idea_id : Text;
        feature_id : Text;
        amount : Nat64;
        expected_amount : Nat64;
        user : Text;
        target : Text;
    };
    public type DocResponse = {
        version : Nat64;
        owner : Principal;
        data : Blob;
        description : ?Text;
        created_at : Nat64;
    };

    public type DocInput = {
        data : Blob;
        description : ?Text;
        version : ?Nat64;
    };
    public type UpdateDocInput = {
        version : Nat64;
        data : Blob;
        description : ?Text;
    };
    public type SetDocInput = {
        key : Text;
        collection : Text;
        doc : DocInput;
    };
    public type UpdateManyDocsInput = [(Text, Text, UpdateDocInput)];
    public type SetManyDocsInput = [(Text, Text, DocInput)];
    public type GetDocResponse = (Doc);
    public type GetDocManyResponse = {
        key : ?Text;
        document : ?Doc;
    };
    public type GetManyDocsResponse = [(Text, ?Doc)];
    public type GetDocResult = { #ok : GetDocResponse; #err : Text };
    public type GetManyDocsInput = [(Text, Text)];
    public type GetManyDocsResult = { #ok : GetManyDocsResponse; #err : Text };
    public type OrderField = { #UpdatedAt; #Keys; #CreatedAt };
    public type Order = ?{ field : OrderField; desc : Bool };
    public type Matcher = ?{ key : ?Text; description : ?Text };
    public type Paginate = ?{ start_after : ?Text; limit : ?Nat64 };

    public type ListDocsFilter = ({
        order : Order;
        owner : ?Principal;
        matcher : Matcher;
        paginate : Paginate;
    });

    public type ListDocsResponse = {
        matches_pages : ?Nat64;
        matches_length : Nat64;
        items_page : ?Nat64;
        items : [(Text, Doc)];
        items_length : Nat64;
    };
    public type ListDocsResult = { #ok : ListDocsResponse; #err : Text };

    public type DelDocInput = (Text, Text, { version : Nat64 });
    public type CollectionKeyPair = {
        collection : Text;
        key : Text;
        docInput : DocInput;
    };

    public type PledgeCreateInput = {
        doc_key : Text;
        idea_id : Text;
        feature_id : Text;
        amount : Nat64;
        accounta : Blob;
    };

    public type User = {
        user : Text;
        amount_pledged : Nat;
        amount_paid : Nat;
    };

    public type UserPledgeListResult = { #ok : [User]; #err : Text };
    public type TotalPledging = {
        pledges : Nat64;
        expected : Nat64;
    };
    public type PledgeActive = {
        pledge : Nat64;
        expected : Nat64;
    };
    public type PledgeActiveNat = {
        pledge : Nat;
        expected : Nat;
    };
    public type ReputationNumbers = {
        amount_promised : Nat64;
        amount_paid : Nat64;
    };
    public type ReputationNumbersNat = {
        amount_promised : Nat;
        amount_paid : Nat;
    };
    public type ReputationNumbersResult = {
        #ok : ReputationNumbers;
        #err : Text;
    };

    public type TotalRevenue = {
        total_revenue : Nat;
    };

    public type PledgeActiveResult = {
        #ok : PledgeActive;
        #err : Text;
    };
    public type TotalPledgingNat = {
        pledges : Nat;
        expected : Nat;
    };
    public type TotalPledgingResult = { #ok : TotalPledging; #err : Text };

    public type Notification = {
        title : Text;
        subtitle : Text;
        imageURL : Text;
        linkURL : Text;
        sender : Text;
        description : Text;
        typeOf : Text;
    };
};
