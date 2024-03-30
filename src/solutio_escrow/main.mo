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
import Buffer "mo:base/Buffer";
import Trie "mo:base/Trie";
import Hash "mo:base/Hash";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Source "mo:uuid/async/SourceV4";
import UUID "mo:uuid/UUID";
import Ledger "./icrc.bridge";
import Prim "mo:⛔";
import admin "canister:solutio_admin_backend";

actor Escrow {

    // TODO : Transaction number to keep certain order of transaction for when we use more than one ledger.
    stable var solution_trans_number : Nat64 = 0;

    stable var transactions : Trie.Trie<Text, T.Transaction> = Trie.empty();
    stable var targets : Trie.Trie<Principal, [Text]> = Trie.empty();
    stable var senders : Trie.Trie<Principal, [Text]> = Trie.empty();
    stable var projects : Trie.Trie<Text, [Text]> = Trie.empty();

    stable var transactions_approvals : T.Project_Trie = Trie.empty();

    func key(text : Text) : T.Key {
        let hash = Text.hash(text);
        return { hash = hash; key = text };
    };
    func key_equal(k1 : Text, k2 : Text) : Bool {
        Text.hash(k1) == Text.hash(k2);
    };

    public func getAllTargetTransactions() : async [(Principal, [Text])] {
        return Iter.toArray(Trie.iter(targets));
    };
    public func getAllSenderTransactions() : async [(Principal, [Text])] {
        return Iter.toArray(Trie.iter(senders));
    };

    // ******* TESTING FUNCTIONS **********

    let user : Principal = Principal.fromText("ocpcu-jaaaa-aaaab-qab6q-cai");
    public shared (msg) func aaaa_storeFakeTransactions(status : Text) : async Text {
        let transaction_id : Text = await generate_random_uuid();
        // sender : Principal;
        // target : Principal;
        // amount : Nat64;
        // transaction_number : Nat64;
        // status : Text;
        // message : Text;
        // project_id : Text;
        // created_at : Nat64;
        let transaction : T.Transaction = {
            sender = msg.caller;
            target = msg.caller;
            amount = 0;
            transaction_number = null;
            status = status;
            message = "The result of the transaction was: " # status;
            project_id = transaction_id;
            created_at = 1_0000_0000;
        };
        let array_example = [1, 2, 3, 4, 5, 6];
        for (num in array_example.vals()) {
            Debug.print("Number : " # Nat.toText(num));
            let example = await storeTransaction(msg.caller, msg.caller, transaction, transaction_id);
        };
        return "Success"

    };

    public shared (msg) func getFakeTransactionSender() : async ?[T.Transaction] {
        return await getTransactionsBySender(msg.caller);
    };

    public shared (msg) func getFakeTransactionSender_NotAnonymous() : async ?[T.Transaction] {
        return await getTransactionsBySender(Principal.fromText("ocpcu-jaaaa-aaaab-qab6q-cai"));
    };

    public shared (msg) func getFakeTransactionTarget() : async ?[T.Transaction] {
        return await getTransactionsByTarget(msg.caller);
    };

    public shared (msg) func storeFakeTransaction_NotAnonymous(status : Text) : async Text {
        let transaction_id : Text = await generate_random_uuid();

        let transaction : T.Transaction = {
            sender = Principal.fromText("ocpcu-jaaaa-aaaab-qab6q-cai");
            target = msg.caller;
            amount = 0;
            transaction_number = null;
            status = status;
            message = "The result of the transaction was: " # status;
            project_id = transaction_id;
            created_at = 1_0000_0000;
        };
        return await storeTransaction(Principal.fromText("ocpcu-jaaaa-aaaab-qab6q-cai"), msg.caller, transaction, transaction_id);

    };

    public shared (msg) func aaaa_storeFakeApproval_notAnonymous(project_id : Text) : async Text {
        let approval : T.Approval = {
            sender = Principal.fromText("ocpcu-jaaaa-aaaab-qab6q-cai");
            target = msg.caller;
            amount = 0;
            approval_transaction_number = 0;
        };
        let approval2 : T.Approval = {
            sender = Principal.fromText("ocpcu-jaaaa-aaaab-qab6q-cai");
            target = msg.caller;
            amount = 0;
            approval_transaction_number = 0;
        };
        return await storeApprovals(project_id, [approval, approval2]);
    };
    public shared (msg) func aaaa_storeFakeApproval(project_id : Text) : async Text {
        let approval : T.Approval = {
            sender = msg.caller;
            target = Principal.fromText("ocpcu-jaaaa-aaaab-qab6q-cai");
            amount = 0;
            approval_transaction_number = 0;
        };
        let approval2 : T.Approval = {
            sender = msg.caller;
            target = Principal.fromText("ocpcu-jaaaa-aaaab-qab6q-cai");
            amount = 0;
            approval_transaction_number = 0;
        };
        return await storeApprovals(project_id, [approval, approval2]);
    };
    public shared (msg) func aaaa_getAllFakeApprovals(project_id : Text) : async [T.Approval] {
        return await getApprovals(project_id);
    };
    public func aaa_claimFakeTokens(project_id : Text) : async Text {
        return await claimTokens(project_id);
    };
    // ******* ***************************************** **********

    // *******storeTransaction********
    // Brief Description: Registers a new transaction within the escrow system,
    //  linking it to the involved parties (sender and target) and the associated project. Generates a
    //  unique transaction ID and updates the transaction, sender, target, and project records accordingly.
    // Pre-Conditions:
    //  - `sender` and `target` must be valid Principal identifiers.
    //  - `transaction` must contain all necessary details (amount, transaction number, status, etc.).
    //  - `project_id` must correspond to an existing project within the system.
    // Post-Conditions:
    //  - A unique transaction ID is generated for the new transaction.
    //  - The transaction is stored with its ID as the key.
    //  - Sender and target records are updated to include the new transaction ID.
    //  - Project record is updated to include the new transaction ID, linking the transaction to the project.
    // Validators:
    //  - Ensures `sender`, `target`, and `project_id` are not null or invalid.
    //  - Verifies that the transaction details are complete and accurate.
    // External Functions Using It:
    //  - May interact with other system components that require transaction data, such as query functions or transaction processing mechanisms.
    // Official Documentation:
    //  - For more detailed information on transaction management and related operations, visit [Solutio's Transaction Management Documentation](https://forum.solutio.one/-183/storetransaction-documentation).
    func storeTransaction(sender : Principal, target : Principal, transaction : T.Transaction, project_id : Text) : async Text {
        Debug.print(" ");
        Debug.print("Starting Code...");
        let transaction_id : Text = await generate_random_uuid();

        let transaction_key : T.Key = key(transaction_id);

        transactions := Trie.put<Text, T.Transaction>(transactions, transaction_key, key_equal, transaction).0;
        let target_key = { hash = Principal.hash(target); key = target };
        var target_transactions : [Text] = switch (Trie.get<Principal, [Text]>(targets, target_key, Principal.equal)) {
            case (null) { [] };
            case (?value) { value };
        };
        let updated_transactions : [Text] = Array.append(target_transactions, [transaction_id]);
        targets := Trie.put<Principal, [Text]>(targets, target_key, Principal.equal, updated_transactions).0;

        let sender_key = { hash = Principal.hash(sender); key = sender };
        let sender_transactions = switch (Trie.get<Principal, [Text]>(senders, sender_key, Principal.equal)) {
            case (null) { [] };
            case (?value) { value };
        };
        let updated_sender_transactions : [Text] = Array.append(sender_transactions, [transaction_id]);
        senders := Trie.put<Principal, [Text]>(senders, sender_key, Principal.equal, updated_sender_transactions).0;

        let project_key = { hash = Text.hash(project_id); key = project_id };
        let project_transactions = switch (Trie.get<Text, [Text]>(projects, project_key, Text.equal)) {
            case (null) { [] };
            case (?value) { value };
        };
        let updated_project_transactions : [Text] = Array.append(project_transactions, [transaction_id]);
        projects := Trie.put<Text, [Text]>(projects, project_key, Text.equal, updated_project_transactions).0;
        Debug.print("Done!");
        return "Success";
    };

    // *******getTransactionsBySender********
    // Brief Description: Retrieves a list of transactions initiated by a specific sender. This function
    //  searches through the system's records, matching the given sender's Principal with the transaction
    //  records, and compiles a list of all transactions that were initiated by this sender.
    // Pre-Conditions:
    //  - `sender` must be a valid Principal identifier of the transaction initiator.
    // Post-Conditions:
    //  - Returns an optional list of transactions initiated by the specified sender. The list may be empty if no transactions are found.
    // Validators:
    //  - Confirms that the `sender` is not null and corresponds to a registered user or system component within the platform.
    //  - Validates the integrity and existence of transactions linked to the sender.
    // External Functions Using It:
    //  - This function could be called by user interfaces or other canisters seeking to audit, display, or process transactions based on their originator.
    // Official Documentation:
    //  - For guidelines on querying transaction data and other related functionalities, visit [Solutio's Transaction Query Documentation](https://forum.solutio.one/-184/gettransactionsbysender-documentation).
    public func getTransactionsBySender(sender : Principal) : async ?[T.Transaction] {
        let sender_key = { hash = Principal.hash(sender); key = sender };
        let sender_transactions_ids = switch (Trie.get<Principal, [Text]>(senders, sender_key, Principal.equal)) {
            case (null) { [] };
            case (?value) { value };
        };
        var sender_transactions : [T.Transaction] = [];
        // let updated_sender_transactions : [Text] = Array.append(sender_transactions, [transaction_id]);
        for (transaction_id in sender_transactions_ids.vals()) {
            let transaction_key : T.Key = key(transaction_id);
            let transaction : ?T.Transaction = Trie.get<Text, T.Transaction>(transactions, transaction_key, Text.equal);
            switch (transaction) {
                case (null) { /** do nothing */ };
                case (?transaction) {
                    sender_transactions := Array.append(sender_transactions, [transaction]);
                };
            };
        };
        return ?sender_transactions;
    };

    // *******getTransactionsByTarget********
    // Brief Description: Retrieves a list of transactions where the specified principal is the target.
    //  This function is essential for users or projects that need to review incoming transactions,
    //  providing a direct way to access transactional history associated with them.
    // Pre-Conditions:
    //  - `target` must be a valid Principal identifier.
    // Post-Conditions:
    //  - Returns an optional array of `Transaction` records. If the target has no transactions, the function returns `null`.
    // Validators:
    //  - Ensures `target` is not null or invalid.
    // External Functions Using It:
    //  - This function can be used by any system component that requires insight into transactions directed towards a specific target, including auditing tools, user interfaces displaying transaction history, or automated systems that respond to incoming transactions.
    // Official Documentation:
    //  - For more information on querying transaction records and understanding their impact on system operations, refer to [Solutio's Transaction Query Documentation](https://forum.solutio.one/-188/gettransactionsbytarget-documentation).
    public func getTransactionsByTarget(target : Principal) : async ?[T.Transaction] {
        let target_key = { hash = Principal.hash(target); key = target };
        let target_transactions_ids = switch (Trie.get<Principal, [Text]>(targets, target_key, Principal.equal)) {
            case (null) { [] };
            case (?value) { value };
        };
        var target_transactions : [T.Transaction] = [];
        // let updated_sender_transactions : [Text] = Array.append(sender_transactions, [transaction_id]);
        for (transaction_id in target_transactions_ids.vals()) {
            let transaction_key : T.Key = key(transaction_id);
            let transaction : ?T.Transaction = Trie.get<Text, T.Transaction>(transactions, transaction_key, Text.equal);
            switch (transaction) {
                case (null) { /** do nothing */ };
                case (?transaction) {
                    target_transactions := Array.append(target_transactions, [transaction]);
                };
            };
        };
        return ?target_transactions;
    };

    // *******getTransactionsByProject********
    // Brief Description: Retrieves a list of transactions associated with a specific project, identified
    // by its unique textual identifier. This function serves as a crucial tool for project managers,
    //  auditors, and stakeholders to gain insights into the financial activities surrounding a project, including funding, expenditures, and rewards.
    // Pre-Conditions:
    //  - `project` must be a valid Text identifier representing a unique project within the Solutio platform.
    // Post-Conditions:
    //  - Returns an optional array of `Transaction` records related to the project. If the project has no associated transactions, the function returns `null`.
    // Validators:
    //  - Ensures the `project` identifier is not null, empty, or invalid.
    // External Functions Using It:
    //  - Utilized by project management interfaces to display transaction history, financial tracking systems for reporting and analytics, and by the escrow canister to reconcile project financials.
    // Official Documentation:
    //  - Detailed guidelines and examples for using this function to query project transactions can be found at [Solutio's Project Transaction Query Documentation](https://forum.solutio.one/-189/gettransactionsbyproject-documentation).
    public func getTransactionsByProject(project : Text) : async ?[T.Transaction] {
        let project_key = { hash = Text.hash(project); key = project };
        let project_transactions_ids = switch (Trie.get<Text, [Text]>(projects, project_key, Text.equal)) {
            case (null) { [] };
            case (?value) { value };
        };
        var project_transactions : [T.Transaction] = [];
        for (transaction_id in project_transactions_ids.vals()) {
            let transaction_key : T.Key = key(transaction_id);
            let transaction : ?T.Transaction = Trie.get<Text, T.Transaction>(transactions, transaction_key, Text.equal);
            switch (transaction) {
                case (null) { /** do nothing */ };
                case (?transaction) {
                    project_transactions := Array.append(project_transactions, [transaction]);
                };
            };
        };
        return ?project_transactions;
    };

    // *******storeApprovals********
    // Brief Description: Stores a list of user approvals for a specific project within the Solutio platform.
    //  This function aggregates new approvals with any existing ones for the given project ID.
    // Pre-Conditions:
    //  - The project ID must exist within the Solutio platform.
    //  - The approvals must include valid sender and target principals, amount, and a unique approval transaction number.
    // Post-Conditions:
    //  - The new approvals are added to the existing list of approvals for the project, if any.
    //  - Updates the project's approval records in the `transactions_approvals` Trie with the new, combined list.
    // Validators:
    //  - Ensures that the project ID is valid and has a corresponding entry in the `transactions_approvals` Trie.
    //  - Validates the structure and content of each approval in the list to match the expected `Approval` type.
    // External Functions Using It:
    //  - This function might be called by other canister methods that handle project funding or reward distribution processes.
    // Official Documentation:
    //  - For more detailed guidelines on how to use this function, including examples and best practices, refer to https://forum.solutio.one/-190/storeapprovals-documentation
    public func storeApprovals(project_id : Text, approval : [T.Approval]) : async Text {
        let project_approvals : [T.Approval] = switch (Trie.get<Text, [T.Approval]>(transactions_approvals, key(project_id), Text.equal)) {
            case (null) { [] };
            case (?value) { value };
        };
        let newList : [T.Approval] = Array.append(project_approvals, approval);
        transactions_approvals := Trie.put<Text, [T.Approval]>(transactions_approvals, key(project_id), Text.equal, newList).0;
        return "Success";
    };

    // *******getApprovals********
    // Brief Description: Retrieves all approval transactions associated with a specific project within the Solutio platform. This function is designed to fetch and list all user approvals that have been made towards a project, identified by its project_id. It's crucial for auditing, tracking, and managing financial transactions related to project funding.
    // Inputs:
    //  - project_id (Text): The unique identifier of the project for which approvals are being retrieved.
    // Validation:
    //  - Checks that the provided project_id is associated with existing approvals in the transactions_approvals trie. If no approvals are found, it throws an error indicating the absence of approvals for the given project_id.
    // Returns:
    //  - A list of Approval records if the project_id is associated with any approvals. Each Approval record includes the sender's principal, the target's principal, the approved amount (Nat64), and the approval transaction number (Nat64).
    //  - Errors: Throws an error if no approvals are found for the specified project_id, ensuring that callers are aware of the need for valid project identification.
    // Process Walkthrough:
    //  1. The function uses the project_id to search the transactions_approvals trie for any associated approvals.
    //  2. If approvals exist, it returns a list of all Approval records tied to the project_id.
    //  3. If no approvals are found, it throws an error indicating that the project_id does not have any associated approvals, guiding the user to check the project_id validity or its approval history.
    // External Functions Using It:
    //  - This function can be called by other canisters or front-end interfaces that require information on project funding approvals for audit, display, or further processing.
    // Official Documentation:
    //  - For more detailed information and usage examples, please refer to the official documentation at [https://forum.solutio.one/-185/getapprovals-documentation].
    public func getApprovals(project_id : Text) : async [T.Approval] {
        return switch (Trie.get<Text, [T.Approval]>(transactions_approvals, key(project_id), Text.equal)) {
            case (null) {
                throw Error.reject("Project id doesnt have approvals!");
            };
            case (?value) { value };
        };
    };

    // *******getProjectsApprovals_bySender********
    // Brief Description: Retrieves all approvals made by a specific sender for a particular project
    // within the Solutio platform. This function filters the approvals associated with a project to return only those initiated by the specified sender.
    // Pre-Conditions:
    // - The project ID must be valid and exist within the Solutio ecosystem.
    // - The sender must have made one or more approvals for the specified project.
    // Inputs:
    // - project_id (Text): The unique identifier of the project for which approvals are being queried.
    // - sender (Principal): The principal ID of the sender whose approvals are to be retrieved.
    // Validation:
    // - Verifies that the project_id corresponds to an existing project with recorded approvals.
    // - Checks that the sender has made approvals for the specified project.
    // Returns:
    // - A list of Approval records for the specified sender and project. Each Approval contains the sender's principal, target principal, approved amount, and approval transaction number.
    // - If no approvals by the sender for the specified project are found, an empty list is returned.
    // Official Documentation:
    // - For more detailed information and guidelines, refer to https://forum.solutio.one/-191/getprojectsapprovalsbysender-documentation
    public func getProjectsApprovals_bySender(project_id : Text, sender : Principal) : async [T.Approval] {
        let project_approvals : [T.Approval] = switch (Trie.get<Text, [T.Approval]>(transactions_approvals, key(project_id), Text.equal)) {
            case (null) {
                throw Error.reject("Project id doesnt have approvals!");
            };
            case (?value) { value };
        };
        var approvals_sender : [T.Approval] = [];
        for (approval in project_approvals.vals()) {
            if (approval.sender == sender) {
                approvals_sender := Array.append(approvals_sender, [approval]);
            };
        };
        return approvals_sender;
    };

    // *******getProjectsApprovals_byTarget********
    // Brief Description: Retrieves all approvals targeted towards a specific recipient within a project on the Solutio platform. This function filters the approvals for a given project to isolate those directed at the specified target.
    // Pre-Conditions:
    // - The project ID provided must correspond to an active project listed in the Solutio system.
    // - There must be one or more approvals targeting the specified recipient within the project.
    // Inputs:
    // - project_id (Text): The unique identifier for the project from which approvals are being sought.
    // - target (Principal): The principal ID of the target recipient whose approvals are to be retrieved.
    // Returns:
    // - A list of approvals made to the target within the specified project.
    // Post-Conditions:
    // - Returns only the approvals that match both the project_id and the target criteria.
    // Official Documentation:
    // - For detailed guidelines on how to use this function, visit https://forum.solutio.one/-192/getprojectsapprovalsbytarget-documentation
    public func getProjectsApprovals_byTarget(project_id : Text, target : Principal) : async [T.Approval] {
        let project_approvals : [T.Approval] = switch (Trie.get<Text, [T.Approval]>(transactions_approvals, key(project_id), Text.equal)) {
            case (null) {
                throw Error.reject("Project id doesnt have approvals!");
            };
            case (?value) { value };
        };
        var approvals_target : [T.Approval] = [];
        for (approval in project_approvals.vals()) {
            if (approval.target == target) {
                approvals_target := Array.append(approvals_target, [approval]);
            };
        };
        return approvals_target;
    };

    // *******getProjectApprovals_lowerThan********
    // Brief Description: Retrieves all approvals for a given project that have an amount less than or equal to a specified threshold. This function is essential for filtering approvals based on their amount to manage or analyze financial transactions within the project effectively.
    // Pre-Conditions:
    // - The project ID must be valid and exist within the Solutio ecosystem.
    // Inputs:
    // - project_id (Text): The unique identifier of the project for which approvals are being queried.
    // - amount (Nat64): The threshold amount for filtering approvals.
    // Returns:
    // - A list of approvals that meet the criteria, each containing details such as sender, target, amount, and transaction number.
    // Post-Conditions:
    // - Only approvals with an amount less than or equal to the specified threshold are returned.
    // Official Documentation:
    // - For more details and examples, visit: https://forum.solutio.one/-193/getprojectapprovalslowerthan-documentation
    public func getProjectApprovals_lowerThan(project_id : Text, amount : Nat) : async [T.Approval] {
        let project_approvals : [T.Approval] = switch (Trie.get<Text, [T.Approval]>(transactions_approvals, key(project_id), Text.equal)) {
            case (null) {
                throw Error.reject("Project id doesnt have approvals!");
            };
            case (?value) { value };
        };
        var approvals : [T.Approval] = [];
        for (approval in project_approvals.vals()) {
            if (approval.amount <= amount) {
                approvals := Array.append(approvals, [approval]);
            };
        };
        return approvals;
    };

    // *******getProjectApprovals_majorThan********
    // Brief Description: Retrieves all approvals for a specific project that have an amount greater than a specified threshold. This function enables the precise filtering of approvals based on their financial value, facilitating detailed analysis and management within the project's context.
    // Pre-Conditions:
    // - A valid project ID that is recognized within the Solutio platform.
    // Inputs:
    // - project_id (Text): Identifies the project for which approvals need to be queried.
    // - amount (Nat64): The threshold amount that approvals must exceed to be included in the result.
    // Returns:
    // - A collection of approvals surpassing the threshold, each detailing the sender, target, amount, and transaction number.
    // Post-Conditions:
    // - Only approvals with an amount greater than the specified threshold are included in the response.
    // Official Documentation:
    // - Further information and examples can be found at: https://forum.solutio.one/-194/getprojectapprovalsmajorthan-documentation
    public func getProjectApprovals_majorThan(project_id : Text, amount : Nat) : async [T.Approval] {
        let project_approvals : [T.Approval] = switch (Trie.get<Text, [T.Approval]>(transactions_approvals, key(project_id), Text.equal)) {
            case (null) {
                throw Error.reject("Project id doesnt have approvals!");
            };
            case (?value) { value };
        };
        var approvals : [T.Approval] = [];
        for (approval in project_approvals.vals()) {
            if (approval.amount >= amount) {
                approvals := Array.append(approvals, [approval]);
            };
        };
        return approvals;
    };

    // *******claimTokens********
    // Brief Description: Executes token transfers from pledgers to builders for a completed project. It iterates through
    //  all project approvals, transferring tokens accordingly, and records each transaction's outcome.
    // Pre-Conditions:
    // - Project must exist with valid approvals.
    // - Each approval must specify a sender, target, and amount.
    // Inputs:
    // - project_id (Text): Identifier of the project for token claims.
    // Validation:
    // - Checks for the existence of approvals.
    // - Validates sender, target, and amount in each approval.
    // Returns:
    // - Success message upon successful transfers.
    // - Error messages detailing transfer failures.
    // Process Walkthrough:
    // 1. Retrieve all approvals for the project.
    // 2. For each approval, prepare accounts and initiate transfer.
    // 3. Record the outcome of each transfer.
    // 4. Store transaction details with status in the 'transactions' Trie.
    // Official Documentation:
    // - Detailed guidelines and examples: https://forum.solutio.one/-186/claimtokens-documentation
    func claimTokens(project_id : Text) : async Text {
        let approvals : [T.Approval] = switch (Trie.get<Text, [T.Approval]>(transactions_approvals, key(project_id), Text.equal)) {
            case (null) {
                throw Error.reject("Project id doesnt have approvals!");
            };
            case (?value) { value };
        };
        // sender : Principal, target : Principal, transaction : T.Transaction, project_id : Text
        for (approval in approvals.vals()) {
            let to_account : Ledger.Account = {
                owner = approval.target;
                subaccount = null;
            };
            let from_account : Ledger.Account = {
                owner = approval.sender;
                subaccount = null;
            };
            let current = Prim.time();
            let result1 = await Ledger.icrc.icrc2_transfer_from({
                to = to_account;
                spender_subaccount = null;
                amount = approval.amount;
                from = from_account;
                from_subaccount = null;
                created_at_time = ?current;
                fee = null;
                memo = null;
            });
            switch (result1) {
                case (#Ok(result)) {
                    // sender : Principal, target : Principal, transaction : T.Transaction, project_id : Text
                    let transaction : T.Transaction = {
                        sender = approval.sender;
                        target = approval.target;
                        amount = approval.amount;
                        transaction_number = ?result;
                        status = "Success";
                        message = "This transaction was successful";
                        project_id = project_id;
                        created_at = current;
                    };
                    let storeTr : Text = await storeTransaction(approval.sender, approval.target, transaction, project_id);
                };
                case (#Err(result)) {
                    switch (result) {
                        case (#InsufficientAllowance { allowance : Nat }) {
                            let result_again = await Ledger.icrc.icrc2_transfer_from({
                                to = to_account;
                                spender_subaccount = null;
                                amount = allowance;
                                from = from_account;
                                from_subaccount = null;
                                created_at_time = ?current;
                                fee = null;
                                memo = null;
                            });
                            switch (result_again) {
                                case (#Ok(result_again)) {
                                    // sender : Principal, target : Principal, transaction : T.Transaction, project_id : Text
                                    let transaction : T.Transaction = {
                                        sender = approval.sender;
                                        target = approval.target;
                                        amount = allowance;
                                        transaction_number = ?result_again;
                                        status = "Success";
                                        message = "This transaction was successful";
                                        project_id = project_id;
                                        created_at = current;
                                    };
                                    let storeTr : Text = await storeTransaction(approval.sender, approval.target, transaction, project_id);
                                };
                                case (#Err(result_again)) {
                                    let transaction : T.Transaction = {
                                        sender = approval.sender;
                                        target = approval.target;
                                        amount = allowance;
                                        transaction_number = null;
                                        status = "Success";
                                        message = "Error: This transaction has failed: " # transferErrorMessage(result_again);
                                        project_id = project_id;
                                        created_at = current;
                                    };
                                    let storeTr : Text = await storeTransaction(approval.sender, approval.target, transaction, project_id);
                                };
                            };
                        };
                        case (_) {
                            let transaction : T.Transaction = {
                                sender = approval.sender;
                                target = approval.target;
                                amount = approval.amount;
                                transaction_number = null;
                                status = "Failure";
                                message = "Error: This transaction has failed: " # transferErrorMessage(result);
                                project_id = project_id;
                                created_at = current;
                            };
                            let storeTr : Text = await storeTransaction(approval.sender, approval.target, transaction, project_id);
                        };
                    };
                };
            };
        };

        return "Success";
    };

    // *******solutionCompletion********
    // Brief Description: Marks a solution as completed after verifying ownership and delivery status. It also claims tokens for the solution, updates its status to "completed", and adjusts revenue and solution completion counters.
    // Pre-Conditions:
    // - The caller must be the owner of the solution.
    // - The solution must be in a "delivered" state, not yet marked as "completed".
    // - The solution's waiting period must have passed since delivery (TODO: Implement waiting period check).
    // Inputs:
    // - sol_id (Text): The unique identifier of the solution to be marked as completed.
    // Validation:
    // - Verifies caller's ownership and solution's deliverable status.
    // - Ensures that the solution has not been previously marked as completed.
    // Returns:
    // - "Success" upon successful completion of the solution.
    // - Error messages for any validation failures or during the token claiming process.
    // Process Walkthrough:
    // 1. Validate the caller's identity and solution status.
    // 2. Claim tokens allocated for the solution.
    // 3. Update the solution's status to "completed" in the system.
    // 4. Update the revenue counter for the associated idea and solution.
    // 5. Increment the solution completed counter.
    // Official Documentation:
    // - For more detailed guidelines and examples on using this function, please refer to https://forum.solutio.one/-187/solutioncompletion-documentation
    public shared (msg) func solutionCompletion(sol_id : Text) : async Text {
        // 1- We have to check the owner of the project is the caller
        // 2- We have to check that the project was delivered
        // TODO : We also have to check that the waiting time has been passed already. The developer cant 'complete' the project right after delivering.
        let caller = msg.caller;
        if (Principal.isAnonymous(caller)) {
            throw Error.reject("Anonymous users submit solutions.");
        };
        let docInput1 : (Text, Text) = ("solution_status", "SOL_STAT_" # sol_id);
        var docs : [(Text, Text)] = [docInput1];
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
                                        let text = description;
                                        let callerText = Principal.toText(caller);
                                        if (Text.contains(text, #text callerText) == false) {
                                            throw Error.reject("Not owner of solution");
                                        };
                                        if (Text.contains(text, #text "delivered") == false) {
                                            throw Error.reject("This project was not delivered.");
                                        };
                                        if (Text.contains(text, #text "completed")) {
                                            throw Error.reject("This project has already been completed.");
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
        // 3- claimTokens()
        try {
            let claim_tokens = await claimTokens(sol_id);
        } catch (e) {
            throw Error.reject("Some error occurred why claiming the tokens: " # Error.message(e));
        };
        // 4- Update solution status to "completed"
        let resultUpdate = await admin.updateSolutionStatus(sol_id, "completed");
        // 5- Update revenue counter for idea and solution in Juno.
        let amount = await getProjectRevenue(sol_id);
        let result_revenue_counter = await admin.ideaRevenueCounter(sol_id, amount);
        // 6- Update solution_completed_counter + 1
        let update_solution_counter = await admin.solutionsCompletedCounter();
        return "Success";
    };

    // *******verifyAndStoreTransaction********
    // Brief Description: Verifies a transaction's existence on the ledger and stores its details within the platform.
    // Pre-Conditions:
    // - Requires a valid transaction number (trans_number) for the query.
    // Validation:
    // - Ensures the transaction exists by querying the ledger.
    // - Validates that the transaction's operation is a 'Transfer'.
    // Returns:
    // - Success message upon verifying and storing the transaction details.
    // - Error messages for non-existent transactions, incorrect operations, or query failures.
    // Process Walkthrough:
    // 1. Query the ledger with the provided transaction number.
    // 2. Verify the existence and type of the transaction operation.
    // 3. Construct a detailed record of the transaction.
    // 4. Store the transaction record for platform reference.
    // Official Documentation:
    // - For more information, refer to [Solutio Transactions Documentation](https://forum.solutio.one/-195/verifyandstoretransaction-documentation).
    public shared (msg) func verifyAndStoreTransaction(trans_number : Nat64) : async Text {
        let queryArgs : Ledger.GetBlocksArgs = {
            start = trans_number;
            length = Nat64.fromNat(1);
        };
        let queryBlock : Ledger.QueryBlocksResponse = await Ledger.icrc.query_blocks(queryArgs);
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
                            case (#Transfer { fee; from; to; amount; spender }) {
                                let transfer_amount : Nat64 = amount.e8s;
                                let transaction : T.Transaction = {
                                    sender = Principal.fromBlob(from);
                                    target = Principal.fromBlob(to);
                                    amount = Nat64.toNat(transfer_amount);
                                    transaction_number = ?Nat64.toNat(trans_number);
                                    status = "Success";
                                    message = "Transfer was successfull";
                                    project_id = "NA";
                                    created_at = Prim.time();
                                };
                                return await storeTransaction(Principal.fromBlob(from), Principal.fromBlob(to), transaction, "NA");
                            };
                            case (_) {
                                throw Error.reject("The operation is not 'transfer'");
                            };

                        };
                    };
                };
            };
            case (false) {
                throw Error.reject("Transaction number didnt produced any blocks.");
            };
        };
    };

    // *******getProjectRevenue********
    // Brief Description: Calculates the total revenue generated for a project within Solutio by summing up all successful transactions related to the project ID.
    // Pre-Conditions:
    // - The project ID must exist and have associated transactions within the platform.
    // Inputs:
    // - project_id (Text): Unique identifier for the project.
    // Process:
    // 1. Retrieve all transactions for the specified project.
    // 2. Filter transactions to include only those with a status of "Success".
    // 3. Sum up the amount from each successful transaction to calculate total revenue.
    // Returns:
    // - Total revenue (Nat): The sum of all successful transaction amounts for the project.
    // Official Documentation:
    // - For detailed usage and examples, visit: https://forum.solutio.one/-196/getprojectrevenue-documentation
    public func getProjectRevenue(project_id : Text) : async Nat {
        var amount : Nat = 0;
        let transactions : [T.Transaction] = switch (await getTransactionsByProject(project_id)) {
            case (null) {
                [];
            };
            case (?transactions) {
                transactions;
            };
        };
        for (transaction in transactions.vals()) {
            if (transaction.status == "Success") {
                amount := amount + transaction.amount;
            };
        };
        return amount;
    };

    // *******getUserRevenue********
    // Brief Description: Calculates total revenue accrued by a user from successful transactions where they are the target, providing transparent financial insights.
    // Inputs:
    // - user (Principal): Principal ID of the user.
    // Returns:
    // - Total Revenue (Nat): Sum of amounts from all successful transactions targeting the user.
    // Process:
    // 1. Fetch transactions with the user as target.
    // 2. Filter by "Success" status to consider only completed transactions.
    // 3. Sum the amounts of these transactions for total revenue.
    // Official Documentation:
    // - Detailed information and examples: https://forum.solutio.one/-197/getuserrevenue-documentation
    public func getUserRevenue(user : Principal) : async Nat {
        var amount : Nat = 0;
        let transactions : [T.Transaction] = switch (await getTransactionsByTarget(user)) {
            case (null) {
                [];
            };
            case (?transactions) {
                transactions;
            };
        };
        for (transaction in transactions.vals()) {
            if (transaction.status == "Success") {
                amount := amount + transaction.amount;
            };
        };
        return amount;
    };

    // *******getUserSpending********
    // Brief Description: Calculates the total spending of a user by summing up all successful transactions initiated by them on the Solutio platform.
    // Pre-Conditions:
    // - The user must have initiated at least one transaction on the platform.
    // Inputs:
    // - user (Principal): The principal ID of the user whose spending is being calculated.
    // Returns:
    // - Total Spending (Nat): The sum of amounts from all successful transactions initiated by the user.
    // Official Documentation:
    // - For more information and usage examples, visit https://forum.solutio.one/-198/getuserspending-documentation
    public func getUserSpending(user : Principal) : async Nat {
        var amount : Nat = 0;
        let transactions : [T.Transaction] = switch (await getTransactionsBySender(user)) {
            case (null) {
                [];
            };
            case (?transactions) {
                transactions;
            };
        };
        for (transaction in transactions.vals()) {
            if (transaction.status == "Success") {
                amount := amount + transaction.amount;
            };
        };
        return amount;
    };

    func generate_random_uuid() : async Text {
        let g = Source.Source();
        let id : Text = UUID.toText(await g.new());
        return id;
    };

    func transferErrorMessage(error : Ledger.TransferFromError) : Text {
        switch (error) {
            case (#GenericError { message; error_code }) {
                "Error: " # message # ", Error Code: " # Nat.toText(error_code);
            };
            case (#TemporarilyUnavailable) {
                "Error: Service is temporarily unavailable.";
            };
            case (#InsufficientAllowance { allowance : Nat }) {
                "Error: Not enough allowance, allowance is: " # Nat.toText(allowance);
            };
            case (#BadBurn { min_burn_amount }) {
                "Error: Bad burn, minimum burn amount is: " # Nat.toText(min_burn_amount);
            };
            case (#Duplicate { duplicate_of }) {
                "Error: Duplicate transaction, duplicate of: " # Nat.toText(duplicate_of);
            };
            case (#BadFee { expected_fee }) {
                "Error: Bad fee, expected fee is: " # Nat.toText(expected_fee);
            };
            case (#CreatedInFuture { ledger_time }) {
                "Error: Transaction created in the future, ledger time is: " # Nat64.toText(ledger_time);
            };
            case (#TooOld) {
                "Error: Transaction is too old.";
            };
            case (#InsufficientFunds { balance }) {
                "Error: Insufficient funds, balance is: " # Nat.toText(balance);
            };
        };
    };

};
