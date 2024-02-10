import Principal "mo:base/Principal";
module {
    public type Doc = {
        updated_at : ?Nat64;
        owner : Principal;
        data : Blob;
        description : ?Text;
        created_at : Nat64;
    };
    public type DocResponse = {
        updated_at : Nat64;
        owner : Principal;
        data : Blob;
        description : ?Text;
        created_at : Nat64;
    };

    public type DocInput = {
        updated_at : ?Nat64;
        data : Blob;
        description : ?Text;
    };
    public type UpdateDocInput = {
        updated_at : Nat64;
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
    public type GetDocResponse = (DocResponse);
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
    public type GetManyDocsResponse = [(Text, ?DocResponse)];
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

    public type DelDocInput = (Text, Text, { updated_at : Nat64 });
    public type CollectionKeyPair = {
        collection : Text;
        key : Text;
        docInput : DocInput;
    };
};
