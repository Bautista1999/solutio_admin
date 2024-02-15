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
  public func setManyDocs(docs : T.SetManyDocsInput) : async Text {
    return await bridge.setManyJunoDocs(docs);
  };
  public func getManyDocs(docsInput : T.GetManyDocsInput) : async T.GetManyDocsResult {
    return await bridge.getManyJunoDocs(docsInput);
  };
  public func listDocs(collection : Text, filter : T.ListDocsFilter) : async T.ListDocsResult {
    return await bridge.listJunoDocs(collection, filter);
  };
  public func updateDocument(collection : Text, key : Text, docsInput : T.DocInput) : async Text {
    return await bridge.updateJunoDocument(collection, key, docsInput);
  };
  public func updateManyDocs(docs : [T.CollectionKeyPair]) : async Text {
    return await bridge.updateManyJunoDocs(docs);
  };
  public func deleteDoc(collection : Text, key : Text) : async Text {
    return await bridge.deleteJunoDoc(collection, key);
  };
  public func deleteManyDocs(docs : [(Text, Text, { updated_at : ?Nat64 })]) : async Text {
    return await bridge.deleteManyJunoDocs(docs);
  };
};
