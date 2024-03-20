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
import Principal "mo:base/Principal";
import Source "mo:uuid/async/SourceV4";
import UUID "mo:uuid/UUID";
import bridge "./juno.bridge";
import enc "./encoding";

module {

    // *******createPersonalNotification********
    // Brief Description: Facilitates the creation of a personalized notification for a specified target user within the Solutio platform, uniquely identified by a random UUID, and saves it to the database.
    // Pre-Conditions:
    //  - Sender and target identifiers (Text) must specify the origin and intended recipient of the notification.
    //  - Notification content must adhere to the T.Notification type structure, encapsulating all relevant information.
    // Post-Conditions:
    //  - Successfully creates a new document in the "notification" collection, associating it with a unique UUID, the encoded notification data, and the target user's identifier.
    //  - Stores the notification in the database for future retrieval and presentation to the target user.
    // Validators:
    //  - Validates the format of the sender and target identifiers to ensure they are valid Text strings.
    //  - Ensures the notification data is properly encoded and structured according to the T.Notification type requirements.
    // External Functions Using It:
    //  - This function is integral for sending system-wide or user-specific notifications related to updates, interactions, or alerts within the Solutio platform.
    // Official Documentation:
    //  - Detailed documentation on the createPersonalNotification function's parameters, usage, and examples can be found at https://forum.solutio.one/-180/createpersonalnotification-documentation
    public func createPersonalNotification(sender : Text, target : Text, notification : T.Notification) : async Text {
        if (Principal.isAnonymous(Principal.fromText(sender))) {
            throw Error.reject("Anonymous users cannot create pledges.");
        };
        let g = Source.Source();
        let noti_id : Text = await generate_random_uuid();
        let data : Blob = await enc.notificationEncode(notification);
        let doc : T.DocInput = {
            updated_at = null;
            data = data;
            description = ?target;
        };
        return await bridge.setJunoDoc("notification", noti_id, doc);

    };

    // *******createGlobalNotification********
    // Brief Description: Generates a global notification linked to a specific idea within the Solutio platform. It targets all users following the idea, effectively distributing notifications based on the element_id (idea_id).
    // Pre-Conditions:
    //  - The element_id must correspond to a valid idea existing within the platform.
    //  - Notification content should conform to the T.Notification type, encapsulating the message or update meant for the followers of the idea.
    // Post-Conditions:
    //  - A new document is created in the "notification" collection with a unique UUID. It contains the encoded notification content and is tagged with the idea's element_id.
    //  - This global notification is stored in the database, becoming accessible to all users following the associated idea.
    // Validators:
    //  - Checks for the existence of the element_id to ensure it's linked to an existing idea on the platform.
    //  - Ensures the notification is properly encoded according to the T.Notification type, maintaining data integrity.
    // External Functions Using It:
    //  - Integral for updating users about significant events, updates, or interactions related to ideas they follow, enhancing community engagement and information dissemination.
    // Official Documentation:
    //  - For a comprehensive guide on utilizing the createGlobalNotification function, including parameter details and usage examples, visit https://forum.solutio.one/-181/createglobalnotification-documentation
    public func createGlobalNotification(element_id : Text, notification : T.Notification) : async Text {
        let g = Source.Source();
        let noti_id : Text = await generate_random_uuid();
        let data : Blob = await enc.notificationEncode(notification);
        let doc : T.DocInput = {
            updated_at = null;
            data = data;
            description = ?element_id;
        };
        return await bridge.setJunoDoc("notification", noti_id, doc);
    };

    public func generate_random_uuid() : async Text {
        let g = Source.Source();
        let id : Text = UUID.toText(await g.new());
    };
};
