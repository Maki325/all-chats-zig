import Reader from "../../Reader.js";
import {wrapResult} from "../../Result.js";

export default class AddMessage {
  /** @type {number} */
  id;
  /** @type {number} */
  platform;
  /** @type {string} */
  platformMessageId;
  /** @type {string} */
  channelId;
  /** @type {string} */
  authorId;
  /** @type {string} */
  author;
  /** @type {string} */
  message;
  /** @type {number} */
  timestampType;
  /** @type {number} */
  timestamp;

  getTrimmedMessage() {
    if(this.message.length <= 500) return this.message;
    return this.message.substring(0, 497) + "...";
  }

  getTrimmedAuthor() {
    if(this.author.length <= 25) return this.author;
    return author.substring(0, 22) + "...";
  }

  static deserialize = wrapResult(deserialize);
}

export const PLATFORM = {
  YOUTUBE: 0,
  TWITCH: 1,
};

/**
 * 
 * @param {Reader} reader 
 * @returns {AddMessage}
 */
function deserialize(reader) {
  const id = reader.readU64().try();
  const platform = reader.readU8().try();
  const platformMessageId = reader.readString().try();
  const channelId = reader.readString().try();
  const authorId = reader.readString().try();
  const author = reader.readString().try();
  const message = reader.readString().try();
  const timestampType = reader.readU8().try();
  const timestamp = reader.readU64().try();

  const msg = new AddMessage();
  msg.id = id;
  msg.platform = platform;
  msg.platformMessageId = platformMessageId;
  msg.channelId = channelId;
  msg.authorId = authorId;
  msg.author = author;
  msg.message = message;
  msg.timestampType = timestampType;
  msg.timestamp = timestamp;

  return msg;
}
