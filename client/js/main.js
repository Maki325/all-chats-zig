import Reader from "./Reader.js";
import { wrapResult } from "./Result.js";
import messages from "./messages/toClient/index.js";

/** @type {HTMLDivElement} */
const container = document.getElementById("container");

const HOST = "127.0.0.1";

window.onload = function init() {
  const ws = new WebSocket(`ws://${HOST}:5882/ws`);
  ws.binaryType = "arraybuffer";
  ws.onopen = e => console.log('Websocket connection opened:', e);
  ws.onerror = (e) => console.log("Websocket error:", e);
  ws.addEventListener('message', (event) => {
    if(event.data instanceof ArrayBuffer) {
      const error = handleData(new Reader(new DataView(event.data))).err();
      if(error) {
        console.log("There was an error while handling websocket data:", error, event.data);
      }
    }
  });
}

const handleData = wrapResult(_handleData);

/**
 * @param {Reader} reader 
 */
function _handleData(reader) {
  const message = messages.readMessage(reader).try();
  console.log("Message:", message);

  switch(message.type) {
    case 'add_message': {
      /** @type {HTMLTemplateElement} */
      const template = document.getElementById("msg");
      /** @type {HTMLDivElement} */
      const clone = template.content.cloneNode(true);

      clone.querySelector(".msg-author").textContent = message.msg.getTrimmedAuthor();
      clone.querySelector(".msg-text").textContent = message.msg.getTrimmedMessage();

      switch(message.msg.platform) {
        case messages.PLATFORM.YOUTUBE: {
          clone.querySelector(".msg-icon").src = "./youtube.svg";
          break;
        }
        case messages.PLATFORM.TWITCH: {
          clone.querySelector(".msg-icon").src = "./twitch-purple.svg";
          break;
        }
      }

      container.appendChild(clone);

      window.scrollTo(0, container.clientHeight)
      break;
    }
  }
  return;
}
