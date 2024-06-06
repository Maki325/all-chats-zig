/**
 * @template T
 * @template E
 * */
export class Result {
  /** @type {boolean} */
  isSuccessful

  /** @type {T | E} */
  #dataOrError

  /**
   * 
   * @param {boolean} isSuccessfull
   * @param {T | E} dataOrError
   */
  constructor(isSuccessful, dataOrError) {
    this.isSuccessful = isSuccessful;
    this.#dataOrError = dataOrError;
  }

  /**
   * @returns {T}
   */
  unwrap() {
    if(!this.isSuccessful){
      throw "Couldn't unwrap value!";
    }
    return this.#dataOrError;
  }

  /**
   * 
   * @param {(T) => T} f
   * @returns {Result.<T, E>}
   */
  map(f) {
    if(!this.isSuccessful) {
      return this;
    }
    this.#dataOrError = f(this.#dataOrError);
    return this;
  }

  /**
   * @returns {T}
   */
  try() {
    if(!this.isSuccessful){
      throw new BubbleError(this.#dataOrError);
    }
    return this.#dataOrError;
  }

  /**
   * Returns the error if the Result isn't successful
   * Otherwise returns null
   * @returns {E | null}
   */
  err() {
    if(this.isSuccessful) {
      return null;
    }
    return this.#dataOrError;
  }

  /**
   * Returns the result if the Result is successful
   * Otherwise returns null
   * @returns {T | null}
   */
  ok() {
    if(!this.isSuccessful) {
      return null;
    }
    return this.#dataOrError;
  }
}

export class BubbleError extends Error {
  /** @type {Error | undefined} inner */
  constructor(inner) {
    super("Bubbling error");
    this.name = "Bubble";
    this.inner = inner;
  }
}

/**
 * @template {E}
 * @param {E} error
 * @returns {Result.<never, E>}
 */
export function err(error) {
  return new Result(false, error);
}

/**
 * @template {T}
 * @param {T} data
 * @returns {Result.<T, never>}
 */
export function ok(data) {
  return new Result(true, data);
}

/**
 * @template F
 * @param {F} f
 * @returns {(...a: Parameters<F>) => Result.<ReturnType<F>, unknown>}
 */
export function wrapResult(f) {
  const a = () => {};
  a.ap
  return function() {
    try {
      const result = f.apply(this, arguments);
      if(result instanceof Result) {
        return result;
      }
      return ok(result);
    } catch(e) {
      return err(e);
    }
  }
}

/**
 * 
 * @param {number} a 
 * @returns
 */
const a = (a) => a + 5;

const b = wrapResult(a);

export default Result;
