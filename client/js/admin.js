import Reader from "./Reader.js";
import { wrapResult } from "./Result.js";
import messages from "./messages/toClient/index.js";

/** @type {HTMLDivElement} */
const container = document.getElementById("messages");

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
      const msg = message.msg;
      /** @type {HTMLTemplateElement} */
      const template = document.getElementById("msg");
      /** @type {HTMLDivElement} */
      const clone = template.content.cloneNode(true);

      const tr = clone.querySelector("tr");
      tr.id = `msg-${msg.id}`;

      clone.querySelector(".msg-id").textContent = msg.id;
      clone.querySelector(".msg-platform-icon").src = PLATFORM_ICON[msg.platform] ?? 'Unknown';

      /** @type {HTMLAnchorElement} */
      const sender = clone.querySelector(".msg-sender");
      sender.textContent = msg.getTrimmedAuthor();
      sender.href = msg.getAuthorLink();

      clone.querySelector(".msg-text").textContent = msg.getTrimmedMessage(100);
      clone.querySelector(".msg-timestamp").textContent = formatDate(msg.getDate());
      clone.querySelector(".msg-timestamp").id = `msg-timestamp-${msg.id}`;

      const action = clone.querySelector(".msg-action");
      action.setAttribute("hx-post", `/messages/${msg.id}/toggle`);
      action.setAttribute("hx-target", `#msg-${msg.id}`);

      container.prepend(clone);

      window.htmx.process(tr);

      window.scrollBy({top: -clone.clientHeight});
      break;
    }
  }
  return;
}

function formatDate(date) {
  if(!date || isNaN(date)) return "Invalid date!";
  return `${date.getFullYear()}/${fillNum(date.getMonth() + 1, 2)}/${fillNum(date.getDate(), 2)} ${fillNum(date.getHours(), 2)}:${fillNum(date.getMinutes(), 2)}:${fillNum(date.getSeconds(), 2)}.${fillNum(date.getMilliseconds(), 3)}`;
}

function fillNum(number, spaces) {
  const string = new String(number);
  if(string.length >= spaces) return string;
  return new Array(spaces - string.length + 1).join("0") + string;
}

const PLATFORM_ICON = [
  "./youtube.svg",
  "./twitch-purple.svg",
]
