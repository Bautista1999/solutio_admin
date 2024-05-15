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
        version : ?Nat64;
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
            version : ?Nat64;
            owner : Principal;
            data : Blob;
            description : ?Text;
            created_at : Nat64;
        };
    };
    public type GetManyDocsResult = { #ok : GetManyDocsResponse; #err : Text };
    public type GetManyDocsResponse = [(Text, ?DocResponse)];
    public type DocResponse = {
        version : Nat64;
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

    public type DelDocInput = (Text, Text, { version : Nat64 });
    public type CollectionKeyPair = {
        collection : Text;
        key : Text;
        docInput : DocInput;
    };
    public type Doc = {
        version : ?Nat64;
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

// 1. *******claimTokens********
// Brief Description: Executes token transfers from pledgers to builders for a completed project. It iterates through
//  https://forum.solutio.one/-186/claimtokens-documentation
//2.  *******solutionCompletion********
// `    Brief Description: Marks a solution as completed after verifying ownership and delivery status. It also claims tokens for the solution, updates its status to "completed", and adjusts revenue and solution completion counters.
//      https://forum.solutio.one/-187/solutioncompletion-documentation
// 3. *******verifyAndStoreTransaction********
// Brief Description: Verifies a transaction's existence on the ledger and stores its details within the platform.
// (https://forum.solutio.one/-195/verifyandstoretransaction-documentation).
//4.*******getProjectRevenue********
// Brief Description: Calculates the total revenue generated for a project within Solutio by summing up all successful transactions related to the project ID.
// Official Documentation:
//  https://forum.solutio.one/-196/getprojectrevenue-documentation
// 5. *******getUserRevenue********
// Brief Description: Calculates total revenue accrued by a user from successful transactions where they are the target, providing transparent financial insights.
// https://forum.solutio.one/-197/getuserrevenue-documentation
// 6. *******getUserSpending********
// Brief Description: Calculates the total spending of a user by summing up all successful transactions initiated by them on the Solutio platform.
//      https://forum.solutio.one/-198/getuserspending-documentation
// 7.  *******getUserReputation********
// Brief Description: Retrieves the reputation score and details of a specified user within the Solutio platform, reflecting their engagement and reliability based on historical transactions and pledges.
//      https://forum.solutio.one/-201/getuserreputation-documentation
//8.  *******editReputation********
// Brief Description: Adjusts a user's reputation based on new and previous transaction figures. It recalculates the user's reputation score, taking into account the latest paid and promised amounts alongside their previous figures.
// https://forum.solutio.one/-200/editreputation-documentation
//9. *******updateReputation********
// Brief Description: Updates a user's reputation based on the ratio of actual payments to promised contributions within Solutio. This function recalculates and updates the reputation score to reflect the user's reliability and engagement in funding projects.
//     https://forum.solutio.one/-199/updateReputation-documentation
//10. *******editApproval********
// Brief Description: Modifies existing project approvals by a specific sender, replacing them with a new set of approvals.
//     https://forum.solutio.one/-203/editapprovals-documentation
//11. *******removeApprovals_bySender********
// Brief Description: Removes all approvals initiated by a specified sender for a given project.
// https://forum.solutio.one/-204/removeapprovalsbysender-documentation
//12. *******updateAllReputations********
// Brief Description: Updates the reputation of multiple users based on their contributions to a completed project. This function iterates through a list of users, updating each one's reputation in the context of the project specified by `project_id`.
// https://forum.solutio.one/-202/updateallreputations-documentation
//13. *******solutionsCompletedCounter********
// Brief Description: Incrementally updates the count of completed solutions within the Solutio platform by adjusting the "solutions_completed_counter" each time a solution is marked as completed.
// https://forum.solutio.one/-173/solutionscompletedcounter-documentation
//14. *******ideaRevenueCounter********
// Brief Description: Updates the revenue counter for a specific idea on the Solutio platform, reflecting new earnings from the idea.
// https://forum.solutio.one/-175/idearevenuecounter-documentation
//15. ******* updateSolutionStatus() ********
// Brief Description: Changes the status of a solution, validating the ownership and current status beforehand.
// https://forum.solutio.one/-176/updatesolutionstatus-documentation.
//16. *******storeTransaction********
// Brief Description: Registers a new transaction within the escrow system,
//  linking it to the involved parties (sender and target) and the associated project. Generates a
//  unique transaction ID and updates the transaction, sender, target, and project records accordingly.
// https://forum.solutio.one/-183/storetransaction-documentation).
//17. *******getTransactionsBySender********
// Brief Description: Retrieves a list of transactions initiated by a specific sender. This function
//  searches through the system's records, matching the given sender's Principal with the transaction
//  records, and compiles a list of all transactions that were initiated by this sender.
// https://forum.solutio.one/-184/gettransactionsbysender-documentation).
//18. *******getTransactionsByTarget********
// Brief Description: Retrieves a list of transactions where the specified principal is the target.
//  This function is essential for users or projects that need to review incoming transactions,
//  providing a direct way to access transactional history associated with them.
// (https://forum.solutio.one/-188/gettransactionsbytarget-documentation).
//19. *******getTransactionsByProject********
// Brief Description: Retrieves a list of transactions associated with a specific project, identified
// by its unique textual identifier. This function serves as a crucial tool for project managers,
//  auditors, and stakeholders to gain insights into the financial activities surrounding a project, including funding, expenditures, and rewards.
// (https://forum.solutio.one/-189/gettransactionsbyproject-documentation).
// 20. *******storeApprovals********
// Brief Description: Stores a list of user approvals for a specific project within the Solutio platform.
//  This function aggregates new approvals with any existing ones for the given project ID.
// https://forum.solutio.one/-190/storeapprovals-documentation
//21. *******getApprovals********
// Brief Description: Retrieves all approval transactions associated with a specific project within the Solutio platform. This function is designed to fetch and list all user approvals that have been made towards a project, identified by its project_id. It's crucial for auditing, tracking, and managing financial transactions related to project funding.
// [https://forum.solutio.one/-185/getapprovals-documentation].
//22. *******getProjectsApprovals_bySender********
// Brief Description: Retrieves all approvals made by a specific sender for a particular project
// within the Solutio platform. This function filters the approvals associated with a project to return only those initiated by the specified sender.
// https://forum.solutio.one/-191/getprojectsapprovalsbysender-documentation
//23. *******getProjectsApprovals_byTarget********
// Brief Description: Retrieves all approvals targeted towards a specific recipient within a project on the Solutio platform. This function filters the approvals for a given project to isolate those directed at the specified target.
// https://forum.solutio.one/-192/getprojectsapprovalsbytarget-documentation
//24. *******getProjectApprovals_lowerThan********
// Brief Description: Retrieves all approvals for a given project that have an amount less than or equal to a specified threshold. This function is essential for filtering approvals based on their amount to manage or analyze financial transactions within the project effectively.
// https://forum.solutio.one/-193/getprojectapprovalslowerthan-documentation
//25. *******getProjectApprovals_majorThan********
// Brief Description: Retrieves all approvals for a specific project that have an amount greater than a specified threshold. This function enables the precise filtering of approvals based on their financial value, facilitating detailed analysis and management within the project's context.
// https://forum.solutio.one/-194/getprojectapprovalsmajorthan-documentation
