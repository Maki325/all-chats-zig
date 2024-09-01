module.exports = {
  apps : [
    {
      name   : "Combining Chats - Server",
      script : "./combining-chats",
    },
    {
      name   : "Combining Chats - Twitch",
      script : "./bot-twitch",
    },
    {
      name   : "Combining Chats - YouTube",
      script : "./bot-youtube",
      args   : "VHsKEx8sbO8",
    },
    {
      name   : "Combining Chats - Client",
      script : "python3 -m http.server --directory ./client 2536"
    }
  ]
}
