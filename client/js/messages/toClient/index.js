import AddMessage, {PLATFORM} from "./addMessage.js";
import Reader from "../../Reader.js";
import Result, { err, ok } from "../../Result.js";

/**
 * 
 * @param {Reader} reader
 * @returns {Result.<{type: "add_message", msg: AddMessage}, UnknownMessageId | unknown>}
 */
function readMessage(reader) {
  const msgId = reader.readU8().try();
  switch(msgId) {
    case 0: {
      return ok({
        type: "add_message",
        msg: AddMessage.deserialize(reader).try(),
      });
    }
    default: {
      return err(new UnknownMessageId(msgId));
    }
  }
}

class UnknownMessageId extends Error {
  name = "UnknownMessageId";

  /**
   * 
   * @param {number} id The unknown message id
   */
  constructor(id) {
    super(`Unknown message id ${id}!`);
    this.id = id;
  }
}

export default {
  readMessage,
  AddMessage,
  PLATFORM,
}
