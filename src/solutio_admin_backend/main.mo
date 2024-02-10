import T "./types";
import bridge "./juno.bridge";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";

actor Admin {

  public shared (msg) func setDoc(collection : Text, key : Text, doc : T.DocInput) : async Text {
    Debug.print(Principal.toText(msg.caller));
    return await bridge.setJunoDoc(collection, key, doc);
  };
  public shared (msg) func getDoc(collection : Text, key : Text) : async T.GetDocResult {
    return await bridge.getJunoDoc(collection, key);
  };

};
