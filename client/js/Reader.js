import Result, { ok, err, wrapResult } from "./Result.js";

export default class Reader {
  /**
   * @type {DataView}
   */
  #dataView;
  #position = 0;

  /**
   * @param {DataView} dataView
   */
  constructor(dataView) {
    this.#dataView = dataView;
    this.#position = 0;
  }

  /** @returns {Result.<number>} */
  readU8() {
    if(this.#position >= this.#dataView.byteLength) {
      return err(new EndOfStream());
    }
    return ok(this.#dataView.getUint8(this.#position++));
  }

  /** @returns {Result.<number>} */
  readU16() {
    const NUMBER_OF_BYTES = 2;
    if(this.#position + NUMBER_OF_BYTES > this.#dataView.byteLength) {
      return err(new EndOfStream());
    }
    const value = this.#dataView.getUint16(this.#position);
    this.#position += NUMBER_OF_BYTES;
    return ok(value);
  }

  /** @returns {Result.<number>} */
  readU32() {
    const NUMBER_OF_BYTES = 4;
    if(this.#position + NUMBER_OF_BYTES > this.#dataView.byteLength) {
      return err(new EndOfStream());
    }
    const value = this.#dataView.getUint32(this.#position);
    this.#position += NUMBER_OF_BYTES;
    return ok(value);
  }

  /** @returns {Result.<bigint>} */
  readU64() {
    const NUMBER_OF_BYTES = 8;
    if(this.#position + NUMBER_OF_BYTES > this.#dataView.byteLength) {
      return err(new EndOfStream());
    }
    const value = this.#dataView.getBigUint64(this.#position);
    this.#position += NUMBER_OF_BYTES;
    return ok(value);
  }

  readArray = wrapResult(() => {
    const len = this.readU64().try();
    const arr = new Array(Number(len));
    for(let i = 0;i < len;i++) {
      arr[i] = this.readU8().try();
    }

    return arr;
  })

  /** @returns {Result.<string>} */
  readString = wrapResult(() => {
    return ok(String.fromCharCode(...this.readArray().try()));
  });
}

export class EndOfStream extends Error {
  constructor() {
    super("Reader has reached end of byte buffer!");
    this.name = "EndOfStream";
  }
}
