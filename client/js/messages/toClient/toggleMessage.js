import Reader from "../../Reader.js";
import {wrapResult} from "../../Result.js";

export default class ToggleMessage {
  /** @type {number} */
  id;
  /** @type {boolean} */
  visible;

  static deserialize = wrapResult(deserialize);
}

/**
 * 
 * @param {Reader} reader 
 * @returns {ToggleMessage}
 */
function deserialize(reader) {
  const id = reader.readU64().try();
  const visible = reader.readU8().try();

  const msg = new ToggleMessage();
  msg.id = id;
  msg.visible = visible !== 0;

  return msg;
}
