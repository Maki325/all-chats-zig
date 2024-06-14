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
  /** @type {bigint} */
  timestamp;

  getTrimmedMessage(maxLen = 500) {
    if(this.message.length <= maxLen) return this.message;
    return this.message.substring(0, maxLen - 3) + "...";
  }

  getTrimmedAuthor() {
    if(this.author.length <= 25) return this.author;
    return author.substring(0, 22) + "...";
  }

  getAuthorLink() {
    switch(this.platform) {
      case PLATFORM.TWITCH: {
        return `https://twitch.tv/${this.author}`;
      }
      case PLATFORM.YOUTUBE: {
        return `https://youtube.com/channel/${this.authorId}`;
      }
      default: return "Unknown Platform!";
    }
  }

  getDate() {
    return AddMessage.timestampToDate(this.timestamp, this.timestampType);
  }

  /**
   * 
   * @param {bigint} timestamp 
   * @param {bigint} timestampType 
   * @returns {Date}
   */
  static timestampToDate(timestamp, timestampType) {
    switch(timestampType) {
      case TIMESTAMP_TYPE.Second: {
        return new Date(Number(timestamp * 1_000n));
      }
      case TIMESTAMP_TYPE.Milisecond: {
        return new Date(Number(timestamp));
      }
      case TIMESTAMP_TYPE.Microsecond: {
        return new Date(Number(timestamp / 1_000n));
      }
      case TIMESTAMP_TYPE.Nanosecond: {
        return new Date(Number(timestamp / 1_000_000n));
      }
      default: return new Date(0);
    }
  }

  static deserialize = wrapResult(deserialize);
}

export const PLATFORM = {
  YOUTUBE: 0,
  TWITCH: 1,
};

export const TIMESTAMP_TYPE = {
  Second: 0,
  Milisecond: 1,
  Microsecond: 2,
  Nanosecond: 3,
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
